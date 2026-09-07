// 同步日志（仅内存态，跟随 App 生命周期，重启即清空）
//
// 设计目标（2026-09-07）：**两端看到相同的同步日志**。
// 做法：两端对「同一次同步事件」各自记一条，且刻意产出**字面相同**的文案——
//   只描述「动作 + 表 + 行数」，不写「谁→谁」，
//   因为各端视角不同（我→对端 / 对端→我）且被动端无从得知对端平台，写了必然不一致。
//
// 动作判定两端都能独立得出，无需任何协议字段：
//   推送 = 我调用了 sendTable（主动推），**或** 我处理了 POST /sync（被动收）
//   拉取 = 我调用了 fetchTable（主动拉），**或** 我处理了 GET /export（被动供）
// 行数统一取「本次传输的行数」（接收端写入数 / 发送端导出数，正常情况相等）。
// 因此同一次事件，两端日志都是「推送 todo_list：5 行」这样完全一致的一行。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日志级别（与 PC 端 SyncLogItem.level 对齐：info / ok / error）
enum SyncLogLevel { info, ok, error }

/// 单条同步日志
class SyncLogEntry {
  const SyncLogEntry({
    required this.time,
    required this.msg,
    this.level = SyncLogLevel.info,
  });

  /// HH:MM:SS（与 PC 端 `toTimeString().slice(0, 8)` 同格式）
  final String time;

  /// 日志正文
  final String msg;

  final SyncLogLevel level;
}

/// 同步日志控制器（新 → 旧）
class SyncLogController extends Notifier<List<SyncLogEntry>> {
  @override
  List<SyncLogEntry> build() => const [];

  /// 最多保留条数（与 PC 端 useSync 的 50 条对齐）
  static const int maxEntries = 50;

  /// 追加一条日志（新在前，超出上限丢弃最旧的）
  void log(String msg, {SyncLogLevel level = SyncLogLevel.info}) {
    final now = DateTime.now().toIso8601String();
    final time = now.substring(11, 19);
    state = <SyncLogEntry>[
      SyncLogEntry(time: time, msg: msg, level: level),
      ...state.take(maxEntries - 1),
    ];
  }

  /// 清空日志
  void clear() => state = const <SyncLogEntry>[];
}

/// 全局同步日志 provider（App 生命周期内有效）
final NotifierProvider<SyncLogController, List<SyncLogEntry>> syncLogProvider =
    NotifierProvider<SyncLogController, List<SyncLogEntry>>(
      SyncLogController.new,
    );
