// 待办页（forui 化，对齐 PC 待办）—— 视图切换(列表/卡片/日历) + 搜索 + 筛选抽屉
// + 已生效条件 chip + 统计横幅 + 分组(无/状态/到期/父任务) + 批量删除选择模式 + 新增/编辑
//
// ⚠️ 页面操作规范：所有弹窗（新增/编辑/筛选/状态/标签/父任务/日期/记录进展/确认/当天待办）
// 一律走底部抽屉（showFSheet + SheetSurface），见 todo_sheets.dart 与 SKILL.md。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import '../providers/todo_providers.dart';
import 'todo_calendar_view.dart';
import 'todo_card_view.dart';
import 'todo_sheets.dart';
import 'todo_tile.dart';

/// 待办页
class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  TodoViewMode _view = TodoViewMode.list;
  String _search = '';
  TodoFilterState _filter = const TodoFilterState();
  bool _selectMode = false;
  final Set<String> _selected = {};

  // 视图切换
  static const _viewItems = [
    (FLucideIcons.list, '列表'),
    (FLucideIcons.grid2x2, '卡片'),
    (FLucideIcons.calendarDays, '日历'),
  ];

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todoListProvider);
    final tagsAsync = ref.watch(todoTagsProvider);
    final t = context.theme;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('待办'),
        prefixes: [
          if (_selectMode)
            FHeaderAction(
              icon: const Icon(FLucideIcons.x),
              onPress: () => setState(() {
                _selectMode = false;
                _selected.clear();
              }),
              semanticsLabel: '退出选择',
            )
          else
            FHeaderAction.back(onPress: () => context.pop()),
        ],
        suffixes: [
          if (_selectMode) ...[
            FHeaderAction(
              icon: const Icon(FLucideIcons.trash2),
              onPress: _selected.isEmpty ? null : _batchDelete,
              semanticsLabel: '批量删除',
            ),
          ] else ...[
            FHeaderAction(
              icon: const Icon(FLucideIcons.search),
              onPress: _toggleSearch,
              semanticsLabel: '搜索',
            ),
            FHeaderAction(
              icon: const Icon(FLucideIcons.listFilter),
              onPress: _openFilter,
              semanticsLabel: '筛选',
            ),
            FHeaderAction(
              icon: const Icon(FLucideIcons.plus),
              onPress: _addTodo,
              semanticsLabel: '新增待办',
            ),
          ],
        ],
      ),
      child: todosAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text('加载失败：$e',
              style: t.typography.body.sm.copyWith(color: t.colors.error),
              textAlign: TextAlign.center),
        ),
        data: (all) {
          final tags = tagsAsync.value ?? const [];
          // 搜索与筛选条件合并（_search 单独持有，便于 chip 单独清除）
          final filtered =
              applyTodoFilters(all, _filter.copyWith(search: _search));
          final groups = groupTodos(filtered, _filter.groupBy);

          // 统计（基于全量，不随过滤跳变）
          final total = all.length;
          final inProgress =
              all.where((x) => effectiveStatus(x) == 'in_progress').length;
          final completed =
              all.where((x) => effectiveStatus(x) == 'completed').length;
          final cancelled =
              all.where((x) => effectiveStatus(x) == 'cancelled').length;

          if (total == 0) {
            return const Center(
              child: EmptyState(icon: FLucideIcons.listTodo, title: '这里空空如也'),
            );
          }

          return Column(
            children: [
              // 搜索框
              if (_searchVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: FTextField(
                    control: FTextFieldControl.managed(
                      controller: _searchController,
                      onChange: (v) => setState(() => _search = v.text),
                    ),
                    hint: '搜索待办…',
                    autofocus: true,
                  ),
                ),
              // 视图切换
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: JianliSegmented(
                  items: [
                    for (final v in _viewItems) (v.$1, v.$2),
                  ],
                  selected: _view.index,
                  onSelect: (i) => setState(() => _view = TodoViewMode.values[i]),
                ),
              ),
              // 已生效筛选条件 chip（搜索单独持有，也纳入「有生效条件」判断）
              if (_filter.hasActive || _search.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_search.isNotEmpty)
                        _condChip('搜索：$_search', () => _clearSearch()),
                      if (_filter.priority != null)
                        _condChip('优先级：${priorityLabel(_filter.priority!)}',
                            () => _updateFilter((f) => f.copyWith(clearPriority: true))),
                      if (_filter.status != null)
                        _condChip('状态：${statusMeta(_filter.status!).label}',
                            () => _updateFilter((f) => f.copyWith(clearStatus: true))),
                      if (_filter.tagKeys.isNotEmpty)
                        _condChip('标签：${_filter.tagKeys.length} 个',
                            () => _updateFilter((f) => f.copyWith(tagKeys: {}))),
                      if (!_filter.showCompleted)
                        _condChip('仅未完成',
                            () => _updateFilter((f) => f.copyWith(showCompleted: true))),
                      if (_filter.showTemplates)
                        _condChip('含重复模板',
                            () => _updateFilter((f) => f.copyWith(showTemplates: false))),
                      if (_filter.groupBy != TodoGroupBy.none)
                        _condChip('分组：${_groupLabel(_filter.groupBy)}',
                            () => _updateFilter((f) => f.copyWith(groupBy: TodoGroupBy.none))),
                      GestureDetector(
                        onTap: _clearAllFilters,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: t.colors.destructive.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                          ),
                          child: Text('清除全部',
                              style: t.typography.body.xs
                                  .copyWith(color: t.colors.destructive)),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _view == TodoViewMode.calendar
                    ? TodoCalendarView(
                        items: filtered,
                        onPickDay: (day, dayItems) => showTodoDaySheet(
                          context,
                          ref,
                          day,
                          dayItems,
                          allTodos: all,
                          tags: tags,
                        ),
                      )
                    : _view == TodoViewMode.card
                        ? filtered.isEmpty
                            ? const Center(
                                child: EmptyState(
                                    icon: FLucideIcons.listTodo, title: '没有匹配的待办'),
                              )
                                      : TodoCardView(
                                items: filtered,
                                allTodos: all,
                                tags: tags,
                                selectable: _selectMode,
                                selectedKeys: _selected,
                                onToggle: (item) => ref
                                    .read(todoRepositoryProvider)
                                    .toggleComplete(
                                      item.key,
                                      effectiveStatus(item) != 'completed',
                                    ),
                                onMore: (item) => showTodoActionSheet(
                                  context,
                                  ref,
                                  item,
                                  allTodos: all,
                                  tags: tags,
                                ),
                                onSelect: (item) => _toggleSelect(item.key),
                                onTap: (item) => _openEdit(item),
                              )
                        : filtered.isEmpty
                            ? const Center(
                                child: EmptyState(
                                    icon: FLucideIcons.listTodo, title: '没有匹配的待办'),
                              )
                            : ListView(
                                padding: EdgeInsets.only(
                                  top: AppTokens.listTopGapOf(context),
                                  bottom: AppTokens.pageBottomGapOf(context),
                                ),
                                children: [
                                  StaggerList(
                                    children: [
                                      PageBanner(
                                        icon: FLucideIcons.listTodo,
                                        title: '待办',
                                        subtitle: '专注当下，一件一件来',
                                        accentIndex: 1,
                                        stats: [
                                          ('$total', '全部'),
                                          ('$inProgress', '进行中'),
                                          ('$completed', '已完成'),
                                          ('$cancelled', '已取消'),
                                        ],
                                      ),
                                      for (final group in groups) ...[
                                        if (_filter.groupBy != TodoGroupBy.none)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 12, 16, 4),
                                            child: Text(
                                              group.$1,
                                              style: t.typography.body.sm.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: t.colors.mutedForeground,
                                              ),
                                            ),
                                          ),
                                        for (final item in group.$2)
                                          TodoListTile(
                                            item: item,
                                            allTodos: all,
                                            tags: tags,
                                            selectable: _selectMode,
                                            selected: _selected.contains(item.key),
                                            onToggle: () => ref
                                                .read(todoRepositoryProvider)
                                                .toggleComplete(
                                                  item.key,
                                                  effectiveStatus(item) != 'completed',
                                                ),
                                            onMore: () => showTodoActionSheet(
                                              context,
                                              ref,
                                              item,
                                              allTodos: all,
                                              tags: tags,
                                            ),
                                            onSelect: () => _toggleSelect(item.key),
                                            onTap: () => _openEdit(item),
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== 搜索 =====
  bool _searchVisible = false;
  final _searchController = TextEditingController();

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _search = '';
        _searchController.clear();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _search = '';
      _searchController.clear();
      _searchVisible = false;
    });
  }

  // ===== 筛选 =====
  void _updateFilter(TodoFilterState Function(TodoFilterState) fn) {
    setState(() => _filter = fn(_filter));
  }

  Future<void> _openFilter() async {
    final tags = ref.read(todoTagsProvider).value ?? const [];
    final next = await showTodoFilterSheet(
      context,
      current: _filter.copyWith(search: _search),
      tags: tags,
    );
    if (next != null) {
      setState(() {
        _filter = next;
        _search = next.search;
        _searchController.text = next.search;
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _filter = const TodoFilterState();
      _search = '';
      _searchController.clear();
      _searchVisible = false;
    });
  }

  String _groupLabel(TodoGroupBy g) => switch (g) {
        TodoGroupBy.status => '按状态',
        TodoGroupBy.due => '按到期',
        TodoGroupBy.parent => '按父任务',
        TodoGroupBy.none => '无',
      };

  // ===== 选择 / 批量删除 =====
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
    if (ok == true) {
      final repo = ref.read(todoRepositoryProvider);
      for (final k in List<String>.from(_selected)) {
        await repo.deleteTodo(k);
      }
      setState(() {
        _selectMode = false;
        _selected.clear();
      });
    }
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

  /// 编辑已有待办（底部抽屉表单 → upsert）
  Future<void> _openEdit(TodoItem item) async {
    final all = ref.read(todoListProvider).value ?? const [];
    final tags = ref.read(todoTagsProvider).value ?? const [];
    final saved = await showTodoEditSheet(
      context,
      ref,
      initial: item,
      allTodos: all,
      tags: tags,
    );
    if (saved != null) {
      await ref.read(todoRepositoryProvider).upsertTodo(saved);
    }
  }

  Widget _condChip(String label, VoidCallback onTap) {
    final theme = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colors.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: theme.typography.body.xs
                    .copyWith(color: theme.colors.foreground)),
            const SizedBox(width: 4),
            Icon(FLucideIcons.x, size: 12, color: theme.colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  /// 新建待办的 key（与仓库一致：UUID v4，drift 表以 key 为主键）
  String _uuid() => const Uuid().v4();

  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}

/// 视图模式
enum TodoViewMode { list, card, calendar }
