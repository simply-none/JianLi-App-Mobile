// 习惯模型 —— 包装桌面端 habit_def / habit_checkin 行的解析结果
//
// 桌面端约定：布尔即 TEXT '1'/'0'；weekDays/reminderTimes 为 JSON 数组文本；
// 展示名：legacy 列 name 里存了真实习惯名（与 remark 同值），优先取 name。
import 'dart:convert';

import '../../../core/db/app_database.dart';

/// 习惯定义条目
class HabitItem {
  const HabitItem({
    required this.key,
    required this.name,
    required this.enabled,
    required this.weekDays,
    required this.reminderTimes,
    required this.freqType,
    required this.chainActions,
  });

  factory HabitItem.fromRow(HabitDefData row) {
    return HabitItem(
      key: row.key ?? '',
      name: (row.name?.isNotEmpty ?? false) ? row.name! : (row.remark ?? '未命名习惯'),
      enabled: row.enabled == '1',
      weekDays: parseIntList(row.weekDays),
      reminderTimes: parseStringList(row.reminderTimes),
      freqType: row.freqType ?? 'daily',
      chainActions: row.chainActions ?? '[]',
    );
  }

  final String key;
  final String name;
  final bool enabled;

  /// 生效星期（1-7），空 = 每天
  final List<int> weekDays;

  /// 提醒时间列表，如 ["08:39"]
  final List<String> reminderTimes;

  /// daily / weekly / ...
  final String freqType;

  /// 链式动作 JSON 原文（移动端 P2 消费）
  final String chainActions;

  /// 今天是否应打卡（weekDays 为空视为每天）
  bool isScheduledOn(DateTime date) {
    if (weekDays.isEmpty) return true;
    // Dart: Monday=1 ... Sunday=7
    return weekDays.contains(date.weekday);
  }
}

/// 解析 JSON 整数数组文本（weekDays）
List<int> parseIntList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.whereType<num>().map((e) => e.toInt()).toList();
    return const [];
  } catch (_) {
    return const [];
  }
}

/// 解析 JSON 字符串数组文本（reminderTimes）
List<String> parseStringList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((e) => e.toString()).toList();
    return const [];
  } catch (_) {
    return const [];
  }
}
