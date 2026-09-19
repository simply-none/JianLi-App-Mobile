// P1-6 小纸条 —— 数据访问（drift）
//
// 只做本机收发记录的读写与清理；**不进同步白名单**（与 file_transfer 同性质：
// 收发记录是本机行为，同步会把两端记录互相灌进对方收件箱）。
//
// ⚠️ drift 的 `customStatement` 不会通知 watch 流，但本仓库全部走 drift 的
// `into/select/update/delete`（非原始 SQL），watch 流会自动刷新，无需手动 notifyUpdates。
import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../models/note_slip.dart';

/// 小纸条仓库
class NoteSlipRepository {
  NoteSlipRepository(this._db);

  final AppDatabase _db;

  /// 全量流（按时间倒序；页面再按方向 Tab 过滤）
  Stream<List<NoteSlipData>> watchAll() => (_db.select(_db.noteSlip)
        ..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.key),
        ]))
      .watch();

  /// 未读数（收到的且未读）
  Stream<int> watchUnread() {
    final q = _db.select(_db.noteSlip)
      ..where(
        (t) => t.direction.equals(kSlipDirectionIn) & t.read.equals(0),
      );
    return q.watch().map((rows) => rows.length);
  }

  /// 按主键取一条（通知点击直达详情用）
  Future<NoteSlipData?> getByKey(String key) =>
      (_db.select(_db.noteSlip)..where((t) => t.key.equals(key)))
          .getSingleOrNull();

  /// 收到一条：按主键幂等写入。
  ///
  /// 返回 `true` = 新纸条（需要弹通知）；`false` = 重复推送（已存在，静默）。
  Future<bool> upsertIncoming({
    required String key,
    required String content,
    required String peerName,
    required String peerIp,
    int? createdAt,
  }) async {
    final existing = await getByKey(key);
    if (existing != null) return false;
    await _db
        .into(_db.noteSlip)
        .insert(
          NoteSlipCompanion.insert(
            key: key,
            direction: const Value(kSlipDirectionIn),
            kind: Value(slipKindOf(content)),
            title: Value(slipTitleOf(content)),
            content: Value(content),
            peerName: Value(peerName),
            peerIp: Value(peerIp),
            createdAt: Value(createdAt ?? DateTime.now().millisecondsSinceEpoch),
          ),
        );
    await trim();
    return true;
  }

  /// 发出一条（写 out 记录）
  Future<void> insertOutgoing({
    required String key,
    required String content,
    required String peerName,
    required String peerIp,
    int? createdAt,
  }) async {
    await _db
        .into(_db.noteSlip)
        .insert(
          NoteSlipCompanion.insert(
            key: key,
            direction: const Value(kSlipDirectionOut),
            kind: Value(slipKindOf(content)),
            title: Value(slipTitleOf(content)),
            content: Value(content),
            peerName: Value(peerName),
            peerIp: Value(peerIp),
            createdAt: Value(createdAt ?? DateTime.now().millisecondsSinceEpoch),
          ),
        );
    await trim();
  }

  /// 标记已读
  Future<void> markRead(String key) => (_db.update(_db.noteSlip)
        ..where((t) => t.key.equals(key)))
      .write(const NoteSlipCompanion(read: Value(1)));

  /// 全部已读（只处理收到的）
  Future<void> markAllRead() => (_db.update(_db.noteSlip)
        ..where((t) => t.direction.equals(kSlipDirectionIn)))
      .write(const NoteSlipCompanion(read: Value(1)));

  /// 删除一条
  Future<void> deleteByKey(String key) =>
      (_db.delete(_db.noteSlip)..where((t) => t.key.equals(key))).go();

  /// 清空全部
  Future<void> clearAll() => _db.delete(_db.noteSlip).go();

  /// 保留最近 [kSlipKeepRows] 条，删最旧的（写入后调用，防无限增长）
  Future<void> trim() async {
    final rows = await (_db.select(_db.noteSlip)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (rows.length <= kSlipKeepRows) return;
    for (final row in rows.skip(kSlipKeepRows)) {
      await deleteByKey(row.key);
    }
  }
}
