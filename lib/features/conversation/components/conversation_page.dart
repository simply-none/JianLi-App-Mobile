// 主题对话页 —— 主题列表 + 消息流（forui 化）
//
// 对齐桌面端 themeConversation 的浏览体验；发送输入栏可追加记录（LLM 后端未定）。
// 新建主题走 showFSheet 底部弹层（替代 showModalBottomSheet）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/conversation_repository.dart';

/// 主题列表页
class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(conversationThemesProvider);
    return FScaffold(
      header: FHeader.nested(
        title: const Text('主题对话'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _showCreateTheme(context, ref),
          ),
        ],
      ),
      child: themesAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (themes) {
          if (themes.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.messageSquareText,
              title: '暂无主题',
              subtitle: '点右上角新建，或等桌面端同步',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              FTileGroup(
                divider: FItemDivider.full,
                children: [
                  for (final theme in themes) _buildThemeTile(context, theme),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建单个主题条目（头像首字 + 标题 + 更新时间）
  /// 注意：FTileGroup.children 要求 FTile 本体（FTileMixin），不能包一层 StatelessWidget
  FTile _buildThemeTile(BuildContext context, ConversationThemeData theme) {
    final t = context.theme;
    return FTile(
      prefix: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.colors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Text(
          (theme.title ?? '主').characters.first,
          style: t.typography.body.md.copyWith(color: t.colors.primary),
        ),
      ),
      title: Text(theme.title ?? '未命名主题'),
      subtitle: Text(
        '更新于 ${theme.updateTime ?? '-'}${(theme.remark?.isNotEmpty ?? false) ? ' · ${theme.remark}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      suffix: Icon(FLucideIcons.chevronRight, size: 18, color: t.colors.mutedForeground),
      onPress: () => context.push('/conversation/${theme.id}'),
    );
  }

  /// 新建主题底部弹层
  Future<void> _showCreateTheme(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final remark = TextEditingController();
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text('新建主题', style: context.theme.typography.body.lg),
            FTextField(
              label: const Text('主题标题'),
              hint: '例如：深夜情绪记录',
              control: FTextFieldControl.managed(controller: title),
              autofocus: true,
            ),
            FTextField(
              label: const Text('备注（可选）'),
              control: FTextFieldControl.managed(controller: remark),
            ),
            const SizedBox(height: 4),
            FButton(
              onPress: () {
                final t = title.text.trim();
                if (t.isEmpty) return;
                ref
                    .read(conversationRepositoryProvider)
                    .createTheme(title: t, remark: remark.text.trim());
                Navigator.pop(context);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 消息流页（themeId 为路由参数；底部输入栏可追加记录）
class ConversationMessagesPage extends ConsumerStatefulWidget {
  const ConversationMessagesPage({super.key, required this.themeId});

  final String themeId;

  @override
  ConsumerState<ConversationMessagesPage> createState() =>
      _ConversationMessagesPageState();
}

class _ConversationMessagesPageState extends ConsumerState<ConversationMessagesPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref
        .read(conversationRepositoryProvider)
        .addMessage(themeId: widget.themeId, content: text);
    _input.clear();
    // TODO(P2): LLM 回复（后端未定稿）；当前为纯记录型对话，与桌面端「情绪记录」语义一致
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.themeId));
    final t = context.theme;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('对话记录'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: messagesAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (messages) {
          if (messages.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.messageSquareText,
              title: '该主题暂无消息',
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  reverse: true, // 从底部最新消息开始展示
                  children: [
                    for (final msg in messages.reversed)
                      Align(
                        // 桌面端消息为用户记录流，统一左对齐气泡（对话式）
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          decoration: BoxDecoration(
                            color: t.colors.secondary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.content ?? '', style: t.typography.body.md),
                              const SizedBox(height: 4),
                              Text(
                                msg.createTime ?? '',
                                style: t.typography.body.xs
                                    .copyWith(color: t.colors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 底部输入栏
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FTextField(
                          control: FTextFieldControl.managed(controller: _input),
                          hint: '记录一下…',
                          maxLines: 1,
                          onSubmit: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FButton.icon(
                        variant: FButtonVariant.primary,
                        onPress: _send,
                        child: const Icon(FLucideIcons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
