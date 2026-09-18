// 到点提醒保活：Android 系统能力 + 常驻服务偏好
//
// 背景：提醒计划存在原生 AlarmManager 层（App 被杀也能响），但系统/ROM 的省电清理会
// 连带取消这些计划，表现为「切后台或关掉 App 后到点不响」。Dart 侧能做的是：
//   ① 把「可能导致不响」的 4 项系统开关暴露成可见状态 + 一键修复入口（见 NotificationService.checkCapabilities）；
//   ② 提供「后台保活」开关 —— 用一条常驻低优先级通知维持前台服务，把进程留在后台。
//
// 本文件承载 ② 的原生通道与偏好读写；① 的权限部分在 NotificationService（permission_handler）。
//
// 通道 `jianli/system_actions`（原生实现见 android/app/.../SystemActionsChannel.kt）：
//   isIgnoringBatteryOptimizations / canUseFullScreenIntent / openFullScreenIntentSettings /
//   startKeepAlive / stopKeepAlive / isKeepAliveRunning
//
// ⚠️ 全部能力**只在 Android 生效**：非 Android（iOS/桌面/测试）一律返回「不适用」的安全值
// （权限类返回 true 表示不拦、动作类返回 false 表示没做成），绝不抛异常给调用方。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../db/app_database.dart';

const MethodChannel _kChannel = MethodChannel('jianli/system_actions');

bool get _isAndroid => Platform.isAndroid;

/// 是否已在系统「电池优化」白名单里（未优化 = 到点更不容易被 Doze 延后）。
/// 非 Android 返回 true（无此概念，视为不拦）。
Future<bool> isIgnoringBatteryOptimizations() async {
  if (!_isAndroid) return true;
  try {
    return await _kChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
        false;
  } catch (_) {
    return false;
  }
}

/// 「全屏通知」是否可用（Android 14+ 对非闹钟类应用默认不授予，未授予时「闹钟」只弹横幅不锁屏全屏）。
/// 非 Android / 低版本返回 true（无此限制）。
Future<bool> canUseFullScreenIntent() async {
  if (!_isAndroid) return true;
  try {
    return await _kChannel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
  } catch (_) {
    return true;
  }
}

/// 跳系统「全屏通知」授权页（低版本原生侧自动退化为本应用详情页）。返回是否成功拉起。
Future<bool> openFullScreenIntentSettings() async {
  if (!_isAndroid) return false;
  try {
    return await _kChannel.invokeMethod<bool>('openFullScreenIntentSettings') ??
        false;
  } catch (_) {
    return false;
  }
}

/// 原生 setAlarmClock 桥（闹钟级送达：息屏/Doze 必响、锁屏全屏）
///
/// 这是「闹钟」送达最可靠的实现：Android 的 `AlarmManager.setAlarmClock` 是专门给
/// 用户闹钟的通路，不受 Doze 延后、会在状态栏显示「下一个闹钟」。
///
/// ⚠️ **setAlarmClock 同样需要 SCHEDULE_EXACT_ALARM（或 USE_EXACT_ALARM）**（2026-09-18 依官方
/// 文档纠正：曾经误以为「用户闹钟通路」免权限）。未授权时抛 `SecurityException`，故：
///   ① 清单同时声明 `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM`（后者 Android 13+ 安装即授予）；
///   ② Dart 侧 `ReminderRepository` 仍保留 awesome 兜底（原生失败即回退，绝不静默丢提醒）。
///
/// 到点后由**广播**承接（不再用 getActivity 直拉 Activity）：`mode='alarm'` → AlarmRingReceiver
/// 发全屏意图通知，由系统拉起响铃页（绕开 Android 15 的 BAL 创建者限制）；`mode='notify'` →
/// ReminderAlarmReceiver 发普通通知。非 Android 直接返回 false（无此能力，不抛）。
///
/// [code] 稳定请求码（用 reminder 的 stableId，保证取消/重排一致）；
/// [repeatSpec] 重复规则 JSON（见 AlarmScheduler.kt），null 表示一次性；
/// [intervalMillis] `repeatSpec.type = 'interval'` 时的间隔毫秒。
Future<bool> setAlarmClock({
  required int code,
  required String title,
  required String body,
  required int triggerAtMillis,
  String? repeatSpec,
  int intervalMillis = 0,
  String mode = 'alarm',
}) async {
  if (!_isAndroid) return false;
  try {
    return await _kChannel.invokeMethod<bool>('setAlarmClock', {
          'code': code,
          'title': title,
          'body': body,
          'triggerAtMillis': triggerAtMillis,
          'repeatSpec': repeatSpec,
          'intervalMillis': intervalMillis,
          'mode': mode,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 取消单条原生闹钟（按 [code]）
Future<bool> cancelAlarmClock(int code) async {
  if (!_isAndroid) return false;
  try {
    return await _kChannel.invokeMethod<bool>('cancelAlarmClock', {'code': code}) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 批量取消原生闹钟
Future<void> cancelAlarmClocks(List<int> codes) async {
  for (final c in codes) {
    await cancelAlarmClock(c);
  }
}

/// 启动常驻前台服务（保活）。必须在 App 处于前台时调用（Android 12+ 限制），返回是否受理。
Future<bool> startKeepAlive() async {
  if (!_isAndroid) return false;
  try {
    return await _kChannel.invokeMethod<bool>('startKeepAlive') ?? false;
  } catch (_) {
    return false;
  }
}

/// 停止常驻前台服务（移除常驻通知）。
Future<bool> stopKeepAlive() async {
  if (!_isAndroid) return false;
  try {
    return await _kChannel.invokeMethod<bool>('stopKeepAlive') ?? false;
  } catch (_) {
    return false;
  }
}

/// 常驻前台服务当前是否在运行。
Future<bool> isKeepAliveRunning() async {
  if (!_isAndroid) return false;
  try {
    return await _kChannel.invokeMethod<bool>('isKeepAliveRunning') ?? false;
  } catch (_) {
    return false;
  }
}

/// 「后台保活」偏好的读写与自愈续启。
///
/// 偏好存 `basic_info` 基础键值表（与番茄钟展示效果/周期规则同表），键 `reminder_keep_alive`：
/// `'1'` = 开启（App 启动/回前台时确保常驻服务在跑），其他/缺失 = 关闭。
///
/// ⚠️ 前台服务无法开机自启（Android 12+ 禁止后台启动前台服务），所以「开启」的效果是：
/// **下次打开 App 时自动续启**；用户杀掉 App 后到下次打开之前，仍只有 AlarmManager 计划在兜底。
class KeepAliveGuard {
  KeepAliveGuard(this._db);

  final AppDatabase _db;

  /// 偏好键
  static const String kPrefKey = 'reminder_keep_alive';

  /// 是否已开启保活偏好
  Future<bool> isPreferred() async {
    final row = await (_db.select(
      _db.basicInfo,
    )..where((t) => t.key.equals(kPrefKey))).getSingleOrNull();
    return row?.value == '1';
  }

  /// 设置保活偏好：写库 + 立即启/停常驻服务（调用点必须是前台交互）。
  /// 返回「设置完成后的服务期望状态」：开 → 是否成功拉起；关 → 恒 false。
  Future<bool> setPreferred(bool on) async {
    await _db
        .into(_db.basicInfo)
        .insertOnConflictUpdate(
          BasicInfoCompanion.insert(key: kPrefKey, value: Value(on ? '1' : '0')),
        );
    if (on) return startKeepAlive();
    await stopKeepAlive();
    return false;
  }

  /// App 启动 / 回到前台时续启：偏好开着但服务没跑 → 拉起一次。
  /// 返回「此刻服务是否在运行」。
  Future<bool> ensureRunning() async {
    if (!await isPreferred()) return false;
    if (await isKeepAliveRunning()) return true;
    await startKeepAlive();
    return isKeepAliveRunning();
  }
}
