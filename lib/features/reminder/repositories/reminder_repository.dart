// 提醒仓库 + 本地通知调度（reminders → awesome_notifications）
//
// 对齐桌面端 newReminder 引擎语义的移动端映射：
// - time 模式：每天/按星期/一次性(带date)/每小时/每月/每年 → NotificationCalendar 定时通知；
// - interval 模式：每 N 分/时/天 → NotificationInterval 周期通知；
// - stateful 模式：番茄钟状态机由 App 前台驱动，不走系统通知；
// - 用户列表过滤 source==='todo'（桌面端 get-tips 同款规则）；
// - 送达方式 delivery：'notification'（系统通知）或 'alarm'（精确+全屏意图，闹钟体验）。
//   闹钟额外增强：① 重复响铃 → 每次排程附 extraRings 次顺延 1 分钟的响铃（id+1000*k）；
//   ② 稍后提醒 → 闹钟自动带 actionSnooze 按钮，点击后 5 分钟再响（见 notification_service）。
// - 免打扰（idleTime）：当前落在免打扰段时顺延到段末（一次性场景最佳；周期类逐次精确跳过
//   需后台 worker，标记为已知近似，见项目 skill reminder 段）。
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/reminder_item.dart';

/// 提醒仓库
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  /// 用户提醒流（过滤引擎托管的待办提醒；番茄钟 stateful 保留展示）
  Stream<List<ReminderItem>> watchUserReminders() {
    return (_db.select(_db.reminders)
          ..where((tbl) => tbl.source.isNull() | tbl.source.equals(''))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.title)]))
        .watch()
        .map((rows) => rows.map(ReminderItem.fromRow).toList());
  }

  /// 进入提醒页 / App 启动时调用：取消并重新排程全部启用提醒，
  /// 防止 awesome 原生计划被系统清理后不再触发。
  Future<void> rescheduleAll() async {
    final rows = await (_db.select(_db.reminders)
          ..where((tbl) => tbl.source.isNull() | tbl.source.equals('')))
        .get();
    for (final row in rows) {
      final item = ReminderItem.fromRow(row);
      final weekly = !item.isStateful && item.mode == 'time' && item.weekDays.isNotEmpty;
      await NotificationService.cancelReminder(item.id, weekly: weekly);
      if (item.enabled && !item.isStateful) {
        await scheduleNotification(item);
      }
    }
  }

  /// 新增 / 编辑统一入口：upsert（按 id 幂等）+ 重排程
  Future<void> saveReminder(ReminderItem item) async {
    await (_db.into(_db.reminders).insertOnConflictUpdate(_toCompanion(item)));
    final weekly = item.mode == 'time' && item.weekDays.isNotEmpty;
    await NotificationService.cancelReminder(item.id, weekly: weekly);
    if (item.enabled && !item.isStateful) {
      await scheduleNotification(item);
    }
  }

  /// 删除提醒（取消通知 + 删库）
  Future<void> deleteReminder(String id) async {
    await NotificationService.cancelReminder(id, weekly: true);
    await (_db.delete(_db.reminders)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 启停提醒（同步增删本地通知计划）
  Future<void> toggleEnabled(ReminderItem item, bool enabled) =>
      saveReminder(item.copyWith(enabled: enabled));

  /// 按 mode + delivery 把提醒翻译为本地通知计划
  Future<void> scheduleNotification(ReminderItem item) async {
    if (item.isStateful) return; // 状态机不走系统通知
    final alarm = item.isAlarm;
    final channel = alarm ? NotificationChannels.alarm : NotificationChannels.todo;
    final baseId = NotificationService.stableId(item.id);

    // 周期模式
    if (item.mode == 'interval') {
      final iv = _parseInterval(item);
      if (iv == null) return;
      await NotificationService.scheduleInterval(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        interval: iv,
        precise: alarm,
        fullScreen: alarm,
      );
      return;
    }

    // 时间模式
    final timeParts = (item.time ?? '').split(':');
    if (timeParts.length < 2) return;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return;
    final repeat = item.repeat ?? 'daily';

    // 免打扰：当前落在免打扰段时顺延到段末（仅一次性场景精确；周期类见模块文档说明）
    final slots = parseIdleSlots(item.idleTime);
    final idleEnd = _idleEndIfNowInSlot(slots);

    if (repeat == 'once' && item.date != null) {
      final dt = _parseDate(item.date!, hour, minute);
      if (dt == null) return;
      await NotificationService.scheduleOnce(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        dateTime: idleEnd ?? dt,
        precise: alarm,
        fullScreen: alarm,
      );
      return;
    }

    if (repeat == 'hourly') {
      await NotificationService.scheduleCalendar(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        minute: minute,
        repeats: true,
        precise: alarm,
        fullScreen: alarm,
        extraRings: alarm ? 2 : 0,
      );
      return;
    }
    if (repeat == 'monthly') {
      final dom = int.tryParse(item.dayOfMonth ?? '') ?? 1;
      await NotificationService.scheduleCalendar(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        day: dom,
        hour: hour,
        minute: minute,
        repeats: true,
        precise: alarm,
        fullScreen: alarm,
        extraRings: alarm ? 2 : 0,
      );
      return;
    }
    if (repeat == 'yearly') {
      final m = int.tryParse(item.month ?? '') ?? 1;
      final dom = int.tryParse(item.dayOfMonth ?? '') ?? 1;
      await NotificationService.scheduleCalendar(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        month: m,
        day: dom,
        hour: hour,
        minute: minute,
        repeats: true,
        precise: alarm,
        fullScreen: alarm,
        extraRings: alarm ? 2 : 0,
      );
      return;
    }

    // 每天 / 每周（weekDays 用 PC 约定 0=周日…6=周六，awesome 1=周日…7=周六 → +1）
    if (item.weekDays.isEmpty) {
      await NotificationService.scheduleCalendar(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        hour: hour,
        minute: minute,
        repeats: true,
        precise: alarm,
        fullScreen: alarm,
        extraRings: alarm ? 2 : 0,
      );
    } else {
      for (final w in item.weekDays) {
        await NotificationService.scheduleCalendar(
          id: baseId + w,
          channelKey: channel,
          title: item.title,
          body: item.content,
          weekday: w + 1,
          hour: hour,
          minute: minute,
          repeats: true,
          precise: alarm,
          fullScreen: alarm,
          extraRings: alarm ? 2 : 0,
        );
      }
    }
  }

  // —— 内部工具 ——

  RemindersCompanion _toCompanion(ReminderItem item) => RemindersCompanion(
        id: Value(item.id),
        mode: Value(item.mode),
        weekDays: Value(_toJson(item.weekDays)),
        loop: Value(item.loop),
        title: Value(item.title),
        content: Value(item.content),
        enabled: Value(item.enabled ? '1' : '0'),
        time: Value(item.time),
        date: Value(item.date),
        repeat: Value(item.repeat),
        interval: Value(item.interval),
        unit: Value(item.unit),
        idleTime: Value(item.idleTime),
        source: Value(item.source),
        delivery: Value(item.delivery),
        month: Value(item.month),
        dayOfMonth: Value(item.dayOfMonth),
      );

  static String _toJson(List<int> v) => v.isEmpty ? '[]' : '[${v.join(',')}]';

  Duration? _parseInterval(ReminderItem item) {
    final n = int.tryParse(item.interval ?? '');
    final u = int.tryParse(item.unit ?? '');
    if (n == null || u == null) return null;
    final ms = n * u;
    if (ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  DateTime? _parseDate(String date, int hour, int minute) {
    final p = date.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    try {
      return DateTime(y, m, d, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// 当前是否落在免打扰段内；是则返回段末时刻（跨午夜顺延到次日）
  DateTime? _idleEndIfNowInSlot(List<IdleSlot> slots) {
    if (slots.isEmpty) return null;
    final now = DateTime.now();
    final hhmm = now.hour * 60 + now.minute;
    for (final s in slots) {
      final sp = s.start.split(':');
      final ep = s.end.split(':');
      if (sp.length < 2 || ep.length < 2) continue;
      final sh = int.tryParse(sp[0]);
      final sm = int.tryParse(sp[1]);
      final eh = int.tryParse(ep[0]);
      final em = int.tryParse(ep[1]);
      if (sh == null || sm == null || eh == null || em == null) continue;
      final start = sh * 60 + sm;
      final end = eh * 60 + em;
      final crosses = end <= start; // 跨午夜（如 22:00-06:00）
      final inSlot = crosses
          ? (hhmm >= start || hhmm < end)
          : (hhmm >= start && hhmm < end);
      if (inSlot) {
        var endDt = DateTime(now.year, now.month, now.day, eh, em);
        if (crosses && hhmm >= start) endDt = endDt.add(const Duration(days: 1));
        return endDt;
      }
    }
    return null;
  }

  /// 把免打扰时段列表编码为桌面端同款存储格式（JSON 数组，元素为 JSON 编码对象字符串）
  static String encodeIdleSlots(List<IdleSlot> slots) =>
      jsonEncode(slots.map((e) => jsonEncode({'start': e.start, 'end': e.end})).toList());
}
