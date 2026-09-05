// 番茄钟状态机模型 —— 解析 reminders(stateful) 的 states JSON 并推算当前所处状态
//
// 桌面端数据形态（reminders 表 id='pomodoro' 行）：
//   startTime: 状态机启动时刻（ms 时间戳文本）
//   states:    [{"key":"work","label":"工作","content":"","duration":23,"unit":"min"}, ...]
// 推算逻辑：按 states 顺序循环，一个周期 = 各状态时长之和；
// elapsed = now - startTime，取模得到当前状态与剩余秒数。
// ⚠️ P2 待办：与桌面端番茄钟提醒引擎逐字段比对（暂停/跳过/lock 状态处理）后再对齐细节。
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

/// 状态机解析结果
class PomodoroSnapshot {
  const PomodoroSnapshot({
    required this.currentState,
    required this.remainingSeconds,
    required this.cycleSeconds,
  });

  final PomodoroStateDef currentState;
  final int remainingSeconds;
  final int cycleSeconds;

  /// 周期内进度（0.0 ~ 1.0）
  double get progress => cycleSeconds <= 0
      ? 0
      : (currentState.durationSeconds - remainingSeconds) /
            currentState.durationSeconds;
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

/// 按启动时间推算当前状态快照
PomodoroSnapshot? computePomodoroSnapshot(
  List<PomodoroStateDef> states,
  int startMs,
  DateTime now,
) {
  if (states.isEmpty || startMs <= 0) return null;
  final cycleSeconds = states.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  if (cycleSeconds <= 0) return null;

  final elapsed = (now.millisecondsSinceEpoch - startMs) ~/ 1000;
  // 负数（时钟回拨）按 0 处理
  final inCycle = elapsed < 0 ? 0 : elapsed % cycleSeconds;

  var cursor = 0;
  for (final state in states) {
    if (inCycle < cursor + state.durationSeconds) {
      return PomodoroSnapshot(
        currentState: state,
        remainingSeconds: cursor + state.durationSeconds - inCycle,
        cycleSeconds: cycleSeconds,
      );
    }
    cursor += state.durationSeconds;
  }
  // 理论不可达，兜底回第一个状态
  return PomodoroSnapshot(
    currentState: states.first,
    remainingSeconds: states.first.durationSeconds,
    cycleSeconds: cycleSeconds,
  );
}
