// 待办模块数据表定义（todo_list / todo_tags）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// ⚠️ 桌面端驼峰列名必须 named() 锁定（详见 habit_tables.dart 顶部说明）。
// todo_list 的声明主键就是业务主键 key TEXT；recurrence 系列字段支撑父子/重复任务。
import 'package:drift/drift.dart';

/// 待办表 todo_list（key TEXT PRIMARY KEY，与桌面端一致）
class TodoList extends Table {
  /// 业务主键（UUID）
  TextColumn get key => text()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  TextColumn get priority => text().nullable()();

  TextColumn get dueDate => text().named('dueDate').nullable()();

  TextColumn get createTime => text().named('createTime').nullable()();

  TextColumn get completedTime => text().named('completedTime').nullable()();

  /// 标签 JSON 数组（todo_tags.key 列表）
  TextColumn get tags => text().nullable()();

  TextColumn get updateTime => text().named('updateTime').nullable()();

  /// 是否完成：'1'/'0'
  TextColumn get completed => text().nullable()();

  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();

  /// 截止提醒配置
  TextColumn get deadlineReminder =>
      text().named('deadlineReminder').nullable()();

  TextColumn get remindCount => text().named('remindCount').nullable()();

  TextColumn get remindInterval => text().named('remindInterval').nullable()();

  TextColumn get remindIntervalUnit =>
      text().named('remindIntervalUnit').nullable()();

  TextColumn get status => text().nullable()();

  /// 父任务 key（父子任务）
  TextColumn get parentId => text().named('parentId').nullable()();

  // ---- 重复任务系列字段 ----
  TextColumn get recurrenceEnd => text().named('recurrenceEnd').nullable()();

  TextColumn get recurrenceId => text().named('recurrenceId').nullable()();

  TextColumn get recurrenceInterval =>
      text().named('recurrenceInterval').nullable()();

  TextColumn get isRecurrenceInstance =>
      text().named('isRecurrenceInstance').nullable()();

  TextColumn get recurrenceRule => text().named('recurrenceRule').nullable()();

  TextColumn get recurrenceWeekdays =>
      text().named('recurrenceWeekdays').nullable()();

  TextColumn get sortOrder => text().named('sortOrder').nullable()();

  TextColumn get parentIds => text().named('parentIds').nullable()();

  /// 旧层遗留的可空整型列（桌面库存在，样例全为 NULL）
  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 待办标签表 todo_tags（key TEXT + color）
class TodoTags extends Table {
  /// 旧层自增主键
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  /// 标签业务主键（UUID）
  TextColumn get key => text().nullable()();
  TextColumn get color => text().nullable()();
}
