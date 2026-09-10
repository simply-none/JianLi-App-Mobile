// 主题对话页 —— 主题列表 + 消息流（对齐桌面端 themeConversation 的移动端子集）
//
// 能力对齐（桌面端 references/modules/theme-conversation.md）：
// - 主题：新建/编辑（标题+备注，底部抽屉 + 底部固定保存条）、删除（子主题禁止 + 级联删消息，
//   底部抽屉二次确认）、消息数角标、主题标签彩色徽标（conversation_tag 解析）、update_time 排序；
// - 消息：置顶（pinned='1' 排前 + 图标）、富文本（is_rich='1' 用 HtmlWidget 渲染，'0' 纯文本）、
//   软删除（长按气泡 → 底部抽屉确认，is_deleted='1' 行保留）、底部输入栏追加记录；
// 未做（桌面端有、移动端裁剪，记 SKILL.md 待办）：引用/跨主题引用、标注、多选、搜索、导出 Markdown、标签管理。
import 'dart:async';
import 'dart:convert';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/filter_sheet.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/db/app_database.dart';
import '../repositories/conversation_repository.dart';
import '../utils/export_markdown.dart';

/// 主题列表页
class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(conversationThemesProvider);
    final countsAsync = ref.watch(themeCountsProvider);
    final tagsAsync = ref.watch(conversationTagsProvider);
    final tagDefs = tagsAsync.value ?? const <ConversationTagData>[];
    final tagById = {for (final t in tagDefs) t.id.toString(): t};
    final counts = countsAsync.value ?? const <String, int>{};

    return FScaffold(
      header: FHeader.nested(
        title: const Text('主题对话'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.download),
            onPress: () => _openExportPicker(context, ref),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _showThemeEditor(context, ref),
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
            var totalMessages = 0;
            for (final t in themes) {
              totalMessages += counts[t.id.toString()] ?? 0;
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
                  stats: [
                    ('${themes.length}', '个主题'),
                    ('$totalMessages', '条记录'),
                  ],
                ),
                StaggerList(
                  children: [
                    for (final theme in themes)
                      _ThemeCard(
                        theme: theme,
                        messageCount: counts[theme.id.toString()] ?? 0,
                        tagById: tagById,
                        onTap: () => context.push('/conversation/${theme.id}'),
                        onLongPress: () =>
                            _showThemeActions(context, ref, theme),
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

  /// 主题长按操作抽屉（页面规范：小功能操作走底部抽屉）
  Future<void> _showThemeActions(
    BuildContext context,
    WidgetRef ref,
    ConversationThemeData theme,
  ) async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => SheetSurface(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              theme.title ?? '未命名主题',
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            FTileGroup(
              divider: FItemDivider.none,
              children: [
                FTile(
                  prefix: const Icon(FLucideIcons.pencil, size: 16),
                  title: const Text('编辑主题'),
                  onPress: () {
                    Navigator.pop(context);
                    _showThemeEditor(context, ref, existing: theme);
                  },
                ),
                FTile(
                  prefix: const Icon(FLucideIcons.download, size: 16),
                  title: const Text('导出 Markdown'),
                  subtitle: const Text('导出该主题全部对话为 .md'),
                  onPress: () {
                    Navigator.pop(context);
                    _exportTheme(context, ref, theme);
                  },
                ),
                FTile(
                  prefix: Icon(
                    FLucideIcons.trash2,
                    size: 16,
                    color: context.theme.colors.destructive,
                  ),
                  title: Text(
                    '删除主题',
                    style: context.theme.typography.body.md.copyWith(
                      color: context.theme.colors.destructive,
                    ),
                  ),
                  onPress: () {
                    Navigator.pop(context);
                    _deleteTheme(context, ref, theme);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 新建 / 编辑主题抽屉（底部固定保存条——页面保存规范）
  Future<void> _showThemeEditor(
    BuildContext context,
    WidgetRef ref, {
    ConversationThemeData? existing,
  }) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final remark = TextEditingController(text: existing?.remark ?? '');
    // 编辑草稿：主题标签 id（scope='theme'），对齐 PC 主题编辑可挂标签
    final editTagIds = <String>{..._ThemeCard._parseIds(existing?.tags)};
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
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
          children: [
            Text(
              existing == null ? '新建主题' : '编辑主题',
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FTextField(
              label: const Text('主题标题'),
              hint: '例如：深夜情绪记录',
              control: FTextFieldControl.managed(controller: title),
              autofocus: existing == null,
            ),
            const SizedBox(height: 10),
            FTextField(
              label: const Text('备注（可选）'),
              control: FTextFieldControl.managed(controller: remark),
            ),
            const SizedBox(height: 14),
            // 主题标签选择（对齐 PC 主题编辑可挂标签；scope='theme'，复用消息标签彩色徽标规格）
            StatefulBuilder(
              builder: (ctx, setInner) {
                final t = ctx.theme;
                final themeTagDefs =
                    ((ref.read(conversationTagsProvider).value ??
                            const <ConversationTagData>[]))
                        .where((d) => d.scope == 'theme')
                        .toList();
                final tagById = {for (final d in themeTagDefs) d.id.toString(): d};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await _openThemeTagPicker(ctx, ref, editTagIds);
                        if (picked != null && ctx.mounted) {
                          editTagIds
                            ..clear()
                            ..addAll(picked);
                          setInner(() {});
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.colors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: t.colors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FLucideIcons.tags,
                              size: 14,
                              color: AppTokens.accent(4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              editTagIds.isEmpty
                                  ? '主题标签'
                                  : '主题标签 ${editTagIds.length}',
                              style: t.typography.body.xs.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (editTagIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final id in editTagIds)
                            if (tagById[id] != null)
                              GestureDetector(
                                onTap: () {
                                  editTagIds.remove(id);
                                  setInner(() {});
                                },
                                child: _ConvTagBadge(tag: tagById[id]!),
                              ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: existing == null ? '创建' : '保存',
              icon: FLucideIcons.check,
              onPress: () {
                final t = title.text.trim();
                if (t.isEmpty) return;
                final repo = ref.read(conversationRepositoryProvider);
                if (existing == null) {
                  repo.createTheme(
                    title: t,
                    remark: remark.text.trim(),
                    tagIds: editTagIds.toList(),
                  );
                } else {
                  repo.updateTheme(
                    existing.id,
                    title: t,
                    remark: remark.text.trim(),
                    tagIds: editTagIds.toList(),
                  );
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 删除主题（底部抽屉二次确认——全局弹窗规范；子主题检查在仓储层）
  Future<void> _deleteTheme(
    BuildContext context,
    WidgetRef ref,
    ConversationThemeData theme,
  ) async {
    final confirmed = await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          12,
          AppTokens.pagePadding,
          12,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '确认删除主题「${theme.title ?? ''}」？',
                style: c.theme.typography.body.lg,
              ),
              const SizedBox(height: 8),
              Text(
                '将同时删除其下全部对话，且不可恢复',
                style: c.theme.typography.body.sm.copyWith(
                  color: c.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => Navigator.pop(c, false),
                      child: const Text('取消'),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.destructive,
                      onPress: () => Navigator.pop(c, true),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(conversationRepositoryProvider).deleteTheme(theme.id);
    } catch (e) {
      if (context.mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('删除失败'),
          description: Text('$e'.replaceFirst('Exception: ', '')),
        );
      }
    }
  }

  /// 打开主题标签选择抽屉（scope='theme'，复用消息标签选择规格；草稿 + 完成/清空）
  Future<Set<String>?> _openThemeTagPicker(
    BuildContext context,
    WidgetRef ref,
    Set<String> seed,
  ) async {
    final tagDefs =
        ((ref.read(conversationTagsProvider).value ??
                const <ConversationTagData>[]))
            .where((d) => d.scope == 'theme')
            .toList();
    final draft = <String>{...seed};
    final result = await showFilterSheet<Set<String>>(
      context: context,
      title: '主题标签',
      confirmLabel: '完成',
      resetLabel: '清空',
      body: (context, refresh) =>
          _buildThemeTagPickerBody(context, ref, tagDefs, draft, refresh),
      onReset: (refresh) {
        draft.clear();
        refresh();
      },
      onConfirm: () => Set<String>.of(draft),
    );
    if (result == null || !context.mounted) return null;
    return result;
  }

  /// 主题标签选择抽屉选项区（统一规格 chip + 新建标签入口，创建 scope='theme'）
  Widget _buildThemeTagPickerBody(
    BuildContext context,
    WidgetRef ref,
    List<ConversationTagData> tagDefs,
    Set<String> draft,
    VoidCallback refresh,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tagDefs.isEmpty)
          Text(
            '暂无主题标签，点下方「新建标签」创建',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tagDefs)
                _ConvTagOption(
                  tag: tag,
                  selected: draft.contains(tag.id.toString()),
                  onTap: () {
                    final key = tag.id.toString();
                    draft.contains(key) ? draft.remove(key) : draft.add(key);
                    refresh();
                  },
                ),
            ],
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _createThemeTag(context, ref, draft, refresh),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(
                color: context.theme.colors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FLucideIcons.plus,
                  size: 13,
                  color: context.theme.colors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '新建标签',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 新建主题标签（scope='theme'，创建后自动加入草稿并刷新选择区）
  Future<void> _createThemeTag(
    BuildContext context,
    WidgetRef ref,
    Set<String> draft,
    VoidCallback refresh,
  ) async {
    final controller = TextEditingController();
    final name = await showFSheet<String>(
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
          children: [
            Text(
              '新建主题标签',
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '配色按顺序自动分配，与桌面端一致',
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 14),
            FTextField(
              control: FTextFieldControl.managed(controller: controller),
              hint: '输入标签名称',
              autofocus: true,
              onSubmit: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: '创建',
              icon: FLucideIcons.check,
              onPress: () => Navigator.pop(context, controller.text),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final tag = await ref
        .read(conversationRepositoryProvider)
        .createThemeTag(name.trim());
    if (context.mounted) {
      draft.add(tag.id.toString());
      refresh();
    }
  }

  /// 导出单个主题为 Markdown 并分享
  Future<void> _exportTheme(
    BuildContext context,
    WidgetRef ref,
    ConversationThemeData theme,
  ) async {
    final repo = ref.read(conversationRepositoryProvider);
    final msgs = await repo.getMessagesByTheme(theme.id.toString());
    final tagById = {
      for (final t in (ref.read(conversationTagsProvider).value ??
              const <ConversationTagData>[]))
        t.id.toString(): t,
    };
    final md = buildThemeMarkdown(theme, msgs, tagById);
    if (!context.mounted) return;
    await _shareMarkdown(
      context,
      md,
      '主题-${_sanitize(theme.title)}_${_timestamp()}.md',
    );
  }

  /// 批量导出：底部多选抽屉（对齐 PC ExportThemesDialog），合并为单个 .md 分享
  Future<void> _openExportPicker(BuildContext context, WidgetRef ref) async {
    final themes = ref.read(conversationThemesProvider).value ??
        const <ConversationThemeData>[];
    if (themes.isEmpty) {
      if (context.mounted) {
        showFToast(context: context, title: const Text('暂无可导出的主题'));
      }
      return;
    }
    final draft = <int>{};
    final result = await showFilterSheet<Set<int>>(
      context: context,
      title: '导出主题',
      confirmLabel: '导出',
      resetLabel: '清空',
      body: (c, refresh) => _buildExportPickerBody(c, ref, refresh, themes, draft),
      onReset: (refresh) {
        draft.clear();
        refresh();
      },
      onConfirm: () => Set<int>.of(draft),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final repo = ref.read(conversationRepositoryProvider);
    final tagById = {
      for (final t in (ref.read(conversationTagsProvider).value ??
              const <ConversationTagData>[]))
        t.id.toString(): t,
    };
    final messagesByTheme = <int, List<ConversationData>>{};
    for (final id in result) {
      messagesByTheme[id] = await repo.getMessagesByTheme(id.toString());
    }
    final selectedThemes = [
      for (final th in themes)
        if (result.contains(th.id)) th,
    ];
    final md = buildThemesMarkdown(selectedThemes, messagesByTheme, tagById);
    if (!context.mounted) return;
    await _shareMarkdown(context, md, '主题对话导出_${_timestamp()}.md');
  }

  /// 批量导出多选抽屉选项区（全选/反选 + 主题勾选行）
  Widget _buildExportPickerBody(
    BuildContext context,
    WidgetRef ref,
    VoidCallback refresh,
    List<ConversationThemeData> themes,
    Set<int> draft,
  ) {
    final counts =
        ref.read(themeCountsProvider).value ?? const <String, int>{};
    final allChecked =
        themes.isNotEmpty && draft.length == themes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                if (allChecked) {
                  draft.clear();
                } else {
                  draft.addAll(themes.map((t) => t.id));
                }
                refresh();
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                allChecked ? '取消全选' : '全选',
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '已选 ${draft.length} / ${themes.length}',
              style: context.theme.typography.body.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final theme in themes)
          _ExportThemeItem(
            theme: theme,
            count: counts[theme.id.toString()] ?? 0,
            selected: draft.contains(theme.id),
            onTap: () {
              draft.contains(theme.id)
                  ? draft.remove(theme.id)
                  : draft.add(theme.id);
              refresh();
            },
          ),
      ],
    );
  }

  /// 生成 Markdown 文本并写入临时目录，经系统分享面板导出（对齐 PC 落盘 .md）
  Future<void> _shareMarkdown(
    BuildContext context,
    String markdown,
    String filename,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(markdown);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: '主题对话导出'),
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
}

/// 单个主题卡（粉渐变头像 + 标题 + 标签彩色徽标 + 消息数 + 更新时间），长按出操作
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.messageCount,
    required this.tagById,
    required this.onTap,
    required this.onLongPress,
  });

  final ConversationThemeData theme;
  final int messageCount;
  final Map<String, ConversationTagData> tagById;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final remark = (theme.remark?.isNotEmpty ?? false)
        ? ' · ${theme.remark}'
        : '';
    // 主题标签：tags JSON（标签 id 数组）→ conversation_tag 名称/颜色
    final themeTags = <ConversationTagData>[
      for (final id in _parseIds(theme.tags))
        if (tagById[id] != null) tagById[id]!,
    ];
    // 长按出操作抽屉（外层长按与 AppCard 内层点击手势可共存）
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
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
                  if (themeTags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final tag in themeTags.take(3))
                          _ConvTagBadge(tag: tag),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '$messageCount 条 · 更新于 ${theme.updateTime ?? '-'}$remark',
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
      ),
    );
  }

  /// 解析 tags JSON 数组文本（异常返回空）
  static List<String> _parseIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final v = raw.replaceAll(RegExp(r'^\[|\]$'), '');
      if (v.trim().isEmpty) return const [];
      return v.split(',').map((e) => e.trim().replaceAll('"', '')).toList();
    } catch (_) {
      return const [];
    }
  }
}

/// 主题标签彩色徽标（conversation_tag 颜色 + 名称）
class _ConvTagBadge extends StatelessWidget {
  const _ConvTagBadge({required this.tag});

  final ConversationTagData tag;

  Color get _color {
    final hex = (tag.color ?? '').replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    return v == null ? const Color(0xFF6366F1) : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            tag.name ?? '',
            style: t.typography.body.xs.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 消息流页（themeId 为路由参数；底部输入栏可追加记录；长按气泡出操作菜单；
/// highlightId：跨主题跳转时定位高亮的消息）
class ConversationMessagesPage extends ConsumerStatefulWidget {
  const ConversationMessagesPage({
    super.key,
    required this.themeId,
    this.highlightId,
  });

  final String themeId;

  /// 跨主题跳转定位：进入后滚动到该消息并短暂高亮
  final int? highlightId;

  @override
  ConsumerState<ConversationMessagesPage> createState() =>
      _ConversationMessagesPageState();
}

class _ConversationMessagesPageState
    extends ConsumerState<ConversationMessagesPage> {
  final _input = TextEditingController();

  /// 发送草稿：待附加到下一条消息的标签 id（输入框上方工具条呈现）
  final Set<String> _pendingTagIds = {};

  /// 发送草稿：待引用的消息 id（同主题写 ref_ids、跨主题写 cross_refs，发送时按归属分类）
  final Set<int> _pendingRefIds = {};

  /// 引用选择抽屉内的草稿与搜索词
  final Set<int> _draftRefSel = {};
  final TextEditingController _refSearchController = TextEditingController();
  String _refKeyword = '';

  /// 标签选择抽屉内的草稿（点「完成」才应用）
  final Set<String> _draftMsgTags = {};

  /// 每条消息的定位 key（引用跳转 ensureVisible 用）
  final Map<int, GlobalKey> _itemKeys = {};
  GlobalKey _keyOf(int id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  int? _highlightId; // 当前高亮的消息（短暂显示后自动清除）
  Timer? _highlightTimer;
  bool _jumped = false; // 跨主题进入的高亮定位只执行一次

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _input.dispose();
    _refSearchController.dispose();
    super.dispose();
  }

  /// 滚动定位到某条消息并高亮片刻
  void _highlightMessage(int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _itemKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.25,
        );
      }
      if (mounted) setState(() => _highlightId = id);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _highlightId = null);
      });
    });
  }

  /// 解析 JSON 字符串数组（消息 ref_ids 用）
  static List<String> _idsOf(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return [
        if (v is List)
          for (final e in v) e.toString(),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 解析跨主题引用 JSON（[{themeId, convId}]）
  static List<({int themeId, int convId})> _crossOf(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return [
        if (v is List)
          for (final e in v)
            if (e is Map)
              (
                themeId: int.tryParse('${e['themeId']}') ?? 0,
                convId: int.tryParse('${e['convId']}') ?? 0,
              ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 点气泡上的引用关系 tag：打开对应的关系抽屉
  Future<void> _openRefTag(ConversationData msg, String kind) async {
    final links = await ref
        .read(conversationRepositoryProvider)
        .loadRefLinks(msg);
    if (!mounted) return;
    switch (kind) {
      case 'outgoing':
        await _showRefDrawer('正向链接', [
          for (final c in links.outgoing) ConvRefItem(c, null),
        ]);
      case 'cross':
        await _showRefDrawer('跨主题引用', links.cross);
      case 'backSame':
        await _showRefDrawer('被引用', [
          for (final b in links.backlinks)
            if (b.msg.themeId == msg.themeId) b,
        ]);
      case 'backCross':
        await _showRefDrawer('被跨主题引用', [
          for (final b in links.backlinks)
            if (b.msg.themeId != msg.themeId) b,
        ]);
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // 引用草稿按归属分类：同主题 → ref_ids；跨主题 → cross_refs（对齐桌面端语义）
    final all =
        ref.read(allConversationsProvider).value ?? const <ConversationData>[];
    final byId = {for (final c in all) c.id: c};
    final sameRefs = <String>[];
    final crossRefs = <({int themeId, int convId})>[];
    for (final id in _pendingRefIds) {
      final m = byId[id];
      if (m == null) continue;
      if (m.themeId == widget.themeId) {
        sameRefs.add('$id');
      } else {
        crossRefs.add((
          themeId: int.tryParse(m.themeId ?? '') ?? 0,
          convId: id,
        ));
      }
    }
    ref
        .read(conversationRepositoryProvider)
        .addMessage(
          themeId: widget.themeId,
          content: text,
          tagIds: _pendingTagIds.toList(),
          refIds: sameRefs,
          crossRefs: crossRefs,
        );
    _input.clear();
    setState(() {
      _pendingTagIds.clear();
      _pendingRefIds.clear();
    });
    // TODO(P2): LLM 回复（后端未定稿）；当前为纯记录型对话，与桌面端「情绪记录」语义一致
  }

  /// 打开「引用对话」选择抽屉（多主题、模糊搜索、多选；页面规范：获取数据走底部抽屉）
  Future<void> _openRefPicker() async {
    _draftRefSel
      ..clear()
      ..addAll(_pendingRefIds);
    _refKeyword = '';
    _refSearchController.clear();
    final result = await showFilterSheet<Set<int>>(
      context: context,
      title: '引用对话',
      confirmLabel: '完成',
      resetLabel: '清空',
      body: (context, refresh) => _buildRefPickerBody(refresh),
      onReset: (refresh) {
        _draftRefSel.clear();
        _refKeyword = '';
        _refSearchController.clear();
        refresh();
      },
      onConfirm: () => Set<int>.of(_draftRefSel),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pendingRefIds
        ..clear()
        ..addAll(result);
    });
  }

  /// 引用选择抽屉选项区：搜索框（模糊匹配内容/主题标题）+ 结果列表（多选）
  Widget _buildRefPickerBody(VoidCallback refresh) {
    final themes =
        ref.read(conversationThemesProvider).value ??
        const <ConversationThemeData>[];
    final themeTitles = {for (final th in themes) th.id: th.title};
    final all =
        (ref.read(allConversationsProvider).value ?? const <ConversationData>[])
            .where((c) => c.isDeleted != '1')
            .toList()
          ..sort((a, b) => (b.createTime ?? '').compareTo(a.createTime ?? ''));

    final kw = _refKeyword.trim().toLowerCase();
    final filtered = kw.isEmpty
        ? all
        : all.where((c) {
            final inContent = (c.content ?? '').toLowerCase().contains(kw);
            final inTheme = (themeTitles[int.tryParse(c.themeId ?? '')] ?? '')
                .toLowerCase()
                .contains(kw);
            return inContent || inTheme;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FTextField(
          // ⚠️ onChange 必须写在 FTextFieldControl.managed 上（FTextField 本体无此
          // 参数，雷区 #6——本文件第二次实踩，搜索框忘挪）
          control: FTextFieldControl.managed(
            controller: _refSearchController,
            onChange: (_) =>
                setState(() => _refKeyword = _refSearchController.text),
          ),
          hint: '模糊搜索内容或主题…',
          size: FTextFieldSizeVariant.sm,
          prefixBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(FLucideIcons.search, size: 15),
          ),
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                '无匹配结果',
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ),
          )
        else ...[
          for (final c in filtered.take(80))
            _RefPickItem(
              msg: c,
              themeTitle: themeTitles[int.tryParse(c.themeId ?? '')],
              selected: _draftRefSel.contains(c.id),
              isCurrentTheme: c.themeId == widget.themeId,
              onTap: () {
                _draftRefSel.contains(c.id)
                    ? _draftRefSel.remove(c.id)
                    : _draftRefSel.add(c.id);
                refresh();
              },
            ),
          if (filtered.length > 80)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '仅展示最近 80 条，请用搜索缩小范围',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// 打开消息标签选择抽屉（页面规范：获取数据走底部抽屉；草稿 + 完成/清空）
  Future<void> _openMsgTagPicker() async {
    final tagDefs =
        ((ref.read(conversationTagsProvider).value ??
                const <ConversationTagData>[]))
            .where((d) => d.scope == 'conversation')
            .toList();
    _draftMsgTags
      ..clear()
      ..addAll(_pendingTagIds);
    final result = await showFilterSheet<Set<String>>(
      context: context,
      title: '选择标签',
      confirmLabel: '完成',
      resetLabel: '清空',
      body: (context, refresh) => _buildMsgTagPickerBody(tagDefs, refresh),
      onReset: (refresh) {
        _draftMsgTags.clear();
        refresh();
      },
      onConfirm: () => Set<String>.of(_draftMsgTags),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pendingTagIds
        ..clear()
        ..addAll(result);
    });
  }

  /// 编辑一条已有消息的标签（长按菜单入口；确认后写回 tags）
  Future<void> _editMsgTags(ConversationData msg) async {
    final tagDefs =
        ((ref.read(conversationTagsProvider).value ??
                const <ConversationTagData>[]))
            .where((d) => d.scope == 'conversation')
            .toList();
    _draftMsgTags
      ..clear()
      ..addAll(_idsOf(msg.tags));
    final result = await showFilterSheet<Set<String>>(
      context: context,
      title: '编辑标签',
      confirmLabel: '完成',
      resetLabel: '清空',
      body: (context, refresh) => _buildMsgTagPickerBody(tagDefs, refresh),
      onReset: (refresh) {
        _draftMsgTags.clear();
        refresh();
      },
      onConfirm: () => Set<String>.of(_draftMsgTags),
    );
    if (result == null || !mounted) return;
    await ref
        .read(conversationRepositoryProvider)
        .updateMessageTags(msg.id, result.toList());
  }

  /// 标签选择抽屉选项区（统一规格 chip + 新建标签入口）
  Widget _buildMsgTagPickerBody(
    List<ConversationTagData> tagDefs,
    VoidCallback refresh,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tagDefs.isEmpty)
          Text(
            '暂无标签，点下方「新建标签」创建',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tagDefs)
                _ConvTagOption(
                  tag: tag,
                  selected: _draftMsgTags.contains(tag.id.toString()),
                  onTap: () {
                    final key = tag.id.toString();
                    _draftMsgTags.contains(key)
                        ? _draftMsgTags.remove(key)
                        : _draftMsgTags.add(key);
                    refresh();
                  },
                ),
            ],
          ),
        const SizedBox(height: 12),
        // 新建标签（抽屉内嵌入口；创建后自动选中）
        GestureDetector(
          onTap: () => _createConversationTag(refresh),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(
                color: context.theme.colors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FLucideIcons.plus,
                  size: 13,
                  color: context.theme.colors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '新建标签',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 新建对话标签小抽屉（创建后自动加入草稿并刷新选择区）
  Future<void> _createConversationTag(VoidCallback refresh) async {
    final controller = TextEditingController();
    final name = await showFSheet<String>(
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
          children: [
            Text(
              '新建标签',
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '配色按顺序自动分配，与桌面端一致',
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 14),
            FTextField(
              control: FTextFieldControl.managed(controller: controller),
              hint: '输入标签名称',
              autofocus: true,
              onSubmit: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: '创建',
              icon: FLucideIcons.check,
              onPress: () => Navigator.pop(context, controller.text),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final tag = await ref
        .read(conversationRepositoryProvider)
        .createConversationTag(name.trim());
    if (mounted) {
      setState(() => _draftMsgTags.add(tag.id.toString()));
      refresh();
    }
  }

  /// 长按气泡：操作菜单（对齐 PC 右键菜单的移动端子集——正向/反向链接、置顶、删除）
  Future<void> _showMessageMenu(ConversationData msg) async {
    final links = await ref
        .read(conversationRepositoryProvider)
        .loadRefLinks(msg);
    if (!mounted) return;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => SheetSurface(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 摘要标题（富文本剥标签）
            Text(
              _snippetOf(msg).isEmpty ? '（无文本内容）' : _snippetOf(msg),
              style: context.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            FTileGroup(
              divider: FItemDivider.none,
              children: [
                // 引用此对话：挂入发送草稿，发送时写入 ref_ids/cross_refs（对齐 PC「引用此对话」）
                FTile(
                  prefix: const Icon(FLucideIcons.link, size: 16),
                  title: const Text('引用此对话'),
                  subtitle: Text(
                    _pendingRefIds.contains(msg.id)
                        ? '已在发送引用草稿中'
                        : '发送下一条记录时一并引用',
                  ),
                  onPress: () {
                    Navigator.pop(context);
                    setState(() => _pendingRefIds.add(msg.id));
                    showFToast(
                      context: context,
                      title: const Text('已加入引用，发送时生效'),
                    );
                  },
                ),
                // 正向链接：本条引用的消息（对齐 PC「正向链接」）
                FTile(
                  prefix: const Icon(FLucideIcons.arrowUpRight, size: 16),
                  title: Text('正向链接（${links.outgoing.length}）'),
                  subtitle: const Text('本条引用的消息'),
                  onPress: links.outgoing.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showRefDrawer('正向链接', [
                            for (final c in links.outgoing)
                              ConvRefItem(c, null),
                          ]);
                        },
                ),
                // 反向链接：引用了本条的消息（含跨主题来源，对齐 PC「反向链接」）
                FTile(
                  prefix: const Icon(FLucideIcons.arrowDownLeft, size: 16),
                  title: Text('反向链接（${links.backlinks.length}）'),
                  subtitle: const Text('引用了本条的消息'),
                  onPress: links.backlinks.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showRefDrawer('反向链接', links.backlinks);
                        },
                ),
                // 跨主题引用：本条 cross_refs 指向的其它主题消息
                if (links.cross.isNotEmpty)
                  FTile(
                    prefix: const Icon(FLucideIcons.layers, size: 16),
                    title: Text('跨主题引用（${links.cross.length}）'),
                    subtitle: const Text('本条引用的其它主题消息'),
                    onPress: () {
                      Navigator.pop(context);
                      _showRefDrawer('跨主题引用', links.cross);
                    },
                  ),
                FTile(
                  prefix: const Icon(FLucideIcons.tags, size: 16),
                  title: const Text('编辑标签'),
                  subtitle: Text('当前 ${_idsOf(msg.tags).length} 个'),
                  onPress: () {
                    Navigator.pop(context);
                    _editMsgTags(msg);
                  },
                ),
                FTile(
                  prefix: Icon(
                    msg.pinned == '1' ? FLucideIcons.pinOff : FLucideIcons.pin,
                    size: 16,
                  ),
                  title: Text(msg.pinned == '1' ? '取消置顶' : '置顶'),
                  onPress: () {
                    Navigator.pop(context);
                    ref.read(conversationRepositoryProvider).togglePin(msg);
                  },
                ),
                FTile(
                  prefix: Icon(
                    FLucideIcons.trash2,
                    size: 16,
                    color: context.theme.colors.destructive,
                  ),
                  title: Text(
                    '删除记录',
                    style: context.theme.typography.body.md.copyWith(
                      color: context.theme.colors.destructive,
                    ),
                  ),
                  onPress: () {
                    Navigator.pop(context);
                    _confirmSoftDelete(msg);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 引用关系右侧抽屉（对齐 PC ReferenceDrawer）：列出关联消息（跨主题附主题名）；
  /// 点击条目跳转定位——同主题滚动+高亮，跨主题 push 对方主题页并带 highlight
  Future<void> _showRefDrawer(String title, List<ConvRefItem> items) async {
    final screenW = MediaQuery.of(context).size.width;
    await showFSheet<void>(
      context: context,
      side: FLayout.rtl,
      builder: (sheetContext) => SheetSurface(
        // 右侧抽屉：左侧圆角
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(AppTokens.radiusLg),
        ),
        child: SafeArea(
          child: SizedBox(
            width: screenW * 0.8 > 340 ? 340 : screenW * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: context.theme.typography.body.lg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${items.length} 条',
                        style: context.theme.typography.body.xs.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const FDivider(),
                Expanded(
                  child: items.isEmpty
                      ? const EmptyState(
                          icon: FLucideIcons.unlink,
                          title: '无引用关系',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          children: [
                            for (final item in items)
                              AppCard(
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  final targetTheme =
                                      item.msg.themeId ?? widget.themeId;
                                  if (targetTheme == widget.themeId) {
                                    _highlightMessage(item.msg.id);
                                  } else {
                                    context.push(
                                      '/conversation/$targetTheme'
                                      '?highlight=${item.msg.id}',
                                    );
                                  }
                                },
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTokens.pagePadding,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.themeTitle != null) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            FLucideIcons.layers,
                                            size: 12,
                                            color: context.theme.colors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.themeTitle!,
                                              style: context
                                                  .theme
                                                  .typography
                                                  .body
                                                  .xs
                                                  .copyWith(
                                                    color: context
                                                        .theme
                                                        .colors
                                                        .primary,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      _snippetOf(item.msg).isEmpty
                                          ? '（无文本内容）'
                                          : _snippetOf(item.msg),
                                      style: context.theme.typography.body.sm,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.msg.createTime ?? '',
                                      style: context.theme.typography.body.xs
                                          .copyWith(
                                            color: context
                                                .theme
                                                .colors
                                                .mutedForeground,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 富文本摘要（剥标签 + 压空白）
  String _snippetOf(ConversationData m) {
    final raw = m.content ?? '';
    final text = m.isRich == '1'
        ? raw.replaceAll(RegExp(r'<[^>]*>'), ' ')
        : raw;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 长按气泡：软删除确认（底部抽屉——全局弹窗规范；行保留对齐桌面追溯语义）
  Future<void> _confirmSoftDelete(ConversationData msg) async {
    final confirmed = await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          12,
          AppTokens.pagePadding,
          12,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('删除这条记录？', style: c.theme.typography.body.lg),
              const SizedBox(height: 8),
              Text(
                '记录将标记为已删除（保留数据以便追溯）',
                style: c.theme.typography.body.sm.copyWith(
                  color: c.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => Navigator.pop(c, false),
                      child: const Text('取消'),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.destructive,
                      onPress: () => Navigator.pop(c, true),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(conversationRepositoryProvider).softDeleteMessage(msg.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.themeId));
    final allAsync = ref.watch(allConversationsProvider);
    // 消息标签定义（scope='conversation'），气泡徽标与工具条草稿解析用
    final msgTagDefs =
        (ref.watch(conversationTagsProvider).value ??
                const <ConversationTagData>[])
            .where((d) => d.scope == 'conversation')
            .toList();
    final msgTagById = {for (final d in msgTagDefs) d.id.toString(): d};
    final t = context.theme;

    // 引用关系计数（一次扫描全表）：被引用（同主题 ref_ids）/ 被跨主题引用（cross_refs）
    final all = allAsync.value ?? const <ConversationData>[];
    final allById = {for (final c in all) c.id: c};
    final sameBack = <int, int>{};
    final crossBack = <int, int>{};
    for (final m in all) {
      for (final rid in _idsOf(m.refIds)) {
        final id = int.tryParse(rid);
        if (id == null || id == m.id) continue;
        sameBack[id] = (sameBack[id] ?? 0) + 1;
      }
      for (final x in _crossOf(m.crossRefs)) {
        if (x.convId == m.id) continue;
        crossBack[x.convId] = (crossBack[x.convId] ?? 0) + 1;
      }
    }

    // 跨主题跳转：数据就绪后定位高亮一次（右侧抽屉/路由 highlight 进入）
    if (!_jumped &&
        widget.highlightId != null &&
        messagesAsync.value?.any((m) => m.id == widget.highlightId) == true) {
      _jumped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _highlightMessage(widget.highlightId!);
      });
    }

    return FScaffold(
      header: FHeader.nested(
        title: const Text('对话记录'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: messagesAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (messages) {
          // 空态只占列表区：底部工具条与输入栏常驻（否则首条记录无法输入）
          return ColoredBox(
            color: AppTokens.pageTint(context),
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: FLucideIcons.messageSquareText,
                            title: '该主题暂无消息',
                            subtitle: '在下方输入框记录第一条',
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppTokens.pagePadding,
                            12,
                            AppTokens.pagePadding,
                            12,
                          ),
                          reverse: true, // 从底部最新消息开始展示
                          children: [
                            for (final msg in messages.reversed)
                              Align(
                                key: _keyOf(msg.id),
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SquircleBox(
                                        size: 30,
                                        radius: 10,
                                        gradient: AppTokens.accentGradient(
                                          AppTokens.accent(4),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          msg.pinned == '1'
                                              ? FLucideIcons.pin
                                              : FLucideIcons.messageSquareText,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onLongPress: () =>
                                              _showMessageMenu(msg),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              // 主题对话专属粉软底气泡（accent(4)）；被定位时加深高亮
                                              color: _highlightId == msg.id
                                                  ? AppTokens.accent(4)
                                                        .withValues(alpha: 0.35)
                                                  : AppTokens.accentSoft(
                                                      context,
                                                      AppTokens.accent(4),
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // 富文本（is_rich='1'，PC vue-quill 产物）走 HTML 渲染
                                                if (msg.isRich == '1')
                                                  HtmlWidget(
                                                    msg.content ?? '',
                                                    textStyle: TextStyle(
                                                      fontSize:
                                                          t
                                                              .typography
                                                              .body
                                                              .md
                                                              .fontSize ??
                                                          14,
                                                      height: 1.6,
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    msg.content ?? '',
                                                    style: t.typography.body.md,
                                                  ),
                                                // 消息标签（对齐 PC 气泡标签行，conversation_tag 彩色徽标）
                                                if (_idsOf(msg.tags)
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      for (final id in _idsOf(
                                                        msg.tags,
                                                      ))
                                                        if (msgTagById[id] !=
                                                            null)
                                                          _ConvTagBadge(
                                                            tag:
                                                                msgTagById[id]!,
                                                          ),
                                                    ],
                                                  ),
                                                ],
                                                // 引用关系 tag（对齐 PC 气泡 footer），点击开对应关系抽屉
                                                if (_idsOf(msg.refIds)
                                                        .isNotEmpty ||
                                                    _crossOf(msg.crossRefs)
                                                        .isNotEmpty ||
                                                    (sameBack[msg.id] ?? 0) >
                                                        0 ||
                                                    (crossBack[msg.id] ?? 0) >
                                                        0) ...[
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      if (_idsOf(msg.refIds)
                                                          .isNotEmpty)
                                                        _RefTagChip(
                                                          icon: FLucideIcons
                                                              .arrowUpRight,
                                                          label:
                                                              '引用 ${_idsOf(msg.refIds).length}',
                                                          onTap: () =>
                                                              _openRefTag(
                                                                msg,
                                                                'outgoing',
                                                              ),
                                                        ),
                                                      if (_crossOf(
                                                        msg.crossRefs,
                                                      ).isNotEmpty)
                                                        _RefTagChip(
                                                          icon: FLucideIcons
                                                              .layers,
                                                          label:
                                                              '跨主题 ${_crossOf(msg.crossRefs).length}',
                                                          onTap: () =>
                                                              _openRefTag(
                                                                msg,
                                                                'cross',
                                                              ),
                                                        ),
                                                      if ((sameBack[msg.id] ??
                                                              0) >
                                                          0)
                                                        _RefTagChip(
                                                          icon: FLucideIcons
                                                              .arrowDownLeft,
                                                          label:
                                                              '被引用 ${sameBack[msg.id]}',
                                                          onTap: () =>
                                                              _openRefTag(
                                                                msg,
                                                                'backSame',
                                                              ),
                                                        ),
                                                      if ((crossBack[msg.id] ??
                                                              0) >
                                                          0)
                                                        _RefTagChip(
                                                          icon: FLucideIcons
                                                              .layers,
                                                          label:
                                                              '被跨主题引用 ${crossBack[msg.id]}',
                                                          onTap: () =>
                                                              _openRefTag(
                                                                msg,
                                                                'backCross',
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    if (msg.pinned == '1') ...[
                                                      Icon(
                                                        FLucideIcons.pin,
                                                        size: 11,
                                                        color: AppTokens.accent(
                                                          4,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '置顶',
                                                        style: t
                                                            .typography
                                                            .body
                                                            .xs
                                                            .copyWith(
                                                              color:
                                                                  AppTokens.accent(
                                                                    4,
                                                                  ),
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    Text(
                                                      msg.createTime ?? '',
                                                      style: t
                                                          .typography
                                                          .body
                                                          .xs
                                                          .copyWith(
                                                            color: t
                                                                .colors
                                                                .mutedForeground,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
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
                // 输入框上方固定工具条（对齐 PC 输入工具条）：标签 / 引用入口 + 草稿 chips
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openMsgTagPicker,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: t.colors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: t.colors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FLucideIcons.tags,
                                  size: 14,
                                  color: AppTokens.accent(4),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _pendingTagIds.isEmpty
                                      ? '标签'
                                      : '标签 ${_pendingTagIds.length}',
                                  style: t.typography.body.xs.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 引用入口：多主题消息模糊搜索 + 多选（对齐 PC 引用/跨主题引用发起）
                        GestureDetector(
                          onTap: _openRefPicker,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _pendingRefIds.isNotEmpty
                                  ? AppTokens.accentSoft(
                                      context,
                                      AppTokens.accent(4),
                                    )
                                  : t.colors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _pendingRefIds.isNotEmpty
                                    ? AppTokens.accent(4)
                                    : t.colors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FLucideIcons.link,
                                  size: 14,
                                  color: _pendingRefIds.isNotEmpty
                                      ? AppTokens.accent(4)
                                      : t.colors.foreground,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _pendingRefIds.isEmpty
                                      ? '引用'
                                      : '引用 ${_pendingRefIds.length}',
                                  style: t.typography.body.xs.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _pendingRefIds.isNotEmpty
                                        ? AppTokens.accent(4)
                                        : t.colors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child:
                              _pendingTagIds.isEmpty && _pendingRefIds.isEmpty
                              ? const SizedBox.shrink()
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final id in _pendingTagIds)
                                        if (msgTagById[id] != null) ...[
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _pendingTagIds.remove(id),
                                            ),
                                            child: _ConvTagBadge(
                                              tag: msgTagById[id]!,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                      // 引用草稿 chip：摘要 + 可点掉
                                      for (final id in _pendingRefIds)
                                        if (allById[id] != null) ...[
                                          _RefDraftChip(
                                            label: _short(
                                              _snippetOf(allById[id]!).isEmpty
                                                  ? '（无文本）'
                                                  : _snippetOf(allById[id]!),
                                              12,
                                            ),
                                            onDelete: () => setState(
                                              () => _pendingRefIds.remove(id),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
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

/// 气泡上的引用关系小 tag（引用 / 跨主题 / 被引用 / 被跨主题引用，点击开对应关系抽屉）
class _RefTagChip extends StatelessWidget {
  const _RefTagChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: t.colors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: t.colors.mutedForeground),
            const SizedBox(width: 3),
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对话标签可选项（统一规格：色点 + 名称 + 选中对勾，同页面规范 chip 尺寸）
class _ConvTagOption extends StatelessWidget {
  const _ConvTagOption({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final ConversationTagData tag;
  final bool selected;
  final VoidCallback onTap;

  Color get _color {
    final hex = (tag.color ?? '').replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    return v == null ? const Color(0xFF6366F1) : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final color = _color;
    final fg = selected ? color : t.colors.foreground;
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : t.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              tag.name ?? '',
              style: t.typography.body.sm.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(FLucideIcons.check, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// 文本截断（超出补省略号）
String _short(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

/// 引用草稿 chip（摘要 + 可点掉）
class _RefDraftChip extends StatelessWidget {
  const _RefDraftChip({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTokens.accentSoft(context, AppTokens.accent(4)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTokens.accent(4).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.link, size: 11, color: AppTokens.accent(4)),
            const SizedBox(width: 4),
            Text(
              label,
              style: t.typography.body.xs.copyWith(color: AppTokens.accent(4)),
            ),
            const SizedBox(width: 3),
            Icon(FLucideIcons.x, size: 11, color: AppTokens.accent(4)),
          ],
        ),
      ),
    );
  }
}

/// 引用选择抽屉的结果项：勾选圆点 + 主题名/时间 + 摘要（多主题、模糊搜索列表）
class _RefPickItem extends StatelessWidget {
  const _RefPickItem({
    required this.msg,
    required this.themeTitle,
    required this.selected,
    required this.isCurrentTheme,
    required this.onTap,
  });

  final ConversationData msg;
  final String? themeTitle;
  final bool selected;
  final bool isCurrentTheme;
  final VoidCallback onTap;

  String get _snippet {
    final raw = msg.content ?? '';
    final text = msg.isRich == '1'
        ? raw.replaceAll(RegExp(r'<[^>]*>'), ' ')
        : raw;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.accentSoft(context, AppTokens.accent(4))
              : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected
                ? AppTokens.accent(4).withValues(alpha: 0.4)
                : t.colors.border,
          ),
        ),
        child: Row(
          children: [
            // 勾选圆点
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTokens.accent(4) : t.colors.background,
                border: Border.all(
                  color: selected
                      ? AppTokens.accent(4)
                      : t.colors.mutedForeground,
                ),
              ),
              child: selected
                  ? const Icon(
                      FLucideIcons.check,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isCurrentTheme) ...[
                        Icon(
                          FLucideIcons.layers,
                          size: 11,
                          color: AppTokens.accent(4),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            themeTitle ?? '未知主题',
                            style: t.typography.body.xs.copyWith(
                              color: AppTokens.accent(4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        msg.createTime ?? '',
                        style: t.typography.body.xs.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _snippet.isEmpty ? '（无文本内容）' : _snippet,
                    style: t.typography.body.sm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 批量导出多选抽屉的单个主题行（勾选圆点 + 标题 + 对话数）
class _ExportThemeItem extends StatelessWidget {
  const _ExportThemeItem({
    required this.theme,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ConversationThemeData theme;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.accentSoft(context, AppTokens.accent(4))
              : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected
                ? AppTokens.accent(4).withValues(alpha: 0.4)
                : t.colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTokens.accent(4) : t.colors.background,
                border: Border.all(
                  color: selected
                      ? AppTokens.accent(4)
                      : t.colors.mutedForeground,
                ),
              ),
              child: selected
                  ? const Icon(
                      FLucideIcons.check,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                theme.title ?? '未命名主题',
                style: t.typography.body.sm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: t.typography.body.xs.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 文件名安全化：去除非法字符并限制长度（对齐 PC sanitizeName）
String _sanitize(String? s) {
  final v = (s ?? '未命名').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return v.length > 40 ? v.substring(0, 40) : v;
}

/// 时间戳：YYYYMMDD_HHmmss（对齐 PC 导出文件名时间戳）
String _timestamp() {
  final d = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${p(d.month)}${p(d.day)}_${p(d.hour)}${p(d.minute)}${p(d.second)}';
}
