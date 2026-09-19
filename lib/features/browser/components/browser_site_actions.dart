// 站点条目**长按动作**（书签 / 历史共用）
//
// 三件事收口在这里，避免两个页面各写一份：
//   · [showBrowserSiteActionMenu]  长按操作单（加入固定标签 / 编辑 / 复制链接 / 删除）
//   · [addSiteToPinned]            加入固定标签页（含 FIFO 替换提示）
//   · [copyLink]                   复制链接
//
// 为什么单独一件：这两条规则是**用户定案的产品行为**，散落在页面里迟早漂移 ——
// 「超 8 个时新的替换最早的」提示文案只在这里写一次。
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/sheet_form.dart';
import '../providers/browser_providers.dart';

/// 站点条目可执行的动作
enum BrowserSiteAction {
  /// 加入固定标签页（书签与历史都支持）
  pin,

  /// 编辑（仅书签：重命名）
  rename,

  /// 复制链接
  copy,

  /// 删除（书签删除 / 历史删除单条）
  delete,
}

/// 长按操作单。返回 null = 用户取消。
///
/// [canRename] 控制是否出现「编辑」——历史条目没有可编辑的字段，传 false。
Future<BrowserSiteAction?> showBrowserSiteActionMenu(
  BuildContext context, {
  required String title,
  required String url,
  bool canRename = false,
}) {
  return showSheetActionMenu<BrowserSiteAction>(
    context,
    title: title.isEmpty ? url : title,
    actions: [
      const SheetAction(
        BrowserSiteAction.pin,
        '加入固定标签页',
        icon: FLucideIcons.pin,
      ),
      if (canRename)
        const SheetAction(
          BrowserSiteAction.rename,
          '编辑',
          icon: FLucideIcons.pencil,
        ),
      const SheetAction(
        BrowserSiteAction.copy,
        '复制链接',
        icon: FLucideIcons.link,
      ),
      const SheetAction(
        BrowserSiteAction.delete,
        '删除',
        icon: FLucideIcons.trash2,
        destructive: true,
      ),
    ],
  );
}

/// 加入固定标签页。
///
/// 满 8 个时仓库会**复用最早加入者的槽位**（九宫格里表现为就地替换），
/// 这里把被替换的站点名明确告诉用户，避免「怎么少了一个」的困惑。
Future<void> addSiteToPinned(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String url,
}) async {
  final clean = url.trim();
  if (clean.isEmpty) return;
  final replaced = await ref
      .read(browserRepositoryProvider)
      .addPinned(title: title.trim().isEmpty ? clean : title.trim(), url: clean);
  if (!context.mounted) return;
  showFToast(
    context: context,
    title: Text(
      replaced == null ? '已加入固定标签页' : '已加入，替换了「$replaced」',
    ),
  );
}

/// 复制链接（含提示）
Future<void> copyLink(BuildContext context, String url) async {
  final clean = url.trim();
  if (clean.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: clean));
  if (!context.mounted) return;
  showFToast(context: context, title: const Text('已复制链接'));
}

/// 请求浏览器主壳导航到 [url]（书签 / 历史 / 固定标签页点条目时用）。
///
/// 为什么不用 `pop(url)` 把结果回传：这些子页可能被**多层**推入
/// （浏览器 → 设置 → 固定标签页管理），`pop` 只能退回一层，结果到不了主壳。
/// 用一条状态通道传递意图，深度无关，主壳负责消费并清空。
void requestBrowserNavigation(WidgetRef ref, String url) {
  final clean = url.trim();
  if (clean.isEmpty) return;
  ref.read(browserPendingUrlProvider.notifier).request(clean);
}
