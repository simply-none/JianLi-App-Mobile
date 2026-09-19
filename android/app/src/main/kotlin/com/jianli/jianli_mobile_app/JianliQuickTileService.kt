package com.jianli.jianli_mobile_app

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import android.util.Log

/**
 * P0-4 快捷磁贴：下拉控制中心的「渐离打卡」磁贴。
 *
 * 点击行为：拉起 MainActivity 并带 `quick_action=habit` extra —— 由 MainActivity
 * 暂存（见 [MainActivity.pendingQuickAction]），Dart 侧经 SystemActionsChannel 的
 * takeQuickAction 拉走后路由到 /habit 打卡页。不直接解析/操作任何业务数据，
 * 原生侧保持「只负责拉起」的薄壳。
 *
 * 为什么用 extra + Dart 轮询而不是 deep link 插件：项目已有 SystemActionsChannel
 * 桥与 appRouter 全局路由，一条 extra 就能复用整套导航，零新增依赖。
 */
class JianliQuickTileService : TileService() {

    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("quick_action", "habit")
        }
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                // Android 14+ 起 startActivityAndCollapse(Intent) 废弃，只收 PendingIntent
                val pi = PendingIntent.getActivity(
                    this, 3001, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                startActivityAndCollapse(pi)
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        } catch (e: Exception) {
            // 磁贴点击失败静默降级（极罕见：task 启动被 ROM 拦截），打日志便于排查
            Log.e("JianliQuickTile", "tile click launch failed", e)
        }
    }
}
