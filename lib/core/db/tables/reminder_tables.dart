// 统一提醒引擎数据表定义（reminders）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// ⚠️ 桌面端驼峰列名必须 named() 锁定（详见 habit_tables.dart 顶部说明）。
// 桌面端习惯/待办/番茄钟到点提醒全部来自本表（id TEXT PRIMARY KEY）；
// 移动端对应实现为本地通知（awesome_notifications），番茄钟等状态型提醒由 App 前台驱动。
import 'package:drift/drift.dart';

/// 提醒表 reminders（id TEXT PRIMARY KEY，如 'pomodoro'）
class Reminders extends Table {
  /// 业务主键（如 pomodoro / habit:xxx / todo:xxx）
  TextColumn get id => text()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  /// 提醒模式，如 stateful（状态机型）/ 定时型
  TextColumn get mode => text().nullable()();

  /// 状态机起始时间戳（ms）
  TextColumn get startTime => text().named('startTime').nullable()();

  /// 状态机定义 JSON，如 [{"key":"work","label":"工作","duration":23,...}]
  TextColumn get states => text().nullable()();

  /// 生效星期 JSON
  TextColumn get weekDays => text().named('weekDays').nullable()();

  /// 是否循环：'1'/'0'
  TextColumn get loop => text().nullable()();

  TextColumn get recordAfter => text().named('recordAfter').nullable()();

  TextColumn get interval => text().nullable()();
  TextColumn get month => text().nullable()();
  TextColumn get minute => text().nullable()();

  TextColumn get dayOfMonth => text().named('dayOfMonth').nullable()();

  TextColumn get unit => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text().nullable()();

  /// 是否启用：'1'/'0'
  TextColumn get enabled => text().nullable()();

  /// 免打扰时段 JSON，如 [{"start":"10:15","end":"10:57"}]
  TextColumn get idleTime => text().named('idleTime').nullable()();

  TextColumn get time => text().nullable()();
  TextColumn get repeat => text().nullable()();
  TextColumn get date => text().nullable()();

  /// 提醒来源（桌面端待办截止提醒引擎写入 'todo'；用户手建为空）
  TextColumn get source => text().nullable()();

  /// 送达方式：'notification'（系统通知，默认）/ 'alarm'（闹钟：精确+全屏意图+高重要渠道）
  /// 对齐 PC newTips 的「提醒方式」概念，移动端作为用户可选维度。
  TextColumn get delivery => text().named('delivery').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
