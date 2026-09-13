// 文本导出原子（全 App 统一）—— 把文本直接落盘到系统 Download/<子目录>/（未授权回退沙盒），
// 成功后顶部提示（forui toast 触摸设备默认 topCenter）。**不弹系统保存对话框。**
//
// 落盘目录/权限复用 `lib/core/storage/public_downloads.dart`；写共享 Download 后触发
// MediaStore 索引（`core/android/media_scan.dart`）使文件管理器立即可见。
//
// 目前消费：主题对话导出（`conversation_page.dart`）、笔记导出（`note_export_sheet.dart`）、
//           习惯打卡导出（`habit_export_sheet.dart`）、电子书导出（`book_export_sheet.dart`）。
import 'dart:io';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../core/android/media_scan.dart';
import '../../core/storage/public_downloads.dart';

/// 默认导出子目录名（`Download/渐离App导出/`）。
const String kExportDirName = '渐离App导出';

/// 生成 Markdown/文本文件并**直接落盘**到「`Download/<dirName>/`」（未授权回退沙盒），
/// 成功后顶部提示已保存路径（失败提示原因）。调用方无需再另弹提示。
Future<void> exportTextToDownloadDir({
  required BuildContext context,
  required String text,
  required String filename,
  String dirName = kExportDirName,
}) async {
  try {
    await ensurePublicDownloadsPermission();
    final isPublic = await hasPublicDownloadsAccess();
    final dir = await moduleDownloadDir(dirName);
    final file = File(p.join(dir.path, _uniqueName(dir.path, filename)));
    await file.writeAsString(text);
    // 触发 MediaStore 索引，文件管理器/系统媒体立即可见（静默，失败不影响已写入）
    await scanFileInMediaStore(file.path);
    if (!context.mounted) return;
    showFToast(
      context: context,
      title: const Text('导出成功'),
      description: Text(
        '已保存到 ${file.path}${isPublic ? '' : '（未授权存储，暂存应用沙盒）'}',
      ),
    );
  } catch (e) {
    if (context.mounted) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('导出失败'),
        description: Text('$e'),
      );
    }
  }
}

/// 同目录重名去重：追加 ` (n)`，保留扩展名
String _uniqueName(String dir, String filename) {
  if (!File(p.join(dir, filename)).existsSync()) return filename;
  final dot = filename.lastIndexOf('.');
  final base = dot > 0 ? filename.substring(0, dot) : filename;
  final ext = dot > 0 ? filename.substring(dot) : '';
  var n = 1;
  var candidate = '$base ($n)$ext';
  while (File(p.join(dir, candidate)).existsSync()) {
    candidate = '$base (${++n})$ext';
  }
  return candidate;
}
