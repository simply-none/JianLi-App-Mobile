// 倒计时 + 二维码历史/模板数据表定义
//
// 与桌面端逐列对齐（来源：references/modules/countdown.md、qrcode.ts ensureTableExists）。
// countdown 计时基准是「结束时间戳 end_time(ms)」，暂停冻结 paused_remaining，
// 基于时间戳天然抗休眠/跨午夜（桌面端同款设计，见 countdown.md）。
// qr_history/qr_template 列来自 electron/main/module/qrcode.ts 的 ensureTableExists。
import 'package:drift/drift.dart';

/// 倒计时表 countdown（key TEXT 主键）
class Countdown extends Table {
  TextColumn get key => text()();

  /// 名称
  TextColumn get name => text().nullable()();

  /// datetime（指定时刻）/ duration（指定时长）
  TextColumn get mode => text().nullable()();

  /// 目标结束时间戳(ms) —— 计时基准
  IntColumn get endTime => integer().named('end_time').nullable()();

  /// 原始时长(ms)，用于「重置」
  IntColumn get duration => integer().nullable()();

  /// 暂停时冻结的剩余(ms)
  IntColumn get pausedRemaining =>
      integer().named('paused_remaining').nullable()();

  /// running / paused / finished
  TextColumn get status => text().nullable()();

  /// 是否完成通知：0/1
  TextColumn get notify => text().nullable()();

  /// 提示音（桌面端预留字段）
  TextColumn get sound => text().nullable()();

  /// 卡片/进度环颜色
  TextColumn get color => text().nullable()();

  IntColumn get createdAt => integer().named('created_at').nullable()();

  IntColumn get finishedAt => integer().named('finished_at').nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 二维码历史表 qr_history（key TEXT 主键，source 区分来源模块）
class QrHistory extends Table {
  TextColumn get key => text()();

  /// 来源标识：'qrCode' 页面 | 其它业务模块名
  TextColumn get source => text().nullable()();

  /// 内容类型：text/url/wifi/contact/email/...
  TextColumn get type => text().nullable()();

  /// 二维码原始文本
  TextColumn get content => text().nullable()();

  /// 样式 JSON（QrStyleOptions 序列化）
  TextColumn get style => text().nullable()();
  TextColumn get note => text().nullable()();

  TextColumn get createdAt => text().named('created_at').nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 二维码模板表 qr_template（key TEXT 主键）
class QrTemplate extends Table {
  TextColumn get key => text()();
  TextColumn get name => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get style => text().nullable()();

  TextColumn get createdAt => text().named('created_at').nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
