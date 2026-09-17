// 默认数据库文件位置解析（需求：库默认落在系统 Download/渐离App，重装不丢数据）
//
// 与 core/storage/public_downloads.dart 同一套「所有文件访问」判定：
// - Android API30+ 且已授权 MANAGE_EXTERNAL_STORAGE → 系统 Download/渐离App/db.sqlite；
//   该目录不在应用沙盒内，应用卸载/重装不会被清，文件管理器可直接看到。
// - 否则（未授权 / 非 Android）→ 回退沙盒 filesDir/databases/db.sqlite，
//   与旧版行为一致，不丢现有数据。
//
// 首启迁移：目标文件不存在时，从候选源里挑「修改时间最新」的一个做**单向拷贝**，
// 兼容历史落位（documents/app_flutter → filesDir/databases）与权限来回切换，
// 避免「沙盒旧副本覆盖 Download 新数据」导致静默丢数据。
//
// ⚠️ 与 public_downloads 的区别：那里写的是「导出给用户看的媒体/文本」，
// 这里写的是「应用自己的活动数据库」——不要对 db.sqlite 调 MediaStore 扫描
//（它不是媒体，扫进图库无意义），也不要把它当导出物处理。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../android/media_scan.dart' show getAndroidSdkInt;
import '../storage/public_downloads.dart'
    show ensurePublicDownloadsPermission, hasPublicDownloadsAccess;
import 'app_database.dart';

/// 公共 Download 子目录名（专用于本机数据库，与传书/互传/导出目录区分）
const String kDbDirName = '渐离App';

/// 数据库文件名
const String kDbFileName = 'db.sqlite';

/// basic_info 标记：首启是否已询问过「所有文件访问」权限（只弹一次）
const String kDbFirstRunPermAsked = 'dbFirstRunPermAsked';

/// 公共 Download 上的数据库目录（仅 Android 且已授权时可达）
Directory get _publicDbDir => Directory('/storage/emulated/0/Download/$kDbDirName');

/// 解析默认数据库文件（异步；由 AppDatabase._openConnection 的 LazyDatabase 首次查询时调用）。
///
/// 返回最终落盘的文件；若该文件尚不存在，则做一次「最新候选源」单向拷贝，
/// 保证老用户升级 / 权限变更后数据不丢。
Future<File> resolveDefaultDatabaseFile() async {
  final target = await _targetFile();
  if (await target.exists()) return target;
  final source = await _newestReadableSource();
  await target.parent.create(recursive: true);
  if (source != null) {
    // 单向拷贝：拷贝失败也不破坏任何已有数据（源保留、目标为空则后续由 drift 建表）
    try {
      await source.copy(target.path);
    } catch (_) {
      // 拷贝失败（如权限被中途收回）→ 退回空库，drift onCreate 重建空表，不崩
    }
  }
  return target;
}

/// 目标落盘位置：公共 Download（已授权）或沙盒 filesDir/databases。
Future<File> _targetFile() async {
  if (Platform.isAndroid && await hasPublicDownloadsAccess()) {
    return File(p.join(_publicDbDir.path, kDbFileName));
  }
  final support = await getApplicationSupportDirectory();
  return File(p.join(support.path, 'databases', kDbFileName));
}

/// 当前是否把活动库放在公共 Download（用于 UI 展示存储模式）
Future<bool> isUsingSharedStorage() async =>
    Platform.isAndroid && await hasPublicDownloadsAccess();

/// 候选源：沙盒当前位置、更旧 documents/app_flutter、以及（本进程当前可读时）公共 Download。
/// 返回其中「修改时间最新」且当前可读的一个；都为空返回 null。
Future<File?> _newestReadableSource() async {
  final candidates = <File>[];
  final support = await getApplicationSupportDirectory();
  candidates.add(File(p.join(support.path, 'databases', kDbFileName)));
  final docs = await getApplicationDocumentsDirectory();
  candidates.add(File(p.join(docs.path, kDbFileName)));
  // 公共 Download 仅当本进程当前可读时才纳入（否则拿到路径也拷不了）
  if (await hasPublicDownloadsAccess()) {
    candidates.add(File(p.join(_publicDbDir.path, kDbFileName)));
  }
  File? newest;
  int? newestMs;
  for (final c in candidates) {
    if (await c.exists()) {
      final ms = await c.lastModified();
      if (newestMs == null || ms.millisecondsSinceEpoch > newestMs) {
        newestMs = ms.millisecondsSinceEpoch;
        newest = c;
      }
    }
  }
  return newest;
}

/// 把当前活动库迁移到公共 Download（数据管理页「迁移到公共存储」按钮）。
///
/// 先申请「所有文件访问」；授权后由 [resolveDefaultDatabaseFile] 自动把沙盒副本
/// 拷到 Download（目标缺失 → 拷贝最新源）。数据库是单例热连接，迁移后须重启 App
/// 才能切到 Download 上的库；重启前的新写入仍落沙盒，重启后自动读 Download。
Future<({bool ok, String message})> migrateToSharedStorage() async {
  await ensurePublicDownloadsPermission();
  if (!await hasPublicDownloadsAccess()) {
    return (
      ok: false,
      message: '未获得「所有文件访问」权限，无法迁移到公共存储。'
          '请到系统设置授予后重试。',
    );
  }
  // 触发一次落位：若 Download 尚不存在，会把当前可读的最新副本拷过去。
  await resolveDefaultDatabaseFile();
  final downloadDb = File(p.join(_publicDbDir.path, kDbFileName));
  if (await downloadDb.exists()) {
    return (
      ok: true,
      message: '已迁移到公共存储 Download/渐离App/db.sqlite，'
          '请完全退出并重新打开 App 以生效。',
    );
  }
  return (ok: false, message: '迁移失败：无法在公共存储创建数据库文件。');
}

/// 当前活动库文件的展示路径（沙盒或直接 Download 路径），用于「数据管理」页展示。
Future<String> describeDatabasePath() async {
  final f = await resolveDefaultDatabaseFile();
  return f.path;
}

/// 首启尝试申请「所有文件访问」，让库默认落在 Download。
///
/// 仅弹一次：用 basic_info(kDbFirstRunPermAsked) 标记去重；只在 Android API30+ 且
/// 当前未授权时弹。已授权或 ≤29（传统存储权限即可写 Download）直接落标记返回。
/// 不阻塞 UI（调用方应在首帧回调里 fire-and-forget，不要 await 阻断首屏）。
Future<void> requestDbStoragePermissionOnce(AppDatabase db) async {
  if (!Platform.isAndroid) return;
  if (await hasPublicDownloadsAccess()) {
    await _markFirstRun(db);
    return;
  }
  final sdk = await getAndroidSdkInt();
  if (sdk < 30) {
    await _markFirstRun(db);
    return;
  }
  final asked = await _readFlag(db, kDbFirstRunPermAsked);
  if (asked == '1') return;
  await ensurePublicDownloadsPermission();
  await _markFirstRun(db);
}

/// 读 basic_info 字符串标记
Future<String?> _readFlag(AppDatabase db, String key) async {
  final row = await (db.select(db.basicInfo)
        ..where((tbl) => tbl.key.equals(key)))
      .getSingleOrNull();
  final v = row?.value;
  return (v == null || v.isEmpty) ? null : v;
}

/// 写 basic_info 字符串标记
Future<void> _markFirstRun(AppDatabase db) async {
  final existing = await (db.select(db.basicInfo)
        ..where((tbl) => tbl.key.equals(kDbFirstRunPermAsked)))
      .getSingleOrNull();
  if (existing == null) {
    await db
        .into(db.basicInfo)
        .insert(BasicInfoCompanion.insert(key: kDbFirstRunPermAsked, value: const Value('1')));
  } else {
    await (db.update(db.basicInfo)
          ..where((tbl) => tbl.key.equals(kDbFirstRunPermAsked)))
        .write(const BasicInfoCompanion(value: Value('1')));
  }
}
