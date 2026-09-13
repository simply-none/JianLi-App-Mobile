// 安全剪贴板（对齐 PC passwordVault copy 语义）：复制敏感内容后 30 秒自动清空
//
// 清空条件与 PC 一致：仅当剪贴板内容仍是本次复制的内容时才清（期间用户复制了
// 别的内容则不打扰）。密码库条目的 用户名/密码/TOTP 复制统一走这里。
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 复制 [text] 到剪贴板，30 秒后若剪贴板仍是该内容则自动清空
Future<void> copyWithAutoClear(
  BuildContext context,
  String text,
  String label,
) async {
  if (text.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    showFToast(context: context, title: Text('$label已复制，30 秒后自动清空'));
  }
  Timer(const Duration(seconds: 30), () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == text) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  });
}
