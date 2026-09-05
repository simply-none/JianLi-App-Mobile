// 倒计时功能域 —— 对齐桌面端 countdown 模块（独立于提醒引擎）
//
// 计时基准：存结束时间戳 end_time(ms)，UI 每秒算 end_time - now；
// 暂停冻结 paused_remaining，恢复时重算 end_time —— 与桌面端完全同构，天然抗休眠漂移。
// 数据模型见 references/modules/countdown.md。
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

/// 倒计时仓库
class CountdownRepository {
  CountdownRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 全部倒计时流（创建时间倒序）
  Stream<List<CountdownData>> watchAll() {
    return (_db.select(_db.countdown)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// 新建倒计时（duration 模式：立即开始；datetime 模式：end 为目标时刻）
  Future<void> create({
    required String name,
    required String mode,
    required int endMs,
    required int durationMs,
    bool notify = true,
    String? color,
  }) async {
    await _db.into(_db.countdown).insert(CountdownCompanion.insert(
          key: _uuid.v4(),
          name: Value(name),
          mode: Value(mode),
          endTime: Value(endMs),
          duration: Value(durationMs),
          pausedRemaining: const Value(0),
          status: const Value('running'),
          notify: Value(notify ? '1' : '0'),
          color: Value(color),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 暂停：冻结剩余
  Future<void> pause(CountdownData row) async {
    final remaining = (row.endTime ?? 0) - DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.countdown)..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        pausedRemaining: Value(remaining > 0 ? remaining : 0),
        status: const Value('paused'),
      ),
    );
  }

  /// 恢复：end_time = now + paused_remaining
  Future<void> resume(CountdownData row) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.countdown)..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        endTime: Value(nowMs + (row.pausedRemaining ?? 0)),
        pausedRemaining: const Value(0),
        status: const Value('running'),
      ),
    );
  }

  /// 重置：按原始时长重新开始
  Future<void> reset(CountdownData row) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.countdown)..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        endTime: Value(nowMs + (row.duration ?? 0)),
        pausedRemaining: const Value(0),
        status: const Value('running'),
      ),
    );
  }

  /// 标记完成
  Future<void> finish(CountdownData row) async {
    await (_db.update(_db.countdown)..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        status: const Value('finished'),
        finishedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 删除
  Future<void> delete(String key) =>
      (_db.delete(_db.countdown)..where((t) => t.key.equals(key))).go();
}

/// 倒计时仓库 provider
final Provider<CountdownRepository> countdownRepositoryProvider =
    Provider<CountdownRepository>((ref) {
  return CountdownRepository(ref.watch(appDatabaseProvider));
});

/// 倒计时列表流 provider
final StreamProvider<List<CountdownData>> countdownListProvider =
    StreamProvider<List<CountdownData>>(
  (ref) => ref.watch(countdownRepositoryProvider).watchAll(),
);
