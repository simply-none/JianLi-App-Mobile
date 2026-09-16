package com.jianli.jianli_mobile_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.util.Calendar

/**
 * 原生闹钟调度器（「闹钟」送达的核心）。
 *
 * 为什么用原生 AlarmManager.setAlarmClock 而不是 awesome_notifications 的 preciseAlarm：
 * - setAlarmClock 是 Android 专门给「用户闹钟」的通路：**不需要 SCHEDULE_EXACT_ALARM 权限**、
 *   息屏与 Doze 下必响、其 showIntent 在到点时直接把锁屏上的全屏 Activity 带到前台；
 * - 而 preciseAlarm 走 setExactAndAllowWhileIdle，Android 12+ 未授权 SCHEDULE_EXACT_ALARM 会抛
 *   SecurityException，正是「闹钟从未响」的主因。
 *
 * 重复类（每天/每周/每月/每年/间隔）在 AlarmRingActivity 用户点「停止」时，由本调度器按
 * repeatSpec 自行排下一次（见 nextTrigger），因此即使 App 被杀也能持续响。
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

    /** 构造指向 AlarmRingActivity 的 Intent（requestCode=code 保证每条闹钟 PendingIntent 唯一） */
    private fun buildIntent(
        context: Context,
        code: Int,
        title: String,
        body: String,
        repeatSpec: String?,
        interval: Long
    ): Intent {
        return Intent(context, AlarmRingActivity::class.java).apply {
            action = "$ACTION_PREFIX.$code"
            putExtra(EXTRA_CODE, code)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            if (repeatSpec != null) putExtra(EXTRA_REPEAT, repeatSpec)
            putExtra(EXTRA_INTERVAL, interval)
        }
    }

    /** 排一条系统级闹钟（setAlarmClock） */
    fun schedule(
        context: Context,
        code: Int,
        title: String,
        body: String,
        triggerAt: Long,
        repeatSpec: String?,
        interval: Long
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = buildIntent(context, code, title, body, repeatSpec, interval)
        val pi = PendingIntent.getActivity(
            context,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val info = AlarmManager.AlarmClockInfo(triggerAt, pi)
        am.setAlarmClock(info, pi)
    }

    /** 取消一条系统级闹钟（按 code 重建同一 PendingIntent 后 cancel） */
    fun cancel(context: Context, code: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = buildIntent(context, code, "", "", null, 0L)
        val pi = PendingIntent.getActivity(
            context,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
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
}
