// 提醒仓库 + 本地通知调度（reminders → awesome_notifications / 原生 AlarmManager）
//
// 对齐桌面端 newReminder 引擎语义的移动端映射：
// - time 模式：每天/按星期/一次性(带date)/每小时/每月/每年 → 定时通知；
// - interval 模式：每 N 分/时/天 → 周期通知；
// - stateful 模式：番茄钟状态机由 App 前台驱动，不走系统通知；
// - 用户列表过滤 source==='todo'（桌面端 get-tips 同款规则）；
// - 送达方式 delivery：'notification'（系统通知）/ 'alarm'（系统级闹钟）。
//
// 送达实现（2026-09-16 系统修复后）：
// - 'alarm' → 原生 AlarmManager.setAlarmClock 桥（见 core/android/system_actions.dart +
//   AlarmScheduler.kt / AlarmRingActivity.kt）：它是 Android 专门的「用户闹钟」通路，
//   **不需要 SCHEDULE_EXACT_ALARM 权限**、息屏与 Doze 下必响、锁屏直接弹全屏 Activity，
//   因此彻底规避了「精确闹钟权限缺失 → setExactAndAllowWhileIdle 抛 SecurityException →
//   排程整体失败 → 闹钟从不响」这一主因。重复类（每天/每周/每月/每年）由原生 AlarmRingActivity
//   在用户点「停止」时按 repeatSpec 自行排下一次，连杀进程也能持续。
// - 'notification' → awesome_notifications（普通系统通知）；精确权限缺失时自动降级为不精确，
//   保证一定排得上（见 notification_service.dart）。
//
// 健壮性（同次修复）：rescheduleAll 逐条 try/catch（一条坏不中断整轮）；saveReminder 排程失败
// 不再让整个保存抛异常（库已写入，尽力排程）；deleteReminder 同时取消原生闹钟。
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/android/system_actions.dart' as sys;
import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/scheduled_sweep.dart';
import '../models/reminder_item.dart';

/// 提醒仓库
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  /// 用户提醒流（过滤引擎托管的待办提醒；番茄钟 stateful 保留展示）
  Stream<List<ReminderItem>> watchUserReminders() {
    return (_db.select(_db.reminders)
          ..where((tbl) => tbl.source.isNull() | tbl.source.equals('')))
        .watch()
        .map((rows) => rows.map(ReminderItem.fromRow).toList());
  }

  /// 进入提醒页 / App 启动 / 回到前台时调用：取消并重新排程全部启用提醒，
  /// 防止原生计划被系统清理后不再触发。逐条保护，单条失败不影响其余。
  Future<void> rescheduleAll() async {
    final rows = await (_db.select(_db.reminders)
          ..where((tbl) => tbl.source.isNull() | tbl.source.equals('')))
        .get();
    for (final row in rows) {
      final item = ReminderItem.fromRow(row);
      // 先取消旧计划（awesome 原生 + 原生闹钟），再重排；任一步失败都不中断整轮
      try {
        await _cancelAllSchedules(item);
      } catch (_) {}
      if (item.enabled && !item.isStateful) {
        try {
          await scheduleNotification(item);
        } catch (_) {}
      }
    }
    // 冷启动/回前台兜底：清掉历史遗留的孤儿时钟闹钟（如老版本删除时未清理的）
    await _reconcileClockAlarms();
    // 全局在排通知对账：清掉 stableId 改造前 hashCode 时代排的孤儿周期通知
    // （已删除提醒的旧计划永远取消不掉的那批；habit/todo 有显式迁移、reminder 漏了，
    // 改为反向对账一次清完，详见 scheduled_sweep.dart 文件头）
    await ScheduledSweep.sweepOrphans(_db);
  }

  /// 新增 / 编辑统一入口：upsert（按 id 幂等）+ 重排程。
  /// 排程失败不再向上抛（库已写入，尽力排程），避免 UI 误判「保存失败」。
  Future<void> saveReminder(ReminderItem item) async {
    await (_db.into(_db.reminders).insertOnConflictUpdate(_toCompanion(item)));
    try {
      await _cancelAllSchedules(item);
    } catch (_) {}
    if (item.enabled && !item.isStateful) {
      try {
        await scheduleNotification(item);
      } catch (_) {}
    }
    // 停用开关 / 改时间后旧时钟闹钟也要跟着撤（对账内部会判定是否还需要）
    await _reconcileClockAlarms();
  }

  /// 删除提醒（取消通知 + 删库 + 对账清理孤儿时钟闹钟）
  Future<void> deleteReminder(String id) async {
    final baseId = NotificationService.stableId(id);
    // awesome（含 weekly 变体）+ 原生闹钟（baseId..baseId+7 覆盖所有可能周几码）
    try {
      await NotificationService.cancelReminder(id, weekly: true);
    } catch (_) {}
    try {
      // +1000/-1000 = 贪睡码（AlarmScheduler.snoozeCode）：响铃页贪睡后立刻删除的场景
      // 也一并取消，否则已删除提醒还会再弹一次（2026-09-19 补）
      await sys.cancelAlarmClocks([
        for (var i = 0; i <= 7; i++) baseId + i,
        baseId + 1000,
        baseId - 1000,
      ]);
    } catch (_) {}
    await (_db.delete(_db.reminders)..where((tbl) => tbl.id.equals(id))).go();
    await _reconcileClockAlarms();
  }

  /// 孤儿时钟闹钟对账（路线 2 收口，2026-09-19）。
  ///
  /// 「闹钟送达 + 每天/每周」的提醒被委托写入系统时钟 App 后，公开 API 原本删不掉：
  /// 删除 / 停用开关 / 改时间后，时钟里的旧闹钟继续每天响「渐离App·旧标题」，
  /// 表现为「弹出已删除内容的提醒」。现在：登记表 entries 与「现存启用中的委托型
  /// 提醒的 HH:mm 集合」对账，不在集合里的一律走 ACTION_DISMISS_ALARM 撤销
  /// （OEM 时钟不支持该 action 时撤不动，仍需手动删 —— 登记表已清，不会重写回）。
  ///
  /// ⚠️ 按 HH:mm 对账而非按提醒 id：两个提醒共用同一时间时，删掉其一不能撤钟
  /// （时钟闹钟还在为存活的那个服务）；ACTION_DISMISS_ALARM 也只能按时间匹配，
  /// 时钟应用内部 id 第三方拿不到。
  Future<void> _reconcileClockAlarms() async {
    try {
      final rows = await (_db.select(_db.reminders)
            ..where((tbl) => tbl.source.isNull() | tbl.source.equals('')))
          .get();
      final needed = <String>{};
      for (final row in rows) {
        final item = ReminderItem.fromRow(row);
        if (!item.enabled || item.isStateful) continue;
        final repeat = item.repeat ?? 'daily';
        // 与 scheduleNotification 的委托条件保持一致：alarm 送达 + time 模式 + 每天/每周
        if (!(item.isAlarm &&
            item.mode == 'time' &&
            (repeat == 'daily' || repeat == 'weekly'))) {
          continue;
        }
        final tp = (item.time ?? '').split(':');
        final h = int.tryParse(tp.isNotEmpty ? tp[0] : '');
        final m = tp.length > 1 ? int.tryParse(tp[1]) : null;
        if (h == null || m == null) continue;
        needed.add('$h|$m');
      }
      final entries = await sys.listSystemClockAlarms();
      for (final e in entries) {
        final key = e['key'] as String? ?? '';
        if (key.isEmpty) continue;
        final h = (e['hour'] as num?)?.toInt() ?? 0;
        final m = (e['minute'] as num?)?.toInt() ?? 0;
        if (!needed.contains('$h|$m')) {
          await sys.removeSystemClockAlarm(key: key, hour: h, minute: m);
        }
      }
    } catch (_) {
      // 对账失败不影响主流程（旧闹钟留时钟里手动删，守护抽屉有说明）
    }
  }

  /// 启停提醒（同步增删本地通知计划）
  Future<void> toggleEnabled(ReminderItem item, bool enabled) =>
      saveReminder(item.copyWith(enabled: enabled));

  /// 按 mode + delivery 把提醒翻译为本地通知计划
  Future<void> scheduleNotification(ReminderItem item) async {
    if (item.isStateful) return; // 状态机不走系统通知

    // —— 路线 2（2026-09-19）：「闹钟送达」+ 每天/每周 → 委托系统时钟 App ——
    //
    // 真机实证：自建 setAlarmClock 计划「系统认账、分组豁免、FGS 在跑」仍被 ROM 扣住
    // 到点广播（锁屏/切后台不响、回 App 补发）；而厂商时钟是**系统应用**，任何 ROM
    // 都不会扣它的闹钟 —— 用 ACTION_SET_ALARM 静默写入（原生侧同参数去重，rescheduleAll
    // 反复跑不会重复建）。接管成功后**不再走自建链**，避免双响。
    // 2026-09-19 收口：删除/停用/改时间后的旧时钟闹钟由 _reconcileClockAlarms 对账清理
    // （ACTION_DISMISS_ALARM，OEM 时钟不支持时需手动删；标签以「渐离App·」开头便于识别）。
    // 其余形态（notify / once / hourly / monthly / yearly / interval）时钟 App 无法表达，
    // 维持路线 1（原生 setAlarmClock 优先 + awesome 兜底）。
    final repeat = item.repeat ?? 'daily';
    if (item.isAlarm && item.mode == 'time' && (repeat == 'daily' || repeat == 'weekly')) {
      final timeParts = (item.time ?? '').split(':');
      final hour = int.tryParse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : null;
      if (hour != null && minute != null) {
        final days = (repeat == 'weekly' && item.weekDays.isNotEmpty)
            ? item.weekDays
            : const <int>[0, 1, 2, 3, 4, 5, 6];
        final delegated = await sys.setSystemClockAlarm(
          key: item.id,
          hour: hour,
          minute: minute,
          message: '渐离App·${item.title}',
          daysPc: days,
        );
        if (delegated) return;
      }
    }

    // 周期模式：无论「通知」还是「闹钟」送达，都**优先**走原生 AlarmManager 桥（alarm=全屏 / notify=普通通知）。
    // awesome 的 NotificationInterval 在 Android 12+ 被 Doze/省电严重节流并会自我停摆，
    // 表现为「只响 2 次就停 + 间隔不准」，正是周期提醒失效根因，故不再走 awesome。
    // ⚠️ 原生桥失败（通道异常/机型限制）时必须回退 awesome —— 否则 rescheduleAll「先取消再重排」
    // 会把提醒取消后静默排不上，表现为「所有提醒都不响」。
    if (item.mode == 'interval') {
      if (await _scheduleNativeInterval(item)) return;
      await _scheduleAwesomeInterval(item);
      return;
    }
    // 时间模式（once/daily/weekly/hourly/monthly/yearly）：**无论通知还是闹钟送达都优先走原生**。
    //
    // ⚠️ 2026-09-18 修复「切后台 / 锁屏后定时提醒不触发、回 App 才补触发」：此前只有「闹钟送达」
    // 走原生，普通「通知送达」的时间模式整条走 awesome `NotificationCalendar` —— 它在后台/Doze/
    // 厂商冻结下依赖自己的 ScheduleReceiver 链，环节多、易被推迟，正是「亮屏或回前台才集中补发」
    // 的成因。原生 `setAlarmClock` 由系统直接持有计划且 Doze 豁免，是后台最可靠的一层。
    // 仍保留 awesome 兜底：原生返回 false（通道异常 / 权限 / 本机不支持）时才降级。
    if (await _scheduleNativeTime(item)) return;
    await _scheduleAwesomeTime(item, fullScreen: item.isAlarm);
  }

  /// 时间模式 → awesome 定时通知。
  /// [fullScreen]=true 用高重要 `alarm` 渠道 + 全屏意图（原生闹钟桥失败时的兜底）；否则用 `todo` 渠道普通通知。
  Future<void> _scheduleAwesomeTime(
    ReminderItem item, {
    required bool fullScreen,
  }) async {
    final channel = fullScreen
        ? NotificationChannels.alarm
        : NotificationChannels.todo;
    final baseId = NotificationService.stableId(item.id);

    // 时间模式
    final timeParts = (item.time ?? '').split(':');
    if (timeParts.length < 2) return;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return;
    final repeat = item.repeat ?? 'daily';

    // 免打扰：当前落在免打扰段时顺延到段末（仅一次性场景精确；周期类逐次精确跳过
    // 需后台 worker，标记为已知近似，见项目 skill reminder 段）。
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
        precise: fullScreen,
        fullScreen: fullScreen,
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
        precise: fullScreen,
        fullScreen: fullScreen,
        extraRings: 0,
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
        precise: fullScreen,
        fullScreen: fullScreen,
        extraRings: 0,
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
        precise: fullScreen,
        fullScreen: fullScreen,
        extraRings: 0,
      );
      return;
    }

    // 每天 / 每周（weekDays 用 PC 约定 0=周日…6=周六；原生 AlarmRingActivity 内部换算为 DateTime.weekday）
    if (item.weekDays.isEmpty) {
      await NotificationService.scheduleCalendar(
        id: baseId,
        channelKey: channel,
        title: item.title,
        body: item.content,
        hour: hour,
        minute: minute,
        repeats: true,
        precise: fullScreen,
        fullScreen: fullScreen,
        extraRings: 0,
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
          precise: fullScreen,
          fullScreen: fullScreen,
          extraRings: 0,
        );
      }
    }
  }

  /// 时间模式 → 原生 setAlarmClock 桥排程（周期模式走 _scheduleNativeInterval）。
  ///
  /// 送达形态由 [mode] 区分：`alarm` = 闹钟（全屏响铃页）、`notify` = 普通系统通知；
  /// 两者都由**系统**持有计划，Doze 下豁免、App 被杀也能到点触发，并由接收器自排下一次。
  ///
  /// 返回 **true = 已由原生桥接手**（至少一条 setAlarmClock 返回成功，或本就无需排程）；
  /// 返回 **false = 原生桥未接手**，调用方须回退 awesome 兜底 —— 这是修复
  /// 「原生桥静默失败 + rescheduleAll 先取消再重排 = 所有提醒都不响」的关键语义。
  Future<bool> _scheduleNativeTime(ReminderItem item) async {
    final baseId = NotificationService.stableId(item.id);
    final title = item.title;
    final body = item.content;
    final mode = item.isAlarm ? 'alarm' : 'notify';

    // 免打扰：当前落在免打扰段内时把首次触发推迟到段末（与 awesome 路径同口径；
    // 周期类「逐次跳过」需后台 worker，仍是已知近似，见 _scheduleAwesomeTime 注释）
    final idleEndMs = _idleEndIfNowInSlot(parseIdleSlots(item.idleTime))
        ?.millisecondsSinceEpoch;
    int? at(int? ms) =>
        ms == null ? null : (idleEndMs != null && ms < idleEndMs ? idleEndMs : ms);

    // 每周多天：一天一个请求码（与 _nativeCodes 同源，保证排/取消一致）
    if (_isWeeklyMultiDay(item)) {
      var any = false;
      for (final w in item.weekDays) {
        final ms = at(_nextAlarmTriggerMillis(item, forWeekdayPc: w));
        if (ms == null) continue;
        final ok = await sys.setAlarmClock(
          code: baseId + w,
          title: title,
          body: body,
          triggerAtMillis: ms,
          repeatSpec: '{"type":"weekly"}',
          mode: mode,
        );
        if (ok) any = true;
      }
      return any;
    }

    final ms = at(_nextAlarmTriggerMillis(item));
    if (ms == null) return true; // 无需排程（如一次性已过期）→ 视为已处理，不触发兜底
    return await sys.setAlarmClock(
      code: baseId,
      title: title,
      body: body,
      triggerAtMillis: ms,
      repeatSpec: _repeatSpecJson(item),
      mode: mode,
    );
  }

  /// 周期模式（每 N 分/时/天）送达：走原生 AlarmManager 桥（alarm=全屏 / notify=普通通知）。
  ///
  /// 不再走 awesome 的 NotificationInterval：它在 Android 12+ 被 Doze/省电严重节流且会自我停摆，
  /// 表现为「只响 2 次就停 + 间隔不准」。原生 setAlarmClock 由系统持有，首次在 now+interval 触发，
  /// 之后由 Receiver/Activity 按 repeatSpec 的 interval 类型自排下次，连 App 被杀也能持续每 interval 弹一次。
  ///
  /// 返回值语义同 [_scheduleNativeTime]：true = 原生桥已接手，false = 须回退 awesome 兜底。
  Future<bool> _scheduleNativeInterval(ReminderItem item) async {
    final baseId = NotificationService.stableId(item.id);
    final iv = _parseInterval(item);
    if (iv == null) return true; // 无有效间隔参数 → 无需排程
    final mode = item.isAlarm ? 'alarm' : 'notify';
    return await sys.setAlarmClock(
      code: baseId,
      title: item.title,
      body: item.content,
      triggerAtMillis: DateTime.now().add(iv).millisecondsSinceEpoch,
      repeatSpec: '{"type":"interval","interval":${iv.inMilliseconds}}',
      intervalMillis: iv.inMilliseconds,
      mode: mode,
    );
  }

  /// 周期模式 → awesome 兜底（仅当原生桥不可用时）。
  ///
  /// awesome 的 NotificationInterval 在 Android 12+ 会被 Doze 节流、甚至自我停摆，体验不如原生桥；
  /// 但它「至少能排得上、能响几次」，远优于原生桥失败时「先取消后静默排不上 = 完全不响」。
  /// 原生桥恢复后，下一次 rescheduleAll / saveReminder 会重新切回原生。
  Future<void> _scheduleAwesomeInterval(ReminderItem item) async {
    final iv = _parseInterval(item);
    if (iv == null) return;
    await NotificationService.scheduleInterval(
      id: NotificationService.stableId(item.id),
      channelKey:
          item.isAlarm ? NotificationChannels.alarm : NotificationChannels.todo,
      title: item.title,
      body: item.content,
      interval: iv,
      precise: item.isAlarm,
      fullScreen: item.isAlarm,
    );
  }

  /// 一次性取消某提醒的全部计划（awesome 原生 + 原生闹钟）
  Future<void> _cancelAllSchedules(ReminderItem item) async {
    final codes = _nativeCodes(item);
    try {
      await NotificationService.cancelReminder(item.id, weekly: codes.length > 1);
    } catch (_) {}
    try {
      await sys.cancelAlarmClocks(codes);
    } catch (_) {}
  }

  /// 原生排程使用的请求码集合：**排程与取消必须共用这一份**。
  ///
  /// ⚠️ 此前排程按「weekDays 非空」、取消按「repeat=='weekly' && weekDays 非空」两套口径，
  /// 不一致时会取消不掉旧计划 ⇒ 「改了提醒时间还按旧时间响 / 关掉了还在响」。
  /// [_scheduleNativeTime] 用 [_isWeeklyMultiDay] 走「每周多天」分支，与此处天然同源。
  List<int> _nativeCodes(ReminderItem item) {
    final baseId = NotificationService.stableId(item.id);
    if (_isWeeklyMultiDay(item)) {
      return item.weekDays.map((w) => baseId + w).toList();
    }
    return [baseId];
  }

  /// 是否「每周多天」（一天一个请求码）：时间模式 + 周几非空 + 非一次性。
  bool _isWeeklyMultiDay(ReminderItem item) =>
      item.mode == 'time' &&
      item.weekDays.isNotEmpty &&
      item.repeat != 'once';

  /// 计算原生闹钟的 repeatSpec JSON（null = 一次性，不重排）
  String? _repeatSpecJson(ReminderItem item) {
    if (item.repeat == 'once') return null;
    switch (item.repeat) {
      case 'hourly':
        return '{"type":"interval","interval":3600000}';
      case 'daily':
        return '{"type":"daily"}';
      case 'monthly':
        return '{"type":"monthly"}';
      case 'yearly':
        return '{"type":"yearly"}';
      case 'weekly':
        return '{"type":"weekly"}';
      default:
        return '{"type":"daily"}';
    }
  }

  /// 下次触发时间（毫秒）。[forWeekdayPc] 为 PC 约定周几（0=周日…6=周六），仅 weekly 用。
  int? _nextAlarmTriggerMillis(ReminderItem item, {int? forWeekdayPc}) {
    final now = DateTime.now();
    final timeParts = (item.time ?? '').split(':');
    if (timeParts.length < 2) return null;
    final h = int.tryParse(timeParts[0]);
    final m = int.tryParse(timeParts[1]);
    if (h == null || m == null) return null;

    switch (item.repeat) {
      case 'once':
        if (item.date == null) return null;
        final dt = _parseDate(item.date!, h, m);
        if (dt == null) return null;
        return dt.isAfter(now) ? dt.millisecondsSinceEpoch : null;
      case 'hourly':
        var cand = DateTime(now.year, now.month, now.day, now.hour, m, 0, 0, 0);
        if (!cand.isAfter(now)) cand = cand.add(const Duration(hours: 1));
        return cand.millisecondsSinceEpoch;
      case 'monthly':
        final dom = int.tryParse(item.dayOfMonth ?? '') ?? now.day;
        return _nextMonthly(dom, h, m, now).millisecondsSinceEpoch;
      case 'yearly':
        final mo = int.tryParse(item.month ?? '') ?? now.month;
        final dom = int.tryParse(item.dayOfMonth ?? '') ?? now.day;
        return _nextYearly(mo, dom, h, m, now).millisecondsSinceEpoch;
      case 'weekly':
        final wd = forWeekdayPc ?? (item.weekDays.isNotEmpty ? item.weekDays.first : 1);
        return _nextWeekly(wd, h, m, now).millisecondsSinceEpoch;
      default: // daily
        var cand = DateTime(now.year, now.month, now.day, h, m, 0, 0, 0);
        if (!cand.isAfter(now)) cand = cand.add(const Duration(days: 1));
        return cand.millisecondsSinceEpoch;
    }
  }

  /// 每周下次触发：PC 周几(0=周日…6=周六) 换算为 DateTime.weekday(1=周一…7=周日)
  DateTime _nextWeekly(int pcW, int h, int m, DateTime now) {
    final dtW = pcW == 0 ? 7 : pcW;
    var days = (dtW - now.weekday) % 7;
    if (days == 0) {
      final todayAt = DateTime(now.year, now.month, now.day, h, m);
      days = todayAt.isAfter(now) ? 0 : 7;
    } else if (days < 0) {
      days += 7;
    }
    return DateTime(now.year, now.month, now.day, h, m)
        .add(Duration(days: days));
  }

  /// 每月下次触发（dayOfMonth 超过当月天数则夹紧）
  DateTime _nextMonthly(int dom, int h, int m, DateTime now) {
    var cand = _clampDay(now.year, now.month, dom, h, m);
    if (!cand.isAfter(now)) {
      final nm = now.month + 1;
      final ny = now.year + (nm > 12 ? 1 : 0);
      cand = _clampDay(ny, nm > 12 ? 1 : nm, dom, h, m);
    }
    return cand;
  }

  /// 每年下次触发
  DateTime _nextYearly(int mo, int dom, int h, int m, DateTime now) {
    var cand = _clampDay(now.year, mo, dom, h, m);
    if (!cand.isAfter(now)) cand = _clampDay(now.year + 1, mo, dom, h, m);
    return cand;
  }

  /// 夹紧 dayOfMonth 到指定月份的实际天数
  DateTime _clampDay(int year, int month, int dom, int h, int m) {
    final last = DateTime(year, month + 1, 0).day;
    final d = dom.clamp(1, last);
    return DateTime(year, month, d, h, m, 0, 0, 0);
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
