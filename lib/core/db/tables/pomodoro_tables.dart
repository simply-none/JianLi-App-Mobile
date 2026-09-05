// 番茄钟模块数据表定义（pomodoro_status / pomodoro_mini_config）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// pomodoro_status 是状态流水（work/rest/lock），7119 行，用于统计与热力图；
// pomodoro_mini_config 存皮肤配置，移动端暂不消费（悬浮小窗不移植），保留以对齐 schema。
import 'package:drift/drift.dart';

/// 番茄钟状态流水表 pomodoro_status
class PomodoroStatus extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 展示标签，如 '正在工作'
  TextColumn get label => text().nullable()();

  /// 状态值：work / rest / lock
  TextColumn get value => text().nullable()();

  /// 场景模式，如 development
  TextColumn get mode => text().nullable()();

  /// 创建时间（桌面端为下划线列名，drift 默认转换即对齐，named() 显式锁定）
  TextColumn get createTime => text().named('create_time').nullable()();

  TextColumn get date => text().nullable()();

  /// 状态变更时刻（桌面端为驼峰列名）
  /// ⚠️ getter 不能叫 dateTime（与 drift Table.dateTime() 构造方法冲突），
  ///    改名 recordedAt 并用 named('dateTime') 锁定桌面列名。
  TextColumn get recordedAt => text().named('dateTime').nullable()();
}

/// 番茄钟小窗皮肤配置表 pomodoro_mini_config（移动端保留结构，暂不消费）
class PomodoroMiniConfig extends Table {
  TextColumn get key => text()();
  TextColumn get skin => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
