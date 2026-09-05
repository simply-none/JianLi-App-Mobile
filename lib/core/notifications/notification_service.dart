// 本地通知封装（awesome_notifications）—— 统一提醒引擎的移动端出口
//
// 桌面端 reminders 表是统一提醒引擎（习惯/待办/番茄钟到点均来自此表）；
// 移动端策略：读取 reminders → 翻译为本地通知计划（awesome_notifications）。
// 番茄钟这类状态机型提醒需 App 前台/前台服务驱动（iOS 受限，见 flutter-port.md 第 4 节）。
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

  /// 全渠道清单（初始化时统一注册）
  static List<NotificationChannel> get all => [
        NotificationChannel(
          channelKey: habit,
          channelName: '习惯提醒',
          channelDescription: '习惯打卡到点提醒',
        ),
        NotificationChannel(
          channelKey: todo,
          channelName: '待办提醒',
          channelDescription: '待办截止与重复实例提醒',
        ),
        NotificationChannel(
          channelKey: pomodoro,
          channelName: '番茄钟',
          channelDescription: '番茄钟工作/休息阶段切换提醒',
        ),
      ];
}

/// 通知服务：App 启动时初始化；具体提醒计划由各 feature 调用 schedule* 方法
class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  /// 初始化通知插件并注册全部渠道
  static Future<void> init() async {
    if (_initialized) return;
    await AwesomeNotifications().initialize(
      null, // 使用默认应用图标；后续可换 resource:resource://drawable/ic_launcher
      NotificationChannels.all,
      debug: false,
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

  /// 每天 HH:mm 定时通知（id 需调用方保证稳定，便于取消）
  static Future<void> scheduleDaily({
    required int id,
    required String channelKey,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) {
    return AwesomeNotifications().createNotification(
      content: NotificationContent(id: id, channelKey: channelKey, title: title, body: body),
      schedule: NotificationCalendar(
        hour: hour,
        minute: minute,
        second: 0,
        repeats: true,
        allowWhileIdle: true,
      ),
    );
  }

  /// 每周指定星期 HH:mm 定时通知（weekday: 1=周一 … 7=周日）
  static Future<void> scheduleWeekly({
    required int id,
    required String channelKey,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
  }) {
    return AwesomeNotifications().createNotification(
      content: NotificationContent(id: id, channelKey: channelKey, title: title, body: body),
      schedule: NotificationCalendar(
        weekday: weekday,
        hour: hour,
        minute: minute,
        second: 0,
        repeats: true,
        allowWhileIdle: true,
      ),
    );
  }
}
