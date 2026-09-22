// 公共 Download 子目录解析（跨模块复用）—— 把文件写到系统 `Download/<子目录>/`，
// 系统文件管理器可直接浏览；未授权或创建失败时回退沙盒 `Documents/<子目录>/`。
//
// 与「文件互传 · 渐离App文件互传」「传书 · 渐离App传书」「流光扫传 · 渐离App隔空互传（目录沿用旧名）」
// 同一套机制（Permission + MediaStore 可见性），本文件把这段反复出现的能力收口成单一来源。
//
// ⚠️ 关键修正（沿用 2026-09-10 结论）：Android 11+(API 30+) 起，普通 READ/WRITE_EXTERNAL_STORAGE
// 已**不再**授予「写共享 Download」的权限，只有「所有文件访问」(MANAGE_EXTERNAL_STORAGE) 才行。
// 旧写法把 `Permission.storage.isGranted` 当成可写，导致 API 30+ 静默回退沙盒（文件管理器看不到）。
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../android/media_scan.dart';

/// 公共 Download 可写判定。非 Android 恒 false（iOS 无共享 Download 概念）。
Future<bool> hasPublicDownloadsAccess() async {
  if (!Platform.isAndroid) return false;
  if (await Permission.manageExternalStorage.isGranted) return true;
  if (await getAndroidSdkInt() <= 29) {
    return Permission.storage.isGranted;
  }
  return false;
}

/// 申请公共 Download 写权限（调用方在导出/接收动作前调一次即可）。
/// API 30+ 只有「所有文件访问」能写共享 Download，申请 storage 无效且误导，故只申请前者；
/// ≤29 才弹传统授权框。拒绝时 [moduleDownloadDir] 自动回退沙盒。
Future<void> ensurePublicDownloadsPermission() async {
  if (!Platform.isAndroid) return;
  if (await hasPublicDownloadsAccess()) return;
  if (await getAndroidSdkInt() >= 30) {
    await Permission.manageExternalStorage.request();
  } else {
    await [Permission.manageExternalStorage, Permission.storage].request();
  }
}

/// 模块公共目录（不存在则创建）：
/// - Android 且已授权 → 系统 `Download/<dirName>/`，文件管理器可直接浏览；
/// - 未授权或公共目录创建失败（权限被收回 / ROM 限制）→ 回退沙盒 `Documents/<dirName>/`。
Future<Directory> moduleDownloadDir(String dirName) async {
  if (Platform.isAndroid && await hasPublicDownloadsAccess()) {
    try {
      final d = Directory('/storage/emulated/0/Download/$dirName');
      if (!d.existsSync()) d.createSync(recursive: true);
      return d;
    } catch (_) {
      // 落到沙盒回退
    }
  }
  final dir = await getApplicationDocumentsDirectory();
  final d = Directory(p.join(dir.path, dirName));
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}
