// 数据库导出（数据管理页「导出数据库文件」按钮）—— 把当前活动库导出为独立快照文件。
//
// 落盘位置 / 权限 / 反馈与本 App 其他导出（主题对话、笔记、习惯、电子书）完全一致：
// 系统 Download/渐离App导出/（未授权回退沙盒 Documents/渐离App导出/），见 app/ui/file_export.dart。
//
// 关键：活动库是 drift 热连接（常开 WAL），直接 File.copy 活文件可能拷到半截 WAL 数据，
// 在别的端打开会提示损坏。这里用 SQLite 的 `VACUUM INTO '目标'` 在同一连接内生成一份
// 「仅含已提交数据」的一致性独立副本，不依赖 -wal/-shm，导出的 .sqlite 可被本 App 或桌面端直接打开/导入。
import 'dart:io';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../android/media_scan.dart' show scanFileInMediaStore;
import '../storage/public_downloads.dart'
    show ensurePublicDownloadsPermission, hasPublicDownloadsAccess, moduleDownloadDir;
import '../../app/ui/file_export.dart' show kExportDirName;
import 'app_database.dart';
import 'db_location.dart' show describeDatabasePath;

/// 导出结果
typedef DbExportResult = ({
  bool ok,
  String message,
  String? path,
});

/// 把当前活动库导出快照到系统 Download/渐离App导出/（未授权回退沙盒）。
///
/// [context] 用于成功 / 失败顶部提示；成功时已触发 MediaStore 索引，文件管理器立即可见。
/// 调用方无需另弹提示。
Future<DbExportResult> exportDatabaseFile(
  AppDatabase db, {
  required BuildContext context,
}) async {
  try {
    await ensurePublicDownloadsPermission();
    final isPublic = await hasPublicDownloadsAccess();
    final dir = await moduleDownloadDir(kExportDirName);
    final name = 'db_导出_${_timestamp()}.sqlite';
    final dest = p.join(dir.path, name);

    // 同一连接内做一致快照；目标必须是新文件（SQLite 要求），timestamp 已保证唯一。
    // 路径来自本 App 自管目录（不含单引号），仍转义以防万一。
    final safeDest = dest.replaceAll("'", "''");
    try {
      await db.customStatement("VACUUM INTO '$safeDest'");
    } on Object {
      // 兜底：少数环境不支持 VACUUM INTO → 刷盘 WAL + 直接拷贝活文件
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await File(await describeDatabasePath()).copy(dest);
    }

    final out = File(dest);
    if (!await out.exists()) {
      return (ok: false, message: '导出失败：未能生成数据库快照文件。', path: null);
    }
    // 触发 MediaStore 索引，文件管理器/系统媒体立即可见（静默，失败不影响已写入）
    await scanFileInMediaStore(out.path);
    if (!context.mounted) return (ok: true, message: '导出成功', path: dest);
    showFToast(
      context: context,
      title: const Text('导出成功'),
      description: Text(
        '已保存到 $dest${isPublic ? '' : '（未授权存储，暂存应用沙盒）'}',
      ),
    );
    return (ok: true, message: '导出成功', path: dest);
  } on Object catch (e) {
    if (context.mounted) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('导出失败'),
        description: Text('$e'),
      );
    }
    return (ok: false, message: '导出失败：$e', path: null);
  }
}

/// 时间戳：YYYYMMDD_HHmmss（对齐各导出文件名口径）
String _timestamp() {
  final n = DateTime.now();
  final p2 = (int v) => v.toString().padLeft(2, '0');
  return '${n.year}${p2(n.month)}${p2(n.day)}'
      '_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
}
