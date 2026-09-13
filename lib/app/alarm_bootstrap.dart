// 到点提醒引导程序（AlarmBootstrap）—— App 启动 / 回到前台时统一重排「到点通知」
//
// 背景：awesome_notifications 的计划存原生 AlarmManager 层（App 被杀也能触发），
// 但系统可能清理原生计划、设备会重启、倒计时还有「跨零补账」需求 ——
// 这些兜底原来只在「进入提醒页」时做，用户不开页面就失效。
//
// 两个入口：
//   bootstrapAlarms(db)   —— App 根组件**首帧后**跑一次：权限 + 自愈重排 + 保活续启；
//   healAlarmSchedules(db)—— App **回到前台**时跑（app.dart，5 分钟节流）：只做自愈部分。
// 之所以把「自愈」单独拆出来：ROM 清理掉原生计划后，用户**随手打开一次 App 就自动恢复**，
// 这是性价比最高的兜底；而申请权限只该在冷启动做（回前台反复申请会骚扰用户）。
//
// 分步 try/catch：任何一步失败不影响其余链路。
//
// ⚠️ 2026-09-13 起**番茄钟不再有启动步骤**：移动端番茄钟改为页面内本地计时
// （见 features/pomodoro/components/pomodoro_page.dart），不再排「阶段边界」原生通知、
// 不再读 reminders.startTime，故原来的第 ④ 步已删除。
import '../core/android/system_actions.dart';
import '../core/db/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../features/countdown/repositories/countdown_repository.dart';
import '../features/reminder/repositories/reminder_repository.dart';

/// App 启动引导（根组件首帧后调用一次；db = 全局单例 `appDatabaseProvider`）
Future<void> bootstrapAlarms(AppDatabase db) async {
  // ① 通知运行时权限：Android 13+ 首启弹系统授权框（已授权则静默通过）
  try {
    await NotificationService.requestPermission();
  } catch (_) {}
  // ②③ 提醒重排 + 倒计时补账（自愈）
  await healAlarmSchedules(db);
  // ④ 后台保活续启：用户开过「后台保活」但服务没在跑（进程重启过）→ 拉起常驻服务。
  //    只能在 App 前台做（Android 12+ 禁止后台启动前台服务），首帧正是前台，安全。
  try {
    await KeepAliveGuard(db).ensureRunning();
  } catch (_) {}
}

/// 到点提醒自愈（**不申请权限**，可安全地反复调用；调用方负责节流）。
///
/// 覆盖两类失效：
///   ① 提醒计划被系统/ROM 清理 → `rescheduleAll()` 按库重建全部启用提醒的原生计划；
///   ② App 被杀期间倒计时已到点但库里仍标 running → `sweepExpired()` 补写 finished。
Future<void> healAlarmSchedules(AppDatabase db) async {
  try {
    await ReminderRepository(db).rescheduleAll();
  } catch (_) {}
  try {
    await CountdownRepository(db).sweepExpired();
  } catch (_) {}
}
