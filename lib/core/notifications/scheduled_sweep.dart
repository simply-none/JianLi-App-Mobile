// 全局 awesome 在排通知对账（孤儿清扫）—— 2026-09-19
//
// 背景：用户报「弹出已删除内容的提醒」。根因之一是 **stableId 改造（2026-09-16）前
// 用 `String.hashCode` 排期的 awesome 周期通知**：hashCode 每次重启都漂移、且无法从
// 库里现存数据反推，导致 ① 已删除提醒的旧计划永远没人取消（repeats:true 永续）；
// ② 现存提醒也可能新旧双计划并行（双响）。habit / todo 仓库当时都补了
// 「rescheduleAll 里显式取消旧 hashCode 残留」的迁移，唯独 reminder 模块漏了。
//
// 硬编码逐个补迁移永远追不完（贪睡 id、extraRings、未来新模块……），改为**反向对账**：
// 枚举 awesome 全部在排计划，凡 id 不落在「现存数据可推出的合法 id 段」内的一律取消。
// 合法段（保守放宽，宁可少杀不可误杀——误杀 = 某模块提醒不响 = 回归）：
//   - 每个合法 key 的 base = NotificationService.stableId(key)
//   - base .. base+7            （每周变体 0..6 + 主 id；所有模块共用该约定）
//   - base+50000 .. base+50999  （awesome「稍后提醒」贪睡段，id = base+50000+毫秒随机）
//
// 合法 key 全集（谁在排 awesome 通知就收集谁，按表驱动，勿硬编码清单）：
//   - reminders 表全量行 id（含 source='habit'/'todo' 的引擎托管行——习惯/待办提醒
//     排期用的就是这些行 id，见 habit_repository.rescheduleAll）
//   - todos 表全量 key（待办截止提醒 stableId(key)）
//   - countdowns 表 'countdown:<key>'（倒计时一次性通知）
//   - 固定串 'pomodoro:end' / 'pomodoro:now'（番茄钟原生兜底通知）
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'notification_service.dart';

class ScheduledSweep {
  ScheduledSweep._();

  /// 对账并取消孤儿在排通知。任何异常静默吞掉（清扫是增强能力，绝不影响主流程）。
  static Future<void> sweepOrphans(AppDatabase db) async {
    try {
      final bases = <int>{};
      void add(String key) => bases.add(NotificationService.stableId(key));

      // 1) reminders 全量行（不过滤 source：习惯/待办托管提醒的排期 id 就是这些行 id）
      final reminders = await (db.select(db.reminders)
            ..where((t) => t.source.isNull() | t.source.equals('')))
          .get();
      for (final r in reminders) {
        add(r.id);
      }
      // 1b) 引擎托管行（source='habit'/'todo'）：id 同样是合法排期键
      final managed = await (db.select(db.reminders)
            ..where((t) => t.source.equals('habit') | t.source.equals('todo')))
          .get();
      for (final r in managed) {
        add(r.id);
      }
      // 2) 待办截止提醒
      final todos = await db.select(db.todoList).get();
      for (final t in todos) {
        add(t.key);
      }
      // 3) 倒计时一次性通知
      final countdowns = await db.select(db.countdown).get();
      for (final c in countdowns) {
        add('countdown:${c.key}');
      }
      // 4) 固定串
      add('pomodoro:end');
      add('pomodoro:now');

      // 逐条检查在排计划：不在任何合法段 → 孤儿，取消
      final scheduled = await AwesomeNotifications().listScheduledNotifications();
      for (final n in scheduled) {
        final id = n.content?.id;
        if (id == null) continue;
        final ok = bases.any((b) =>
            (id >= b && id <= b + 7) ||
            (id >= b + 50000 && id <= b + 50999));
        if (!ok) {
          try {
            await AwesomeNotifications().cancel(id);
          } catch (_) {}
        }
      }
    } catch (_) {
      // 清扫失败不影响主流程（旧计划顶多再弹，等下次冷启动再清）
    }
  }
}
