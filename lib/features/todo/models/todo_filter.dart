// 待办筛选状态模型（对齐 PC useTodo 的过滤/分组能力）
//
// 移动端待办页的搜索 / 优先级 / 状态 / 标签 / 显示开关 / 分组方式统一收进本状态类；
// 列表页持有该状态，applyTodoFilters 生成过滤后的扁平列表，分组在视图层按 groupBy 处理。
import '../models/todo.dart';

/// 分组方式
enum TodoGroupBy { none, status, due, parent }

/// 待办筛选状态
class TodoFilterState {
  const TodoFilterState({
    this.search = '',
    this.priority,
    this.status,
    this.tagKeys = const {},
    this.showCompleted = true,
    this.showTemplates = false,
    this.groupBy = TodoGroupBy.none,
  });

  final String search;
  final String? priority; // null=全部；high/medium/low
  final String? status; // null=全部；六态之一
  final Set<String> tagKeys; // 命中任一即保留（与 PC some 语义一致）
  final bool showCompleted; // false 时隐藏已完成
  final bool showTemplates; // false 时隐藏重复模板
  final TodoGroupBy groupBy;

  TodoFilterState copyWith({
    String? search,
    String? priority,
    bool clearPriority = false,
    String? status,
    bool clearStatus = false,
    Set<String>? tagKeys,
    bool? showCompleted,
    bool? showTemplates,
    TodoGroupBy? groupBy,
  }) {
    return TodoFilterState(
      search: search ?? this.search,
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
      tagKeys: tagKeys ?? this.tagKeys,
      showCompleted: showCompleted ?? this.showCompleted,
      showTemplates: showTemplates ?? this.showTemplates,
      groupBy: groupBy ?? this.groupBy,
    );
  }

  /// 是否有任何非默认筛选条件（用于筛选按钮角标 / 是否显示「清除全部」）
  bool get hasActive =>
      search.isNotEmpty ||
      priority != null ||
      status != null ||
      tagKeys.isNotEmpty ||
      !showCompleted ||
      showTemplates ||
      groupBy != TodoGroupBy.none;

  /// 已生效条件数量（筛选按钮角标）
  int get activeCount =>
      (search.isNotEmpty ? 1 : 0) +
      (priority != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (tagKeys.isNotEmpty ? 1 : 0) +
      (!showCompleted ? 1 : 0) +
      (showTemplates ? 1 : 0) +
      (groupBy != TodoGroupBy.none ? 1 : 0);
}

/// 解析待办日期文本（yyyy-MM-dd HH:mm:ss / yyyy/M/d 均兼容；失败返回 null）
DateTime? parseTodoDateTime(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s.trim().replaceAll('/', '-'));
  } catch (_) {
    return null;
  }
}

/// 把过滤后的扁平列表再按 groupBy 分组成「标题 -> 子列表」；none 返回单组（标题空）。
List<(String, List<TodoItem>)> groupTodos(
  List<TodoItem> items,
  TodoGroupBy groupBy,
) {
  switch (groupBy) {
    case TodoGroupBy.none:
      return [('', items)];
    case TodoGroupBy.status:
      final order = [
        'not_started',
        'in_progress',
        'blocked',
        'restart',
        'completed',
        'cancelled',
      ];
      final map = <String, List<TodoItem>>{};
      for (final it in items) {
        final s = effectiveStatus(it);
        (map[s] ??= []).add(it);
      }
      return [
        for (final s in order)
          if (map.containsKey(s)) (statusMeta(s).label, map[s]!),
      ];
    case TodoGroupBy.due:
      final order = [
        'overdue',
        'today',
        'tomorrow',
        'thisweek',
        'later',
        'nodate',
      ];
      final labelOf = {
        'overdue': '已逾期',
        'today': '今天',
        'tomorrow': '明天',
        'thisweek': '本周',
        'later': '以后',
        'nodate': '无日期',
      };
      final map = <String, List<TodoItem>>{};
      for (final it in items) {
        (map[dueGroupOf(it)] ??= []).add(it);
      }
      return [
        for (final g in order)
          if (map.containsKey(g)) (labelOf[g]!, map[g]!),
      ];
    case TodoGroupBy.parent:
      final roots = items.where((t) => !t.isChild).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final result = <(String, List<TodoItem>)>[];
      for (final root in roots) {
        final children = childrenOf(items, root.key);
        result.add((root.title, [root, ...children]));
      }
      return result;
  }
}

/// 应用筛选状态，返回过滤后的扁平列表（分组在视图层处理）。
/// 语义对齐 PC useTodo.filteredTodos：搜索(标题/描述) + 优先级 + 状态 + 标签(任一命中)
/// + 显示已完成开关 + 显示模板开关。
List<TodoItem> applyTodoFilters(List<TodoItem> all, TodoFilterState f) {
  final kw = f.search.trim().toLowerCase();
  return all.where((t) {
    if (!f.showCompleted && effectiveStatus(t) == 'completed') return false;
    if (!f.showTemplates && t.isTemplate) return false;
    if (kw.isNotEmpty) {
      final hay = '${t.title} ${t.description}'.toLowerCase();
      if (!hay.contains(kw)) return false;
    }
    if (f.priority != null && t.priority != f.priority) return false;
    if (f.status != null && effectiveStatus(t) != f.status) return false;
    if (f.tagKeys.isNotEmpty && !t.tags.any(f.tagKeys.contains)) return false;
    return true;
  }).toList();
}

/// 到期分组键（对齐 PC dueGroup：overdue/today/tomorrow/thisweek/later/nodate）
String dueGroupOf(TodoItem t) {
  final due = parseTodoDateTime(t.dueDate);
  if (due == null) return 'nodate';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final diff = dueDay.difference(today).inDays;
  if (diff < 0) return 'overdue';
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff <= 7) return 'thisweek';
  return 'later';
}
