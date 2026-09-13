package com.jianli.jianli_mobile_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
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

    fun register(activity: FlutterActivity, messenger: BinaryMessenger) {
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

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                // 任何原生异常都降级为 false，让 Dart 侧走保守分支（提示用户手动设置）
                result.success(false)
            }
        }
    }

    /** 是否已忽略电池优化（Android 6 以下无此概念，恒 true） */
    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
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
