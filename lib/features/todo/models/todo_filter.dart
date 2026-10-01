// 待办筛选状态模型（对齐 PC useTodo 的过滤/分组能力）
//
// 移动端待办页的搜索 / 优先级 / 状态 / 标签 / 显示开关 / 分组方式统一收进本状态类；
// 列表页持有该状态，applyTodoFilters 生成过滤后的扁平列表，分组在视图层按 groupBy 处理。
// 文件末段另收「日期口径」两个纯函数（parseTodoDateTime / formatTodoDue）——
// 它们是列表卡片、详情抽屉、日历三处的共用口径，放这里避免各自复制一份后漂掉。
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo.dart';

/// 分组方式
enum TodoGroupBy { none, status, due, parent }

/// 排序模式（D7 移动端排序选项）
/// - updated 更新时间（默认，与仓库 watchTodos 的 updateTime 倒序口径一致）
/// - due 截止最早 / priority 优先级 / created 创建时间
enum TodoSortMode { updated, due, priority, created }

/// 排序选项（值 + 字面量），供「显示风格」弹层与后续 UI 复用
const List<(TodoSortMode, String)> kTodoSortOptions = [
  (TodoSortMode.updated, '更新时间'),
  (TodoSortMode.due, '截止最早'),
  (TodoSortMode.priority, '优先级'),
  (TodoSortMode.created, '创建时间'),
];

/// 排序模式持久化（shared_preferences，键 `todo.sortMode`，写法参照 todo_view_mode.dart）
abstract final class TodoSortModeStore {
  static const _key = 'todo.sortMode';

  static Future<TodoSortMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    return TodoSortMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => TodoSortMode.updated,
    );
  }

  static Future<void> save(TodoSortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

/// 列表页 Tab 栏的状态范围
/// （画布「07 待办·列表页 主态」Tab 栏：进行中 / 未开始 / 已完成 / 已取消 / 全部）
enum TodoScope { active, notStarted, completed, cancelled, all }

/// Tab 栏选项（值 + 字面量），顺序即画布顺序
const List<(TodoScope, String)> kTodoScopeTabs = [
  (TodoScope.active, '进行中'),
  (TodoScope.notStarted, '未开始'),
  (TodoScope.completed, '已完成'),
  (TodoScope.cancelled, '已取消'),
  (TodoScope.all, '全部'),
];

/// 按 Tab 栏状态范围过滤。
///
/// ⚠️ 六个状态 → 五个 scope 是**完整划分**（不重不漏），改这里先看这张表。
/// 2026-09-14 修正：旧实现把 `active` 写成「未完成且未取消」，
/// 于是「进行中」页签里混进了未开始的任务（用户实指）。
///
/// | scope      | 覆盖状态                              |
/// |------------|---------------------------------------|
/// | active     | `in_progress` / `blocked` / `restart` |
/// | notStarted | `not_started`                         |
/// | completed  | `completed`                           |
/// | cancelled  | `cancelled`                           |
/// | all        | 全部                                  |
///
/// 「进行中」口径 = **已开工未收尾**：进行中 / 阻塞 / 重新开始三者都算「动手了但没结束」。
/// 与 PC `useTodo.inProgressCount`（严格 `=== 'in_progress'`）有意不同 ——
/// 移动端 Tab 栏只有 5 格、塞不下 6 个状态各自一格；卡片自身的状态 chip
/// 仍标精确状态（阻塞 / 重新开始分得清），信息不丢。
List<TodoItem> applyTodoScope(List<TodoItem> items, TodoScope scope) {
  switch (scope) {
    case TodoScope.active:
      return items
          .where((t) {
            final s = effectiveStatus(t);
            return s == 'in_progress' || s == 'blocked' || s == 'restart';
          })
          .toList();
    case TodoScope.notStarted:
      return items.where((t) => effectiveStatus(t) == 'not_started').toList();
    case TodoScope.completed:
      return items.where((t) => effectiveStatus(t) == 'completed').toList();
    case TodoScope.cancelled:
      return items.where((t) => effectiveStatus(t) == 'cancelled').toList();
    case TodoScope.all:
      return items;
  }
}

/// 待办筛选状态
class TodoFilterState {
  const TodoFilterState({
    this.search = '',
    this.priority,
    this.status,
    this.tagKeys = const {},
    this.dueGroup,
    this.showCompleted = true,
    this.showTemplates = false,
    this.groupBy = TodoGroupBy.none,
    this.sortBy = TodoSortMode.updated,
  });

  final String search;
  final String? priority; // null=全部；high/medium/low
  final String? status; // null=全部；六态之一
  final Set<String> tagKeys; // 命中任一即保留（与 PC some 语义一致）

  /// 到期时间段：null=不限；overdue/today/tomorrow/thisweek/later/nodate
  /// （取值同 [dueGroupOf]，对应画布「10 高级搜索」的「到期时间」组）
  final String? dueGroup;

  final bool showCompleted; // false 时隐藏已完成
  final bool showTemplates; // false 时隐藏重复模板
  final TodoGroupBy groupBy;

  /// 排序模式（D7）：默认 updated（更新时间倒序，与仓库查询口径一致）。
  /// 属显示项（同 groupBy），不计入 hasActive / activeCount。
  final TodoSortMode sortBy;

  TodoFilterState copyWith({
    String? search,
    String? priority,
    bool clearPriority = false,
    String? status,
    bool clearStatus = false,
    Set<String>? tagKeys,
    String? dueGroup,
    bool clearDueGroup = false,
    bool? showCompleted,
    bool? showTemplates,
    TodoGroupBy? groupBy,
    TodoSortMode? sortBy,
  }) {
    return TodoFilterState(
      search: search ?? this.search,
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
      tagKeys: tagKeys ?? this.tagKeys,
      dueGroup: clearDueGroup ? null : (dueGroup ?? this.dueGroup),
      showCompleted: showCompleted ?? this.showCompleted,
      showTemplates: showTemplates ?? this.showTemplates,
      groupBy: groupBy ?? this.groupBy,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// 是否有任何非默认筛选条件（用于筛选按钮角标 / 是否显示「清除全部」）
  bool get hasActive =>
      search.isNotEmpty ||
      priority != null ||
      status != null ||
      tagKeys.isNotEmpty ||
      dueGroup != null ||
      !showCompleted ||
      showTemplates ||
      groupBy != TodoGroupBy.none;

  /// 已生效条件数量（筛选按钮角标）
  int get activeCount =>
      (search.isNotEmpty ? 1 : 0) +
      (priority != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (tagKeys.isNotEmpty ? 1 : 0) +
      (dueGroup != null ? 1 : 0) +
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

/// 到期时间的可读文案（列表卡片 / 详情抽屉 / 日历共用，避免各处各写一份漂掉）。
///
/// 口径：今天 18:00 / 明天 10:00 / 本周内 周五 20:00 / 更远（含已过期）9月20日 09:00。
/// 解析失败或无值返回 null。
String? formatTodoDue(String? raw) {
  final d = parseTodoDateTime(raw);
  if (d == null) return null;
  String p2(int n) => n.toString().padLeft(2, '0');
  final hm = '${p2(d.hour)}:${p2(d.minute)}';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return '今天 $hm';
  if (diff == 1) return '明天 $hm';
  if (diff > 1) {
    // 本周内（周一为一周之始）用「周X」
    final weekEnd = today.add(Duration(days: DateTime.daysPerWeek - today.weekday));
    if (!day.isAfter(weekEnd)) {
      const weeks = ['一', '二', '三', '四', '五', '六', '日'];
      return '周${weeks[d.weekday - 1]} $hm';
    }
  }
  return '${d.month}月${d.day}日 $hm';
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
        'later': '更晚',
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
/// + 到期时间段 + 显示已完成开关 + 显示模板开关。
/// 管线末端按 [TodoFilterState.sortBy] 排序（D7）——排序必须先于视图层分组。
/// 仓库的 watchTodos 仍固定 updateTime 倒序，不动。
List<TodoItem> applyTodoFilters(List<TodoItem> all, TodoFilterState f) {
  final kw = f.search.trim().toLowerCase();
  final matched = all.where((t) {
    if (!f.showCompleted && effectiveStatus(t) == 'completed') return false;
    if (!f.showTemplates && t.isTemplate) return false;
    if (kw.isNotEmpty) {
      final hay = '${t.title} ${t.description}'.toLowerCase();
      if (!hay.contains(kw)) return false;
    }
    if (f.priority != null && t.priority != f.priority) return false;
    if (f.status != null && effectiveStatus(t) != f.status) return false;
    if (f.tagKeys.isNotEmpty && !t.tags.any(f.tagKeys.contains)) return false;
    if (f.dueGroup != null && dueRangeOf(t) != f.dueGroup) return false;
    return true;
  }).toList();
  return sortTodos(matched, f.sortBy);
}

/// 按 [mode] 内存排序（D7）。比较键全部用「定长格式字符串的安全比较」——
/// createTime / updateTime / dueDate 均为 yyyy-MM-dd HH:mm:ss 定长文本，
/// 字典序即时间序，无需解析成 DateTime。
/// - updated：updateTime 倒序（空排最后）
/// - due：dueDate 字符串升序（空排最后）
/// - priority：high < medium < low（未知值排最后）
/// - created：createTime 倒序（空排最后）
List<TodoItem> sortTodos(List<TodoItem> items, TodoSortMode mode) {
  // 升序比较：空值一律排最后
  int cmpAsc(String? a, String? b) {
    final aEmpty = a == null || a.isEmpty;
    final bEmpty = b == null || b.isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return 1;
    if (bEmpty) return -1;
    return a.compareTo(b);
  }

  // 倒序比较：非空按倒序，空值仍排最后（不是简单取反 cmpAsc）
  int cmpDesc(String? a, String? b) {
    final aEmpty = a == null || a.isEmpty;
    final bEmpty = b == null || b.isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return 1;
    if (bEmpty) return -1;
    return b.compareTo(a);
  }

  switch (mode) {
    case TodoSortMode.updated:
      return items.toList()..sort((a, b) => cmpDesc(a.updateTime, b.updateTime));
    case TodoSortMode.created:
      return items.toList()..sort((a, b) => cmpDesc(a.createTime, b.createTime));
    case TodoSortMode.due:
      return items.toList()..sort((a, b) => cmpAsc(a.dueDate, b.dueDate));
    case TodoSortMode.priority:
      // 对齐 PC 优先级语义：高 → 中 → 低
      const rank = {'high': 0, 'medium': 1, 'low': 2};
      return items.toList()
        ..sort((a, b) => (rank[a.priority] ?? 3).compareTo(rank[b.priority] ?? 3));
  }
}

/// 到期时间段的用户语义标签（画布「10 高级搜索 · 到期时间」组与生效条件 chip 共用）。
/// 与 [groupTodos] 的到期分组键不同：这里是「筛选范围」，[dueGroupOf] 是「列表分组」。
const Map<String, String> kDueRangeLabels = {
  'overdue': '已逾期',
  'today': '今天',
  'thisweek': '本周',
  'thismonth': '本月',
  'later': '更晚',
  'nodate': '无期限',
};

/// 「10 高级搜索 · 到期时间」chip 顺序（不含「不限」，由调用方补在最前）
const List<String> kDueRangeOptions = [
  'overdue',
  'today',
  'thisweek',
  'thismonth',
  'later',
  'nodate',
];

/// 到期时间段归类（筛选语义）：overdue/today/thisweek/thismonth/later/nodate。
/// - 今天之前 → overdue；今天 → today；本周内（周一为一周之始，含今天）→ thisweek；
///   本月内 → thismonth；更远 → later；无到期日 → nodate。
String dueRangeOf(TodoItem t) {
  final due = parseTodoDateTime(t.dueDate);
  if (due == null) return 'nodate';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  if (day.isBefore(today)) return 'overdue';
  if (day == today) return 'today';
  final weekEnd = today.add(Duration(days: DateTime.daysPerWeek - today.weekday));
  if (!day.isAfter(weekEnd)) return 'thisweek';
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  if (!day.isAfter(monthEnd)) return 'thismonth';
  return 'later';
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
