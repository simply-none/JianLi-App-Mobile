// 首页聚合 providers —— 一次拉取跨模块统计（ habits / todos / pomodoro / reminders / countdown ）
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../habit/models/habit.dart';
import '../../todo/models/todo.dart';

/// 首页聚合数据
class DashboardStats {
  const DashboardStats({
    required this.habitsTotal,
    required this.habitsDoneToday,
    required this.todosActive,
    required this.pomodoroToday,
    required this.remindersEnabled,
    required this.nextCountdownName,
    required this.nextCountdownEndMs,
  });

  final int habitsTotal;
  final int habitsDoneToday;
  final int todosActive;
  final int pomodoroToday;
  final int remindersEnabled;
  final String? nextCountdownName;
  final int? nextCountdownEndMs;

  String get habitProgressLabel =>
      habitsTotal == 0 ? '0/0' : '$habitsDoneToday/$habitsTotal';
}

/// 聚合统计（一次性查询；页面下拉刷新重取）
final FutureProvider<DashboardStats>
dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final todayPrefix =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  // 习惯
  final habits = await db.select(db.habitDef).get();
  final habitItems = habits
      .map(HabitItem.fromRow)
      .where((h) => h.enabled && h.key.isNotEmpty);
  final checkins = await (db.select(
    db.habitCheckin,
  )..where((t) => t.date.equals(todayPrefix))).get();
  final doneKeys = checkins.map((c) => c.habitKey ?? '').toSet();

  // 待办
  final todos = await db.select(db.todoList).get();
  final activeTodos = todos
      .map(TodoItem.fromRow)
      .where((t) => !t.completed)
      .length;

  // 番茄钟今日记录
  final pomodoroToday =
      await (db.selectOnly(db.pomodoroStatus)
            ..addColumns([db.pomodoroStatus.id.count()])
            ..where(
              db.pomodoroStatus.value.equals('work') &
                  db.pomodoroStatus.createTime.like('$todayPrefix%'),
            ))
          .getSingle()
          .then((r) => r.read(db.pomodoroStatus.id.count()) ?? 0);

  // 启用的提醒
  final enabledReminders =
      await (db.selectOnly(db.reminders)
            ..addColumns([db.reminders.id.count()])
            ..where(db.reminders.enabled.equals('1')))
          .getSingle()
          .then((r) => r.read(db.reminders.id.count()) ?? 0);

  // 最近倒计时（running 且 end_time 最近）
  final runningCountdowns =
      await (db.select(db.countdown)
            ..where(
              (t) =>
                  t.status.equals('running') &
                  t.endTime.isBiggerThanValue(now.millisecondsSinceEpoch),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.endTime)])
            ..limit(1))
          .get();
  final nextCountdown = runningCountdowns.isEmpty
      ? null
      : runningCountdowns.first;

  return DashboardStats(
    habitsTotal: habitItems.length,
    habitsDoneToday: habitItems.where((h) => doneKeys.contains(h.key)).length,
    todosActive: activeTodos,
    pomodoroToday: pomodoroToday,
    remindersEnabled: enabledReminders,
    nextCountdownName: nextCountdown?.name,
    nextCountdownEndMs: nextCountdown?.endTime,
  );
});
