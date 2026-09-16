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
 * 由原生 AlarmManager.setAlarmClock 的 showIntent 在到点时直接拉起——息屏 / Doze / 锁屏下
 * 也能前台显示并亮屏（setShowWhenLocked / setTurnScreenOn / FLAG_SHOW_WHEN_LOCKED）。
 * 提供「停止」与「稍后提醒」两个按钮：
 * - 停止：重复类按 repeatSpec 排下一次（见 AlarmScheduler.nextTrigger）；
 * - 稍后提醒：5 分钟后再响一次（一次性）。
 *
 * 完全独立于 Flutter，因此 App 被杀 / 未启动也能正常响铃与交互。
 */
class AlarmRingActivity : Activity() {
    private var code = 0
    private var title = ""
    private var body = ""
    private var repeatSpec: String? = null
    private var interval: Long = 0L

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
        repeatSpec = intent.getStringExtra(AlarmScheduler.EXTRA_REPEAT)
        interval = intent.getLongExtra(AlarmScheduler.EXTRA_INTERVAL, 0L)

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
            // 5 分钟后再次响（一次性，repeatSpec=null）
            AlarmScheduler.schedule(
                this, code, title, body,
                System.currentTimeMillis() + 5L * 60L * 1000L, null, 0L
            )
        } else {
            // 重复类：排下一次（连杀进程也能持续）
            val next = AlarmScheduler.nextTrigger(
                System.currentTimeMillis(), repeatSpec, interval
            )
            if (next != null) {
                AlarmScheduler.schedule(this, code, title, body, next, repeatSpec, interval)
            }
        }
        finish()
    }

    override fun onBackPressed() {
        // 不允许返回键关闭，必须点「停止」或「稍后提醒」
    }
}
