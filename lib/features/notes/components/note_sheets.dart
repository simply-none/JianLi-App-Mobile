// 笔记标签管理抽屉 —— 对齐 PC 端 TagSelector 的标签管理能力（重命名 / 改色 / 删除）
//
// 入口：笔记列表页头部「标签」图标。
// - 重命名：同名去重由仓储保证（与活跃标签重名时 toast 提示不写入）；
// - 改色：PC 同款 10 色板（kNoteTagPalette），选中带勾；
// - 删除：软删（deleted: true），笔记上已挂的 key 保留，与桌面端语义一致。
// 数据直接写 basic_info.note_tags（同步白名单行，改完双端互通）。
// 弹窗一律三档制：管理 = lg 定高 / 编辑 = md，均走共享 SheetScaffold 骨架。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import '../repositories/note_repository.dart';

/// 标签管理抽屉（lg 定高）：标签行列表，每行「改色 / 重命名 / 删除」。
/// 行内操作直接改库，抽屉无需返回值（basic_info 流自动刷新页面）。
Future<void> showNoteTagManagerSheet(BuildContext context, WidgetRef ref) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _TagManagerSheet(),
  );
}

class _TagManagerSheet extends ConsumerWidget {
  const _TagManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(noteTagsProvider).value ?? const <NoteTag>[];
    return SheetScaffold(
      title: '标签管理',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            '重命名 / 改色即时生效；删除后标签从选择器移除，已有笔记保留标记。',
            style: context.theme.typography.body.sm.copyWith(
              fontSize: 12,
              color: context.theme.colors.mutedForeground,
            ),
          ),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  '暂无标签，编辑笔记时可新建',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ),
            )
          else
            for (final tag in tags) _TagRow(tag: tag),
        ],
      ),
    );
  }
}

/// 标签行：色点 + 名称 + 改色 / 重命名 / 删除
class _TagRow extends ConsumerWidget {
  const _TagRow({required this.tag});

  final NoteTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final repo = ref.read(noteRepositoryProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tag.colorValue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tag.name,
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tag.deleted ? t.colors.mutedForeground : t.colors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (tag.deleted)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '已删除',
                style: t.typography.body.xs.copyWith(
                  fontSize: 11,
                  color: t.colors.mutedForeground,
                ),
              ),
            )
          else ...[
            _rowIcon(context, FLucideIcons.palette, () => _pickColor(context, ref)),
            _rowIcon(context, FLucideIcons.pencil, () => _rename(context, ref)),
            _rowIcon(context, FLucideIcons.trash2, () => _remove(context, ref, repo),
                destructive: true),
          ],
        ],
      ),
    );
  }

  Widget _rowIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: destructive ? t.colors.destructive : t.colors.mutedForeground,
        ),
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, WidgetRef ref) async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => _TagColorSheet(tag: tag),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    // 铅笔 = 完整编辑抽屉（重命名 + 改色 + 删除合并形态）
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => _TagEditSheet(tag: tag),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, NoteRepository repo) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除标签',
      message: '确定删除「${tag.name}」？已有笔记上的标记会保留。',
    );
    if (!ok) return;
    await repo.deleteTagDef(tag.key);
  }
}

/// 标签改色抽屉（sm）：PC 同款 10 色板，点选即生效
class _TagColorSheet extends ConsumerWidget {
  const _TagColorSheet({required this.tag});

  final NoteTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    return SheetScaffold(
      title: '标签颜色',
      size: SheetSize.sm,
      body: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final hex in kNoteTagPalette)
            GestureDetector(
              onTap: () async {
                await ref.read(noteRepositoryProvider).updateTagColor(
                      tag.key,
                      hex,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hexColor(hex),
                  border: tag.color.toLowerCase() == hex
                      ? Border.all(
                          color: t.colors.foreground,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )
                      : null,
                ),
                child: tag.color.toLowerCase() == hex
                    ? Icon(FLucideIcons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

Color _hexColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x6366F1;
  return Color(0xFF000000 | value);
}

class _TagEditSheet extends ConsumerStatefulWidget {
  const _TagEditSheet({required this.tag});

  final NoteTag tag;

  @override
  ConsumerState<_TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends ConsumerState<_TagEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.tag.name);
  late String _color = widget.tag.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetScaffold(
      title: '编辑标签',
      // 内含输入框 → lg 80vh 定高（2026-09-13 全局定案）
      size: SheetSize.lg,
      // 字段组：label↔值间距只由 SheetFieldLabel 自带 bottom:6 提供（6px），
      // 组间用 SizedBox(16) 显式分隔（不许多叠 spacing——曾叠出 20px，用户实指）
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetFieldLabel('名称'),
          SheetInputBox(controller: _name, hintText: '标签名称'),
          const SizedBox(height: 16),
          const SheetFieldLabel('颜色'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in kNoteTagPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hexColor(hex),
                      border: _color.toLowerCase() == hex
                          ? Border.all(
                              color: t.colors.foreground,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            )
                          : null,
                    ),
                    child: _color.toLowerCase() == hex
                        ? Icon(FLucideIcons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
      // 底部按钮区：删除（危险）| 取消 | 保存 并列（2026-09-13 用户定案）
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.destructive,
            prefix: const Icon(FLucideIcons.trash2, size: 16),
            onPress: () async {
              final ok = await showSheetConfirm(
                context,
                title: '删除标签',
                message: '确定删除「${widget.tag.name}」？已有笔记上的标记会保留。',
              );
              if (ok != true || !context.mounted) return;
              await ref
                  .read(noteRepositoryProvider)
                  .deleteTagDef(widget.tag.key);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ),
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: () async {
              final ok = await ref
                  .read(noteRepositoryProvider)
                  .renameTagDef(widget.tag.key, _name.text);
              if (!ok) {
                if (context.mounted) {
                  showFToast(context: context, title: const Text('该名称已被其它标签使用'));
                }
                return;
              }
              await ref
                  .read(noteRepositoryProvider)
                  .updateTagColor(widget.tag.key, _color);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
