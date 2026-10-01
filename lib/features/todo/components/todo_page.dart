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
//   Tab 栏   状态范围：进行中（默认）/ 未开始 / 已完成 / 已取消 / 全部
//            ⚠️ 五格是 6 个状态的**完整划分**，口径表见 `todo_filter.dart` 的 [applyTodoScope]；
//            「进行中」= 已开工未收尾（in_progress / blocked / restart），**不含未开始**。
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
import '../../../app/ui/file_export.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/scope_tab_bar.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import '../models/todo_view_mode.dart';
import '../providers/todo_providers.dart';
import '../utils/export_todo_markdown.dart';
import 'todo_calendar_view.dart';
import 'todo_card_view.dart';
import 'todo_sheets.dart';
import 'todo_tile.dart';

// 搜索行几何（上留白 12 + 搜索框 40 + 下留白 8）与吸顶高度已抽出为共享原子
// `lib/app/ui/pinned_search_row.dart`（kSearchRowExtent = 60），本页只消费、不再自带一份。

/// 待办页
class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  /// 待办域专属蓝强调色（与 Hub 入口卡图标色一致，2026-09-13 功能色定案）
  static final Color _accent = AppTokens.accent(1);
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
    // D7：排序模式一并恢复（持久化键 todo.sortMode，默认 updated）
    final sort = await TodoSortModeStore.load();
    if (mounted) {
      setState(() {
        _view = saved;
        _filter = _filter.copyWith(sortBy: sort);
      });
    }
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
            onTap: _exportMarkdown,
            child: Icon(
              // D4：导出 Markdown 入口（工具区），落盘走 exportTextToDownloadDir
              FLucideIcons.download,
              size: 20,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: _openRecycleBin,
            child: Icon(
              // E5：回收站入口（软删除的待办在此恢复 / 彻底删除）
              FLucideIcons.trash2,
              size: 18,
              color: t.colors.foreground,
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

    // D10 统一：卡片 / 日历分支并入列表的 CustomScrollView 骨架 ——
    // 吸顶锚点同为搜索行（PinnedSearchHeader + kSearchRowExtent，minExtent==maxExtent），
    // 横幅 / 条件 chip / Tab 栏作为普通 sliver 随滚动移出；pinnedCover 只在
    // shrinkOffset>0 时铺（共享原子内部逻辑，三视图行为一致）。
    // ⚠️ 视图子组件（TodoCardView / TodoCalendarView）不改：
    //   - 卡片瀑布：TodoCardView 内层的 SingleChildScrollView 在 SliverToBoxAdapter
    //     给出的无界主轴约束下直接收缩为内容高（不产生内层滚动），整页统一由外层滚动；
    //   - 日历：TodoCalendarView 内层是 ListView（无界高度会抛异常），故用
    //     SliverFillRemaining 给有界剩余空间；月历卡片内容通常不溢出，
    //     内层不可拖拽（canDrag=false）时手势自动落到外层，滚动行为与列表一致。
    Widget bodySliver() {
      switch (_view) {
        case TodoViewMode.calendar:
          return SliverFillRemaining(
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
          );
        case TodoViewMode.card:
          return scoped.isEmpty
              ? SliverFillRemaining(hasScrollBody: false, child: empty)
              : SliverToBoxAdapter(
                  child: TodoCardView(
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
                );
        case TodoViewMode.list:
          return scoped.isEmpty
              ? SliverFillRemaining(hasScrollBody: false, child: empty)
              : SliverPadding(
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
                );
      }
    }

    // 三视图共用骨架（画布 07 / 08）：整页可滚，**吸顶以搜索行为锚点**——
    // 横幅 / 条件 chip / Tab 栏随滚动移出视口，搜索框常驻顶部（随时可改关键词）。
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(context, all)),
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: _searchRow(context),
          ),
        ),
        SliverToBoxAdapter(child: _chipsRow(context)),
        SliverToBoxAdapter(child: _tabBar(context)),
        bodySliver(),
      ],
    );
  }

  /// 统计横幅（画布 5:431，含纹理「卡11」+ 同心圆环装饰）
  Widget _banner(BuildContext context, List<TodoItem> all) => PageBanner(
    icon: FLucideIcons.check,
    title: '待办',
    subtitle: '专注当下，一件一件来',
    // 画布渐变与首页英雄卡同源 → 走主色渐变（换外观色系时整屏跟着走）
    gradient: AppTokens.accentGradient(_accent),
    cornerRadius: 22,
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
  /// ⚠️ 尺寸常量与吸顶高度已收口到共享原子 `PinnedSearchRow`（kSearchRowExtent 同源推导）。
  Widget _searchRow(BuildContext context) => PinnedSearchRow(
    controller: _searchController,
    hintText: '搜索待办…',
    onChanged: (v) => setState(() => _search = v),
    onFilter: _openFilter,
  );

  /// 生效条件（画布 5:424）：无生效条件时整块不渲染。
  ///
  /// 上留白为 0 —— 与搜索框之间的 8px 间距由搜索行的 [_kSearchRowBottomGap] 提供，
  /// 这样吸顶时那 8px 也被搜索行的底色盖住，chip 从框下方 8px 处开始消失。
  Widget _chipsRow(BuildContext context) {
    final t = context.theme;
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(
        _condChip(context, '搜索：$_search', _accent, () {
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
          _accent,
          () => _updateFilter((f) => f.copyWith(tagKeys: {})),
        ),
      );
    }
    if (_filter.dueGroup != null) {
      chips.add(
        _condChip(
          context,
          '到期：${kDueRangeLabels[_filter.dueGroup] ?? ''}',
          _accent,
          () => _updateFilter((f) => f.copyWith(clearDueGroup: true)),
        ),
      );
    }
    if (!_filter.showCompleted) {
      chips.add(
        _condChip(
          context,
          '仅未完成',
          _accent,
          () => _updateFilter((f) => f.copyWith(showCompleted: true)),
        ),
      );
    }
    if (_filter.showTemplates) {
      chips.add(
        _condChip(
          context,
          '含重复模板',
          _accent,
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

  /// Tab 栏（画布 8:2）：状态范围切换（共享原子 [ScopeTabBar]）。
  ///
  /// ⚠️ **不吸顶** —— 吸顶锚点是上方的搜索行，本栏随滚动移出（见文件头吸顶规则）。
  Widget _tabBar(BuildContext context) => ScopeTabBar<TodoScope>(
    tabs: kTodoScopeTabs,
    selected: _scope,
    onSelect: (tab) => setState(() => _scope = tab),
  );

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
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(FLucideIcons.list, size: 32, color: _accent),
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

  /// 生效条件 chip（画布 5:425：底 = 同色 12% · r10 · 内边距 6 · 11/SemiBold，共享原子 [SoftChip]）
  Widget _condChip(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
  ) => SoftChip(
    label: label,
    color: color,
    alpha: 0.12,
    padding: const EdgeInsets.all(6),
    onRemove: onTap,
  );

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
      // D7：排序是显示项（已持久化），清筛选不重置排序
      _filter = TodoFilterState(
        groupBy: TodoGroupBy.due,
        sortBy: _filter.sortBy,
      );
      _search = '';
    });
  }

  /// 显示风格（画布 09）+ 排序（D7）：点选即生效并持久化
  Future<void> _openViewModeSheet() async {
    final next = await showTodoViewModeSheet(
      context,
      current: _view,
      sort: _filter.sortBy,
    );
    if (!mounted || next == null) return;
    final viewChanged = next.view != _view;
    final sortChanged = next.sort != _filter.sortBy;
    if (!viewChanged && !sortChanged) return;
    if (viewChanged) setState(() => _view = next.view);
    if (sortChanged) _updateFilter((f) => f.copyWith(sortBy: next.sort));
    if (viewChanged) await TodoViewModeStore.save(next.view);
    if (sortChanged) await TodoSortModeStore.save(next.sort);
  }

  /// 导出 Markdown（D4）：把当前「筛选 + 状态范围」下的列表（与用户所见一致）
  /// 组稿后经共享 helper 落盘到 `Download/渐离App导出/待办_<时间戳>.md`
  /// （exportTextToDownloadDir 内含权限 / 落盘 / 媒体索引 / toast，直接用）。
  Future<void> _exportMarkdown() async {
    final all = ref.read(todoListProvider).value ?? const <TodoItem>[];
    final tags = ref.read(todoTagsProvider).value ?? const <TodoTagView>[];
    final filtered = applyTodoFilters(all, _filter.copyWith(search: _search));
    final scoped = applyTodoScope(filtered, _scope);
    await exportTextToDownloadDir(
      context: context,
      text: buildTodoMarkdown(scoped, tags: tags),
      filename: '待办_${_fileStamp()}.md',
    );
  }

  /// 导出文件名时间戳（yyyyMMdd_HHmmss，与习惯打卡 / 番茄钟导出同款）
  String _fileStamp() {
    final n = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
  }

  /// 回收站（E5）：lg 抽屉列出软删除待办，可恢复 / 彻底删除 / 清空
  Future<void> _openRecycleBin() =>
      showTodoRecycleBinSheet(context, ref);

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
      // 2026-10-01 批次新列缺省（新建即有效待办 / 无专注累计 / 缺省 fixed）
      deleted: 0,
      focusedMinutes: 0,
      recurrenceMode: null,
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

// 吸顶头 delegate 已抽出为共享原子 `lib/app/ui/pinned_search_row.dart`
// 的 [PinnedSearchHeader]（shrinkOffset>0 才铺 pinnedCover 的正确逻辑同源保留）。
