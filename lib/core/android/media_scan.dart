// 原生辅助：读取 Android API 级别 + 触发 MediaStore 扫描，使写入共享 Download 的文件
// 立即被文件管理器 / 系统媒体索引到。
//
// 复用 MainActivity 的 jianli/file_actions 通道（#open-folder 同通道），
// 新增 getSdkVersion / scanFile 两个方法（见 android/app/.../MainActivity.kt）。
import 'dart:io';

import 'package:flutter/services.dart';

const _kChannel = MethodChannel('jianli/file_actions');

int? _cachedSdkInt;

/// Android API level（非 Android / 取不到时返回 0）。
/// 用于区分边界：API 30+（Android 11 起）写共享 Download 必须「所有文件访问」，
/// ≤29 传统存储权限（配合 manifest 的 requestLegacyExternalStorage）仍可用。
Future<int> getAndroidSdkInt() async {
  if (!Platform.isAndroid) return 0;
  if (_cachedSdkInt != null) return _cachedSdkInt!;
  try {
    final v = await _kChannel.invokeMethod<int>('getSdkVersion');
    _cachedSdkInt = v ?? 0;
  } catch (_) {
    _cachedSdkInt = 0;
  }
  return _cachedSdkInt!;
}

/// 落盘后调用：让 MediaStore 重新索引该文件，文件管理器 / 系统媒体立即可见。
/// 失败静默忽略（扫描仅为可见性加速，非写入必需）。
Future<void> scanFileInMediaStore(String path) async {
  if (!Platform.isAndroid) return;
  try {
    await _kChannel.invokeMethod<bool>('scanFile', {'path': path});
  } catch (_) {
    // 忽略：扫描失败不影响已成功写入的文件
  }
}
