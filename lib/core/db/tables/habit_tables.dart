// 习惯模块数据表定义（habit_def / habit_checkin）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// ⚠️ drift 默认把驼峰 getter 转为下划线列名，而桌面端业务列就是驼峰（createTime/habitKey…），
//    因此所有驼峰列必须显式 named() 锁定桌面原名，否则静默读坏真实库。
// 其他约定：
// 1. 桌面端布尔以 TEXT（'1'/'0'）存储，此处保持 TEXT 保证双端 schema 一致、可按主键幂等 upsert；
//    布尔/JSON 解析放 feature 层模型，不放表定义。
// 2. name/value/created_at 是旧 SQL 层遗留列，桌面库真实存在，原样保留为可空列。
import 'package:drift/drift.dart';

/// 习惯定义表 habit_def（桌面端声明主键是旧层自增 id，业务主键为 key TEXT）
class HabitDef extends Table {
  /// 旧层自增主键（桌面端声明的主键）
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列（读旧库必须保留） ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列（named() 锁定桌面驼峰列名） ----
  /// 业务主键，形如 habit:mtdnjxqr-xc665i
  TextColumn get key => text().nullable()();

    TextColumn get createTime => text().named('createTime').nullable()();

    TextColumn get updateTime => text().named('updateTime').nullable()();

  /// 链式动作 JSON，如 [{"type":"themeConversation"}]
    TextColumn get chainActions => text().named('chainActions').nullable()();

  /// 生效星期 JSON，如 []
    TextColumn get weekDays => text().named('weekDays').nullable()();

  /// 是否启用：'1'/'0'（桌面端布尔即文本）
  TextColumn get enabled => text().nullable()();

  /// 提醒时间 JSON，如 ["08:39"]
    TextColumn get reminderTimes => text().named('reminderTimes').nullable()();

  TextColumn get remark => text().nullable()();

  /// 频率类型，如 daily
    TextColumn get freqType => text().named('freqType').nullable()();
}

/// 习惯打卡记录表 habit_checkin（打卡 key = habitKey#date 天然幂等，利于同步）
class HabitCheckin extends Table {
  /// 旧层自增主键
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  /// 打卡主键，形如 habit:xxx#2026-08-29
  TextColumn get key => text().nullable()();

  /// 所属习惯的 key
    TextColumn get habitKey => text().named('habitKey').nullable()();

  TextColumn get note => text().nullable()();

  /// 打卡日期 yyyy-MM-dd
  TextColumn get date => text().nullable()();

  /// 来源，如 manual
  TextColumn get source => text().nullable()();

  /// 打卡时间 HH:mm:ss
  TextColumn get time => text().nullable()();
}
