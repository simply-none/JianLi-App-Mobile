// 番茄钟阶段定义 —— 解析 reminders(stateful) 的 states JSON（**仅配置源**，不推算状态）
//
// 桌面端数据形态（reminders 表 id='pomodoro' 行）：
//   states: [{"key":"work","label":"专注","content":"","duration":35,"unit":"min"}, ...]
//
// ⚠️ 2026-09-13 重构：移动端计时已改为**页面内本地计时**（见 pomodoro_page.dart），
// 不再用 startTime 推算当前状态、不再依赖「下两个阶段边界」的原生通知计划。
// 故此处仅保留**阶段定义解析**（供页面取 work/rest 时长、设置弹窗回显），
// 原 `computePomodoroSnapshot` / `PomodoroSnapshot`（based on startTime % cycle）已删除。
import 'dart:convert';

/// 单个状态定义
class PomodoroStateDef {
  const PomodoroStateDef({
    required this.key,
    required this.label,
    required this.durationSeconds,
    this.content = '',
  });

  factory PomodoroStateDef.fromJson(Map<String, dynamic> json) {
    final duration = (json['duration'] as num?)?.toDouble() ?? 25;
    final unit = (json['unit'] as String?) ?? 'min';
    final seconds = unit == 'min' ? (duration * 60).round() : duration.round();
    return PomodoroStateDef(
      key: json['key'] as String? ?? 'unknown',
      label: json['label'] as String? ?? json['key'] as String? ?? '',
      durationSeconds: seconds,
      content: json['content'] as String? ?? '',
    );
  }

  final String key;
  final String label;
  final int durationSeconds;
  final String content;
}

/// 解析 states JSON 文本；空/非法返回空列表
List<PomodoroStateDef> parsePomodoroStates(String? statesJson) {
  if (statesJson == null || statesJson.isEmpty) return const [];
  try {
    final decoded = jsonDecode(statesJson);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PomodoroStateDef.fromJson)
        .where((s) => s.durationSeconds > 0)
        .toList();
  } catch (_) {
    return const [];
  }
}
