// 番茄钟仓库 —— 读取 reminders(stateful) 配置 + 写状态流水
//
// reminders.id='pomodoro' 行是番茄钟的唯一配置源（与桌面端一致）；
// pomodoro_status 每次状态变更写一行流水，供统计（桌面端 7119 行热力图数据同源）。
import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../models/pomodoro_state_machine.dart';

/// 番茄钟仓库
class PomodoroRepository {
  PomodoroRepository(this._db);

  final AppDatabase _db;

  /// 读取番茄钟状态机配置（不存在/未启用返回 null）
  Future<PomodoroSnapshot?> loadSnapshot() async {
    final row = await (_db.select(_db.reminders)..where((tbl) => tbl.id.equals('pomodoro')))
        .getSingleOrNull();
    if (row == null || row.enabled != '1') return null;
    final states = parsePomodoroStates(row.states);
    final startMs = int.tryParse(row.startTime ?? '') ?? 0;
    return computePomodoroSnapshot(states, startMs, DateTime.now());
  }

  /// 记录一条状态流水（label/value/mode 与桌面端约定一致）
  Future<void> recordStatus({
    required String label,
    required String value,
    required String mode,
  }) async {
    final now = DateTime.now();
    final nowStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await _db.into(_db.pomodoroStatus).insert(PomodoroStatusCompanion.insert(
          label: Value(label),
          value: Value(value),
          mode: Value(mode),
          createTime: Value(nowStr),
        ));
  }
}
