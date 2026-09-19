// P0-2 桌面小组件「渐离·今日」—— 快照写入
//
// 数据流：dashboardStatsProvider 每次算出新统计（首页进页 / 切回 / 回前台自动刷新，
// 见 dashboard_page）→ 本函数把人话快照写进 SharedPreferences（home_widget 桥）
// → 触发 APPWIDGET_UPDATE → 原生 TodayWidgetProvider.onUpdate 读取渲染。
//
// ⚠️ 快照键（w_updated/w_todos/w_habits/w_focus/w_countdown）与 Kotlin 侧
// TodayWidgetProvider 是双端契约，改键必须两端同步。任何失败静默吞掉——
// 小组件是「锦上添花」能力，绝不影响 App 主流程。
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import 'providers/dashboard_providers.dart';

const _androidWidgetName = 'TodayWidgetProvider';

/// 把首页聚合统计写入桌面小组件快照并触发重绘（非 Android 直接跳过）
Future<void> updateTodayWidget(DashboardStats s) async {
  if (!Platform.isAndroid) return;
  try {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    await HomeWidget.saveWidgetData<String>('w_updated', '$hh:$mm 更新');

    final todosDone = s.todosTotal - s.todosActive;
    await HomeWidget.saveWidgetData<String>(
      'w_todos',
      s.todosTotal == 0
          ? '待办 · 今天没有待办'
          : '待办 · $todosDone/${s.todosTotal} 完成，剩 ${s.todosActive} 项',
    );
    await HomeWidget.saveWidgetData<String>(
      'w_habits',
      s.habitsTotal == 0 ? '习惯 · 还没有习惯' : '习惯 · ${s.habitProgressLabel} 已打卡',
    );
    await HomeWidget.saveWidgetData<String>(
      'w_focus',
      s.pomodoroToday == 0
          ? '专注 · 今日还没开始'
          : '专注 · 今日 ${s.pomodoroToday} 轮 · ${s.pomodoroTodayMinutes} min',
    );
    final countdown = (s.nextCountdownName != null && s.nextCountdownEndMs != null)
        ? '倒计时 · ${s.nextCountdownName} ${_fmtRemaining(s.nextCountdownEndMs!)}'
        : '';
    await HomeWidget.saveWidgetData<String>('w_countdown', countdown);

    // 触发原生 onUpdate 重渲染（组件名与 manifest 的 receiver 同名）
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  } catch (_) {
    // 快照失败不影响 App（组件会显示 Kotlin 侧的占位文案）
  }
}

/// 倒计时剩余的人话格式：X天Y小时 / X小时Y分 / X分钟
String _fmtRemaining(int endMs) {
  final diff = endMs - DateTime.now().millisecondsSinceEpoch;
  if (diff <= 0) return '已到点';
  final d = Duration(milliseconds: diff);
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '剩$days天$hours小时';
  if (hours > 0) return '剩$hours小时$minutes分';
  return '剩$minutes分钟';
}
