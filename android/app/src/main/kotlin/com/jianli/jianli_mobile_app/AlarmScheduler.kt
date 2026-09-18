package com.jianli.jianli_mobile_app

import android.app.ActivityOptions
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import org.json.JSONObject
import java.util.Calendar

/**
 * 原生闹钟调度器（「闹钟」送达 + 周期「通知」送达的核心）。
 *
 * 为什么用原生 AlarmManager.setAlarmClock：这是 Android 专门给「用户闹钟」的通路，
 * 息屏与 Doze 下必响、计划由系统持有（连 App 被杀也能到点触发）、状态栏会显示「下一个闹钟」。
 * 而 awesome 的 NotificationInterval 会在 Doze/省电下被节流并自我停摆（只响 2 次就停、间隔不准）。
 * ⚠️ **setAlarmClock 同样需要 SCHEDULE_EXACT_ALARM（或 USE_EXACT_ALARM）**，未授权会抛
 * SecurityException —— 故 Dart 侧必须有 awesome 兜底（见 reminder_repository.dart）。
 *
 * 到点一律由**广播**处理（不再用 PendingIntent.getActivity 直拉 Activity）：
 * - `mode = alarm` → [AlarmRingReceiver]：发一条带**全屏意图**的高优通知，由**系统**把
 *   [AlarmRingActivity] 拉到前台（锁屏/息屏直接全屏响铃；正在使用手机时先弹悬浮横幅、点开进响铃页），
 *   随后立即自排下一次（重复类不再依赖用户点「停止」）；
 * - `mode = notify` → [ReminderAlarmReceiver]：收到即发普通系统通知 + 自排下次。
 *
 * ⚠️ **为什么不再用 getActivity 直拉 Activity（2026-09-18 修复 Android 15 闹钟不响）**：
 * 本项目 `targetSdk = 36`（≥35）。Android 15 起「PendingIntent 的**创建者**默认不再委托后台启动
 * Activity 权限（BAL）」，必须用 `ActivityOptions.setPendingIntentCreatorBackgroundActivityStartMode(
 * MODE_BACKGROUND_ACTIVITY_START_ALLOWED)` 显式 opt-in；不 opt-in 时闹钟到点、系统拉起 Activity 会被
 * **静默拦截**（`setAlarmClock` 不报错、无异常，只有 logcat 里有 "Background activity launch blocked!"）。
 * Android 14 及以前创建者是**隐式**委托的，所以模拟器（AOSP 14）正常、真机（Android 15）失效。
 * 现在闹钟改由「广播 + 全屏意图通知」承担，Activity 由**系统**在通知路径上拉起（系统持有 BAL 特权），
 * 从根上绕开该限制；[balOptions] 作为第二重保险，仍用在所有 getActivity 上。
 *
 * 官方参考：https://developer.android.com/guide/components/activities/secure-bal
 */
object AlarmScheduler {
    private const val ACTION_PREFIX = "com.jianli.jianli_mobile_app.ALARM_RING"
    const val EXTRA_CODE = "code"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_REPEAT = "repeat"
    const val EXTRA_INTERVAL = "interval"
    const val EXTRA_MODE = "mode"

    /** 响铃通知上的「停止」动作（由 [AlarmRingReceiver] 处理，收掉常驻响铃通知） */
    const val EXTRA_DISMISS = "dismiss"

    /** 闹钟送达：到点由 [AlarmRingReceiver] 发全屏意图通知，系统拉起 [AlarmRingActivity] */
    const val MODE_ALARM = "alarm"

    /** 通知送达：发普通系统通知（不弹全屏），由 [ReminderAlarmReceiver] 处理 */
    const val MODE_NOTIFY = "notify"

    /** 周期「通知」送达使用的原生通知渠道 */
    private const val NOTIFY_CHANNEL_ID = "reminder_notify"

    /**
     * 「稍后提醒」请求码偏移。
     *
     * ⚠️ **必须用独立请求码**（2026-09-18）：到点时 [AlarmRingReceiver] 会**立即**用原 code 排好
     * 「下一次」重复闹钟；若贪睡仍用原 code 去 `setAlarmClock`，会因 PendingIntent 相同而**覆盖**
     * 那条下一次计划 ⇒ 重复链断掉（只再响一次，之后永不响）。故贪睡统一走 `code + SNOOZE_OFFSET`。
     */
    private const val SNOOZE_OFFSET = 1000

    /** 贪睡用的请求码（带溢出保护：code 已由 Dart 侧 stableId 掩到 0x7fffffff）。 */
    fun snoozeCode(code: Int): Int =
        if (code > Int.MAX_VALUE - SNOOZE_OFFSET) code - SNOOZE_OFFSET else code + SNOOZE_OFFSET

    /**
     * 闹钟响铃通知渠道。
     * ⚠️ 与 Dart 侧 `NotificationChannels.alarm` **共用同一个键 `alarm`**（awesome 启动时也会创建它），
     * 这样系统设置里只有一个「闹钟提醒」条目；这里再兜一次「不存在就创建」，保证 App 被杀时也发得出去。
     */
    private const val ALARM_CHANNEL_ID = "alarm"

    /** 构造投递给目标组件的 Intent（extras 会随 AlarmManager / 通知一起投递） */
    private fun buildIntent(
        context: Context,
        target: Class<*>,
        code: Int,
        title: String,
        body: String,
        repeatSpec: String?,
        interval: Long,
        mode: String
    ): Intent = Intent(context, target).apply {
        action = "$ACTION_PREFIX.$code"
        putExtra(EXTRA_CODE, code)
        putExtra(EXTRA_TITLE, title)
        putExtra(EXTRA_BODY, body)
        if (repeatSpec != null) putExtra(EXTRA_REPEAT, repeatSpec)
        putExtra(EXTRA_INTERVAL, interval)
        putExtra(EXTRA_MODE, mode)
    }

    /** 到点投递给广播接收器的 Intent */
    private fun buildReceiverIntent(
        context: Context,
        code: Int,
        title: String,
        body: String,
        repeatSpec: String?,
        interval: Long,
        mode: String
    ): Intent {
        val target = if (mode == MODE_NOTIFY) ReminderAlarmReceiver::class.java
        else AlarmRingReceiver::class.java
        return buildIntent(context, target, code, title, body, repeatSpec, interval, mode)
    }

    /** 响铃页 Intent（全屏意图通知的 contentIntent / fullScreenIntent 都指向它） */
    private fun buildRingIntent(
        context: Context,
        code: Int,
        title: String,
        body: String,
        repeatSpec: String?,
        interval: Long
    ): Intent = buildIntent(
        context, AlarmRingActivity::class.java,
        code, title, body, repeatSpec, interval, MODE_ALARM
    )

    /**
     * BAL 创建者 opt-in（Android 15 / targetSdk ≥ 35 必须）。
     *
     * 「创建者」在创建 PendingIntent 时显式委托自己的后台启动 Activity 权限，发送方（系统或通知）
     * 才能把 Activity 拉到前台；不委托则被静默拦截。API < 35 没有这个开关（旧版隐式委托），返回 null。
     */
    private fun balOptions(): Bundle? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            ActivityOptions.makeBasic().apply {
                pendingIntentCreatorBackgroundActivityStartMode =
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            }.toBundle()
        } else {
            null
        }

    /** 取/建一个指向 Activity 的 PendingIntent（withBal=false 用于取消 v1 历史遗留的那种） */
    private fun activityPi(
        context: Context,
        code: Int,
        intent: Intent,
        withBal: Boolean = true
    ): PendingIntent = if (withBal) {
        PendingIntent.getActivity(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            balOptions()
        )
    } else {
        PendingIntent.getActivity(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** 取/建一个指向广播接收器的 PendingIntent */
    private fun broadcastPi(context: Context, code: Int, intent: Intent): PendingIntent =
        PendingIntent.getBroadcast(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    /**
     * 排一条系统级闹钟。到点由广播接收器处理（见文件头 BAL 说明），不再让系统直接拉 Activity。
     */
    fun schedule(
        context: Context,
        code: Int,
        title: String,
        body: String,
        triggerAt: Long,
        repeatSpec: String?,
        interval: Long,
        mode: String = MODE_ALARM
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val operation = broadcastPi(
            context, code,
            buildReceiverIntent(context, code, title, body, repeatSpec, interval, mode)
        )
        // showIntent = 状态栏「下一个闹钟」被点开时打开的页面（用户主动点击，不受 BAL 限制）
        val showPi = activityPi(
            context, code,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        )
        am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, showPi), operation)
    }

    /**
     * 取消一条系统级闹钟：把该 code 下**所有历史形态**的 PendingIntent 都取消掉，并收掉响铃通知。
     *
     * - 当前形态：广播（alarm → [AlarmRingReceiver]；notify → [ReminderAlarmReceiver]）
     * - 贪睡形态：[snoozeCode] 的那条广播（若不取消，删掉提醒后它仍会到点响）
     * - v1 形态（2026-09-17 及以前）：getActivity 指向 [AlarmRingActivity]（**不带** BAL options）
     * 一律用 FLAG_NO_CREATE 取（不存在即返回 null 跳过），避免「为了取消反而新建一堆 PendingIntent」。
     */
    fun cancel(context: Context, code: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val noCreate = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        val legacyRing = buildRingIntent(context, code, "", "", null, 0L)
        val stale = listOf(
            PendingIntent.getBroadcast(
                context, code,
                buildReceiverIntent(context, code, "", "", null, 0L, MODE_ALARM), noCreate
            ),
            PendingIntent.getBroadcast(
                context, code,
                buildReceiverIntent(context, code, "", "", null, 0L, MODE_NOTIFY), noCreate
            ),
            PendingIntent.getActivity(context, code, legacyRing, noCreate),
            PendingIntent.getActivity(context, code, legacyRing, noCreate, balOptions())
        )
        for (pi in stale) if (pi != null) am.cancel(pi)
        cancelRingNotification(context, code)
        // 贪睡那条也一并清掉（它用独立请求码，不在上面 4 种形态里）
        val snooze = snoozeCode(code)
        PendingIntent.getBroadcast(
            context, snooze,
            buildReceiverIntent(context, snooze, "", "", null, 0L, MODE_ALARM), noCreate
        )?.let { am.cancel(it) }
        cancelRingNotification(context, snooze)
    }

    /** 重复类计算下一次触发时间（毫秒）；null = 不再重排（一次性） */
    fun nextTrigger(current: Long, repeatSpec: String?, interval: Long): Long? {
        if (repeatSpec == null) return null
        return try {
            val obj = JSONObject(repeatSpec)
            val type = obj.optString("type", "once")
            val cal = Calendar.getInstance().apply { timeInMillis = current }
            when (type) {
                "interval" -> current + if (interval > 0) interval else 60000L
                "daily" -> current + 86400000L
                "weekly" -> current + 604800000L
                "monthly" -> {
                    cal.add(Calendar.MONTH, 1)
                    cal.timeInMillis
                }
                "yearly" -> {
                    cal.add(Calendar.YEAR, 1)
                    cal.timeInMillis
                }
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    /** 确保周期「通知」送达的渠道存在（API 26+ 需显式创建；<26 由系统用默认渠道） */
    fun ensureNotifyChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        if (nm.getNotificationChannel(NOTIFY_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            NOTIFY_CHANNEL_ID,
            "渐离App 提醒",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "周期提醒的普通系统通知"
            enableLights(true)
            enableVibration(true)
            // IMPORTANCE_HIGH = 悬浮横幅（不用下拉通知栏即可看到）；锁屏也完整可见
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)
    }

    /** 确保闹钟响铃渠道存在（与 Dart 侧共用键 `alarm`，见常量注释） */
    fun ensureAlarmChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        if (nm.getNotificationChannel(ALARM_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            ALARM_CHANNEL_ID,
            "闹钟提醒",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "强提醒/闹钟，锁屏可弹全屏"
            enableLights(true)
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)
    }

    /** 发一条普通系统通知（周期「通知」送达用；点击打开 App 首页） */
    fun postNotification(context: Context, code: Int, title: String, body: String) {
        ensureNotifyChannel(context)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val tapPi = activityPi(
            context, code,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, NOTIFY_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder.setContentTitle(if (title.isEmpty()) "提醒" else title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(tapPi)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        nm.notify(code, builder.build())
    }

    /**
     * 发「闹钟响铃」通知：带**全屏意图**，由系统把 [AlarmRingActivity] 拉到前台。
     *
     * - 息屏 / 锁屏：系统直接全屏拉起响铃界面（亮屏）；
     * - 正在解锁使用中：系统先弹**悬浮横幅**，点开进响铃界面（不打断当前操作）；
     * - 通知带常驻「停止」动作：若「全屏通知」未授予（Android 14+ 非闹钟类应用默认不授予），
     *   进程也不会因为通知收不掉而卡住。
     */
    @Suppress("DEPRECATION")
    fun postRingNotification(
        context: Context,
        code: Int,
        title: String,
        body: String,
        repeatSpec: String?,
        interval: Long
    ) {
        ensureAlarmChannel(context)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val fullIntent = buildRingIntent(context, code, title, body, repeatSpec, interval)
            .apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
        val fullPi = activityPi(context, code, fullIntent)
        val dismissPi = broadcastPi(
            context, code,
            Intent(context, AlarmRingReceiver::class.java).apply {
                action = "$ACTION_PREFIX.DISMISS.$code"
                putExtra(EXTRA_CODE, code)
                putExtra(EXTRA_DISMISS, true)
            }
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ALARM_CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        builder.setContentTitle(if (title.isEmpty()) "闹钟" else title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(fullPi)
            .setFullScreenIntent(fullPi, true)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "停止", dismissPi)
        nm.notify(code, builder.build())
    }

    /** 收掉某条闹钟的响铃通知（点「停止」/「稍后提醒」，或取消提醒时调用） */
    fun cancelRingNotification(context: Context, code: Int) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        nm.cancel(code)
    }
}
