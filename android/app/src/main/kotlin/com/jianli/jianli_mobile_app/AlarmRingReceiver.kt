package com.jianli.jianli_mobile_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 闹钟到点的广播接收器（`mode = alarm`）。
 *
 * 由 [AlarmScheduler] 用 `PendingIntent.getBroadcast` + `AlarmManager.setAlarmClock` 挂上，
 * 到点即触发（即使 App 被杀、系统也会派发）。收到后做三件事：
 *   ① 发一条带**全屏意图**的高优通知（[AlarmScheduler.postRingNotification]）——由**系统**负责把
 *      响铃界面 [AlarmRingActivity] 拉到前台。**这是刻意的**：见 [AlarmScheduler] 文件头关于
 *      Android 15「PendingIntent 创建者默认不委托后台启动 Activity 权限（BAL）」的说明，
 *      让系统走通知路径就不会被静默拦截。
 *   ② 立即排下一次（重复类，按 repeatSpec）——不再依赖用户点「停止」才续排，避免用户没理会就断链。
 *   ③ 处理通知上的「停止」动作（[AlarmScheduler.EXTRA_DISMISS]）：只收通知，不做别的。
 *
 * 与 [ReminderAlarmReceiver]（`mode = notify`，发普通通知）区别：本接收器走全屏意图 + 响铃界面。
 */
class AlarmRingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val code = intent.getIntExtra(AlarmScheduler.EXTRA_CODE, 0)

        // ③ 通知上的「停止」按钮
        if (intent.getBooleanExtra(AlarmScheduler.EXTRA_DISMISS, false)) {
            AlarmScheduler.cancelRingNotification(context, code)
            return
        }

        val title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: ""
        val body = intent.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: ""
        val repeatSpec = intent.getStringExtra(AlarmScheduler.EXTRA_REPEAT)
        val interval = intent.getLongExtra(AlarmScheduler.EXTRA_INTERVAL, 0L)

        // ① 响铃：全屏意图通知（系统拉起 AlarmRingActivity）
        AlarmScheduler.postRingNotification(context, code, title, body, repeatSpec, interval)

        // ② 自排下一次（一次性 repeatSpec=null → nextTrigger 返回 null，不再排）
        val next = AlarmScheduler.nextTrigger(
            System.currentTimeMillis(), repeatSpec, interval
        )
        if (next != null) {
            AlarmScheduler.schedule(
                context, code, title, body, next, repeatSpec, interval,
                AlarmScheduler.MODE_ALARM
            )
        }
    }
}
