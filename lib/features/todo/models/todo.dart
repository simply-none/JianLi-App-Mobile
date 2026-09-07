// 待办模型 —— 包装桌面端 todo_list 行的解析结果
//
// 与 PC 端（jianli-app/src/views/todoList）字段约定逐一对齐：
// - key 为 UUID；completed='1'/'0'；tags 为标签 key 的 JSON 数组文本；
// - 父子任务用 parentIds（JSON 数组，可关联多个父任务；空数组=根任务）；
// - 重复任务字段（recurrence*）原样透传/消费；
// - 状态 status 六态（not_started/in_progress/blocked/completed/cancelled/restart），
//   缺省按 completed 推导（对齐 PC effectiveStatus）。
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../core/db/app_database.dart';
import '../../habit/models/habit.dart' show parseStringList;

/// 待办状态（6 态，与 PC statusConfig 一致）
typedef TodoStatus = String;

/// 状态选项（值 + 中文名），供状态选择/筛选复用
const List<(String, String)> kTodoStatusOptions = [
  ('not_started', '未开始'),
  ('in_progress', '进行中'),
  ('blocked', '阻塞'),
  ('completed', '已完成'),
  ('cancelled', '已取消'),
  ('restart', '重新开始'),
];

/// 优先级选项
const List<(String, String)> kTodoPriorityOptions = [
  ('high', '高'),
  ('medium', '中'),
  ('low', '低'),
];

/// 待办条目
class TodoItem {
  const TodoItem({
    required this.key,
    required this.title,
    required this.description,
    required this.completed,
    required this.priority,
    required this.dueDate,
    required this.completedTime,
    required this.tags,
    required this.status,
    required this.deadlineReminder,
    required this.remindCount,
    required this.remindInterval,
    required this.remindIntervalUnit,
    required this.createTime,
    required this.updateTime,
    required this.sortOrder,
    required this.parentIds,
    required this.recurrenceRule,
    required this.recurrenceInterval,
    required this.recurrenceWeekdays,
    required this.recurrenceEnd,
    required this.recurrenceId,
    required this.isRecurrenceInstance,
  });

  factory TodoItem.fromRow(TodoListData row) {
    return TodoItem(
      key: row.key,
      title: row.title ?? '（无标题）',
      description: row.description ?? '',
      completed: row.completed == '1',
      priority: row.priority ?? 'medium',
      dueDate: row.dueDate,
      completedTime: row.completedTime,
      tags: parseStringList(row.tags),
      status: row.status,
      deadlineReminder: int.tryParse(row.deadlineReminder ?? '') ?? 0,
      remindCount: int.tryParse(row.remindCount ?? '') ?? 1,
      remindInterval: int.tryParse(row.remindInterval ?? '') ?? 30,
      remindIntervalUnit: row.remindIntervalUnit == 'hour' ? 'hour' : 'minute',
      createTime: row.createTime,
      updateTime: row.updateTime,
      sortOrder: int.tryParse(row.sortOrder ?? '') ?? 0,
      parentIds: _parseParentIds(row.parentIds, row.parentId),
      recurrenceRule: row.recurrenceRule,
      recurrenceInterval: int.tryParse(row.recurrenceInterval ?? '') ?? 1,
      recurrenceWeekdays: _parseWeekdays(row.recurrenceWeekdays),
      recurrenceEnd: row.recurrenceEnd,
      recurrenceId: row.recurrenceId,
      isRecurrenceInstance: int.tryParse(row.isRecurrenceInstance ?? '') ?? 0,
    );
  }

  final String key;
  final String title;
  final String description;

  /// 是否完成：true/false（行内 '1'/'0'）
  final bool completed;

  /// 优先级：high / medium / low
  final String priority;

  /// 截止时间（yyyy-MM-dd HH:mm:ss 文本，桌面端原样）
  final String? dueDate;

  /// 完成时间（yyyy-MM-dd HH:mm:ss，未完成为空）
  final String? completedTime;

  /// 标签 key 列表（展示名需关联 todo_tags）
  final List<String> tags;

  /// 状态（6 态之一；null 表示按 completed 推导）
  final String? status;

  /// 截止提醒开关（0/1）
  final int deadlineReminder;
  final int remindCount;
  final int remindInterval;

  /// 提醒间隔单位：minute / hour
  final String remindIntervalUnit;

  final String? createTime;
  final String? updateTime;

  /// 同级排序权重（用 sortOrder 而非 order，避免 SQL 保留字冲突）
  final int sortOrder;

  /// 关联父任务 key 数组；空数组/空表示根任务
  final List<String> parentIds;

  /// 重复规则：daily / weekly / null
  final String? recurrenceRule;
  final int recurrenceInterval;

  /// 每周生效的星期（0-6 数组）
  final List<int> recurrenceWeekdays;

  /// 重复结束日期 YYYY-MM-DD；空=无限
  final String? recurrenceEnd;

  /// 关联模板 key；实例行非空
  final String? recurrenceId;

  /// 是否为周期自动生成的实例（0/1）
  final int isRecurrenceInstance;

  /// 是否子任务（关联了任一父任务）
  bool get isChild => parentIds.isNotEmpty;

  /// 是否为重复模板（有规则且非实例）
  bool get isTemplate => recurrenceRule != null && recurrenceRule!.isNotEmpty && isRecurrenceInstance != 1;
}

/// 待办标签展示模型
class TodoTagView {
  const TodoTagView({
    required this.key,
    required this.name,
    required this.color,
  });

  /// 行类型为 TodoTag（drift 对 s 结尾表名单数化，注意不是 TodoTagsData）
  factory TodoTagView.fromRow(TodoTag row) => TodoTagView(
        key: row.key ?? '',
        name: row.name ?? '',
        color: row.color ?? '#8b5cf6',
      );

  final String key;
  final String name;
  final String color;
}

/// 解析父子关联：新数据 parentIds(JSON 数组)，旧数据兼容单 parentId
List<String> _parseParentIds(String? json, String? legacy) {
  if (json != null && json.isNotEmpty) {
    try {
      final arr = jsonDecode(json);
      if (arr is List) return [for (final e in arr) e.toString()];
    } catch (_) {
      // 非 JSON：视为单个 key
      return [json];
    }
  }
  if (legacy != null && legacy.isNotEmpty) return [legacy];
  return const [];
}

List<int> _parseWeekdays(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final arr = jsonDecode(raw);
    if (arr is List) return [for (final e in arr) int.tryParse(e.toString()) ?? 0];
  } catch (_) {
    /* ignore */
  }
  return const [];
}

/// 状态元信息（中文名 + 文字色 + 软底背景色），对齐 PC statusConfig 配色
class TodoStatusMeta {
  const TodoStatusMeta(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;
}

const Map<String, TodoStatusMeta> _kStatusMeta = {
  'not_started': TodoStatusMeta('未开始', Color(0xFF6b7280), Color(0x266b7280)),
  'in_progress': TodoStatusMeta('进行中', Color(0xFF3b82f6), Color(0x263b82f6)),
  'blocked': TodoStatusMeta('阻塞', Color(0xFFef4444), Color(0x26ef4444)),
  'completed': TodoStatusMeta('已完成', Color(0xFF22c55e), Color(0x2622c55e)),
  'cancelled': TodoStatusMeta('已取消', Color(0xFF9ca3af), Color(0x269ca3af)),
  'restart': TodoStatusMeta('重新开始', Color(0xFF8b5cf6), Color(0x268b5cf6)),
};

/// 取状态元信息，未命中回退「未开始」
TodoStatusMeta statusMeta(String? s) => _kStatusMeta[s] ?? _kStatusMeta['not_started']!;

/// 优先级 → 文字色（对齐 PC 优先级配色）
Color priorityColor(String p) => switch (p) {
      'high' => const Color(0xFFef4444),
      'low' => const Color(0xFF22c55e),
      _ => const Color(0xFFf59e0b), // medium
    };

String priorityLabel(String p) => switch (p) {
      'high' => '高',
      'low' => '低',
      _ => '中',
    };

/// 有效状态（兼容旧数据无 status 字段）
String effectiveStatus(TodoItem t) =>
    (t.status != null && t.status!.isNotEmpty)
        ? t.status!
        : (t.completed ? 'completed' : 'not_started');

bool isSubtask(TodoItem t) => t.parentIds.isNotEmpty;

/// 取某任务的直属子任务（按 sortOrder 排序）
List<TodoItem> childrenOf(List<TodoItem> all, String key) =>
    all.where((t) => t.parentIds.contains(key)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

/// 子任务完成进度，无子任务返回 null
({int done, int total})? subtaskProgress(List<TodoItem> all, String key) {
  final children = childrenOf(all, key);
  if (children.isEmpty) return null;
  final done = children.where((c) => effectiveStatus(c) == 'completed').length;
  return (done: done, total: children.length);
}

/// 取某子任务所关联的父任务对象列表（用于点击父任务 chip 打开只读详情）
List<TodoItem> parentItemsOf(List<TodoItem> all, TodoItem child) =>
    child.parentIds
        .map((k) => all.where((t) => t.key == k))
        .expand((x) => x)
        .toList();

/// 把重复配置格式化为可读文案，如「每 2 天」「每周一、三」
String formatRecurrence(String? rule, int interval, List<int> weekdays) {
  if (rule == null || rule.isEmpty) return '';
  if (rule == 'daily') return interval > 1 ? '每 $interval 天' : '每天';
  const labels = ['日', '一', '二', '三', '四', '五', '六'];
  if (weekdays.isNotEmpty) {
    final days = weekdays.map((d) => '周${labels[d % 7]}').join('、');
    return interval > 1 ? '$interval 周（$days）' : days;
  }
  return '每周';
}

/// 待办列表过滤模式（移动端首批沿用；已被视图/筛选体系取代，保留兼容）
enum TodoFilter { active, completed, all }

/// 过滤 todo 列表（旧版简单过滤，保留兼容）
List<TodoItem> applyTodoFilter(List<TodoItem> items, TodoFilter filter) {
  switch (filter) {
    case TodoFilter.active:
      return items.where((t) => !t.completed).toList();
    case TodoFilter.completed:
      return items.where((t) => t.completed).toList();
    case TodoFilter.all:
      return items;
  }
}
