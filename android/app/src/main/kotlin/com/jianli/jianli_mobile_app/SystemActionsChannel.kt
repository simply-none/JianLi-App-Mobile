package com.jianli.jianli_mobile_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.AlarmClock
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * 到点提醒保活：系统能力通道（`jianli/system_actions`）
 *
 * 为什么单开一个通道：这几项都是 Dart 侧 permission_handler 覆盖不到的「系统能力」——
 *   - 忽略电池优化：permission_handler 能申请（走 `Permission.ignoreBatteryOptimizations`），
 *     但查询口径需要原生 PowerManager 兜底；
 *   - 全屏意图：Android 14+ 的 `NotificationManager.canUseFullScreenIntent()` permission_handler 没有，
 *     跳转页 `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` 也必须原生拉起；
 *   - 前台服务保活：见 ReminderKeepAliveService。
 *
 * 方法（全部返回同步布尔，失败一律 false，调用方据此降级，不抛异常给 Dart）：
 * - isIgnoringBatteryOptimizations() → 是否已在系统「电池优化」白名单
 * - canUseFullScreenIntent()        → 「全屏通知」是否可用（API<34 恒 true）
 * - openFullScreenIntentSettings()  → 跳「全屏通知」开关页（API<34 退化为应用详情页）
 * - startKeepAlive()                → 启动常驻前台服务
 * - stopKeepAlive()                 → 停止常驻前台服务
 * - isKeepAliveRunning()            → 服务是否在运行
 */
object SystemActionsChannel {

    private const val CHANNEL = "jianli/system_actions"

    // SDK stub（API 34~37 的 android.jar 均如此）没有 AlarmClock.EXTRA_ALARM_SEARCH_MODE_TIME
    // 这个编译期字段，但它是 AOSP「时钟合同」的公开常量，值固定不变，按值内联。
    // extra 值可为 Long（epoch ms）或 String（HH:mm），AOSP DeskClock 两种都认。
    private const val EXTRA_ALARM_SEARCH_MODE_TIME = "android.intent.extra.alarm.TIME"

    // ⚠️ 参数用 android.app.Activity 而非 FlutterActivity：P1-1 起 MainActivity 是
    // FlutterFragmentActivity（为 local_auth 的 BiometricPrompt），它与 FlutterActivity 是
    // **兄弟类**（前者继承 FragmentActivity），钉 FlutterActivity 会编译不过。
    // 本通道只用 Context 级 API（startActivity / 系统服务），Activity 够用。
    fun register(activity: android.app.Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations(activity))

                    "canUseFullScreenIntent" ->
                        result.success(canUseFullScreenIntent(activity))

                    "openFullScreenIntentSettings" ->
                        result.success(openFullScreenIntentSettings(activity))

                    "startKeepAlive" -> {
                        ReminderKeepAliveService.start(activity)
                        result.success(true)
                    }

                    "stopKeepAlive" -> {
                        ReminderKeepAliveService.stop(activity)
                        result.success(true)
                    }

                    "isKeepAliveRunning" ->
                        result.success(ReminderKeepAliveService.isRunning)

                    // P0-4 快捷动作：拉走 MainActivity 暂存的 quick_action extra（取走即清空，
                    // 重复调用返回 null）。App 冷启动 postFrame 与回前台 resumed 各轮询一次
                    "takeQuickAction" -> {
                        val action = MainActivity.pendingQuickAction
                        MainActivity.pendingQuickAction = null
                        result.success(action)
                    }

                    // 闹钟级送达：原生 setAlarmClock（息屏/Doze 必响、锁屏全屏、无需 SCHEDULE_EXACT_ALARM）
                    "setAlarmClock" -> {
                        // ⚠️ 数字参数一律按 Number 读再转 Long/Int：Flutter 的 StandardMessageCodec
                        // 会把 int32 范围内的 Dart int 编成 Java Integer、超范围才编成 Long。
                        // 若写死 `call.argument<Long>`，收到 Integer 会在 checkcast 处抛
                        // ClassCastException，被下方 catch 吞成 false → 原生闹钟永远排不上
                        //（表现＝周期提醒 + 闹钟送达「完全不响」）。Number 对 Int/Long 都兼容。
                        val code = call.argument<Number>("code")?.toInt() ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val triggerAt = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
                        val repeatSpec = call.argument<String>("repeatSpec")
                        val interval = call.argument<Number>("intervalMillis")?.toLong() ?: 0L
                        // mode: 'alarm'=全屏 Activity；'notify'=普通系统通知（见 AlarmScheduler）
                        val mode = call.argument<String>("mode") ?: AlarmScheduler.MODE_ALARM
                        // ⚠️ 成败必须由原生如实回传：此前这里恒 `success(true)`，
                        // 而 AlarmScheduler.schedule 内部失败是静默 return ⇒ Dart 以为原生已接手、
                        // 不回退 awesome ⇒ 「先取消再重排」后提醒彻底消失（2026-09-18 修复）。
                        if (triggerAt <= 0L) {
                            result.success(false)
                        } else {
                            result.success(
                                AlarmScheduler.schedule(
                                    activity, code, title, body, triggerAt, repeatSpec, interval, mode
                                )
                            )
                        }
                    }

                    "cancelAlarmClock" -> {
                        val code = call.argument<Number>("code")?.toInt() ?: 0
                        AlarmScheduler.cancel(activity, code)
                        result.success(true)
                    }

                    // 诊断快照：「提醒为什么没响」的取证口（排程条数 / 系统下一个闹钟 /
                    // standby bucket / 省电 / Doze / 保活）。详见 AlarmScheduler.diagnostics。
                    "alarmDiagnostics" ->
                        result.success(AlarmScheduler.diagnostics(activity))

                    // 路线 2（2026-09-19）：把重复闹钟写入**系统时钟 App**（ACTION_SET_ALARM）。
                    // 厂商时钟是系统应用，任何 ROM 都不会扣它 —— 真机实证自建 setAlarmClock
                    // 计划「系统认账仍被扣」，系统时钟闹钟是唯一绕开的通路。
                    // 详见本文件 setSystemClockAlarm(...) 注释。
                    "setSystemClockAlarm" -> {
                        val key = call.argument<String>("key") ?: ""
                        val hour = call.argument<Number>("hour")?.toInt() ?: 0
                        val minute = call.argument<Number>("minute")?.toInt() ?: 0
                        val message = call.argument<String>("message") ?: ""
                        val daysPc = call.argument<List<*>>("daysPc")
                            ?.mapNotNull { (it as? Number)?.toInt() }
                            ?: emptyList()
                        result.success(
                            setSystemClockAlarm(activity, key, hour, minute, message, daysPc)
                        )
                    }

                    // 路线 2 收口（2026-09-19）：登记表对账 + 清理孤儿时钟闹钟。
                    // 删除/停用/改时间后，旧时钟闹钟必须跟着撤 —— 详见 removeSystemClockAlarm。
                    "listSystemClockAlarms" ->
                        result.success(listSystemClockAlarms(activity))

                    "removeSystemClockAlarm" -> {
                        val key = call.argument<String>("key") ?: ""
                        val hour = call.argument<Number>("hour")?.toInt() ?: 0
                        val minute = call.argument<Number>("minute")?.toInt() ?: 0
                        result.success(removeSystemClockAlarm(activity, key, hour, minute))
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                // 任何原生异常都降级为 false，让 Dart 侧走保守分支；并打日志便于定位静默失效
                Log.e("SystemActionsChannel", "method ${call.method} failed", e)
                result.success(false)
            }
        }
    }

    /** 写入系统时钟的闹钟登记表（key -> "h|m|days"，用于同参数去重，防 rescheduleAll 反复建） */
    private const val CLOCK_ALARM_PREF = "jianli_clock_alarms"

    /**
     * 路线 2（2026-09-19）：把重复闹钟写入**系统时钟 App**（`AlarmManager.ACTION_SET_ALARM`）。
     *
     * 为什么：真机实证（排程 9 条 + 系统认账 + 分组豁免 + FGS 运行中）锁屏/切后台仍不响，
     * 即 ROM 会扣住第三方 App 的到点广播；而厂商时钟是**系统应用**，任何 ROM 都不会扣它 ——
     * 这是公开 API 里唯一「绕开 ROM 管制」的闹钟通路。需要 manifest 声明
     * `com.android.alarm.permission.SET_ALARM`，`EXTRA_SKIP_UI` 才能静默写入不弹时钟界面。
     *
     * 参数：
     * - [key] 稳定键（提醒 id），用于登记表同参数去重 —— rescheduleAll 每次开 App 都会跑，
     *   **绝不能**每次都新建一条时钟闹钟；
     * - [daysPc] PC 周几（0=周日…6=周六），换算为 Calendar 的 1..7；空列表 = 一次性
     *   （下一个该 HH:mm 触发）。
     *
     * ⚠️ **公开 API 无法枚举/删除系统时钟里的闹钟**（ACTION_DISMISS_ALARM 的 EXTRA_ALARM_IDS
     * 是时钟应用内部 id，第三方拿不到）：删除/修改提醒后，旧闹钟会留在时钟里，
     * 需用户手动删除 —— 闹钟标签统一加「渐离App·」前缀便于识别。这是路线 2 的已知代价。
     *
     * 返回 true = 已受理（含「同参数已写入过」的直接返回）。
     */
    private fun setSystemClockAlarm(
        context: Context,
        key: String,
        hour: Int,
        minute: Int,
        message: String,
        daysPc: List<Int>
    ): Boolean {
        return try {
            val prefs = context.getSharedPreferences(CLOCK_ALARM_PREF, Context.MODE_PRIVATE)
            val sig = "$hour|$minute|${daysPc.sorted().joinToString(",")}"
            if (prefs.getString(key, null) == sig) return true // 同参数已写入过，去重
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                if (message.isNotEmpty()) putExtra(AlarmClock.EXTRA_MESSAGE, message)
                if (daysPc.isNotEmpty()) {
                    // PC 周几(0=周日…6=周六) → Calendar 星期(1=周日…7=周六)
                    putExtra(AlarmClock.EXTRA_DAYS, ArrayList(daysPc.map { it % 7 + 1 }))
                }
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                putExtra(AlarmClock.EXTRA_VIBRATE, true)
            }
            context.startActivity(intent)
            prefs.edit().putString(key, sig).apply()
            Log.i("SystemActionsChannel", "system clock alarm set: key=$key sig=$sig")
            true
        } catch (e: Exception) {
            Log.e("SystemActionsChannel", "setSystemClockAlarm failed", e)
            false
        }
    }

    /**
     * 列出时钟闹钟登记表（key → hour/minute/days）。Dart 侧拿它和「现存启用中的
     * 委托型提醒」做对账，找出孤儿闹钟再逐条 removeSystemClockAlarm。
     */
    private fun listSystemClockAlarms(context: Context): List<Map<String, Any?>> {
        return try {
            val prefs = context.getSharedPreferences(CLOCK_ALARM_PREF, Context.MODE_PRIVATE)
            prefs.all.mapNotNull { (k, v) ->
                val sig = v as? String ?: return@mapNotNull null
                val p = sig.split("|")
                mapOf(
                    "key" to k,
                    "hour" to (p.getOrNull(0)?.toIntOrNull() ?: 0),
                    "minute" to (p.getOrNull(1)?.toIntOrNull() ?: 0),
                    "days" to (p.getOrNull(2)?.split(",")
                        ?.mapNotNull { it.toIntOrNull() } ?: emptyList<Int>()),
                )
            }
        } catch (e: Exception) {
            Log.e("SystemActionsChannel", "listSystemClockAlarms failed", e)
            emptyList()
        }
    }

    /**
     * 清理一条孤儿时钟闹钟（提醒已删除 / 停用 / 改时间）。
     *
     * 用标准 `AlarmClock.ACTION_DISMISS_ALARM`（API 23+，AOSP 时钟合同）+ `ALARM_SEARCH_MODE_TIME`
     * 按时间匹配撤销：AOSP DeskClock 系实现按「到点时刻的时:分相等」命中并静默撤销；
     * **OEM 时钟不一定实现该 action** —— resolveActivity 判定支持才发，不支持返回 false
     * （此时旧闹钟只能留在时钟里手动删，标签「渐离App·」前缀便于识别）。
     * 登记表条目无论支持与否都移除：孤儿不再跟踪，也绝不能被 rescheduleAll 重写回去。
     *
     * 共享同一 HH:mm 的场景由 Dart 侧对账保证：只要还有存活的委托型提醒用这个时间，
     * 就不会调到这里（时钟闹钟继续为存活提醒服务）。
     */
    private fun removeSystemClockAlarm(
        context: Context,
        key: String,
        hour: Int,
        minute: Int
    ): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_DISMISS_ALARM).apply {
                putExtra(AlarmClock.EXTRA_ALARM_SEARCH_MODE, AlarmClock.ALARM_SEARCH_MODE_TIME)
                putExtra(EXTRA_ALARM_SEARCH_MODE_TIME, nextOccurrenceMillis(hour, minute))
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            }
            val supported = intent.resolveActivity(context.packageManager) != null
            if (supported) context.startActivity(intent)
            context.getSharedPreferences(CLOCK_ALARM_PREF, Context.MODE_PRIVATE)
                .edit().remove(key).apply()
            Log.i("SystemActionsChannel", "system clock alarm removed: key=$key supported=$supported")
            supported
        } catch (e: Exception) {
            Log.e("SystemActionsChannel", "removeSystemClockAlarm failed", e)
            false
        }
    }

    /** 下一个 HH:mm 触发时刻（今天已过则明天；DISMISS 按时:分匹配，具体日期不影响命中） */
    private fun nextOccurrenceMillis(hour: Int, minute: Int): Long {
        val cal = java.util.Calendar.getInstance()
        cal.set(java.util.Calendar.HOUR_OF_DAY, hour)
        cal.set(java.util.Calendar.MINUTE, minute)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    /** 是否已忽略电池优化（Android 6 以下无此概念，恒 true） */
    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /** 「全屏通知」是否可用（Android 14 起对非闹钟类应用默认不授予） */
    private fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false
        return nm.canUseFullScreenIntent()
    }

    /** 跳系统「全屏通知」授权页；低版本退化为本应用详情页（便于找其他权限） */
    private fun openFullScreenIntentSettings(context: Context): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= 34) {
                Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:${context.packageName}")
                )
            } else {
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${context.packageName}")
                )
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
