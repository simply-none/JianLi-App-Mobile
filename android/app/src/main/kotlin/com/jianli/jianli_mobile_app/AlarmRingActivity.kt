package com.jianli.jianli_mobile_app

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 全屏闹钟 Activity（「闹钟」送达的用户界面）。
 *
 * 由 [AlarmRingReceiver] 发出的**全屏意图通知**拉起：息屏 / 锁屏 / Doze 下系统会把本页带到前台并亮屏
 * （setShowWhenLocked / setTurnScreenOn / FLAG_KEEP_SCREEN_ON）。
 *
 * ⚠️ 本页**不再负责重排**：下一次的计划由 [AlarmRingReceiver] 在到点那一刻就排好了
 * （这样即使用户不理会/手机不在手边，重复闹钟也不会断链）。本页只负责响铃 UI 与两个动作：
 * - 停止：收掉响铃通知；
 * - 稍后提醒：5 分钟后再响一次（一次性）。
 *
 * 完全独立于 Flutter，因此 App 被杀 / 未启动也能正常响铃与交互。
 */
class AlarmRingActivity : Activity() {
    private var code = 0
    private var title = ""
    private var body = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 息屏 / 锁屏也能前台显示并亮屏
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        code = intent.getIntExtra(AlarmScheduler.EXTRA_CODE, 0)
        title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: ""
        body = intent.getStringExtra(AlarmScheduler.EXTRA_BODY) ?: ""

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF101014.toInt())
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
        }
        val t = TextView(this).apply {
            text = if (title.isEmpty()) "闹钟" else title
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 30f
            gravity = Gravity.CENTER
        }
        val b = TextView(this).apply {
            text = body
            setTextColor(0xFFCCCCCC.toInt())
            textSize = 18f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 48)
        }
        val stop = Button(this).apply {
            text = "停止"
            setOnClickListener { dismissAlarm(false) }
        }
        val snooze = Button(this).apply {
            text = "稍后提醒"
            setOnClickListener { dismissAlarm(true) }
        }
        root.addView(t)
        root.addView(b)
        root.addView(stop)
        root.addView(snooze)
        setContentView(root)
    }

    private fun dismissAlarm(snooze: Boolean) {
        if (snooze) {
            // 5 分钟后再响一次（一次性，repeatSpec=null）。
            // ⚠️ 必须用 snoozeCode(code) 而不是 code：到点时 AlarmRingReceiver 已用原 code 排好了
            // 「下一次」重复闹钟，同码会因 PendingIntent 相同而被这条贪睡**覆盖**（重复链断掉）。
            AlarmScheduler.schedule(
                this, AlarmScheduler.snoozeCode(code), title, body,
                System.currentTimeMillis() + 5L * 60L * 1000L, null, 0L,
                AlarmScheduler.MODE_ALARM
            )
        }
        // 停止：下一次已由 AlarmRingReceiver 在到点时排好（见类注释），这里只需收掉响铃通知
        AlarmScheduler.cancelRingNotification(this, code)
        finish()
    }

    override fun onBackPressed() {
        // 不允许返回键关闭，必须点「停止」或「稍后提醒」
    }
}
