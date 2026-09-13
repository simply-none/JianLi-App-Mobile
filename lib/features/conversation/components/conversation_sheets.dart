// 主题对话标签管理抽屉 —— 对齐 PC 端标签管理能力（重命名 / 改色 / 删除）
//
// 入口：主题对话列表页头部「标签」图标。会话标签分两个作用域（conversation_tag.scope）：
// theme = 主题标签 / conversation = 对话标签，管理抽屉分组展示。
// 删除对齐桌面端 deleteTag 语义：删行 + 自动从主题/对话 tags 字段移除该 id（仓库层实现）。
// 弹窗一律三档制：管理 = lg 定高 / 编辑 = md / 改色 = sm，均走共享 SheetScaffold 骨架。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../core/db/app_database.dart';
import '../repositories/conversation_repository.dart';

/// 标签管理抽屉（lg 定高）：按作用域分组的标签行列表。
/// 行内操作直接改库，抽屉无需返回值（conversation_tag 流自动刷新页面）。
Future<void> showConversationTagManagerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _ConvTagManagerSheet(),
  );
}

class _ConvTagManagerSheet extends ConsumerWidget {
  const _ConvTagManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(conversationTagsProvider).value ?? const <ConversationTagData>[];
    final themeTags = tags.where((d) => d.scope == 'theme').toList();
    const msgTagsScope = 'conversation';
    final msgTags = tags.where((d) => d.scope == msgTagsScope).toList();

    Widget groupLabel(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            text,
            style: context.theme.typography.body.xs.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.theme.colors.mutedForeground,
            ),
          ),
        );

    return SheetScaffold(
      title: '标签管理',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            '重命名 / 改色即时生效；删除后自动从主题与对话上移除该标签。',
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
                  '暂无标签，编辑主题或发送记录时可新建',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ),
            )
          else ...[
            if (themeTags.isNotEmpty) ...[
              groupLabel('主题标签 · ${themeTags.length}'),
              for (final tag in themeTags) _ConvTagRow(tag: tag),
            ],
            if (msgTags.isNotEmpty) ...[
              groupLabel('对话标签 · ${msgTags.length}'),
              for (final tag in msgTags) _ConvTagRow(tag: tag),
            ],
          ],
        ],
      ),
    );
  }
}

/// 标签行：色点 + 名称 + 改色 / 编辑 / 删除
class _ConvTagRow extends ConsumerWidget {
  const _ConvTagRow({required this.tag});

  final ConversationTagData tag;

  Color get _color {
    final hex = (tag.color ?? '').replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    return v == null ? const Color(0xFF6366F1) : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tag.name ?? '',
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.colors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _rowIcon(context, FLucideIcons.palette, () => _pickColor(context, ref)),
          _rowIcon(context, FLucideIcons.pencil, () => _edit(context)),
          _rowIcon(context, FLucideIcons.trash2, () => _remove(context, ref),
              destructive: true),
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

  /// 快捷改色（sm 色板抽屉，点选即生效）
  Future<void> _pickColor(BuildContext context, WidgetRef ref) async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => _ConvTagColorSheet(tag: tag),
    );
  }

  /// 编辑（md：重命名 + 改色 + 删除合并形态）
  Future<void> _edit(BuildContext context) async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => _ConvTagEditSheet(tag: tag),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除标签',
      message: '确定删除「${tag.name ?? ''}」？将自动从主题与对话上移除该标签。',
    );
    if (!ok) return;
    await ref.read(conversationRepositoryProvider).deleteTag(tag.id);
  }
}

/// 标签改色抽屉（sm）：10 色板，点选即生效
class _ConvTagColorSheet extends ConsumerWidget {
  const _ConvTagColorSheet({required this.tag});

  final ConversationTagData tag;

  Color _hexColor(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF6366F1) : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final current = (tag.color ?? '').toLowerCase();
    return SheetScaffold(
      title: '标签颜色',
      size: SheetSize.sm,
      body: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final hex in ConversationRepository.kTagPalette)
            GestureDetector(
              onTap: () async {
                await ref
                    .read(conversationRepositoryProvider)
                    .updateTag(tag.id, color: hex);
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hexColor(hex),
                  border: current == hex.toLowerCase()
                      ? Border.all(
                          color: t.colors.foreground,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )
                      : null,
                ),
                child: current == hex.toLowerCase()
                    ? Icon(FLucideIcons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// 单标签编辑抽屉（md）：重命名 + 改色 + 删除合并形态
class _ConvTagEditSheet extends ConsumerStatefulWidget {
  const _ConvTagEditSheet({required this.tag});

  final ConversationTagData tag;

  @override
  ConsumerState<_ConvTagEditSheet> createState() => _ConvTagEditSheetState();
}

class _ConvTagEditSheetState extends ConsumerState<_ConvTagEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.tag.name ?? '');
  late String _color = widget.tag.color ?? ConversationRepository.kTagPalette.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Color _hexColor(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF6366F1) : Color(0xFF000000 | v);
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
              for (final hex in ConversationRepository.kTagPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hexColor(hex),
                      border: _color.toLowerCase() == hex.toLowerCase()
                          ? Border.all(
                              color: t.colors.foreground,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            )
                          : null,
                    ),
                    child: _color.toLowerCase() == hex.toLowerCase()
                        ? Icon(FLucideIcons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
      // 底部按钮区：删除（危险）| 取消 | 保存 并列（2026-09-13 用户定案，与笔记同款）
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.destructive,
            prefix: const Icon(FLucideIcons.trash2, size: 16),
            onPress: () async {
              final ok = await showSheetConfirm(
                context,
                title: '删除标签',
                message:
                    '确定删除「${widget.tag.name ?? ''}」？将自动从主题与对话上移除该标签。',
              );
              if (ok != true || !context.mounted) return;
              await ref
                  .read(conversationRepositoryProvider)
                  .deleteTag(widget.tag.id);
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
              final name = _name.text.trim();
              if (name.isEmpty) {
                showFToast(context: context, title: const Text('名称不能为空'));
                return;
              }
              await ref
                  .read(conversationRepositoryProvider)
                  .updateTag(widget.tag.id, name: name, color: _color);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
