// 待办页 —— 1:1 对齐画布「07 待办·列表页 主态」/「08 待办·列表页 空态」；
// 「09 显示风格」「10 高级搜索」两个弹层落在 todo_sheets.dart。
//
// 画布纵向顺序（07 = 节点 5:405）：
//   头部      ‹22 · 待办18/Bold · ⚙18 · ＋22，左右 16 / 上下 12 / 间距 10
//   统计横幅  渐变 · r22 · 内边距 18 / 间距 14 · 叠纹理「卡11」+ 同心圆环 + 环内小圆
//   搜索行    左右 16 / 上 12 · 白底 · 描边 · r10 · 高 40 · 内含「≡」28×28 #F1F2F4 r8
//   生效条件  Wrap · 间距 6 · 左右 16 / 上下 8 · chip r10 高 25 · 11/SemiBold
//   Tab 栏    左右 16 / 上下 4 · 底 #EEF0F4 · r11 · 高 34 · 内边距 3 / 间距 3
//   列表区    左右 16 / 上 4 · 间距 10 · 分组标题 12/Bold · 卡片 r16 / 内边距 14
//
// ⚠️ 吸顶规则（全 App 统一，见 skills/…/modules/interaction-patterns.md §4）：
//   列表页滚动吸顶**以搜索行为锚点** —— 搜索框常驻视口顶部，横幅 / 条件 chip / Tab 栏随滚动移出。
//   禁止改为「Tab 栏吸顶」（本页早期实现即如此，2026-09-12 修正）。
//
// 画布 → 行为映射：
//   ⚙        09 显示风格弹层（列表 / 卡片 / 日历，点选即生效并持久化）
//   ＋       新增待办抽屉
//   搜索框   实时过滤标题/描述（复用 TodoFilterState.search）
//   ≡        10 高级搜索弹层（优先级 / 标签 / 到期时间 / 其他 / 分组方式）
//   Tab 栏   状态范围：进行中（默认 = 未完成且未取消）/ 已完成 / 已取消 / 全部
//   条件 chip 单点清除，「清除全部」清空全部筛选；分组方式属显示项，不进 chip
//   单击卡片 → 待办详情（只读；父任务可继续下钻，「编辑」在详情里进表单）
//   长按卡片 → 多选模式（头部切 ✕ + 批量删除）
//
// ⚠️ 页面操作规范：所有弹窗（新增/编辑/筛选/状态/标签/父任务/日期/记录进展/确认/当天待办）
// 一律走底部抽屉（showFSheet + SheetSurface），见 todo_sheets.dart 与 SKILL.md。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/card_textures.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/tap_scale.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import '../models/todo_view_mode.dart';
import '../providers/todo_providers.dart';
import 'todo_calendar_view.dart';
import 'todo_card_view.dart';
import 'todo_sheets.dart';
import 'todo_tile.dart';

/// 搜索行几何：上留白 12 + 搜索框 40 + 下留白 8（画布 5:420 / 5:421）
const double _kSearchBoxHeight = 40;
const double _kSearchRowTopGap = 12;
const double _kSearchRowBottomGap = 8;

/// 搜索行总高 = 上留白 + 搜索框 + 下留白。
///
/// ⚠️ **搜索行是本页的吸顶元素**（见 `_body` 的 sliver 结构），`SliverPersistentHeader`
/// 必须显式给高度，所以这里由「搜索行自身用到的三个常量」推导，避免两处尺寸漂移。
/// 下留白让内容从搜索框下方 8px 处开始被遮住，而不是贴着框底消失。
const double _kSearchRowExtent =
    _kSearchRowTopGap + _kSearchBoxHeight + _kSearchRowBottomGap;

/// 待办页
class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  /// 显示风格（画布 09；持久化于 shared_preferences）
  TodoViewMode _view = TodoViewMode.list;

  /// Tab 栏状态范围（画布 07 默认「进行中」）
  TodoScope _scope = TodoScope.active;

  /// 搜索框实时关键词（单独持有，便于 chip 单独清除）
  String _search = '';

  /// 高搜条件（画布 10 产出）。
  /// 默认「按到期」分组 —— 对齐画布 07 主态的「今天 / 明天 / 更晚」分组标题。
  TodoFilterState _filter = const TodoFilterState(groupBy: TodoGroupBy.due);

  bool _selectMode = false;
  final Set<String> _selected = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreViewMode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreViewMode() async {
    final saved = await TodoViewModeStore.load();
    if (mounted) setState(() => _view = saved);
  }

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todoListProvider);
    final tagsAsync = ref.watch(todoTagsProvider);
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
                child: todosAsync.when(
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
                  data: (all) =>
                      _body(context, all, tagsAsync.value ?? const []),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部（画布 5:406） =====================

  Widget _header(BuildContext context) {
    final t = context.theme;
    const pad = EdgeInsets.fromLTRB(16, 12, 16, 12);
    if (_selectMode) {
      return Padding(
        padding: pad,
        child: Row(
          spacing: 10,
          children: [
            TapScale(
              onTap: () => setState(() {
                _selectMode = false;
                _selected.clear();
              }),
              child: Icon(FLucideIcons.x, size: 22, color: t.colors.foreground),
            ),
            Expanded(
              child: Text(
                '已选 ${_selected.length} 项',
                style: t.typography.body.lg.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.colors.foreground,
                ),
              ),
            ),
            TapScale(
              onTap: _selected.isEmpty ? null : _batchDelete,
              child: Icon(
                FLucideIcons.trash2,
                size: 20,
                color: _selected.isEmpty
                    ? t.colors.mutedForeground
                    : t.colors.destructive,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: pad,
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
              '待办',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: _openViewModeSheet,
            child: Icon(
              FLucideIcons.settings,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: _addTodo,
            child: Icon(FLucideIcons.plus, size: 22, color: t.colors.foreground),
          ),
        ],
      ),
    );
  }

  // ===================== 主体 =====================

  Widget _body(BuildContext context, List<TodoItem> all, List<TodoTagView> tags) {
    final filtered = applyTodoFilters(all, _filter.copyWith(search: _search));
    final scoped = applyTodoScope(filtered, _scope);
    final groups = groupTodos(scoped, _filter.groupBy);
    final empty = _emptyState(context, totallyEmpty: all.isEmpty);

    // 卡片 / 日历：整个头部（搜索 / 条件 / Tab）都固定在滚动区外，不参与滚动。
    // ⚠️ 与列表页的「搜索行吸顶」是两种形态，待统一（见 interaction-patterns.md §4 待办项）。
    if (_view == TodoViewMode.calendar) {
      return Column(
        children: [
          _searchRow(context),
          _chipsRow(context),
          _tabBar(context),
          Expanded(
            child: TodoCalendarView(
              items: scoped,
              onPickDay: (day, dayItems) => showTodoDaySheet(
                context,
                ref,
                day,
                dayItems,
                allTodos: all,
                tags: tags,
              ),
            ),
          ),
        ],
      );
    }
    if (_view == TodoViewMode.card) {
      return Column(
        children: [
          _searchRow(context),
          _chipsRow(context),
          _tabBar(context),
          Expanded(
            child: scoped.isEmpty
                ? empty
                : TodoCardView(
                    items: scoped,
                    allTodos: all,
                    tags: tags,
                    selectable: _selectMode,
                    selectedKeys: _selected,
                    onToggle: (item) => _toggle(item),
                    onMore: (item) => _more(context, item, all, tags),
                    onSelect: (item) => _toggleSelect(item.key),
                    onTap: (item) => _openDetail(item),
                  ),
          ),
        ],
      );
    }

    // 列表（画布 07 / 08）：整页可滚，**吸顶以搜索行为锚点**——
    // 横幅 / 条件 chip / Tab 栏随滚动移出视口，搜索框常驻顶部（随时可改关键词）。
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(context, all)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeader(
            extent: _kSearchRowExtent,
            child: _searchRow(context),
          ),
        ),
        SliverToBoxAdapter(child: _chipsRow(context)),
        SliverToBoxAdapter(child: _tabBar(context)),
        if (scoped.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: empty)
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _listChildren(context, groups, all, tags),
              ),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（画布 5:431，含纹理「卡11」+ 同心圆环装饰）
  Widget _banner(BuildContext context, List<TodoItem> all) => PageBanner(
    icon: FLucideIcons.check,
    title: '待办',
    subtitle: '专注当下，一件一件来',
    // 画布渐变与首页英雄卡同源 → 走主色渐变（换外观色系时整屏跟着走）
    gradient: AppTokens.primaryGradient(context),
    cornerRadius: 22,
    textureAsset: CardTextures.texture11,
    ringDecor: true,
    shadow: false,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    stats: [
      ('${all.length}', '全部'),
      ('${applyTodoScope(all, TodoScope.active).length}', '进行中'),
      ('${applyTodoScope(all, TodoScope.completed).length}', '已完成'),
      ('${applyTodoScope(all, TodoScope.cancelled).length}', '已取消'),
    ],
  );

  /// 搜索行（画布 5:420）：白底框 + 实搜输入 + 「≡ 高级搜索」按钮。
  ///
  /// ⚠️ 尺寸（上留白 / 框高 / 下留白）由 [_kSearchRowTopGap] / [_kSearchBoxHeight] /
  /// [_kSearchRowBottomGap] 三个常量决定，吸顶高度 [_kSearchRowExtent] 与之一一对应，
  /// 改边距必须同源改常量，禁止让这里和吸顶高度各写一套数。
  Widget _searchRow(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        _kSearchRowTopGap,
        16,
        _kSearchRowBottomGap,
      ),
      child: Container(
        height: _kSearchBoxHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.colors.border),
        ),
        child: Row(
          spacing: 8,
          children: [
            Icon(
              FLucideIcons.search,
              size: 15,
              color: t.colors.mutedForeground,
            ),
            Expanded(
              // ⚠️ 原生 Material TextField 需要 Material 祖先；forui 的 FScaffold 不提供，
              // 而底部抽屉里能用是因为抽屉路由自带 Material。这里显式补一层透明 Material。
              child: Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.foreground,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: '搜索待办…',
                    hintStyle: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            TapScale(
              onTap: _openFilter,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.colors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FLucideIcons.listFilter,
                  size: 15,
                  color: t.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 生效条件（画布 5:424）：无生效条件时整块不渲染。
  ///
  /// 上留白为 0 —— 与搜索框之间的 8px 间距由搜索行的 [_kSearchRowBottomGap] 提供，
  /// 这样吸顶时那 8px 也被搜索行的底色盖住，chip 从框下方 8px 处开始消失。
  Widget _chipsRow(BuildContext context) {
    final t = context.theme;
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(
        _condChip(context, '搜索：$_search', t.colors.primary, () {
          _searchController.clear();
          setState(() => _search = '');
        }),
      );
    }
    if (_filter.priority != null) {
      chips.add(
        _condChip(
          context,
          '优先级：${priorityLabel(_filter.priority!)}',
          priorityColor(_filter.priority!),
          () => _updateFilter((f) => f.copyWith(clearPriority: true)),
        ),
      );
    }
    if (_filter.tagKeys.isNotEmpty) {
      chips.add(
        _condChip(
          context,
          '标签：${_filter.tagKeys.length} 个',
          t.colors.primary,
          () => _updateFilter((f) => f.copyWith(tagKeys: {})),
        ),
      );
    }
    if (_filter.dueGroup != null) {
      chips.add(
        _condChip(
          context,
          '到期：${kDueRangeLabels[_filter.dueGroup] ?? ''}',
          t.colors.primary,
          () => _updateFilter((f) => f.copyWith(clearDueGroup: true)),
        ),
      );
    }
    if (!_filter.showCompleted) {
      chips.add(
        _condChip(
          context,
          '仅未完成',
          t.colors.primary,
          () => _updateFilter((f) => f.copyWith(showCompleted: true)),
        ),
      );
    }
    if (_filter.showTemplates) {
      chips.add(
        _condChip(
          context,
          '含重复模板',
          t.colors.primary,
          () => _updateFilter((f) => f.copyWith(showTemplates: false)),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    chips.add(
      _condChip(context, '清除全部', t.colors.destructive, _clearAllFilters),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  /// Tab 栏（画布 8:2）：状态范围切换。
  ///
  /// ⚠️ **不吸顶** —— 吸顶锚点是上方的搜索行，本栏随滚动移出视口（见文件头吸顶规则）。
  Widget _tabBar(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          spacing: 3,
          // 画布选中态是 fill_container 高度（填满 34-3-3=28 的内轨），
          // Row 默认 center 会让白底药丸只有文字高 → 必须 stretch
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tab in kTodoScopeTabs)
              Expanded(
                child: FTappable(
                  onPress: () => setState(() => _scope = tab.$1),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _scope == tab.$1
                          ? t.colors.card
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab.$2,
                      style: t.typography.body.xs.copyWith(
                        fontSize: 13,
                        fontWeight: _scope == tab.$1
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _scope == tab.$1
                            ? t.colors.foreground
                            : t.colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 列表子项（分组标题 + 卡片），逐项下留 10 的间距（画布列表区 gap 10）
  List<Widget> _listChildren(
    BuildContext context,
    List<(String, List<TodoItem>)> groups,
    List<TodoItem> all,
    List<TodoTagView> tags,
  ) {
    final t = context.theme;
    final grouped = _filter.groupBy != TodoGroupBy.none;
    final children = <Widget>[];
    for (final group in groups) {
      if (grouped && group.$1.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${group.$1} · ${group.$2.length}',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
        );
      }
      for (final item in group.$2) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TodoListTile(
              item: item,
              allTodos: all,
              tags: tags,
              selectable: _selectMode,
              selected: _selected.contains(item.key),
              indent: _filter.groupBy == TodoGroupBy.parent && item.isChild,
              onToggle: () => _toggle(item),
              onMore: () => _more(context, item, all, tags),
              onSelect: () => _toggleSelect(item.key),
              onLongPress: () => _enterSelect(item.key),
              onTap: () => _openDetail(item),
            ),
          ),
        );
      }
    }
    return children;
  }

  /// 空态（画布 08 = 节点 5:523）：图标盘 76Ø + 16/Bold 标题 + 13/次字
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
              color: t.colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(FLucideIcons.list, size: 32, color: t.colors.primary),
          ),
          Text(
            totallyEmpty ? '还没有待办' : '没有匹配的待办',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点右上角 ＋ 记录第一件事' : '换个关键词，或清除筛选条件',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 生效条件 chip（画布 5:425：底 = 同色 12% · r10 · 内边距 6 · 11/SemiBold）
  Widget _condChip(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final t = context.theme;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(FLucideIcons.x, size: 11, color: color),
          ],
        ),
      ),
    );
  }

  // ===================== 行为 =====================

  Future<void> _toggle(TodoItem item) => ref
      .read(todoRepositoryProvider)
      .toggleComplete(item.key, effectiveStatus(item) != 'completed');

  Future<void> _more(
    BuildContext context,
    TodoItem item,
    List<TodoItem> all,
    List<TodoTagView> tags,
  ) => showTodoActionSheet(context, ref, item, allTodos: all, tags: tags);

  void _updateFilter(TodoFilterState Function(TodoFilterState) fn) =>
      setState(() => _filter = fn(_filter));

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _filter = const TodoFilterState(groupBy: TodoGroupBy.due);
      _search = '';
    });
  }

  /// 显示风格（画布 09）：点选即生效并持久化
  Future<void> _openViewModeSheet() async {
    final next = await showTodoViewModeSheet(context, current: _view);
    if (!mounted || next == null || next == _view) return;
    setState(() => _view = next);
    await TodoViewModeStore.save(next);
  }

  /// 高级搜索（画布 10）
  Future<void> _openFilter() async {
    final tags = ref.read(todoTagsProvider).value ?? const <TodoTagView>[];
    final next = await showTodoFilterSheet(
      context,
      current: _filter.copyWith(search: _search),
      tags: tags,
    );
    if (!mounted || next == null) return;
    setState(() {
      _filter = next;
      _search = next.search;
      _searchController.text = next.search;
    });
  }

  // ===== 选择 / 批量删除 =====
  void _enterSelect(String key) {
    setState(() {
      _selectMode = true;
      _selected.add(key);
    });
  }

  void _toggleSelect(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _batchDelete() async {
    final ok = await showTodoConfirmSheet(
      context,
      '批量删除',
      '确定删除选中的 ${_selected.length} 项待办及其子任务？',
    );
    if (ok != true) return;
    final repo = ref.read(todoRepositoryProvider);
    for (final k in List<String>.from(_selected)) {
      await repo.deleteTodo(k);
    }
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  // ===== 新增 / 编辑 =====
  Future<void> _addTodo() async {
    final all = ref.read(todoListProvider).value ?? const [];
    final tags = ref.read(todoTagsProvider).value ?? const [];
    final now = _now();
    final draft = TodoItem(
      key: _uuid(),
      title: '',
      description: '',
      completed: false,
      priority: 'medium',
      dueDate: null,
      completedTime: null,
      tags: const [],
      status: 'not_started',
      deadlineReminder: 0,
      remindCount: 1,
      remindInterval: 30,
      remindIntervalUnit: 'minute',
      createTime: null,
      updateTime: now,
      sortOrder: all.length,
      parentIds: const [],
      recurrenceRule: null,
      recurrenceInterval: 1,
      recurrenceWeekdays: const [],
      recurrenceEnd: null,
      recurrenceId: null,
      isRecurrenceInstance: 0,
    );
    final saved = await showTodoEditSheet(
      context,
      ref,
      initial: draft,
      allTodos: all,
      tags: tags,
    );
    if (saved != null) {
      await ref.read(todoRepositoryProvider).upsertTodo(saved);
    }
  }

  /// 单击待办 → **先看详情**（不是直接进编辑表单）。
  /// 「编辑」/「记录进展」由详情抽屉作为出口动作返回，统一由 openTodoDetail 收口，
  /// 页面这一层不再单独持有「打开编辑表单」的入口。
  Future<void> _openDetail(TodoItem item) async {
    final all = ref.read(todoListProvider).value ?? const [];
    final tags = ref.read(todoTagsProvider).value ?? const [];
    await openTodoDetail(context, ref, item, allTodos: all, tags: tags);
  }

  /// 新建待办的 key（与仓库一致：UUID v4，drift 表以 key 为主键）
  String _uuid() => const Uuid().v4();

  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}

/// 吸顶头（通用）：列表页把**搜索行**作为滚动吸顶锚点，滚过横幅后搜索框常驻顶部。
///
/// - [extent] 必须与实际子节点高度（搜索行上留白 + 框高 + 下留白）完全一致，
///   否则吸顶瞬间会跳一下；
/// - 覆盖色走 [AppTokens.pinnedCover]（背板同源渐变），**只在有内容滚过时才画**。
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeader({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  /// ⚠️ 背景**只在「吸顶后（下方内容从缝里滚过）」才画**——用 [shrinkOffset] > 0 判断。
  ///
  /// pinned 头的 `build(overlapsContent:)` 那个 `overlapsContent` 是「前方是否有 floating sliver
  /// 压着自己」（本布局前方是 banner，永远为 false），**不是**「下方内容是否滚到了头下面」。
  /// 所以不能直接用 `overlapsContent`，否则它永远 false → 吸顶后透明 → 列表文字从缝里透出来
  /// （2026-09-12 用户实指：滚动时灰色列表文字出现在间隙里）。
  ///
  /// 正确信号是 [shrinkOffset]：它 = 已滚过的量，> 0 即已滚动、头已吸顶、下方内容正从缝下经过。
  /// - shrinkOffset == 0（静止在顶部，banner 还在上方）→ **完全透明**，透出页面渐变背板，无额外色块；
  /// - shrinkOffset > 0（已滚动）→ 铺背板同源渐变（`AppTokens.pinnedCover`）：盖住内容且与背板无缝。
  ///
  /// ❌ 早期实现无条件刷 `colors.background` 纯色，静止时也是一块灰白挡板
  /// （上半屏紫渐变、往下突然灰白 = 背景被内容区切断，2026-09-12 用户实指）。
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      DecoratedBox(
        decoration: shrinkOffset > 0
            ? AppTokens.pinnedCover(context, extent)
            : const BoxDecoration(),
        child: child,
      );

  @override
  bool shouldRebuild(covariant _PinnedHeader oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}
