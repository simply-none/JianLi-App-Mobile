// 文件互传「打开」按钮的原生桥接（#open-folder）
//
// 对应 Android 原生通道 jianli/file_actions（见 android/.../MainActivity.kt）：
//   - queryOpenableApps(path)  → 可打开该文件的应用列表（系统解析，含应用图标 PNG base64）
//   - openContainingFolder(path) → 打开文件所在文件夹（尽力而为，无目录型文件管理器时返回 false）
//   - openWithApp(path, pkg, act) → 用指定应用打开文件
//
// 不用 open_filex：它只能打开文件本身、无法打开所在文件夹。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 一个可打开某文件的应用（来自系统解析）
class OpenableApp {
  final String packageName;
  final String activityName;
  final String label;
  final Uint8List icon;

  const OpenableApp({
    required this.packageName,
    required this.activityName,
    required this.label,
    required this.icon,
  });
}

/// 文件操作的原生桥接封装
class FileActions {
  static const MethodChannel _channel = MethodChannel('jianli/file_actions');

  /// 查询能打开该文件的应用列表（系统解析，含图标）。失败/无结果为空列表。
  static Future<List<OpenableApp>> queryOpenableApps(String path) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'queryOpenableApps',
      {'path': path},
    );
    if (raw == null) return const [];
    return raw.map((m) {
      final iconB64 = (m['icon'] as String?) ?? '';
      return OpenableApp(
        packageName: m['packageName'] as String,
        activityName: m['activityName'] as String,
        label: m['label'] as String,
        icon: iconB64.isEmpty ? Uint8List(0) : base64Decode(iconB64),
      );
    }).toList();
  }

  /// 打开文件所在文件夹。成功返回 true；无应用能响应返回 false。
  static Future<bool> openContainingFolder(String path) async {
    final r = await _channel.invokeMethod<bool>(
      'openFolder',
      {'path': path},
    );
    return r ?? false;
  }

  /// 用指定应用打开文件。成功返回 true。
  static Future<bool> openWithApp(
    String path,
    String packageName,
    String activityName,
  ) async {
    final r = await _channel.invokeMethod<bool>(
      'openWithApp',
      {
        'path': path,
        'packageName': packageName,
        'activityName': activityName,
      },
    );
    return r ?? false;
  }
}
