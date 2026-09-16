// 本地通知封装（awesome_notifications）—— 统一提醒引擎的移动端出口
//
// 桌面端 reminders 表是统一提醒引擎（习惯/待办/番茄钟到点均来自此表）；
// 移动端策略：读取 reminders → 翻译为本地通知计划（awesome_notifications）。
// 番茄钟这类状态机型提醒需 App 前台/前台服务驱动（iOS 受限，见 flutter-port.md 第 4 节）。
//
// 送达双模式：
// - 'notification'（系统通知）：awesome_notifications 普通渠道，allowWhileIdle 息屏可响；
//   精确闹钟权限缺失时自动降级为不精确（保证一定排得上，最多延迟几分钟），见各 schedule* 的 canExact。
// - 'alarm'（闹钟）：**不再走 awesome**。历史上走 preciseAlarm，在 Android 12+ 未授权
//   SCHEDULE_EXACT_ALARM 会抛 SecurityException → 闹钟从不响。2026-09-16 起改走原生
//   AlarmManager.setAlarmClock 桥（见 core/android/system_actions.dart + AlarmScheduler.kt /
//   AlarmRingActivity.kt）：Android 专门「用户闹钟」通路，息屏/Doze 必响、锁屏全屏、
//   **无需精确闹钟权限**，彻底修复「闹钟从未响」。重复类由原生 Activity 自行重排。
//
// 普通通知增强（仍走 awesome）：
// - scheduleCalendar(extraRings:N) 额外排 N 次顺延 1 分钟的响铃（id+1000*k），一次连响 N+1 次；
// - fullScreen=true 时自动带「稍后提醒」动作（_onActionReceived 处理，5 分钟再响一次）。
//   （注：新版 alarm 送达走原生 AlarmRingActivity，awesome 的 fullScreen/snooze 主要服务
//   普通通知被设为全屏的场景。）
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../android/system_actions.dart' as sys;

/// 通知渠道定义（与功能域一一对应，便于系统级分组管理）
class NotificationChannels {
  NotificationChannels._();

  /// 习惯打卡提醒
  static const String habit = 'habit';

  /// 待办截止/每日实例提醒
  static const String todo = 'todo';

  /// 番茄钟阶段切换
  static const String pomodoro = 'pomodoro';

  /// 倒计时到点（普通系统通知；精确性由 scheduleOnce 的 preciseAlarm 保证）
  static const String countdown = 'countdown';

  /// 闹钟（强提醒）：高重要 + 可全屏
  static const String alarm = 'alarm';

  /// 全渠道清单（初始化时统一注册）
  static List<NotificationChannel> get all => [
        NotificationChannel(
          channelKey: habit,
          channelName: '习惯提醒',
          channelDescription: '习惯打卡到点提醒',
          channelShowBadge: true,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: todo,
          channelName: '待办提醒',
          channelDescription: '待办截止与重复实例提醒',
          channelShowBadge: true,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: pomodoro,
          channelName: '番茄钟',
          channelDescription: '番茄钟工作/休息阶段切换提醒',
          channelShowBadge: true,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: countdown,
          channelName: '倒计时提醒',
          channelDescription: '倒计时到点提醒',
          channelShowBadge: true,
          importance: NotificationImportance.High,
          playSound: true,
        ),
        NotificationChannel(
          channelKey: alarm,
          channelName: '闹钟提醒',
          channelDescription: '强提醒/闹钟，锁屏可弹全屏',
          channelShowBadge: true,
          importance: NotificationImportance.High,
          playSound: true,
        ),
      ];
}

/// 通知服务：App 启动时初始化；具体提醒计划由各 feature 调用 schedule* 方法
class NotificationService {
  NotificationService._();

  /// 闹钟「稍后提醒」动作 key（点击后在 snoozeMinutes 分钟后再响一次）
  static const String actionSnooze = 'snooze';

  /// 稍后提醒间隔（分钟）
  static const int snoozeMinutes = 5;

  /// 闹钟「重复响铃」附加响铃次数（=0 表示只响一次）
  static const int defaultExtraRings = 2;

  static bool _initialized = false;

  /// 初始化通知插件并注册全部渠道
  static Future<void> init() async {
    if (_initialized) return;
    await AwesomeNotifications().initialize(
      null, // 使用默认应用图标；后续可换 resource:resource://drawable/ic_launcher
      NotificationChannels.all,
      debug: false,
    );
    // 注册动作回调：闹钟「稍后提醒」点击后重排一次响铃。
    // ⚠️ 必须传静态/顶层函数引用（不能是闭包），插件内部用
    // PluginUtilities.getCallbackHandle 取句柄，闭包会取不到导致回调不触发。
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
    );
    _initialized = true;
  }

  /// 请求通知权限（Android 13+ 需运行时授权）
  static Future<bool> requestPermission() async {
    return AwesomeNotifications().isNotificationAllowed().then((allowed) {
      if (allowed) return true;
      return AwesomeNotifications().requestPermissionToSendNotifications();
    });
  }

  /// 精确闹钟（Android 12+「闹钟和提醒」特殊权限）当前是否可用。
  ///
  /// Android 12 以下没有该权限概念，permission_handler 直接返回 granted；
  /// Android 12+ 需用户在系统设置里开「闹钟和提醒」，未授权时 AlarmManager
  /// 的精确调度会退化为非精确（到点可能延迟几分钟）。
  static Future<bool> get exactAlarmAllowed async {
    try {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      // 平台不支持该权限（如 iOS/低版本）时按「可用」处理
      return true;
    }
  }

  /// 引导用户去系统设置开「闹钟和提醒」（Android 12+；低版本直接返回 true）
  static Future<bool> requestExactAlarmPermission() =>
      Permission.scheduleExactAlarm.request().then((s) => s.isGranted);

  /// 是否已忽略电池优化（Android 6+；未忽略时 Doze 下闹钟可能被延后几分钟）。
  /// 非 Android / 低版本恒 true（无此概念）。
  static Future<bool> get batteryOptimizationOff =>
      sys.isIgnoringBatteryOptimizations();

  /// 申请「忽略电池优化」：直接弹系统对话框「是否允许忽略电池优化」。
  ///
  /// 走 permission_handler 的 ignoreBatteryOptimizations（原生 ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS），
  /// 需清单声明 `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`；对话框关闭后才有结果，故返回值是「用户点完之后」的状态。
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final s = await Permission.ignoreBatteryOptimizations.request();
      return s.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 「全屏通知」是否可用（Android 14+ 对非闹钟类应用默认不授予）。
  /// 未授予时「闹钟」送达只弹横幅，不会锁屏全屏弹出。低版本 / 非 Android 恒 true。
  static Future<bool> get fullScreenIntentAllowed => sys.canUseFullScreenIntent();

  /// 跳系统「全屏通知」授权页（低版本原生侧退化为本应用详情页）
  static Future<bool> openFullScreenIntentSettings() =>
      sys.openFullScreenIntentSettings();

  /// 一次性检查到点提醒的**四项前置条件**（提醒页「提醒守护」卡用）。
  ///
  /// - notifications：Android 13+ 通知运行时权限（不授予 → 到点完全不弹）；
  /// - exactAlarm：Android 12+「闹钟和提醒」特殊权限（不授予 → 精确调度退化为不精确，可能延迟几分钟）；
  /// - batteryOptimizationOff：已忽略电池优化（未忽略 → Doze 下闹钟可能被延后）；
  /// - fullScreenIntent：Android 14+ 全屏通知（不授予 → 「闹钟」只弹横幅不锁屏全屏）。
  ///
  /// ⚠️ 新增判定项时**同时更新** `reminder_list_page.dart` 的守护卡与 `NotificationService` 文档，
  /// 避免「页面少一项、用户以为都开了」。
  static Future<({
    bool notifications,
    bool exactAlarm,
    bool batteryOptimizationOff,
    bool fullScreenIntent,
  })>
  checkCapabilities() async {
    final notifications = await Permission.notification.isGranted;
    final exactAlarm = await exactAlarmAllowed;
    final batteryOptimizationOff = await sys.isIgnoringBatteryOptimizations();
    final fullScreenIntent = await sys.canUseFullScreenIntent();
    return (
      notifications: notifications,
      exactAlarm: exactAlarm,
      batteryOptimizationOff: batteryOptimizationOff,
      fullScreenIntent: fullScreenIntent,
    );
  }

  /// 取消单条通知（含其定时计划）
  static Future<void> cancel(int id) => AwesomeNotifications().cancel(id);

  /// **立即**弹出一条通知（无定时计划）——前台「到点提示音 + 横幅」用。
  ///
  /// 用途：番茄钟在页面内计时，阶段完成时 App 在前台，此时用本方法借
  /// 「番茄钟」渠道（`playSound: true`）**发出真实提示音**并弹一条横幅，
  /// 不依赖系统「触摸音效」开关（`SystemSound.play` 在关闭触摸音效的机器上无声）。
  /// [id] 传稳定 id（`stableId`），重复调用会**替换**同 id 的上一条，不堆积。
  static Future<void> showNow({
    required int id,
    required String channelKey,
    required String title,
    required String body,
  }) {
    return AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        category: NotificationCategory.Reminder,
      ),
    );
  }

  /// 稳定 int id：用 FNV-1a 哈希，跨进程/重启一致，
  /// 避免 String.hashCode 在 App 重启后变化导致无法按 id 取消。
  static int stableId(String id) {
    var h = 0x811c9dc5;
    for (final r in id.runes) {
      h ^= r;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// 取消一条提醒的全部可能通知（每天 1 个 + 每周 7 个变体）
  static Future<void> cancelReminder(String id, {bool weekly = false}) async {
    final base = stableId(id);
    await AwesomeNotifications().cancel(base);
    if (weekly) {
      for (var w = 1; w <= 7; w++) {
        await AwesomeNotifications().cancel(base + w);
      }
    }
  }

  /// 日历式定时通知（定点/周期/每年每月通用）
  ///
  /// [precise]=true 走精确闹钟（需 Android12+ SCHEDULE_EXACT_ALARM）；
  /// [fullScreen]=true 锁屏弹全屏（闹钟体验），需配合高重要渠道，
  /// 并自动附带「稍后提醒」动作按钮（点击后 snoozeMinutes 分钟再响一次）。
  /// [extraRings]>0 时额外排 N 次「重复响铃」：每次在基准时刻上顺延 1 分钟，
  /// 通知 id 用 [id]+1000*k 区分（保证可单独取消、不与主响铃冲突）。
  static Future<void> scheduleCalendar({
    required int id,
    required String channelKey,
    required String title,
    required String body,
    int? year,
    int? month,
    int? day,
    int? weekday,
    int? hour,
    int? minute,
    int? second,
    bool repeats = false,
    bool precise = false,
    bool fullScreen = false,
    int extraRings = 0,
  }) async {
    // 精确闹钟（Android 12+ SCHEDULE_EXACT_ALARM）未授权时退化为不精确，
    // 保证提醒「一定排得上」（最多延迟几分钟），绝不再抛 SecurityException。
    final canExact = precise ? await exactAlarmAllowed : false;
    for (var k = 0; k <= extraRings; k++) {
      var m = (minute ?? 0) + k;
      var h = hour;
      while (m >= 60) {
        m -= 60;
        // hourly 场景 hour 为 null（只按分钟循环），此时仅回绕分钟、不引入小时约束
        if (h != null) h = (h + 1) % 24;
      }
      final ringId = id + k * 1000;
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: ringId,
            channelKey: channelKey,
            title: title,
            body: body,
            fullScreenIntent: fullScreen,
            category: fullScreen
                ? NotificationCategory.Alarm
                : NotificationCategory.Reminder,
            payload: fullScreen
                ? {
                    'id': '$ringId',
                    'channel': channelKey,
                    'title': title,
                    'body': body,
                  }
                : null,
          ),
          // ⚠️ actionButtons 是 createNotification 的参数，不是 NotificationContent 的
          actionButtons: fullScreen
              ? [
                  NotificationActionButton(
                    key: actionSnooze,
                    label: '稍后提醒',
                  )
                ]
              : null,
          schedule: NotificationCalendar(
            year: year,
            month: month,
            day: day,
            weekday: weekday,
            hour: h,
            minute: m,
            second: second ?? 0,
            repeats: repeats,
        preciseAlarm: canExact,
        allowWhileIdle: true,
      ),
    );
    } catch (_) {
      // 单条排程失败（权限/参数）忽略，保证其余提醒不受影响
    }
    }
  }

  /// 间隔式定时通知（周期模式：每 N 分/时/天）
  static Future<void> scheduleInterval({
    required int id,
    required String channelKey,
    required String title,
    required String body,
    required Duration interval,
    bool precise = false,
    bool fullScreen = false,
  }) async {
    final canExact = precise ? await exactAlarmAllowed : false;
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey,
          title: title,
          body: body,
          fullScreenIntent: fullScreen,
          category: fullScreen
              ? NotificationCategory.Alarm
              : NotificationCategory.Reminder,
          payload: fullScreen
              ? {
                  'id': '$id',
                  'channel': channelKey,
                  'title': title,
                  'body': body,
                }
              : null,
        ),
        // ⚠️ actionButtons 是 createNotification 的参数，不是 NotificationContent 的
        actionButtons: fullScreen
            ? [
                NotificationActionButton(
                  key: actionSnooze,
                  label: '稍后提醒',
                )
              ]
            : null,
        schedule: NotificationInterval(
          interval: interval,
          repeats: true,
          preciseAlarm: canExact,
          allowWhileIdle: true,
        ),
      );
    } catch (_) {
      // 单条排程失败（权限/参数）忽略，保证其余提醒不受影响
    }
  }

  /// 单次定点通知（如待办截止 / 一次性提醒；repeats=false 即一次性，到点触发后不再重复）
  static Future<void> scheduleOnce({
    required int id,
    required String channelKey,
    required String title,
    required String body,
    required DateTime dateTime,
    bool precise = false,
    bool fullScreen = false,
  }) async {
    final canExact = precise ? await exactAlarmAllowed : false;
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey,
          title: title,
          body: body,
          fullScreenIntent: fullScreen,
          category: fullScreen
              ? NotificationCategory.Alarm
              : NotificationCategory.Reminder,
          payload: fullScreen
              ? {
                  'id': '$id',
                  'channel': channelKey,
                  'title': title,
                  'body': body,
                }
              : null,
        ),
        // ⚠️ actionButtons 是 createNotification 的参数，不是 NotificationContent 的
        actionButtons: fullScreen
            ? [
                NotificationActionButton(
                  key: actionSnooze,
                  label: '稍后提醒',
                )
              ]
            : null,
        schedule: NotificationCalendar.fromDate(
          date: dateTime,
          repeats: false,
          preciseAlarm: canExact,
          allowWhileIdle: true,
        ),
      );
    } catch (_) {
      // 单条排程失败（权限/参数）忽略，保证其余提醒不受影响
    }
  }

  /// 通知动作回调：点击闹钟的「稍后提醒」后，[snoozeMinutes] 分钟后再响一次。
  ///
  /// 重排的通知同样带「稍后提醒」动作（fullScreen=true 自动附加），可连续贪睡；
  /// id 用 base+50000 段偏移，避开主响铃 id 与重复响铃的 id+1000*k 段。
  ///
  /// ⚠️ 必须为**顶层函数**（不能放在类里）：awesome_notifications 在 App 被杀后靠
  /// `PluginUtilities.getCallbackHandle` 取句柄投递动作，静态方法取不到句柄会导致
  /// 杀进程后点击「稍后提醒」无反应。
}

/// 顶层动作回调（供 awesome 在 App 被杀后通过回调句柄投递；详见上方说明）
@pragma('vm:entry-point')
Future<void> _onActionReceived(ReceivedAction action) async {
  if (action.buttonKeyPressed != NotificationService.actionSnooze) return;
  final p = action.payload ?? {};
  final baseId = int.tryParse(p['id'] ?? '') ?? action.id ?? 0;
  final channel = p['channel'] ?? NotificationChannels.alarm;
  final title = p['title'] ?? '提醒';
  final body = p['body'] ?? '';
  final alarm = channel == NotificationChannels.alarm;
  final snoozeId = baseId + 50000 + (DateTime.now().millisecond % 1000);
  await NotificationService.scheduleOnce(
    id: snoozeId,
    channelKey: channel,
    title: title,
    body: body,
    dateTime: DateTime.now().add(const Duration(minutes: NotificationService.snoozeMinutes)),
    precise: alarm,
    fullScreen: alarm,
  );
}
