// 文件互传历史仓库 —— 读写 file_transfer 表（设备本地记录，不入同步白名单）
//
// 写入后通过 drift watch 流自动推送到页面历史列表（顶层 StreamProvider 订阅）。
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

/// 文件互传历史仓库
class TransferRepository {
  TransferRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 历史流（新→旧）
  Stream<List<FileTransferData>> watchAll() {
    return (_db.select(
      _db.fileTransfer,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// 历史分页查询（新→旧）；[limit]/[offset] 为空则全量
  Future<List<FileTransferData>> list({int? limit, int? offset}) {
    final q = _db.select(_db.fileTransfer)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) q.limit(limit, offset: offset ?? 0);
    return q.get();
  }

  /// 历史总数
  Future<int> count() async {
    final row = await (_db.selectOnly(_db.fileTransfer)
          ..addColumns([_db.fileTransfer.key.count()]))
        .getSingle();
    return row.read(_db.fileTransfer.key.count()) ?? 0;
  }

  /// 自动清理：超过 [maxRows] 时删除最旧的超额行（#20）
  Future<void> trim(int maxRows) async {
    final cnt = await count();
    if (cnt <= maxRows) return;
    final excess = cnt - maxRows;
    final oldest = await (_db.selectOnly(_db.fileTransfer)
          ..addColumns([_db.fileTransfer.key])
          ..orderBy([OrderingTerm.asc(_db.fileTransfer.createdAt)])
          ..limit(excess))
        .map((row) => row.read(_db.fileTransfer.key))
        .get();
    if (oldest.isEmpty) return;
    await (_db.delete(_db.fileTransfer)
          ..where((t) => t.key.isIn(oldest.whereType<String>().toList())))
        .go();
  }

  /// 写入一条历史（发送/接收各阶段调用）
  Future<void> add({
    required String tid,
    required String fid,
    required String direction,
    required String peerName,
    required String peerIp,
    required String fileName,
    required int size,
    String? mime,
    required String path,
    required String status,
    String? error,
  }) {
    return _db.into(_db.fileTransfer).insert(
          FileTransferCompanion.insert(
            key: _uuid.v4(),
            tid: Value(tid),
            fid: Value(fid),
            direction: Value(direction),
            peerName: Value(peerName),
            peerIp: Value(peerIp),
            fileName: Value(fileName),
            size: Value(size),
            mime: Value(mime),
            path: Value(path),
            status: Value(status),
            error: Value(error),
            createdAt: Value(_now()),
          ),
        );
  }

  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }
}

/// 历史仓库 provider
final Provider<TransferRepository> transferRepositoryProvider =
    Provider<TransferRepository>(
      (ref) => TransferRepository(ref.watch(appDatabaseProvider)),
    );
