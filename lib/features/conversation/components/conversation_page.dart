// 主题对话页 —— 主题列表 + 消息流（forui 化）
//
// 对齐桌面端 themeConversation 的浏览体验；发送输入栏可追加记录（LLM 后端未定）。
// 新建主题走 showFSheet 底部弹层（替代 showModalBottomSheet）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
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
      child: ColoredBox(
        color: AppTokens.pageTint(context),
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
              padding: EdgeInsets.only(
                top: AppTokens.listTopGapOf(context),
                bottom: AppTokens.pageBottomGapOf(context),
              ),
              children: [
                // 页面专属粉渐变横幅（与内容分组页「主题对话」入口色对齐）
                PageBanner(
                  icon: FLucideIcons.messageSquareText,
                  title: '主题对话',
                  subtitle: '把情绪与想法安放进主题',
                  accentIndex: 4,
                  stats: [('${themes.length}', '个主题')],
                ),
                StaggerList(
                  children: [
                    for (final theme in themes)
                      _ThemeCard(
                        theme: theme,
                        onTap: () => context.push('/conversation/${theme.id}'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 新建主题底部弹层
  Future<void> _showCreateTheme(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final remark = TextEditingController();
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
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

/// 单个主题卡（专属色圆头像 + 标题 + 更新时间 + 箭头），替换原 FTile
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.onTap});

  final ConversationThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final remark = (theme.remark?.isNotEmpty ?? false)
        ? ' · ${theme.remark}'
        : '';
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          SquircleBox(
            size: 44,
            radius: 14,
            gradient: AppTokens.accentGradient(AppTokens.accent(4)),
            alignment: Alignment.center,
            child: Text(
              (theme.title ?? '主').characters.first,
              style: t.typography.body.md.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.title ?? '未命名主题',
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '更新于 ${theme.updateTime ?? '-'}$remark',
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            FLucideIcons.chevronRight,
            size: 18,
            color: t.colors.mutedForeground,
          ),
        ],
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

class _ConversationMessagesPageState
    extends ConsumerState<ConversationMessagesPage> {
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
          return ColoredBox(
            color: AppTokens.pageTint(context),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    reverse: true, // 从底部最新消息开始展示
                    children: [
                      for (final msg in messages.reversed)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SquircleBox(
                                  size: 30,
                                  radius: 10,
                                  gradient: AppTokens.accentGradient(
                                    AppTokens.accent(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    FLucideIcons.messageSquareText,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      // 主题对话专属粉软底气泡（accent(4)），与列表页横幅同色系
                                      color: AppTokens.accentSoft(
                                        context,
                                        AppTokens.accent(4),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.content ?? '',
                                          style: t.typography.body.md,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          msg.createTime ?? '',
                                          style: t.typography.body.xs.copyWith(
                                            color: t.colors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                            control: FTextFieldControl.managed(
                              controller: _input,
                            ),
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
            ),
          );
        },
      ),
    );
  }
}
