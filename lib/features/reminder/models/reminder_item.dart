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
    required this.delivery,
    required this.month,
    required this.dayOfMonth,
    required this.statesSummary,
    required this.loop,
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
      delivery: row.delivery ?? 'notification',
      month: row.month,
      dayOfMonth: row.dayOfMonth,
      loop: row.loop ?? '1',
      statesSummary: states.isEmpty ? null : '${states.length} 个状态',
    );
  }

  /// 不可变更新（启停 / 编辑保存时用）
  ReminderItem copyWith({
    String? id,
    String? mode,
    String? title,
    String? content,
    bool? enabled,
    List<int>? weekDays,
    String? time,
    String? date,
    String? repeat,
    String? interval,
    String? unit,
    String? idleTime,
    String? source,
    String? delivery,
    String? month,
    String? dayOfMonth,
    String? statesSummary,
    String? loop,
  }) =>
      ReminderItem(
        id: id ?? this.id,
        mode: mode ?? this.mode,
        title: title ?? this.title,
        content: content ?? this.content,
        enabled: enabled ?? this.enabled,
        weekDays: weekDays ?? this.weekDays,
        time: time ?? this.time,
        date: date ?? this.date,
        repeat: repeat ?? this.repeat,
        interval: interval ?? this.interval,
        unit: unit ?? this.unit,
        idleTime: idleTime ?? this.idleTime,
        source: source ?? this.source,
        delivery: delivery ?? this.delivery,
        month: month ?? this.month,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        statesSummary: statesSummary ?? this.statesSummary,
        loop: loop ?? this.loop,
      );

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

  /// 每年/每月定点：月（yearly 用，1-12）
  final String? month;

  /// 每年/每月定点：日（monthly/yearly 用，1-31）
  final String? dayOfMonth;

  /// 周期间隔 + 单位（interval 模式）
  final String? interval;
  final String? unit;

  /// 免打扰时段 JSON 原文
  final String? idleTime;
  final String source;

  /// 送达方式：'notification'（系统通知）/ 'alarm'（闹钟：精确+全屏）
  final String delivery;

  /// 状态序列是否循环（stateful 用；默认 '1'）
  final String loop;

  /// stateful 模式的状态摘要
  final String? statesSummary;

  bool get isStateful => mode == 'stateful';

  /// 是否为闹钟送达（精确+全屏）
  bool get isAlarm => delivery == 'alarm';

  /// 送达方式中文标签
  String get deliveryLabel => isAlarm ? '闹钟' : '通知';

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

  /// 重复方式中文标签（覆盖 hourly/yearly 等 time 模式的细分，列表副标题用）
  String get repeatLabel {
    switch (repeat) {
      case 'daily':
        return '每天';
      case 'weekly':
        return weekDays.isEmpty ? '每周' : '每周${weekDays.length}天';
      case 'once':
        return '一次性';
      case 'monthly':
        return '每月';
      case 'hourly':
        return '每小时';
      case 'yearly':
        return '每年';
      default:
        return modeLabel;
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
