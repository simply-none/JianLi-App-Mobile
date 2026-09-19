// 原生「通知送达」统一封装（2026-09-19 全模块收口）
//
// 背景：2026-09-18 只把「提醒」功能页迁到原生 setAlarmClock 后，真机 Android 15 仍复现
// 「切后台/锁屏不响、回 App 过段时间补响」—— 因为习惯 / 待办 / 倒计时的提醒仍整条走
// awesome_notifications：它的 NotificationCalendar 依赖自己的 ScheduleReceiver + SharedPreferences
// 恢复链，在后台 / Doze / 厂商冻结下被系统推迟，App 回前台解除节流后才集中派发。
//
// 本文件把「原生 setAlarmClock(mode=notify) 优先 + awesome 兜底」的公共部分抽出来给
// habit / todo / countdown 复用（reminder 仓库自身已有同构实现，不强制改用它）：
//   - 触发时刻计算（今天已过则明天 / 按 PC 周几取下一次）
//   - repeatSpec 组装（daily / weekly / 一次性 null）—— 到点由原生 ReminderAlarmReceiver
//     发通知并自排下一次，App 进程不在也持续
//   - 统一 mode='notify'（普通系统通知；原生侧统一走 High 渠道 `reminder_notify`，
//     ⚠️ 因此 habit/todo/countdown 的原生通知不再区分各自渠道，要分渠道需扩展
//     AlarmScheduler 增加 channelId 参数）
//
// ⚠️ 铁律（与提醒模块同款）：**排程与取消必须共用同一份请求码口径**——
// habit 每周多天 = 一天一个码（baseId + wd，wd 为 PC 周几 0=周日…6=周六）；
// 一次性 = baseId。取消走 [cancelNativeAlarms]（原生 cancel 内部连带清贪睡码与响铃通知）。
import '../android/system_actions.dart' as sys;

/// 今天/明天 HH:mm 的下一次触发时刻（此刻已过 → 明天）
DateTime nextDailyAt(int hour, int minute) {
  final now = DateTime.now();
  var cand = DateTime(now.year, now.month, now.day, hour, minute);
  if (!cand.isAfter(now)) cand = cand.add(const Duration(days: 1));
  return cand;
}

/// 「PC 周几 pcW(0=周日…6=周六) + HH:mm」的下一次触发时刻
DateTime nextWeeklyAt(int pcW, int hour, int minute) {
  final now = DateTime.now();
  final dtW = pcW == 0 ? 7 : pcW; // DateTime.weekday 1=周一…7=周日
  var days = (dtW - now.weekday) % 7;
  if (days == 0) {
    final todayAt = DateTime(now.year, now.month, now.day, hour, minute);
    days = todayAt.isAfter(now) ? 0 : 7;
  } else if (days < 0) {
    days += 7;
  }
  return DateTime(now.year, now.month, now.day, hour, minute)
      .add(Duration(days: days));
}

/// 原生一次性通知（mode=notify；到点由 ReminderAlarmReceiver 发通知、不重排）。
///
/// 返回 true = 原生桥已接手；false = 调用方须回退 awesome。
/// [at] 已过期时返回 true（视为已处理），**不排也不取消**——已排的原生计划留着
/// 「回 App 补响一次」，胜过取消后静默丢提醒。
Future<bool> scheduleNativeNotifyOnce({
  required int code,
  required String title,
  required String body,
  required DateTime at,
}) {
  if (!at.isAfter(DateTime.now())) return Future.value(true);
  return sys.setAlarmClock(
    code: code,
    title: title,
    body: body,
    triggerAtMillis: at.millisecondsSinceEpoch,
    repeatSpec: null,
    mode: 'notify',
  );
}

/// 原生每天通知（repeatSpec=daily，接收器自排明天同一时刻）。
/// 返回 true = 原生桥已接手；false = 调用方须回退 awesome。
Future<bool> scheduleNativeNotifyDaily({
  required int code,
  required String title,
  required String body,
  required int hour,
  required int minute,
}) {
  return sys.setAlarmClock(
    code: code,
    title: title,
    body: body,
    triggerAtMillis: nextDailyAt(hour, minute).millisecondsSinceEpoch,
    repeatSpec: '{"type":"daily"}',
    mode: 'notify',
  );
}

/// 原生按周几通知（每周多天 = 一天一个请求码 `code + wd`；返回 true = 至少一条排上）。
/// [weekDaysPc] 为 PC 周几（0=周日…6=周六）；空列表请改用 [scheduleNativeNotifyDaily]。
/// 返回 false = 全部失败，调用方须回退 awesome。
Future<bool> scheduleNativeNotifyWeekly({
  required int code,
  required String title,
  required String body,
  required int hour,
  required int minute,
  required List<int> weekDaysPc,
}) async {
  var any = false;
  for (final wd in weekDaysPc) {
    final ok = await sys.setAlarmClock(
      code: code + wd,
      title: title,
      body: body,
      triggerAtMillis: nextWeeklyAt(wd, hour, minute).millisecondsSinceEpoch,
      repeatSpec: '{"type":"weekly"}',
      mode: 'notify',
    );
    if (ok) any = true;
  }
  return any;
}

/// 批量取消原生闹钟（与排程同一份请求码口径）
Future<void> cancelNativeAlarms(List<int> codes) => sys.cancelAlarmClocks(codes);
