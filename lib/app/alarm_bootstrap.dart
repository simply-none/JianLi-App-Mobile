// 到点提醒引导程序（AlarmBootstrap）—— App 启动后统一重排三类「到点通知」
//
// 背景：awesome_notifications 的计划存原生 AlarmManager 层（App 被杀也能触发），
// 但系统可能清理原生计划、设备会重启、倒计时/番茄钟还有「跨零补账」需求 ——
// 这些兜底原来只在「进入提醒页」时做，用户不开页面就失效。
// 现在统一在 App 根组件首帧后跑一次：
//   ① 通知运行时权限（Android 13+ POST_NOTIFICATIONS）；
//   ② 提醒：rescheduleAll 重排全部启用提醒（防原生计划被清理）；
//   ③ 倒计时：sweepExpired 把「running 且已到点」的行补写 finished（对齐 PC 到点写库）；
//   ④ 番茄钟：重排「下两个阶段边界」的一次性精确通知（专注↔休息到点提醒）。
// 分步 try/catch：任何一步失败不影响其余链路。
import '../core/db/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../features/countdown/repositories/countdown_repository.dart';
import '../features/pomodoro/repositories/pomodoro_repository.dart';
import '../features/reminder/repositories/reminder_repository.dart';

/// App 启动引导（根组件首帧后调用一次；db = 全局单例 `appDatabaseProvider`）
Future<void> bootstrapAlarms(AppDatabase db) async {
  // ① 通知运行时权限：Android 13+ 首启弹系统授权框（已授权则静默通过）
  try {
    await NotificationService.requestPermission();
  } catch (_) {}
  // ② 提醒：重排全部启用提醒
  try {
    await ReminderRepository(db).rescheduleAll();
  } catch (_) {}
  // ③ 倒计时：补写已到点却仍标 running 的行（App 被杀期间到点的兜底）
  try {
    await CountdownRepository(db).sweepExpired();
  } catch (_) {}
  // ④ 番茄钟：重排下两个阶段边界通知（配置缺失/未启用时内部会只做取消）
  try {
    await PomodoroRepository(db).reschedulePhaseNotifications();
  } catch (_) {}
}
