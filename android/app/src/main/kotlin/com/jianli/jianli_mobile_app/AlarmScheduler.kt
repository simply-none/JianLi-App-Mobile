package com.jianli.jianli_mobile_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

/**
 * 原生闹钟调度器（「闹钟」+ 周期「通知」送达的核心）。
 *
 * 为什么用原生 AlarmManager.setAlarmClock 而不是 awesome_notifications 的 preciseAlarm / NotificationInterval：
 * - setAlarmClock 是 Android 专门给「用户闹钟」的通路：**不需要 SCHEDULE_EXACT_ALARM 权限**、
 *   息屏与 Doze 下必响、系统持有计划（连 App 被杀也能到点触发）；
 * - 而 awesome 的 preciseAlarm 在 Android 12+ 未授权会抛 SecurityException；周期通知的
 *   NotificationInterval 则会在 Doze/省电下被节流并自我停摆（典型表现：只响 2 次就停、间隔不准）。
 *   「周期 + 通知送达」此前就走 NotificationInterval，正是用户报的「1 分钟提醒弹 2 次就停」根因，
 *   故一并改走原生桥。
 *
 * 重复类（每天/每周/每月/每年/间隔）在触发时由本调度器按 repeatSpec 自行排下一次：
 * - alarm 模式：AlarmRingActivity 用户点「停止」时排下次（见 AlarmRingActivity.dismissAlarm）；
 * - notify 模式：ReminderAlarmReceiver 收到广播即发通知并自排下次（无需用户操作）。
 *
 * 与原生通道 jianli/system_actions 的 setAlarmClock / cancelAlarmClock 共用本对象。
 */
object AlarmScheduler {
    private const val ACTION_PREFIX = "com.jianli.jianli_mobile_app.ALARM_RING"
    const val EXTRA_CODE = "code"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_REPEAT = "repeat"
    const val EXTRA_INTERVAL = "interval"
    const val EXTRA_MODE = "mode"

    /** 闹钟送达：拉起全屏 AlarmRingActivity */
    const val MODE_ALARM = "alarm"

    /** 通知送达：发普通系统通知（不弹全屏），由 ReminderAlarmReceiver 处理 */
    const val MODE_NOTIFY = "notify"

    /** 周期「通知」送达使用的原生通知渠道 */
    private const val NOTIFY_CHANNEL_ID = "reminder_notify"

    /** 构造指向目标组件的 Intent（requestCode=code 保证每条闹钟 PendingIntent 唯一） */
    private fun buildIntent(
        context: Context,
        code: Int,
        title: String,
        body: String,
        repeatSpec: String?,
        interval: Long,
        mode: String
    ): Intent {
        val target = if (mode == MODE_NOTIFY) ReminderAlarmReceiver::class.java
        else AlarmRingActivity::class.java
        return Intent(context, target).apply {
            action = "$ACTION_PREFIX.$code"
            putExtra(EXTRA_CODE, code)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            if (repeatSpec != null) putExtra(EXTRA_REPEAT, repeatSpec)
            putExtra(EXTRA_INTERVAL, interval)
            putExtra(EXTRA_MODE, mode)
        }
    }

    /** 排一条系统级闹钟（setAlarmClock；mode 决定响时拉起 Activity 还是发普通通知） */
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
        val intent = buildIntent(context, code, title, body, repeatSpec, interval, mode)
        val pi = if (mode == MODE_NOTIFY) {
            PendingIntent.getBroadcast(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getActivity(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val info = AlarmManager.AlarmClockInfo(triggerAt, pi)
        am.setAlarmClock(info, pi)
    }

    /** 取消一条系统级闹钟：同时按 alarm/notify 两种 PendingIntent 形态取消（按 code 重建后 cancel） */
    fun cancel(context: Context, code: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intentA = buildIntent(context, code, "", "", null, 0L, MODE_ALARM)
        am.cancel(
            PendingIntent.getActivity(
                context,
                code,
                intentA,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        val intentB = buildIntent(context, code, "", "", null, 0L, MODE_NOTIFY)
        am.cancel(
            PendingIntent.getBroadcast(
                context,
                code,
                intentB,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
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

    /** 发一条普通系统通知（周期「通知」送达用；点击打开 App 首页） */
    fun postNotification(context: Context, code: Int, title: String, body: String) {
        ensureNotifyChannel(context)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPi = PendingIntent.getActivity(
            context,
            code,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
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
}
