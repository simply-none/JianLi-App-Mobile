// 主题对话页 —— 主题列表 + 消息流（只读）
//
// 对齐桌面端 themeConversation 的浏览体验；发送输入框暂隐藏（LLM 后端未定）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/ui_atoms.dart';
import '../repositories/conversation_repository.dart';

/// 主题列表页
class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(conversationThemesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('主题对话')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTheme(context, ref),
        child: const Icon(Icons.add),
      ),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (themes) {
          if (themes.isEmpty) {
            return const EmptyState(
              icon: Icons.forum,
              title: '暂无主题',
              subtitle: '点右下角新建，或等桌面端同步',
            );
          }
          return ListView(
            children: [
              for (final theme in themes)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (theme.title ?? '主').characters.first,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(theme.title ?? '未命名主题'),
                  subtitle: Text(
                    '更新于 ${theme.updateTime ?? '-'}${(theme.remark?.isNotEmpty ?? false) ? ' · ${theme.remark}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/conversation/${theme.id}'),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 新建主题弹层
  Future<void> _showCreateTheme(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final remark = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: '主题标题', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: remark,
              decoration: const InputDecoration(
                  labelText: '备注（可选）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
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
    return Scaffold(
      appBar: AppBar(title: const Text('对话记录')),
      body: messagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (messages) {
          if (messages.isEmpty) {
            return const EmptyState(icon: Icons.chat_bubble_outline, title: '该主题暂无消息');
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
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
                            color:
                                Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.content ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Text(
                                msg.createTime ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: '记录一下…',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.send),
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
