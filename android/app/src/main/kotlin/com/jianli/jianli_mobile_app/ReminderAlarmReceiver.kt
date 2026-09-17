package com.jianli.jianli_mobile_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 周期「通知」送达的广播接收器。
 *
 * 由原生 AlarmManager.setAlarmClock 在到点时触发（即使 App 被杀，系统也会派发此广播）。
 * 收到后做两件事：
 *   ① 用 NotificationManager 发一条普通系统通知（渠道见 AlarmScheduler.ensureNotifyChannel）；
 *   ② 按 repeatSpec 的 interval 类型自排下一次（连进程不在也能持续，因为计划由系统持有）。
 *
 * 与 alarm 模式（AlarmRingActivity 需用户点「停止」才排下次）不同，本接收器**无需用户操作**
 * 即可持续周期提醒，契合「每 N 分/时/天 弹一次通知」的场景。
 */
class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val code = intent.getIntExtra(AlarmScheduler.EXTRA_CODE, 0)
        val title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: ""
        val body = intent.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: ""
        val repeatSpec = intent.getStringExtra(AlarmScheduler.EXTRA_REPEAT)
        val interval = intent.getLongExtra(AlarmScheduler.EXTRA_INTERVAL, 0L)

        // ① 发普通通知
        AlarmScheduler.postNotification(context, code, title, body)

        // ② 自排下一次（重复类按 interval 累加；一次性 null 不再排）
        val next = AlarmScheduler.nextTrigger(
            System.currentTimeMillis(), repeatSpec, interval
        )
        if (next != null) {
            AlarmScheduler.schedule(
                context,
                code,
                title,
                body,
                next,
                repeatSpec,
                interval,
                AlarmScheduler.MODE_NOTIFY
            )
        }
    }
}
