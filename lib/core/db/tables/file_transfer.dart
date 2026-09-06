// 文件互传历史表 file_transfer（key TEXT 主键，设备本地记录，不入同步白名单）
//
// 与桌面端 electron/main/module/transfer/transferModule.ts 的 ensureTableExists 逐列对齐：
// 双端同构，便于后续统一展示 / 排障（不跨设备同步）。
// 列名一律 .named('snake_name') 锁定（drift 三大铁律之一）。
import 'package:drift/drift.dart';

/// 文件互传历史表（每文件一条）
class FileTransfer extends Table {
  /// 每文件一条 uuid
  TextColumn get key => text()();

  /// 批次号（一次 offer 一批）
  TextColumn get tid => text().named('tid').nullable()();

  /// 批次内序号（"1"、"2"…）
  TextColumn get fid => text().named('fid').nullable()();

  /// 方向：'send' | 'receive'
  TextColumn get direction => text().named('direction').nullable()();

  /// 对端设备名
  TextColumn get peerName => text().named('peer_name').nullable()();

  /// 对端 IP
  TextColumn get peerIp => text().named('peer_ip').nullable()();

  /// 文件名
  TextColumn get fileName => text().named('file_name').nullable()();

  /// 大小（字节，INTEGER）
  IntColumn get size => integer().named('size').nullable()();

  /// MIME（可空）
  TextColumn get mime => text().nullable()();

  /// 本机落盘路径（发送成功时为源路径）
  TextColumn get path => text().nullable()();

  /// 状态：'done' | 'failed' | 'canceled'
  TextColumn get status => text().named('status').nullable()();

  /// 失败原因（size mismatch / hash mismatch / peer rejected 等），成功或取消时为空
  TextColumn get error => text().named('error').nullable()();

  /// 创建时间（ISO 文本）
  TextColumn get createdAt => text().named('created_at').nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
