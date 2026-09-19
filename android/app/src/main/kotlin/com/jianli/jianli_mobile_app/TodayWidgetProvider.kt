package com.jianli.jianli_mobile_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * P0-2 桌面小组件「渐离·今日」。
 *
 * 数据流（单向）：Dart 侧（lib/features/home/widget_snapshot.dart）把首页聚合统计
 * 写进 SharedPreferences（HomeWidget.saveWidgetData）→ 触发 updateWidget 走
 * APPWIDGET_UPDATE 广播 → 本 Provider onUpdate 读取快照渲染 RemoteViews。
 * 原生侧**不做任何业务查询**，缺数据时展示占位文案。
 *
 * 快照键（Dart/Kotlin 双端约定，改键必须两端同步）：
 * - w_updated : 快照生成时间「HH:mm 更新」
 * - w_todos   : 待办行（如「待办 · 3 项未完成」）
 * - w_habits  : 习惯行（如「习惯 · 2/5」）
 * - w_focus   : 专注行（如「专注 · 今日 3 轮 · 105 min」；无记录 = 「专注 · 今日还没开始」）
 * - w_countdown : 倒计时行（如「倒计时 · 项目上线 剩1天2小时」；无 = 整行隐藏）
 *
 * 整体点击 → 打开 App（不做按钮级交互，那需要 RemoteViews 广播 + 状态回写，Phase 2）。
 */
class TodayWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            mgr.updateAppWidget(id, buildViews(context))
        }
    }

    /** Dart 侧 updateWidget 之外，系统还会在解锁/桌面重排时回调，一并重渲染 */
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))
        onUpdate(context, mgr, ids)
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today)

        // home_widget 0.7：getData(context) 只收 1 参、返回 SharedPreferences，再按 key 取值
        val prefs = HomeWidgetPlugin.getData(context)
        fun snap(key: String): String? = prefs.getString(key, null)

        views.setTextViewText(R.id.w_updated, snap("w_updated") ?: "")
        views.setTextViewText(R.id.w_todos, snap("w_todos") ?: "待办 · 打开 App 同步数据")
        views.setTextViewText(R.id.w_habits, snap("w_habits") ?: "习惯 · 打开 App 同步数据")
        views.setTextViewText(R.id.w_focus, snap("w_focus") ?: "专注 · 今日还没开始")
        val countdown = snap("w_countdown")
        views.setTextViewText(R.id.w_countdown, countdown ?: "")
        views.setViewVisibility(R.id.w_countdown, if (countdown.isNullOrEmpty()) android.view.View.GONE else android.view.View.VISIBLE)

        // 整体点击 → 打开 App（到首页 Dashboard，看全量统计）
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val pi = PendingIntent.getActivity(
                context, 2001, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)
        }
        return views
    }
}
