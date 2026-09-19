// P0-3 系统分享接收 —— 落地页 + 处理抽屉
//
// /share-intake 是一个**透明壳路由**（NoTransitionPage）：只为承载 md 档处理抽屉，
// 抽屉关闭即自动 pop，用户感知不到中间页。
//
// 抽屉动作（分享文本/链接 →）：
//   存为笔记（note_book，纯文本段落化路径，与手动新建同源）
//   新建待办（todo_list，addTodo）
//   用浏览器打开（仅 URL；走 /browser?url= 直接导航，与书签/历史打开同构）
//   复制内容（系统剪贴板）
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../app/ui/sheet_form.dart';
// ⚠️ SheetSize 在 sheet_surface.dart（sheet_form.dart 不 re-export，须双导，红线）
import '../../app/ui/sheet_surface.dart' show SheetSize;
import '../notes/providers/note_providers.dart';
import '../todo/providers/todo_providers.dart';
import 'share_intake_controller.dart';

/// 分享接收落地页（透明壳）
class ShareIntakePage extends ConsumerStatefulWidget {
  const ShareIntakePage({super.key});

  @override
  ConsumerState<ShareIntakePage> createState() => _ShareIntakePageState();
}

class _ShareIntakePageState extends ConsumerState<ShareIntakePage> {
  @override
  void initState() {
    super.initState();
    // 首帧后弹处理抽屉（不能在 initState 直接 showFSheet——导航尚未挂载）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openSheet();
    });
  }

  Future<void> _openSheet() async {
    final item = ref.read(pendingShareProvider);
    if (item == null) {
      // 无待处理内容（异常路径）：直接退壳，不留透明页
      if (mounted) context.pop();
      return;
    }
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => ShareIntakeSheet(item: item),
    );
    if (!mounted) return;
    // 抽屉关闭（无论是否完成动作）即消费意图 + 退透明壳
    ref.read(pendingShareProvider.notifier).consume();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(),
    );
  }
}

/// 分享处理抽屉（md 档：预览 + 四动作）。ConsumerStatefulWidget：State 自持 ref，
/// 动作方法里能直接读仓库（ConsumerWidget 的 ref 只是 build 参数，方法里拿不到）。
class ShareIntakeSheet extends ConsumerStatefulWidget {
  const ShareIntakeSheet({super.key, required this.item});

  final ShareIntakeItem item;

  @override
  ConsumerState<ShareIntakeSheet> createState() => _ShareIntakeSheetState();
}

class _ShareIntakeSheetState extends ConsumerState<ShareIntakeSheet> {
  ShareIntakeItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetScaffold(
      title: '分享接收',
      size: SheetSize.md,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 预览卡：muted 底 r14，最多 8 行
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.colors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              item.isUrl ? item.displayUrl : item.text,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: t.typography.body.sm.copyWith(
                fontSize: 13,
                height: 1.5,
                color: t.colors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _actionTile(context, FLucideIcons.notebookPen, '存为笔记',
              () => _saveNote(context)),
          _actionTile(context, FLucideIcons.listTodo, '新建待办',
              () => _saveTodo(context)),
          if (item.isUrl)
            _actionTile(context, FLucideIcons.globe, '用浏览器打开',
                () => _openInBrowser(context)),
          _actionTile(context, FLucideIcons.copy, '复制内容',
              () => _copy(context)),
        ],
      ),
    );
  }

  /// 动作行（对齐 showSheetActionMenu 的条目视觉：muted 底 r14 + 图标 18 + 15/w600）
  Widget _actionTile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FTappable(
        onPress: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: t.colors.muted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: t.colors.foreground),
              const SizedBox(width: 10),
              Text(
                label,
                style: t.typography.body.sm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: t.colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote(BuildContext sheetContext) async {
    try {
      await ref.read(noteRepositoryProvider).createNote(
            title: item.noteTitle,
            content: item.text,
          );
      if (!sheetContext.mounted) return;
      showFToast(context: sheetContext, title: const Text('已存入笔记'));
      Navigator.pop(sheetContext);
    } catch (e) {
      if (!sheetContext.mounted) return;
      showFToast(
        context: sheetContext,
        variant: FToastVariant.destructive,
        title: const Text('保存失败'),
        description: Text('$e'),
      );
    }
  }

  Future<void> _saveTodo(BuildContext sheetContext) async {
    try {
      await ref.read(todoRepositoryProvider).addTodo(
            title: item.todoTitle,
            description: item.text == item.todoTitle ? null : item.text,
          );
      if (!sheetContext.mounted) return;
      showFToast(context: sheetContext, title: const Text('已新建待办'));
      Navigator.pop(sheetContext);
    } catch (e) {
      if (!sheetContext.mounted) return;
      showFToast(
        context: sheetContext,
        variant: FToastVariant.destructive,
        title: const Text('新建失败'),
        description: Text('$e'),
      );
    }
  }

  void _openInBrowser(BuildContext sheetContext) {
    // 与书签/历史「打开」同构：直接带 url 查询参数导航（BrowserPage initialUrl）
    appRouter.push('/browser?url=${Uri.encodeComponent(item.text)}');
    Navigator.pop(sheetContext);
  }

  Future<void> _copy(BuildContext sheetContext) async {
    await Clipboard.setData(ClipboardData(text: item.text));
    if (!sheetContext.mounted) return;
    showFToast(context: sheetContext, title: const Text('已复制'));
    Navigator.pop(sheetContext);
  }
}
