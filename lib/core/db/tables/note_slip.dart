// 小纸条表 note_slip —— P1-6 双端文字/链接速传的收发记录
//
// 双端同构（桌面端 noteSlip.ts 用 ensureTableExists 建同名同列表），**不入同步白名单**：
// 收发记录是本机行为（与 file_transfer 同性质），同步会把两端的记录互相灌进对方收件箱。
//
// drift 三大铁律：
//   1. 驼峰 getter 一律 `.named('桌面原名')` 锁定列名（peer_name / peer_ip / created_at）；
//   2. getter 不能叫 `text` / `dateTime`（与 drift 的 Table 构造方法冲突）；
//   3. 行类名会被单数化 → `NoteSlipData`（本表名本身已单数，仅加 Data 后缀）。
import 'package:drift/drift.dart';

/// 小纸条表 note_slip（key TEXT 主键）
class NoteSlip extends Table {
  /// uuid（由发送端生成，收端按主键 upsert → 重复推送不重复入库/不重复弹通知）
  TextColumn get key => text()();

  /// 方向：in（收到的）/ out（发出的）
  TextColumn get direction => text().nullable()();

  /// 内容类型：text / url
  TextColumn get kind => text().nullable()();

  /// 首行摘要（列表与通知标题用）
  TextColumn get title => text().nullable()();

  /// 正文
  TextColumn get content => text().nullable()();

  /// 对端昵称（广播名，带「的PC」/「的App」后缀）
  TextColumn get peerName => text().named('peer_name').nullable()();

  /// 对端 IP
  TextColumn get peerIp => text().named('peer_ip').nullable()();

  /// 已读标记：0 未读 / 1 已读（仅 direction='in' 有意义）
  IntColumn get read => integer().withDefault(const Constant(0))();

  /// 毫秒时间戳（排序用，与 countdown 同款）
  IntColumn get createdAt => integer().named('created_at').nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
