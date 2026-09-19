// P1-6 小纸条 —— 详情抽屉（lg 80vh）
//
// 点列表条目 / 点通知直达：展示全文 + 五个落点动作（复制 / 浏览器打开 / 存笔记 / 建待办 / 删除）。
// ⚠️ 抽屉属于 Navigator overlay 子树，**自带 ConsumerStatefulWidget** 订阅 provider
//（红线 #28：在 builder 里用页面 State 的 ref.watch 会永远停在首帧）。
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router/app_router.dart';
import '../../../app/ui/sheet_form.dart';
// ⚠️ SheetSize 在 sheet_surface.dart（sheet_form.dart 不 re-export，须双导，红线）
import '../../../app/ui/sheet_surface.dart' show SheetSize;
import '../../../core/db/app_database.dart';
import '../../notes/providers/note_providers.dart';
import '../../todo/providers/todo_providers.dart';
import '../models/note_slip.dart';
import '../providers/note_slip_providers.dart';

/// 小纸条详情抽屉
class NoteSlipDetailSheet extends ConsumerStatefulWidget {
  const NoteSlipDetailSheet({super.key, required this.item});

  final NoteSlipData item;

  @override
  ConsumerState<NoteSlipDetailSheet> createState() =>
      _NoteSlipDetailSheetState();
}

class _NoteSlipDetailSheetState extends ConsumerState<NoteSlipDetailSheet> {
  NoteSlipData get item => widget.item;

  @override
  void initState() {
    super.initState();
    // 打开即已读（仅收到的）
    if (item.direction == kSlipDirectionIn && item.read == 0) {
      ref.read(noteSlipRepositoryProvider).markRead(item.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final isUrl = item.kind == kSlipKindUrl;
    return SheetScaffold(
      title: '小纸条',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 元信息行：方向 + 对端 + 时间
          Row(
            children: [
              Icon(
                item.direction == kSlipDirectionIn
                    ? FLucideIcons.arrowDownToLine
                    : FLucideIcons.arrowUpFromLine,
                size: 14,
                color: t.colors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.direction == kSlipDirectionIn ? '来自' : '发往'} ${item.peerName}'
                  '${slipTimeLabel(item.createdAt).isEmpty ? '' : ' · ${slipTimeLabel(item.createdAt)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 全文（muted 底 r14，可随滚动区滚动）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.colors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              item.content ?? '',
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                height: 1.6,
                color: t.colors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _actionTile(context, FLucideIcons.copy, '复制内容', () => _copy(context)),
          if (isUrl)
            _actionTile(context, FLucideIcons.globe, '用浏览器打开',
                () => _openInBrowser(context)),
          _actionTile(context, FLucideIcons.notebookPen, '存为笔记',
              () => _saveNote(context)),
          _actionTile(context, FLucideIcons.listTodo, '新建待办',
              () => _saveTodo(context)),
          _actionTile(
            context,
            FLucideIcons.trash2,
            '删除',
            () => _delete(context),
            destructive: true,
          ),
        ],
      ),
    );
  }

  /// 动作行（对齐 showSheetActionMenu 条目视觉：muted 底 r14 + 图标 18 + 15/w600）
  Widget _actionTile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final t = context.theme;
    final color = destructive ? t.colors.destructive : t.colors.foreground;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FTappable(
        onPress: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: destructive
                ? t.colors.destructive.withValues(alpha: 0.08)
                : t.colors.muted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: t.typography.body.sm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext sheetContext) async {
    await Clipboard.setData(ClipboardData(text: item.content ?? ''));
    if (!sheetContext.mounted) return;
    showFToast(context: sheetContext, title: const Text('已复制'));
  }

  void _openInBrowser(BuildContext sheetContext) {
    final url = (item.content ?? '').trim();
    appRouter.push('/browser?url=${Uri.encodeComponent(url)}');
    Navigator.pop(sheetContext);
  }

  Future<void> _saveNote(BuildContext sheetContext) async {
    final text = item.content ?? '';
    try {
      await ref.read(noteRepositoryProvider).createNote(
            title: slipTitleOf(text),
            content: text,
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
    final text = item.content ?? '';
    final title = slipTitleOf(text);
    try {
      await ref.read(todoRepositoryProvider).addTodo(
            title: title,
            description: text == title ? null : text,
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

  Future<void> _delete(BuildContext sheetContext) async {
    final ok = await showSheetConfirm(
      sheetContext,
      title: '删除小纸条',
      message: '删除后本机不再保留这条记录（不影响对端）。',
      confirmLabel: '删除',
    );
    if (ok != true) return;
    await ref.read(noteSlipRepositoryProvider).deleteByKey(item.key);
    if (!sheetContext.mounted) return;
    showFToast(context: sheetContext, title: const Text('已删除'));
    Navigator.pop(sheetContext);
  }
}
