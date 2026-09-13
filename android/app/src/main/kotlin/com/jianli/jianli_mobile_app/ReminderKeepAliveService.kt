package com.jianli.jianli_mobile_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * 到点提醒保活：常驻前台服务
 *
 * 背景：提醒走 awesome_notifications → Android AlarmManager 原生闹钟，App 被杀也能响。
 * 但部分 ROM 的省电/后台清理会在杀进程时**顺手取消**该应用已排的原生计划，于是「到点不响」。
 * 本服务的作用 = 用一条常驻的**低优先级**通知维持前台服务身份，把进程留在后台，
 * 显著降低被清理的概率（同时也让 App 在回到前台时有机会做自愈重排）。
 *
 * 声明为 `specialUse` 而非 `dataSync`：Android 15 起 dataSync 前台服务有 6 小时/天上限，
 * 超时会被系统 `onTimeout` 掐掉，不适合「长期守护」；specialUse 无时长限制。
 *
 * ⚠️ 只在用户**明示开启**时运行（提醒 → 提醒守护 → 后台保活开关），且启动动作发生在
 * App 前台（用户点开关 / App 冷启动续启），避免 Android 12+ 后台启动前台服务的限制。
 *
 * 通道：`jianli/system_actions` 的 startKeepAlive / stopKeepAlive / isKeepAliveRunning。
 */
class ReminderKeepAliveService : Service() {

    companion object {
        /** 服务是否在运行（供 Dart 侧查询；进程内存级，不跨进程重启保留） */
        @Volatile
        var isRunning: Boolean = false
            private set

        /** 常驻通知渠道（低优先级、无声、无角标，尽量不打扰） */
        private const val CHANNEL_ID = "jianli_keep_alive"

        /** 常驻通知 id（固定，重复 start 只更新不叠加） */
        private const val NOTIFICATION_ID = 91001

        /** 启动服务（前台服务需走 startForegroundService，Android 8+） */
        fun start(context: Context) {
            val intent = Intent(context, ReminderKeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** 停止服务 */
        fun stop(context: Context) {
            context.stopService(Intent(context, ReminderKeepAliveService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 必须尽快 startForeground，否则 Android 会抛 ANR / 直接杀服务
        try {
            startForeground(NOTIFICATION_ID, buildNotification())
        } catch (e: Exception) {
            // 通知权限被拒 / 系统限制时退化为普通后台服务，不崩溃
        }
        isRunning = true
        // START_STICKY：被系统回收后尽量自动重建
        return START_STICKY
    }

    // 用旧的 boolean 重载 stopForeground（API 5+ 全版本可用），避免 STOP_FOREGROUND_* 常量的版本门槛
    @Suppress("DEPRECATION")
    override fun onDestroy() {
        isRunning = false
        try {
            stopForeground(true)
        } catch (e: Exception) {
        }
        super.onDestroy()
    }

    /** 构建常驻通知（点它回到 App） */
    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
            // 必须带渠道；IMPORTANCE_LOW = 不出横幅、不响铃、可折叠
            val channel = NotificationChannel(
                CHANNEL_ID,
                "提醒守护",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持提醒在后台准时响起的常驻通知"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("渐离App 正在守护提醒")
            .setContentText("退出 App 后，提醒仍会按时响起")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }
}
