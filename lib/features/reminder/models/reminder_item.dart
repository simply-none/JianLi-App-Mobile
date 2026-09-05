// 提醒模型 —— 对齐桌面端 newReminder 引擎的三种模式
//
// 桌面端约定（references/modules/reminder.md）：
// - mode: 'time'（定点，可 repeat/weekDays 周期）/ 'interval'（周期间隔）/
//         'stateful'（多状态机，番茄钟专用，移动端只展示不调度）
// - 布尔字段 DB 均为 '1'/'0' 文本；idleTime 为免打扰时段 JSON；
// - source==='todo' 的行由待办截止提醒引擎托管，用户列表要过滤掉（get-tips 规则）。
import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../habit/models/habit.dart' show parseIntList, parseStringList;

/// 提醒条目
class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.mode,
    required this.title,
    required this.content,
    required this.enabled,
    required this.weekDays,
    required this.time,
    required this.date,
    required this.repeat,
    required this.interval,
    required this.unit,
    required this.idleTime,
    required this.source,
    required this.statesSummary,
  });

  factory ReminderItem.fromRow(Reminder row) {
    final states = parsePomodoroStatesSafe(row.states);
    return ReminderItem(
      id: row.id,
      mode: row.mode ?? 'time',
      title: row.title ?? '（未命名提醒）',
      content: row.content ?? '',
      enabled: row.enabled == '1',
      weekDays: parseIntList(row.weekDays),
      time: row.time,
      date: row.date,
      repeat: row.repeat,
      interval: row.interval,
      unit: row.unit,
      idleTime: row.idleTime,
      source: row.source ?? '',
      statesSummary: states.isEmpty ? null : '${states.length} 个状态',
    );
  }

  final String id;
  final String mode;
  final String title;
  final String content;
  final bool enabled;

  /// 定点周期：生效星期（1-7），空 = 每天
  final List<int> weekDays;

  /// 定点时刻 HH:mm
  final String? time;

  /// 一次性定点日期
  final String? date;
  final String? repeat;

  /// 周期间隔 + 单位（interval 模式）
  final String? interval;
  final String? unit;

  /// 免打扰时段 JSON 原文
  final String? idleTime;
  final String source;

  /// stateful 模式的状态摘要
  final String? statesSummary;

  bool get isStateful => mode == 'stateful';

  /// 模式的中文标签
  String get modeLabel {
    switch (mode) {
      case 'stateful':
        return '多状态';
      case 'interval':
        return '周期';
      default:
        return weekDays.isEmpty ? '每天' : '每周${weekDays.length}天';
    }
  }
}

/// 安全解析 states JSON（避免脏数据炸 UI）
List<Map<String, dynamic>> parsePomodoroStatesSafe(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  } catch (_) {
    return const [];
  }
}

/// 免打扰时段
class IdleSlot {
  const IdleSlot({required this.start, required this.end});

  factory IdleSlot.fromJson(Map<String, dynamic> json) => IdleSlot(
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
  );

  final String start;
  final String end;
}

/// 解析免打扰时段 JSON
List<IdleSlot> parseIdleSlots(String? raw) => parseStringList(raw)
    .map((e) {
      try {
        return IdleSlot.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
    .whereType<IdleSlot>()
    .toList();
