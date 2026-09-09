// 本地通知封装（awesome_notifications）—— 统一提醒引擎的移动端出口
//
// 桌面端 reminders 表是统一提醒引擎（习惯/待办/番茄钟到点均来自此表）；
// 移动端策略：读取 reminders → 翻译为本地通知计划（awesome_notifications）。
// 番茄钟这类状态机型提醒需 App 前台/前台服务驱动（iOS 受限，见 flutter-port.md 第 4 节）。
//
// 送达双模式（2026-09-09 与 PC newTips 对齐）：
// - 'notification'（系统通知）：普通渠道，allowWhileIdle 息屏可响；
// - 'alarm'（闹钟）：preciseAlarm + fullScreenIntent + 高重要'alarm'渠道，
//   锁屏弹全屏、息屏精确唤醒（Android 上等价系统闹钟体验，且 App 被杀也能响）。
// 二者均走 awesome_notifications，无需引入 android_alarm_manager_plus（iOS 无等价能力）。
//
// 闹钟增强（2026-09-09，对齐 PC 提醒的「强提醒」诉求）：
// - 重复响铃：scheduleCalendar(extraRings:N) 额外排 N 次顺延 1 分钟的响铃（id+1000*k），
//   即一次闹钟连响 N+1 次，避免只响一声被错过；
// - 稍后提醒：闹钟（fullScreen=true）自动带 actionSnooze 动作按钮，点击后 snoozeMinutes
//   分钟再响一次，重排的通知仍带该按钮可连续贪睡；由 init() 注册的 onActionReceived
//   → _onActionReceived 处理，依赖 payload 透传 id/渠道/标题/内容。
import 'package:awesome_notifications/awesome_notifications.dart';

/// 通知渠道定义（与功能域一一对应，便于系统级分组管理）
class NotificationChannels {
  NotificationChannels._();

  /// 习惯打卡提醒
  static const String habit = 'habit';

  /// 待办截止/每日实例提醒
  static const String todo = 'todo';

  /// 番茄钟阶段切换
  static const String pomodoro = 'pomodoro';

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

  /// 取消单条通知（含其定时计划）
  static Future<void> cancel(int id) => AwesomeNotifications().cancel(id);

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
    for (var k = 0; k <= extraRings; k++) {
      var m = (minute ?? 0) + k;
      var h = hour;
      while (m >= 60) {
        m -= 60;
        // hourly 场景 hour 为 null（只按分钟循环），此时仅回绕分钟、不引入小时约束
        if (h != null) h = (h + 1) % 24;
      }
      final ringId = id + k * 1000;
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
          preciseAlarm: precise,
          allowWhileIdle: true,
        ),
      );
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
  }) {
    return AwesomeNotifications().createNotification(
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
        preciseAlarm: precise,
        allowWhileIdle: true,
      ),
    );
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
  }) {
    return AwesomeNotifications().createNotification(
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
        preciseAlarm: precise,
        allowWhileIdle: true,
      ),
    );
  }

  /// 通知动作回调：点击闹钟的「稍后提醒」后，[snoozeMinutes] 分钟后再响一次。
  ///
  /// 重排的通知同样带「稍后提醒」动作（fullScreen=true 自动附加），可连续贪睡；
  /// id 用 base+50000 段偏移，避开主响铃 id 与重复响铃的 id+1000*k 段。
  static Future<void> _onActionReceived(ReceivedAction action) async {
    if (action.buttonKeyPressed != actionSnooze) return;
    final p = action.payload ?? {};
    final baseId = int.tryParse(p['id'] ?? '') ?? action.id ?? 0;
    final channel = p['channel'] ?? NotificationChannels.alarm;
    final title = p['title'] ?? '提醒';
    final body = p['body'] ?? '';
    final alarm = channel == NotificationChannels.alarm;
    final snoozeId = baseId + 50000 + (DateTime.now().millisecond % 1000);
    await scheduleOnce(
      id: snoozeId,
      channelKey: channel,
      title: title,
      body: body,
      dateTime: DateTime.now().add(const Duration(minutes: snoozeMinutes)),
      precise: alarm,
      fullScreen: alarm,
    );
  }
}
