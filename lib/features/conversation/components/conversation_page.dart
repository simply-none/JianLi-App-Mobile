// 主题对话页 —— 对齐待办列表页骨架（专属色横幅统计 + 吸顶搜索行 + 条件 chip + 分段 Tab + 列表）
//
// 能力对齐（桌面端 references/modules/theme-conversation.md）：
// - 主题：新建/编辑（标题+备注+主题标签，lg 三档抽屉）、删除（子主题禁止 + 级联删消息，
//   底部抽屉二次确认）、消息数角标、主题标签彩色徽标（conversation_tag 解析）、
//   update_time 排序；跨主题搜索（标题+内容+标签，吸顶搜索行实时过滤）；
//   标签筛选（多选任一命中，SoftChip 可点掉）；标签管理（重命名/改色/删除，
//   conversation_sheets.dart）；分段 Tab：全部 / 有引用 / 本周更新；
// - 消息：置顶（pinned='1' 排前 + 图标）、富文本（is_rich='1' 用 HtmlWidget 渲染，'0' 纯文本）、
//   软删除（长按气泡 → 底部抽屉确认，is_deleted='1' 行保留）、底部输入栏追加记录、
//   引用/跨主题引用（ref_ids / cross_refs）与正反向链接抽屉、消息标签编辑、
//   **富文本写入与编辑**（底部栏 Aa → 沉浸式编辑页 conversation_compose_page.dart；
//   长按菜单「编辑内容」复用同一页；归一化判据见 core/text/rich_text.dart）。
// 未做（桌面端有、移动端裁剪，记 SKILL.md 待办）：子主题发起、多选批量、情绪预设、LLM 回复。
import 'dart:async';
import 'dart:convert';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/file_export.dart';
import '../../../app/ui/filter_sheet.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/scope_tab_bar.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../../../core/text/rich_text.dart';
import '../repositories/conversation_repository.dart';
import '../utils/export_markdown.dart';
import 'conversation_chips.dart';
import 'conversation_sheets.dart';

/// 分段 Tab 范围（主题列表）
const List<(String, String)> kConvTabs = [
  ('all', '全部'),
  ('refs', '有引用'),
  ('week', '本周更新'),
];

/// 主题列表页
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  /// 主题对话域专属粉强调色（与内容分组页「主题对话」入口色对齐）
  static final Color _accent = AppTokens.accent(4);

  /// 页内搜索关键词（跨主题：标题 + 内容 + 标签名，实时过滤）
  String _keyword = '';

  /// 分段 Tab 范围（kConvTabs）
  String _tab = 'all';

  /// 已生效标签筛选（主题标签 id，多选任一命中）
  final Set<String> _selectedTagIds = {};
  final _searchController = TextEditingController();

  // 查询抽屉内的标签草稿（点「查询」才应用）
  final Set<String> _draftTags = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(conversationThemesProvider);
    final countsAsync = ref.watch(themeCountsProvider);
    final tagDefs =
        ref.watch(conversationTagsProvider).value ?? const <ConversationTagData>[];
    final t = context.theme;

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        // 全局渐变背板由 app.dart 根容器绘制，页面保持透明以透出背板
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: themesAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败：$e',
                      textAlign: TextAlign.center,
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.error,
                      ),
                    ),
                  ),
                  data: (themes) => _body(
                    context,
                    themes,
                    countsAsync.value ?? const <String, int>{},
                    tagDefs,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部（对齐待办：‹ / 标题 / 标签 / 导出 / ＋） =====================

  Widget _header(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: () => context.pop(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
          Expanded(
            child: Text(
              '主题对话',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: () => showConversationTagManagerSheet(context, ref),
            child: Icon(FLucideIcons.tags, size: 18, color: t.colors.foreground),
          ),
          TapScale(
            onTap: () => _openExportPicker(context, ref),
            child: Icon(
              FLucideIcons.download,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: () => _showThemeEditor(context, ref),
            child: Icon(FLucideIcons.plus, size: 22, color: t.colors.foreground),
          ),
        ],
      ),
    );
  }

  // ===================== 主体（待办骨架） =====================

  Widget _body(
    BuildContext context,
    List<ConversationThemeData> themes,
    Map<String, int> counts,
    List<ConversationTagData> tagDefs,
  ) {
    final allMsgs =
        ref.watch(allConversationsProvider).value ?? const <ConversationData>[];
    final tagById = {for (final d in tagDefs) d.id.toString(): d};
    var totalMessages = 0;
    for (final th in themes) {
      totalMessages += counts[th.id.toString()] ?? 0;
    }
    final scoped = _filterThemes(
      themes: themes,
      allMsgs: allMsgs,
      tagDefs: tagDefs,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _banner(context, themes.length, totalMessages, allMsgs, tagDefs),
        ),
        // ★吸顶锚点：搜索行常驻视口顶部（横幅 / chip / Tab 随滚动移出）
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索主题、内容与标签…',
              onChanged: (v) => setState(() => _keyword = v),
              onFilter: () => _openFilterSheet(tagDefs),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _chipsRow(context, tagDefs)),
        SliverToBoxAdapter(
          child: ScopeTabBar<String>(
            tabs: kConvTabs,
            selected: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
        if (themes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: true),
          )
        else if (scoped.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: false),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              AppTokens.listTopGapOf(context),
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                StaggerList(
                  children: [
                    for (final theme in scoped)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ThemeCard(
                          theme: theme,
                          messageCount: counts[theme.id.toString()] ?? 0,
                          tagById: tagById,
                          onTap: () =>
                              context.push('/conversation/${theme.id}'),
                          onLongPress: () =>
                              _showThemeActions(context, ref, theme),
                        ),
                      ),
                  ],
                ),
              ]),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（粉专属渐变 + 纹理 + 同心圆环）
  Widget _banner(
    BuildContext context,
    int themeCount,
    int totalMessages,
    List<ConversationData> allMsgs,
    List<ConversationTagData> tagDefs,
  ) {
    final todayPrefix = _todayPrefix();
    var todayMsgs = 0;
    for (final m in allMsgs) {
      if ((m.createTime ?? '').startsWith(todayPrefix) && m.isDeleted != '1') {
        todayMsgs++;
      }
    }
    return PageBanner(
      icon: FLucideIcons.messageSquareText,
      title: '主题对话',
      subtitle: '把情绪与想法安放进主题',
      accentIndex: 4,
      cornerRadius: 22,
      ringDecor: true,
      shadow: false,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      stats: [
        ('$themeCount', '主题'),
        ('$totalMessages', '记录'),
        ('$todayMsgs', '今日'),
      ],
    );
  }

  /// 生效条件 chip（关键词/标签逐个可点掉；无生效条件整块不渲染）
  Widget _chipsRow(BuildContext context, List<ConversationTagData> tagDefs) {
    final tagById = {for (final d in tagDefs) d.id.toString(): d};
    final chips = <Widget>[];
    if (_keyword.trim().isNotEmpty) {
      chips.add(
        _condChip(context, '搜索：${_keyword.trim()}', _accent, () {
          _searchController.clear();
          setState(() => _keyword = '');
        }),
      );
    }
    for (final id in _selectedTagIds) {
      final tag = tagById[id];
      if (tag == null) continue;
      chips.add(
        _condChip(
          context,
          tag.name ?? '',
          parseConvTagColor(tag),
          () => setState(() => _selectedTagIds.remove(id)),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    chips.add(
      _condChip(context, '清除全部', context.theme.colors.destructive,
          _clearAllFilters),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  /// 生效条件 chip（SoftChip 可点掉形态）
  Widget _condChip(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
  ) =>
      SoftChip(
        label: label,
        color: color,
        alpha: 0.12,
        padding: const EdgeInsets.all(6),
        onRemove: onTap,
      );

  /// 空态（对齐待办）
  Widget _emptyState(BuildContext context, {required bool totallyEmpty}) {
    final t = context.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              totallyEmpty
                  ? FLucideIcons.messageSquareText
                  : FLucideIcons.searchX,
              size: 32,
              color: _accent,
            ),
          ),
          Text(
            totallyEmpty ? '还没有主题' : '没有匹配的主题',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点右上角 ＋ 建第一个主题' : '换个关键词，或清除筛选条件',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 过滤与行为 =====================

  /// 主题过滤：Tab 范围 → 标签多选（任一命中）→ 关键词（标题/内容/标签名）。
  /// 消息内容命中也算主题命中（跨主题搜索，对齐 PC 搜索语义）。
  List<ConversationThemeData> _filterThemes({
    required List<ConversationThemeData> themes,
    required List<ConversationData> allMsgs,
    required List<ConversationTagData> tagDefs,
  }) {
    final tagById = {for (final d in tagDefs) d.id.toString(): d};
    // themeId → 命中信息
    final hasRefs = <String>{};
    final contentTexts = <String, String>{};
    for (final m in allMsgs) {
      if (m.isDeleted == '1') continue;
      final tid = m.themeId ?? '';
      if (convStrIds(m.refIds).isNotEmpty ||
          convCrossRefs(m.crossRefs).isNotEmpty) {
        hasRefs.add(tid);
      }
      // 关键词搜索索引：与气泡渲染同口径（is_rich 决定是否去标签，见 core/text/rich_text.dart）
      final text = plainLineOf(m.content, html: m.isRich == '1');
      contentTexts[tid] = '${contentTexts[tid] ?? ''}\n$text';
    }
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final kw = _keyword.trim().toLowerCase();

    return themes.where((th) {
      final id = th.id.toString();
      // Tab 范围
      switch (_tab) {
        case 'refs':
          if (!hasRefs.contains(id)) return false;
        case 'week':
          final u = DateTime.tryParse(th.updateTime ?? '');
          if (u == null || u.isBefore(weekAgo)) return false;
      }
      // 标签筛选（任一命中）
      if (_selectedTagIds.isNotEmpty) {
        final ids = convStrIds(th.tags);
        if (!_selectedTagIds.any(ids.contains)) return false;
      }
      // 关键词：主题标题 / 标签名 / 消息内容
      if (kw.isNotEmpty) {
        final inTitle = (th.title ?? '').toLowerCase().contains(kw);
        final inTagNames = convStrIds(th.tags).any(
          (k) => (tagById[k]?.name ?? '').toLowerCase().contains(kw),
        );
        final inContent = (contentTexts[id] ?? '').toLowerCase().contains(kw);
        if (!inTitle && !inTagNames && !inContent) return false;
      }
      return true;
    }).toList();
  }

  /// 打开「查询抽屉」（主题标签多选）：草稿从已生效条件初始化
  Future<void> _openFilterSheet(List<ConversationTagData> tagDefs) async {
    final themeTags = tagDefs.where((d) => d.scope == 'theme').toList();
    _draftTags
      ..clear()
      ..addAll(_selectedTagIds);
    final result = await showFilterSheet<Set<String>>(
      context: context,
      title: '筛选主题',
      body: (context, refresh) =>
          _buildFilterBody(context, themeTags, refresh),
      onReset: (refresh) {
        _draftTags.clear();
        refresh();
      },
      onConfirm: () => Set<String>.of(_draftTags),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedTagIds..clear()..addAll(result));
  }

  /// 查询抽屉选项区：主题标签多选
  Widget _buildFilterBody(
    BuildContext context,
    List<ConversationTagData> themeTags,
    VoidCallback refresh,
  ) {
    if (themeTags.isEmpty) {
      return Text(
        '暂无主题标签，可在编辑主题时新建',
        style: context.theme.typography.body.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in themeTags)
          _ConvTagOption(
            tag: tag,
            selected: _draftTags.contains(tag.id.toString()),
            onTap: () {
              final key = tag.id.toString();
              _draftTags.contains(key) ? _draftTags.remove(key) : _draftTags.add(key);
              refresh();
            },
          ),
      ],
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _keyword = '';
      _selectedTagIds.clear();
    });
  }

  /// 今天的 'yyyy-MM-dd' 前缀（横幅「今日」统计用）
  static String _todayPrefix() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${p(n.month)}-${p(n.day)}';
  }

  /// 主题长按操作菜单（sm 档共享操作菜单：编辑 / 导出 / 删除）
  Future<void> _showThemeActions(
    BuildContext context,
    WidgetRef ref,
    ConversationThemeData theme,
  ) async {
    final action = await showSheetActionMenu<String>(
      context,
      title: theme.title ?? '未命名主题',
      actions: const [
        SheetAction('edit', '编辑主题', icon: FLucideIcons.pencil),
        SheetAction('export', '导出 Markdown', icon: FLucideIcons.download),
        SheetAction(
          'delete',
          '删除主题',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _showThemeEditor(context, ref, existing: theme);
      case 'export':
        await _exportTheme(context, ref, theme);
      case 'delete':
        await _deleteTheme(context, ref, theme);
    }
  }

  /// 新建 / 编辑主题抽屉（lg 定高三档制；打开不自动聚焦——红线 #14⑤）
  Future<void> _showThemeEditor(
    BuildContext context,
    WidgetRef ref, {
    ConversationThemeData? existing,
  }) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final remark = TextEditingController(text: existing?.remark ?? '');
    // 编辑草稿：主题标签 id（scope='theme'），对齐 PC 主题编辑可挂标签
    final editTagIds = <String>{...convStrIds(existing?.tags)};
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final t = sheetContext.theme;
          final themeTagDefs = (ref.read(conversationTagsProvider).value ??
                  const <ConversationTagData>[])
              .where((d) => d.scope == 'theme')
              .toList();
          final tagById = {for (final d in themeTagDefs) d.id.toString(): d};
          return SheetScaffold(
            title: existing == null ? '新建主题' : '编辑主题',
            size: SheetSize.lg,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                // 字段组：label↔输入框间距只由 SheetFieldLabel 自带 bottom:6 提供
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetFieldLabel('主题标题'),
                    SheetInputBox(
                      controller: title,
                      hintText: '例如：深夜情绪记录',
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SheetFieldLabel('备注（可选）'),
                    SheetInputBox(controller: remark, hintText: '备注'),
                  ],
                ),
                // 主题标签（对齐 PC 主题编辑可挂标签；scope='theme'，点行开选择抽屉）
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SheetFieldLabel('主题标签'),
                        GestureDetector(
                          onTap: () async {
                            final picked = await _openThemeTagPicker(
                              sheetContext,
                              ref,
                              editTagIds,
                            );
                            if (picked != null) {
                              editTagIds
                                ..clear()
                                ..addAll(picked);
                              setSheetState(() {});
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FLucideIcons.tags,
                                  size: 13,
                                  color: AppTokens.accent(4),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '选择',
                                  style: t.typography.body.xs.copyWith(
                                    fontSize: 12,
                                    color: t.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (editTagIds.isEmpty)
                      Text(
                        '未选择标签',
                        style: t.typography.body.sm.copyWith(
                          fontSize: 13,
                          color: t.colors.mutedForeground,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final id in editTagIds)
                            if (tagById[id] != null)
                              GestureDetector(
                                onTap: () {
                                  editTagIds.remove(id);
                                  setSheetState(() {});
                                },
                                child: ConvTagBadge(tag: tagById[id]!),
                              ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            bottomBar: [
              Expanded(
                child: FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.pop(sheetContext),
                  child: const Text('取消'),
                ),
              ),
              Expanded(
                child: GradientButton(
                  label: existing == null ? '创建' : '保存',
                  icon: FLucideIcons.check,
                  onPress: () {
                    final titleText = title.text.trim();
                    if (titleText.isEmpty) {
                      showFToast(
                        context: sheetContext,
                        title: const Text('标题不能为空'),
                      );
                      return;
                    }
                    final repo = ref.read(conversationRepositoryProvider);
                    if (existing == null) {
                      repo.createTheme(
                        title: titleText,
                        remark: remark.text.trim(),
                        tagIds: editTagIds.toList(),
                      );
                    } else {
                      repo.updateTheme(
                        existing.id,
                        title: titleText,
                        remark: remark.text.trim(),
                        tagIds: editTagIds.toList(),
                      );
                    }
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 删除主题（sm 确认抽屉；子主题检查在仓储层）
  Future<void> _deleteTheme(
    BuildContext context,
    WidgetRef ref,
    ConversationThemeData theme,
  ) async {
    final confirmed = await showSheetConfirm(
      context,
      title: '删除主题',
      message: '确定删除「${theme.title ?? ''}」？将同时删除其下全部对话，且不可恢复。',
      confirmLabel: '删除',
    );
    if (!confirmed) return;
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
          onTap: () => _createThemeTag(context, ref, draft, tagDefs, refresh),
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

  /// 新建主题标签（scope='theme'，创建后即时加入列表并刷新选择区，无需关闭重开）
  Future<void> _createThemeTag(
    BuildContext context,
    WidgetRef ref,
    Set<String> draft,
    List<ConversationTagData> tagDefs,
    VoidCallback refresh,
  ) async {
    final name = await showConvPromptSheet(
      context,
      title: '新建主题标签',
      subtitle: '配色按顺序自动分配，与桌面端一致',
      hint: '输入标签名称',
      confirmLabel: '创建',
    );
    if (name == null || !context.mounted) return;
    final tag = await ref
        .read(conversationRepositoryProvider)
        .createThemeTag(name);
    if (context.mounted) {
      draft.add(tag.id.toString());
      tagDefs.add(tag); // 直接补进快照列表，刷新即显示，不依赖 provider 时序
      refresh();
    }
  }

  /// 导出单个主题为 Markdown（落盘到系统 Download/渐离App导出/，未授权回退沙盒）
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
    await exportTextToDownloadDir(
      context: context,
      text: md,
      filename: '主题-${_sanitize(theme.title)}_${_timestamp()}.md',
    );
  }

  /// 批量导出：底部多选抽屉（对齐 PC ExportThemesDialog），合并为单个 .md 落盘 Download/渐离App导出/
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
      size: SheetSize.lg,
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
    await exportTextToDownloadDir(
      context: context,
      text: md,
      filename: '主题对话导出_${_timestamp()}.md',
    );
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

}

/// 单个主题卡（方案 A 三行式：首字头像+标题+chevron / 标签行 / 统计·备注行），长按出操作
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

  /// 标签展示上限（超出以「+N」呈现；2026-09-14 画布定案）
  static const int _kMaxTags = 4;

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
    // 子主题（parent_id 非空）+ 标签，共同占据第 2 行徽标区
    final isSubTheme = theme.parentId?.isNotEmpty ?? false;
    final shownTags = themeTags.take(_kMaxTags).toList();
    final overflow = themeTags.length - shownTags.length;
    final hasBadges = isSubTheme || shownTags.isNotEmpty;

    // 长按出操作抽屉（外层长按与 AppCard 内层点击手势可共存）
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        // 列表卡 margin 清零：间距只由外层 Padding(bottom:10) 提供
        //（AppCard 默认 vertical:6 会叠出 22px 大间隙，2026-09-13 用户实指）
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // R1：首字头像（普通圆角矩形，弧度对齐首页快捷入口）+ 标题 + chevron
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTokens.accentGradient(AppTokens.accent(4)),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                  child: Text(
                    theme.title ?? '未命名主题',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.md.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  FLucideIcons.chevronRight,
                  size: 18,
                  color: t.colors.mutedForeground,
                ),
              ],
            ),
            // R2：徽标行（子主题 + 主题标签，最多 4 个，超出「+N」）——有才渲染
            if (hasBadges) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isSubTheme) const _FlatBadge(label: '子主题'),
                  for (final tag in shownTags)
                    ConvTagBadge(tag: tag, radius: 10),
                  if (overflow > 0) _FlatBadge(label: '+$overflow'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // R3：N 条 · 更新于 X · 备注（单行超出省略）
            Text(
              '$messageCount 条 · 更新于 ${convFriendlyTime(theme.updateTime)}$remark',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.body.sm.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
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

/// 中性灰徽标（主题卡第 2 行的「子主题」与标签溢出「+N」用；方形软底、无圆点）
class _FlatBadge extends StatelessWidget {
  const _FlatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: t.typography.body.xs.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.colors.mutedForeground,
        ),
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

  /// 导出本主题**全部**对话记录为 Markdown（落盘 `Download/渐离App导出/`，未授权回退沙盒）。
  ///
  /// 页面只持有 `themeId`，主题元信息（标题/标签/时间）从主题流取——
  /// 用 `.future` 等首帧，避免 `ref.read(...).value` 在 provider 尚未被本页监听时读到 null
  /// （会误判「未找到该主题」）。生成器/文件名口径与列表页「导出主题」完全一致。
  Future<void> _exportTheme() async {
    final themes = await ref.read(conversationThemesProvider.future);
    ConversationThemeData? theme;
    for (final t in themes) {
      if (t.id.toString() == widget.themeId) {
        theme = t;
        break;
      }
    }
    if (!mounted) return;
    if (theme == null) {
      showFToast(context: context, title: const Text('未找到该主题'));
      return;
    }
    final msgs = await ref
        .read(conversationRepositoryProvider)
        .getMessagesByTheme(widget.themeId);
    if (!mounted) return;
    if (msgs.isEmpty) {
      showFToast(context: context, title: const Text('该主题暂无对话记录'));
      return;
    }
    final tagById = {
      for (final t in await ref.read(conversationTagsProvider.future))
        t.id.toString(): t,
    };
    if (!mounted) return;
    await exportTextToDownloadDir(
      context: context,
      text: buildThemeMarkdown(theme, msgs, tagById),
      filename: '主题-${_sanitize(theme.title)}_${_timestamp()}.md',
    );
  }

  /// 进沉浸式富文本编辑页（底部栏 Aa）——新建或编辑一条对话的内容。
  ///
  /// 与 PC `ChatInput` 的「展开富文本编辑」是同一个动作位，只是移动端把它做成独立页
  /// （原因见 conversation_compose_page.dart 文件头：抽屉装不下「编辑区+工具条+键盘」）。
  /// 新建态把当前的标签 / 引用草稿一并带过去，发送成功后清空本地草稿。
  Future<void> _openCompose({int? messageId}) async {
    // 新建态把标签 / 引用草稿经查询参数带过去（编辑态不带：编辑页只改内容）。
    // 用查询参数而非 `extra`：可声明、可从路由状态复原，也不怕热重载丢 extra。
    final params = <String, String>{
      if (messageId != null) 'messageId': '$messageId',
      if (messageId == null && _pendingTagIds.isNotEmpty)
        'tags': _pendingTagIds.join(','),
      if (messageId == null && _pendingRefIds.isNotEmpty)
        'refs': _pendingRefIds.join(','),
    };
    final url = Uri(
      path: '/conversation/${widget.themeId}/compose',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
    final sent = await context.push<bool>(url);
    if (!mounted || sent != true) return;
    setState(() {
      _pendingTagIds.clear();
      _pendingRefIds.clear();
    });
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
      // 内含搜索输入框 → lg 80vh 定高（2026-09-13 全局定案：含输入框一律 lg）
      size: SheetSize.lg,
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
          onTap: () => _createConversationTag(tagDefs, refresh),
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

  /// 新建对话标签小抽屉（创建后即时加入列表并刷新选择区，无需关闭重开）
  Future<void> _createConversationTag(
    List<ConversationTagData> tagDefs,
    VoidCallback refresh,
  ) async {
    final name = await showConvPromptSheet(
      context,
      title: '新建标签',
      subtitle: '配色按顺序自动分配，与桌面端一致',
      hint: '输入标签名称',
      confirmLabel: '创建',
    );
    if (name == null || !mounted) return;
    final tag = await ref
        .read(conversationRepositoryProvider)
        .createConversationTag(name);
    if (mounted) {
      setState(() => _draftMsgTags.add(tag.id.toString()));
      tagDefs.add(tag); // 直接补进快照列表，刷新即显示，不依赖 provider 时序
      refresh();
    }
  }

  /// 长按气泡：操作菜单（sm 档共享操作菜单；链接类条目为空时省略，
  /// 对齐 PC 右键菜单的移动端子集——引用/链接、标签、置顶、删除）
  Future<void> _showMessageMenu(ConversationData msg) async {
    final links = await ref
        .read(conversationRepositoryProvider)
        .loadRefLinks(msg);
    if (!mounted) return;
    final actions = <SheetAction<String>>[
      const SheetAction('ref', '引用此对话', icon: FLucideIcons.link),
      // 编辑内容（对齐 PC ConversationEditDialog）：进沉浸式富文本编辑页改正文，
      // 保存后由仓库侧归一化重新判定 is_rich（改回纯文字会自动降级）
      const SheetAction('edit', '编辑内容', icon: FLucideIcons.squarePen),
      if (links.outgoing.isNotEmpty)
        SheetAction(
          'outgoing',
          '正向链接（${links.outgoing.length}）',
          icon: FLucideIcons.arrowUpRight,
        ),
      if (links.backlinks.isNotEmpty)
        SheetAction(
          'backlinks',
          '反向链接（${links.backlinks.length}）',
          icon: FLucideIcons.arrowDownLeft,
        ),
      if (links.cross.isNotEmpty)
        SheetAction(
          'cross',
          '跨主题引用（${links.cross.length}）',
          icon: FLucideIcons.layers,
        ),
      const SheetAction('tags', '编辑标签', icon: FLucideIcons.tags),
      SheetAction(
        'pin',
        msg.pinned == '1' ? '取消置顶' : '置顶',
        icon: msg.pinned == '1' ? FLucideIcons.pinOff : FLucideIcons.pin,
      ),
      const SheetAction(
        'delete',
        '删除记录',
        icon: FLucideIcons.trash2,
        destructive: true,
      ),
    ];
    final action = await showSheetActionMenu<String>(
      context,
      title: _snippetOf(msg).isEmpty ? '（无文本内容）' : _snippetOf(msg),
      actions: actions,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'ref':
        setState(() => _pendingRefIds.add(msg.id));
        showFToast(context: context, title: const Text('已加入引用，发送时生效'));
      case 'edit':
        await _openCompose(messageId: msg.id);
        // 编辑返回后把该条滚到视口并高亮片刻（`_highlightMessage` 返回 void，勿 await）
        _highlightMessage(msg.id);
      case 'outgoing':
        await _showRefDrawer('正向链接', [
          for (final c in links.outgoing) ConvRefItem(c, null),
        ]);
      case 'backlinks':
        await _showRefDrawer('反向链接', links.backlinks);
      case 'cross':
        await _showRefDrawer('跨主题引用', links.cross);
      case 'tags':
        await _editMsgTags(msg);
      case 'pin':
        await ref.read(conversationRepositoryProvider).togglePin(msg);
      case 'delete':
        await _confirmSoftDelete(msg);
    }
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
  /// 单行摘要（预览/抽屉/长按菜单标题用）。
  /// ⚠️ `html:` 必须按 is_rich 传 —— 纯文本消息里出现的 `<...>` 要原样显示，
  /// 与气泡的渲染分支（HtmlWidget / Text）保持同一口径。工具见 core/text/rich_text.dart。
  String _snippetOf(ConversationData m) =>
      snippetOf(m.content, html: m.isRich == '1');

  /// 长按气泡：软删除确认（sm 确认抽屉；行保留对齐桌面追溯语义）
  Future<void> _confirmSoftDelete(ConversationData msg) async {
    final confirmed = await showSheetConfirm(
      context,
      title: '删除记录',
      message: '确定删除这条记录？记录将标记为已删除（保留数据以便追溯）。',
    );
    if (confirmed) {
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
        // 右上角导出：导出本主题**全部**对话记录为 Markdown
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.download),
            onPress: _exportTheme,
          ),
        ],
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
                                                          ConvTagBadge(
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
                                            child: ConvTagBadge(
                                              tag: msgTagById[id]!,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                      // 引用草稿 chip：摘要 + 可点掉
                                      for (final id in _pendingRefIds)
                                        if (allById[id] != null) ...[
                                          ConvRefDraftChip(
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
                        // Aa：进沉浸式富文本编辑页（与 PC ChatInput 的「展开富文本编辑」
                        // 同一动作位）。做成 40×40 的 muted 软底方块，与右侧发送钮同高同圆角；
                        // ⚠️ 不用 FButton/IconButton —— 与 SheetInputBox(h40) 天生不等高
                        // （见 interaction-patterns §4.6：并排一律自绘容器）。
                        TapScale(
                          onTap: _openCompose,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.colors.muted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              FLucideIcons.type,
                              size: 18,
                              color: t.colors.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 根因修复（参考文件互传「手动填 IP」行）：forui `FTextField` 的可见
                        // 边框按内容固有高度绘制、**不随 Row 的紧约束拉伸**，与同排按钮天生
                        // 不等高。改用自绘边框的共享 `SheetInputBox`（定高 40）＋自绘同高
                        // 40 / 同圆角 10 的发送钮，两侧天然对齐。
                        Expanded(
                          child: SheetInputBox(
                            controller: _input,
                            hintText: '记录一下…',
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TapScale(
                          onTap: _send,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppTokens.primaryGradient(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              FLucideIcons.send,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
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

  /// 单行摘要（与消息页 `_snippetOf` 同口径，见 core/text/rich_text.dart）
  String get _snippet => snippetOf(msg.content, html: msg.isRich == '1');

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

// ===================== 模块级共享辅助 =====================

/// 解析 JSON 字符串数组（tags / ref_ids 通用，异常返回空）
List<String> convStrIds(String? raw) {
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

/// 解析跨主题引用 JSON（[{themeId, convId}]，异常返回空）
List<({int themeId, int convId})> convCrossRefs(String? raw) {
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

/// 'yyyy-MM-dd HH:mm:ss' → 今天 HH:mm / 昨天 HH:mm / M月D日（跨年带年份）
String convFriendlyTime(String? raw) {
  final d = DateTime.tryParse(raw ?? '');
  if (d == null) return raw ?? '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  final hhmm =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return '今天 $hhmm';
  if (diff == 1) return '昨天 $hhmm';
  if (d.year == now.year) return '${d.month}月${d.day}日';
  return '${d.year}年${d.month}月${d.day}日';
}

/// 轻量输入抽屉（sm 档共享骨架）：controller 由自身 State 释放（红线：controller
/// 生命周期跟 State，不跟 await 之后的调用点）；打开不自动聚焦（红线 #14⑤）。
Future<String?> showConvPromptSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String? subtitle,
}) {
  return showFSheet<String>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => _ConvPromptSheet(
      title: title,
      subtitle: subtitle,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ConvPromptSheet extends StatefulWidget {
  const _ConvPromptSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String hint;
  final String confirmLabel;

  @override
  State<_ConvPromptSheet> createState() => _ConvPromptSheetState();
}

class _ConvPromptSheetState extends State<_ConvPromptSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 内含输入框 → lg 80vh 定高（2026-09-13 全局定案：含输入框一律 lg）
    return SheetScaffold(
      title: widget.title,
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: context.theme.typography.body.sm.copyWith(
                fontSize: 12,
                color: context.theme.colors.mutedForeground,
              ),
            ),
          SheetInputBox(controller: _controller, hintText: widget.hint),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: widget.confirmLabel,
            icon: FLucideIcons.check,
            onPress: () {
              final v = _controller.text.trim();
              Navigator.pop(context, v.isEmpty ? null : v);
            },
          ),
        ),
      ],
    );
  }
}
