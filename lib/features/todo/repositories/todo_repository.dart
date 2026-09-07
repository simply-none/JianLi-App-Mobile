// 待办仓库 —— 列表流 + 新增/编辑 + 完成切换 + 级联删除 + 标签 + 重复实例生成 + 截止提醒调度
//
// 与桌面端字段约定一致：
// - key 为 UUID；completed='1'/'0'；createTime/updateTime 格式 yyyy-MM-dd HH:mm:ss；
// - 父子/重复字段与 PC 同列；upsert 走 INSERT OR REPLACE（按 key 主键，对齐同步幂等写）。
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/todo.dart';

/// 待办标签调色板（对齐 PC TagSelectPopover）
const List<String> kTodoTagPalette = [
  '#6366f1', '#8b5cf6', '#ec4899', '#f43f5e', '#f97316',
  '#eab308', '#22c55e', '#14b8a6', '#06b6d4', '#3b82f6',
];

/// 待办仓库
class TodoRepository {
  TodoRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 全部待办流（updateTime 倒序）
  Stream<List<TodoItem>> watchTodos() {
    return (_db.select(_db.todoList)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]))
        .watch()
        .map((rows) => rows.map(TodoItem.fromRow).toList());
  }

  /// 标签流（供展示映射）
  Stream<List<TodoTagView>> watchTags() {
    return _db
        .select(_db.todoTags)
        .watch()
        .map((rows) => rows.map(TodoTagView.fromRow).toList());
  }

  /// 新增待办（title 必填，其余走默认值）；返回新建 key
  Future<String> addTodo({required String title, String? description}) async {
    final key = _uuid.v4();
    final now = _now();
    await _db.into(_db.todoList).insert(
          TodoListCompanion.insert(
            // key 是非空必填列，insert() 构造器这里要传原始值（不能包 Value）
            key: key,
            title: Value(title),
            description: Value(description),
            completed: const Value('0'),
            priority: const Value('medium'),
            createTime: Value(now),
            updateTime: Value(now),
          ),
        );
    return key;
  }

  /// 切换完成状态（仅改 completed / completedTime / updateTime，不碰其它字段）
  Future<void> toggleComplete(String key, bool completed) async {
    final now = _now();
    await (_db.update(_db.todoList)..where((tbl) => tbl.key.equals(key))).write(
      TodoListCompanion(
        completed: Value(completed ? '1' : '0'),
        completedTime: Value(completed ? now : null),
        updateTime: Value(now),
      ),
    );
  }

  /// 全字段 upsert（新增/编辑通用）。按 key 主键 INSERT OR REPLACE，对齐 PC new-sql:upsert。
  /// 会按需生成重复实例、调度截止提醒。
  Future<void> upsertTodo(TodoItem item) async {
    await _db.into(_db.todoList).insert(
          TodoListCompanion(
            key: Value(item.key),
            name: const Value(null),
            value: const Value(null),
            createdAt: const Value(null),
            priority: Value(item.priority),
            dueDate: Value(item.dueDate),
            createTime: Value(item.createTime),
            completedTime: Value(item.completedTime),
            tags: Value(jsonEncode(item.tags)),
            updateTime: Value(item.updateTime),
            completed: Value(item.completed ? '1' : '0'),
            title: Value(item.title),
            description: Value(item.description),
            deadlineReminder: Value(item.deadlineReminder.toString()),
            remindCount: Value(item.remindCount.toString()),
            remindInterval: Value(item.remindInterval.toString()),
            remindIntervalUnit: Value(item.remindIntervalUnit),
            status: Value(item.status),
            parentId: Value(item.parentIds.isNotEmpty ? item.parentIds.first : null),
            recurrenceEnd: Value(item.recurrenceEnd),
            recurrenceId: Value(item.recurrenceId),
            recurrenceInterval: Value(item.recurrenceInterval.toString()),
            isRecurrenceInstance: Value(item.isRecurrenceInstance.toString()),
            recurrenceRule: Value(item.recurrenceRule),
            recurrenceWeekdays: Value(
              item.recurrenceWeekdays.isNotEmpty
                  ? jsonEncode(item.recurrenceWeekdays)
                  : null,
            ),
            sortOrder: Value(item.sortOrder.toString()),
            parentIds: Value(
              item.parentIds.isNotEmpty ? jsonEncode(item.parentIds) : null,
            ),
          ),
          mode: InsertMode.replace,
        );

    // 重复模板：补生成下一个周期实例（对齐 PC recurrence:sync）
    if (item.isTemplate) {
      try {
        await _ensureNextRecurrenceInstance(item);
      } catch (_) {
        /* 生成失败不阻塞保存 */
      }
    }
    // 截止提醒：开启且填了到期时间则调度；否则取消既有提醒（对齐 PC update-todo-reminders）
    try {
      if (item.deadlineReminder == 1 && item.dueDate != null) {
        await scheduleDeadlineReminder(item);
      } else {
        await cancelDeadlineReminder(item.key);
      }
    } catch (_) {
      /* 通知调度失败不阻塞保存 */
    }
  }

  /// 新增标签（同名去重，取调色板顺序色），返回新建标签
  Future<TodoTagView> addTag(String name) async {
    final trimmed = name.trim();
    final existing = await (_db.select(_db.todoTags)
          ..where((t) => t.name.equals(trimmed)))
        .get();
    if (existing.isNotEmpty) {
      return TodoTagView.fromRow(existing.first);
    }
    final key = _uuid.v4();
    final all = await _db.select(_db.todoTags).get();
    final color = kTodoTagPalette[all.length % kTodoTagPalette.length];
    // ⚠️ drift 生成名：表名 TodoTags → 数据类 TodoTag（单数）、Companion 是 TodoTagsCompanion（复数）
    await _db.into(_db.todoTags).insert(
          TodoTagsCompanion.insert(
            key: Value(key),
            name: Value(trimmed),
            color: Value(color),
          ),
        );
    return TodoTagView(key: key, name: trimmed, color: color);
  }

  /// 删除待办（含其直接子任务，对齐 PC 级联删除）
  Future<void> deleteTodo(String key) async {
    await (_db.delete(_db.todoList)
          ..where(
            (tbl) =>
                tbl.key.equals(key) |
                tbl.parentId.equals(key) |
                tbl.parentIds.like('%$key%'),
          ))
        .go();
  }

  /// 批量删除（按 key 列表，含各自子任务）
  Future<void> deleteTodos(Iterable<String> keys) async {
    for (final k in keys) {
      await deleteTodo(k);
    }
  }

  // ===== 重复实例生成（对齐 PC recurrence 引擎，移动端单实例保底） =====
  /// 为模板生成「下一个」周期实例（bounded，最多迭代 366 次避免死循环）。
  Future<void> _ensureNextRecurrenceInstance(TodoItem template) async {
    if (template.dueDate == null || template.dueDate!.isEmpty) return;
    final base = _parseDateTime(template.dueDate!);
    if (base == null) return;
    final next = _nextOccurrence(
      base: base,
      rule: template.recurrenceRule!,
      interval: template.recurrenceInterval,
      weekdays: template.recurrenceWeekdays,
    );
    if (next == null) return;
    // 重复结束日期限制
    if (template.recurrenceEnd != null && template.recurrenceEnd!.isNotEmpty) {
      final end = _parseDateTime(template.recurrenceEnd!);
      if (end != null && next.isAfter(end)) return;
    }
    // 若已存在同一 dueDate 的实例则跳过
    final existing = await (_db.select(_db.todoList)
          ..where((t) =>
              t.recurrenceId.equals(template.key) &
              t.dueDate.equals(_formatDateTime(next))))
        .get();
    if (existing.isNotEmpty) return;

    final key = _uuid.v4();
    final now = _now();
    await _db.into(_db.todoList).insert(
          TodoListCompanion.insert(
            key: key,
            title: Value(template.title),
            description: Value(template.description),
            completed: const Value('0'),
            priority: Value(template.priority),
            dueDate: Value(_formatDateTime(next)),
            createTime: Value(now),
            updateTime: Value(now),
            tags: Value(jsonEncode(template.tags)),
            status: const Value('not_started'),
            recurrenceId: Value(template.key),
            recurrenceRule: const Value(null),
            isRecurrenceInstance: const Value('1'),
            sortOrder: Value(template.sortOrder.toString()),
            parentIds: const Value(null),
          ),
        );
  }

  DateTime? _nextOccurrence({
    required DateTime base,
    required String rule,
    required int interval,
    required List<int> weekdays,
  }) {
    final step = max(interval, 1);
    if (rule == 'daily') {
      var d = base;
      for (var i = 0; i < 366; i++) {
        d = d.add(Duration(days: step));
        if (d.isAfter(DateTime.now())) return d;
      }
      return null;
    }
    // weekly
    final days = weekdays.isNotEmpty
        ? weekdays.toSet()
        : {base.weekday % 7}; // 0-6，周日=0
    var d = base;
    for (var i = 0; i < 366; i++) {
      d = d.add(Duration(days: 7 * step));
      if (days.contains(d.weekday % 7) && d.isAfter(DateTime.now())) return d;
    }
    return null;
  }

  // ===== 截止提醒 → 本地通知（对齐 PC update-todo-reminders） =====
  /// 调度单条截止提醒（到点一次性通知；周期为「提前 remindCount×unit」多次由 PC 引擎负责，
  /// 移动端保底在截止时刻提醒一次）。
  Future<void> scheduleDeadlineReminder(TodoItem item) async {
    final due = _parseDateTime(item.dueDate!);
    if (due == null || due.isBefore(DateTime.now())) return;
    await NotificationService.scheduleOnce(
      id: item.key.hashCode & 0x7fffffff,
      channelKey: NotificationChannels.todo,
      title: '待办即将到期：${item.title}',
      body: '截止时间 ${item.dueDate}',
      dateTime: due,
    );
  }

  /// 取消某待办的截止提醒
  Future<void> cancelDeadlineReminder(String key) async {
    await NotificationService.cancel(key.hashCode & 0x7fffffff);
  }

  // ===== 工具 =====
  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDateTime(String s) {
    try {
      return DateTime.parse(s.replaceAll('/', '-'));
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
