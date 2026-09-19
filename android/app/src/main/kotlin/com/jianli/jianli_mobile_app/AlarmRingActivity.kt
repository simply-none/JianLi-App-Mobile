package com.jianli.jianli_mobile_app

import android.app.Activity
import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.text.format.DateFormat
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * 全屏闹钟 Activity（「闹钟」送达的用户界面）。
 *
 * 由 [AlarmRingReceiver] 发出的**全屏意图通知**拉起：息屏 / 锁屏 / Doze 下系统会把本页带到前台并亮屏
 * （setShowWhenLocked / setTurnScreenOn / FLAG_KEEP_SCREEN_ON）。
 *
 * UI（2026-09-19 方案 B 重做）：仿厂商闹钟的浅色响铃页——
 *   - 顶部大号实时时钟（跟随系统 12/24 小时制，秒数小字跳动）+ 日期行；
 *   - 中部提醒标题 / 正文；
 *   - 底部两枚药丸大按钮：关闭（白）、稍后提醒（红）。
 * 同时补上**铃声循环播放**（系统默认闹钟铃声，USAGE_ALARM 音频流）与**循环震动**，
 * 到点体验与厂商时钟一致。全部纯代码构建，独立于 Flutter，App 被杀也能响铃与交互。
 *
 * ⚠️ 本页**不再负责重排**：下一次的计划由 [AlarmRingReceiver] 在到点那一刻就排好了
 * （这样即使用户不理会/手机不在手边，重复闹钟也不会断链）。本页只负责响铃 UI 与两个动作：
 * - 关闭：收掉响铃通知；
 * - 稍后提醒：5 分钟后再响一次（一次性）。
 */
class AlarmRingActivity : Activity() {
    private var code = 0
    private var title = ""
    private var body = ""

    // 响铃资源（onCreate 启动、停止/销毁时释放）
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    // 实时时钟（每秒刷新）
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var tvAmPm: TextView
    private lateinit var tvTime: TextView
    private lateinit var tvSec: TextView
    private lateinit var tvDate: TextView

    private val fmtTime = SimpleDateFormat("HH:mm", Locale.getDefault())
    private val fmtTime12 = SimpleDateFormat("h:mm", Locale.getDefault())
    private val fmtAmPm = SimpleDateFormat("a", Locale.getDefault())
    private val fmtSec = SimpleDateFormat("ss", Locale.getDefault())
    private val fmtDate = SimpleDateFormat("M月d日 EEEE", Locale.CHINESE)

    private val tick = object : Runnable {
        override fun run() {
            refreshClock()
            handler.postDelayed(this, 1000L)
        }
    }

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

        setContentView(buildUi())
        refreshClock()
        handler.post(tick)
        startRing()
    }

    // ---------------------------------------------------------------- 响铃

    /** 铃声（系统默认闹钟铃声循环）+ 震动（0.6s 响 / 0.5s 停 循环） */
    private fun startRing() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (uri != null) {
                val mp = MediaPlayer()
                try {
                    mp.setDataSource(this@AlarmRingActivity, uri)
                    mp.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    mp.isLooping = true
                    mp.prepare()
                    mp.start()
                    player = mp
                } catch (e: Exception) {
                    Log.e("AlarmRing", "start ringtone failed", e)
                    try {
                        mp.release()
                    } catch (_: Exception) {
                    }
                    player = null
                }
            }
        } catch (e: Exception) {
            Log.e("AlarmRing", "resolve ringtone uri failed", e)
            player = null
        }
        try {
            vibrator = obtainVibrator()
            val pattern = longArrayOf(0, 600, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e("AlarmRing", "start vibrate failed", e)
            vibrator = null
        }
    }

    private fun obtainVibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun stopRing() {
        handler.removeCallbacks(tick)
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        vibrator?.cancel()
        vibrator = null
    }

    // ---------------------------------------------------------------- UI

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density + 0.5f).toInt()

    /** 药丸按钮背景 */
    private fun pill(color: Int): GradientDrawable = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(26).toFloat()
    }

    private fun buildUi(): android.view.View {
        // 浅色渐变底（仿厂商闹钟的清爽浅色，告别黑屏）
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xFFE7F1F2.toInt(), 0xFFF7F8FA.toInt())
            )
            setPadding(dp(24), dp(72), dp(24), dp(28))
        }

        // —— 时钟区：下午 6:08 09 ——
        val clockRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER_HORIZONTAL
        }
        tvAmPm = TextView(this).apply {
            setTextColor(0xFF5F6368.toInt())
            textSize = 20f
            setPadding(0, 0, dp(8), dp(6))
        }
        tvTime = TextView(this).apply {
            setTextColor(0xFF1A1C1E.toInt())
            textSize = 76f
            typeface = Typeface.create("sans-serif-light", Typeface.BOLD)
        }
        tvSec = TextView(this).apply {
            setTextColor(0xFF9AA0A6.toInt())
            textSize = 20f
            setPadding(dp(6), 0, 0, dp(8))
        }
        clockRow.addView(tvAmPm)
        clockRow.addView(tvTime)
        clockRow.addView(tvSec)

        tvDate = TextView(this).apply {
            setTextColor(0xFF5F6368.toInt())
            textSize = 17f
            setPadding(0, dp(4), 0, 0)
        }

        root.addView(clockRow)
        root.addView(tvDate)

        // —— 提醒信息（垂直居中区域）——
        val info = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
            )
        }
        info.addView(TextView(this).apply {
            text = if (title.isEmpty()) "闹钟" else title
            setTextColor(0xFF1A1C1E.toInt())
            textSize = 26f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })
        if (body.isNotEmpty()) {
            info.addView(TextView(this).apply {
                text = body
                setTextColor(0xFF80868B.toInt())
                textSize = 15f
                gravity = Gravity.CENTER
                setPadding(dp(16), dp(10), dp(16), 0)
            })
        }
        root.addView(info)

        // —— 按钮区：关闭（白） / 稍后提醒（红）——
        val btnRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val stop = Button(this).apply {
            text = "关闭"
            textSize = 17f
            setTextColor(0xFF1A1C1E.toInt())
            background = pill(0xFFFFFFFF.toInt())
            stateListAnimator = null
            layoutParams = LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                marginEnd = dp(12)
            }
            setOnClickListener { dismissAlarm(false) }
        }
        val snooze = Button(this).apply {
            text = "稍后提醒"
            textSize = 17f
            setTextColor(0xFFFFFFFF.toInt())
            background = pill(0xFFFA5150.toInt())
            stateListAnimator = null
            layoutParams = LinearLayout.LayoutParams(0, dp(52), 1f)
            setOnClickListener { dismissAlarm(true) }
        }
        btnRow.addView(stop)
        btnRow.addView(snooze)
        root.addView(btnRow)
        return root
    }

    /** 刷新时钟（每秒）：12/24 小时制跟随系统，秒数小字跳动 */
    private fun refreshClock() {
        val cal = Calendar.getInstance()
        val now = Date(cal.timeInMillis)
        val is24 = DateFormat.is24HourFormat(this)
        if (is24) {
            tvAmPm.visibility = android.view.View.GONE
            tvTime.text = fmtTime.format(now)
        } else {
            tvAmPm.visibility = android.view.View.VISIBLE
            tvAmPm.text = fmtAmPm.format(now)
            tvTime.text = fmtTime12.format(now)
        }
        tvSec.text = fmtSec.format(now)
        tvDate.text = fmtDate.format(now)
    }

    // ---------------------------------------------------------------- 动作

    private fun dismissAlarm(snooze: Boolean) {
        stopRing()
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
        // 关闭：下一次已由 AlarmRingReceiver 在到点时排好（见类注释），这里只需收掉响铃通知
        AlarmScheduler.cancelRingNotification(this, code)
        finish()
    }

    override fun onBackPressed() {
        // 不允许返回键关闭，必须点「关闭」或「稍后提醒」
    }

    override fun onDestroy() {
        // 兜底：任何路径离开本页都停铃（noHistory + finish 双保险之外的安全网）
        stopRing()
        super.onDestroy()
    }
}
