// 倒计时功能域 —— 对齐桌面端 countdown 模块（独立于提醒引擎）
//
// 计时基准：存结束时间戳 end_time(ms)，UI 每秒算 end_time - now；
// 暂停冻结 paused_remaining，恢复时重算 end_time —— 与桌面端完全同构，天然抗休眠漂移。
// 到点通知（2026-09-12 补齐，对齐 PC「主进程到点 → 系统通知」链路）：
//   create/resume/reset 排一次性系统通知（end_time 时刻，精确闹钟可用才 precise），
//   pause/delete/finish 取消 —— 计划存原生 AlarmManager，App 被杀也能到点触发；
//   sweepExpired 在启动/进页时把「running 且已到点」的行补写 finished（App 被杀期间
//   错过通知的兜底，与 PC 启动时重排/落账同思路）。
// 数据模型见 references/modules/countdown.md。
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';

/// 倒计时仓库
class CountdownRepository {
  CountdownRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 全部倒计时流（创建时间倒序）
  Stream<List<CountdownData>> watchAll() {
    return (_db.select(
      _db.countdown,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// 到点通知的稳定 int id（FNV-1a，跨重启一致，见 NotificationService.stableId）
  static int _notifyId(String key) =>
      NotificationService.stableId('countdown:$key');

  /// 排「到点系统通知」：end_time 在未来才排；精确闹钟可用时走 precise（到点不延迟）。
  Future<void> _armNotification({
    required String key,
    required String? name,
    required int? endMs,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (endMs == null || endMs <= nowMs) return;
    final precise = await NotificationService.exactAlarmAllowed;
    await NotificationService.scheduleOnce(
      id: _notifyId(key),
      channelKey: NotificationChannels.countdown,
      title: '⏳ 倒计时结束',
      body: '「${name ?? '倒计时'}」时间到',
      dateTime: DateTime.fromMillisecondsSinceEpoch(endMs),
      precise: precise,
    );
  }

  /// 取消一条倒计时的到点通知
  static Future<void> _cancelNotification(String key) =>
      NotificationService.cancel(_notifyId(key));

  /// 新建倒计时（duration 模式：立即开始；datetime 模式：end 为目标时刻）
  Future<void> create({
    required String name,
    required String mode,
    required int endMs,
    required int durationMs,
    bool notify = true,
    String? color,
  }) async {
    final key = _uuid.v4();
    await _db
        .into(_db.countdown)
        .insert(
          CountdownCompanion.insert(
            key: key,
            name: Value(name),
            mode: Value(mode),
            endTime: Value(endMs),
            duration: Value(durationMs),
            pausedRemaining: const Value(0),
            status: const Value('running'),
            notify: Value(notify ? '1' : '0'),
            color: Value(color),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    await _armNotification(key: key, name: name, endMs: endMs);
  }

  /// 暂停：冻结剩余（取消到点通知，恢复时重排）
  Future<void> pause(CountdownData row) async {
    final remaining =
        (row.endTime ?? 0) - DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.countdown,
    )..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        pausedRemaining: Value(remaining > 0 ? remaining : 0),
        status: const Value('paused'),
      ),
    );
    await _cancelNotification(row.key);
  }

  /// 恢复：end_time = now + paused_remaining（重排到点通知）
  Future<void> resume(CountdownData row) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final newEnd = nowMs + (row.pausedRemaining ?? 0);
    await (_db.update(
      _db.countdown,
    )..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        endTime: Value(newEnd),
        pausedRemaining: const Value(0),
        status: const Value('running'),
      ),
    );
    await _cancelNotification(row.key);
    await _armNotification(key: row.key, name: row.name, endMs: newEnd);
  }

  /// 重置：按原始时长重新开始（重排到点通知）
  Future<void> reset(CountdownData row) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final newEnd = nowMs + (row.duration ?? 0);
    await (_db.update(
      _db.countdown,
    )..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        endTime: Value(newEnd),
        pausedRemaining: const Value(0),
        status: const Value('running'),
      ),
    );
    await _cancelNotification(row.key);
    await _armNotification(key: row.key, name: row.name, endMs: newEnd);
  }

  /// 编辑倒计时（长按 → 编辑，对齐 PC CountdownDialog 语义）：
  /// 名称随时可改；**时间设定（mode + 时刻/时长）没变时保留原 end_time 与状态**，
  /// 变了则重算 end/时长并回到 running（finishedAt 清空，pausedRemaining 归零）。
  /// 到点通知始终重排（名称变了通知正文也要更新；end 在过去时 _armNotification 内部跳过）。
  Future<void> updateTiming({
    required CountdownData row,
    required String name,
    required String mode,
    required int endMs,
    required int durationMs,
  }) async {
    final timingChanged =
        mode != (row.mode ?? '') ||
        (mode == 'datetime'
            ? endMs != (row.endTime ?? 0)
            : durationMs != (row.duration ?? 0));
    if (timingChanged) {
      await (_db.update(
        _db.countdown,
      )..where((t) => t.key.equals(row.key))).write(
        CountdownCompanion(
          name: Value(name),
          mode: Value(mode),
          endTime: Value(endMs),
          duration: Value(durationMs),
          pausedRemaining: const Value(0),
          status: const Value('running'),
          finishedAt: const Value(null),
        ),
      );
    } else {
      await (_db.update(_db.countdown)..where((t) => t.key.equals(row.key)))
          .write(CountdownCompanion(name: Value(name)));
    }
    await _cancelNotification(row.key);
    await _armNotification(
      key: row.key,
      name: name,
      endMs: timingChanged ? endMs : row.endTime,
    );
  }

  /// 标记完成（同时取消到点通知——通知本体已触发/已不需要）
  Future<void> finish(CountdownData row) async {
    await (_db.update(
      _db.countdown,
    )..where((t) => t.key.equals(row.key))).write(
      CountdownCompanion(
        status: const Value('finished'),
        finishedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await _cancelNotification(row.key);
  }

  /// 删除（先取消到点通知再删行）
  Future<void> delete(String key) async {
    await _cancelNotification(key);
    await (_db.delete(_db.countdown)..where((t) => t.key.equals(key))).go();
  }

  /// 清扫已到点却仍标 running 的行 → 补写 finished（返回补写条数）。
  ///
  /// App 启动（AlarmBootstrap）与进页时调用：App 被杀/后台期间到点的行，
  /// 原生通知已弹过，但库里还是 running —— 在这里补账，与 PC「到点写库」对齐。
  Future<int> sweepExpired() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expired =
        await (_db.select(_db.countdown)..where(
              (t) =>
                  t.status.equals('running') &
                  t.endTime.isNotNull() &
                  t.endTime.isSmallerOrEqualValue(nowMs),
            ))
            .get();
    for (final row in expired) {
      await finish(row);
    }
    return expired.length;
  }
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
