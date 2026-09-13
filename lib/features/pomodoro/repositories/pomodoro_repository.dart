// 番茄钟仓库 —— 读取 reminders(stateful) 配置 + 写状态流水
//
// reminders.id='pomodoro' 行是番茄钟的时长配置源（与桌面端一致）；
// pomodoro_status 每次「阶段完成」写一行流水，供记录弹窗/首页统计使用。
//
// ⚠️ 2026-09-13 重构（用户定案：移动端逻辑独立于 PC）：
//   计时改为**页面内本地计时**，仓库不再承担任何计时/调度职责 ——
//   `startRound`（写 startTime）/ `loadSnapshot`（按 startTime 推算）/ `reschedulePhaseNotifications`
//   （排原生 AlarmManager 阶段通知）全部删除；`updateDurations` 也不再重排通知。
//   保留：展示效果读写（basic_info）、阶段配置读写（reminders.states）、流水写入（pomodoro_status）。
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../models/pomodoro_state_machine.dart';

/// 未完成的专注进度（**仅专注阶段**会保存；phase 固定 0）
class PomodoroProgress {
  const PomodoroProgress({required this.remainingSeconds});

  /// 离开页面时专注阶段的剩余秒数
  final int remainingSeconds;
}

/// 番茄钟仓库
class PomodoroRepository {
  PomodoroRepository(this._db);

  final AppDatabase _db;

  // ===================== 展示效果（存 basic_info 基础键值表） =====================
  //
  // 展示效果是「页面观感」偏好，与 reminders 里的计时配置（states）无涉，
  // 按用户拍板放基础键值表 basic_info（key PRIMARY KEY），不与其他字段混存一表。
  // 取值：normal=普通 / clean=清爽 / landscape=横屏大字倒计时。

  /// basic_info 里的配置键
  static const String _kDisplayKey = 'pomodoro_display';

  /// 合法取值（页面侧中文标签见 pomodoro_page 的 kDisplayLabels）
  static const List<String> kDisplayModes = ['normal', 'clean', 'landscape'];

  /// 读取展示效果（未配置/非法值回退 normal）
  Future<String> loadDisplay() async {
    final row = await (_db.select(
      _db.basicInfo,
    )..where((t) => t.key.equals(_kDisplayKey))).getSingleOrNull();
    final v = row?.value;
    return kDisplayModes.contains(v) ? v! : 'normal';
  }

  /// 保存展示效果（幂等 upsert）
  Future<void> saveDisplay(String mode) async {
    assert(kDisplayModes.contains(mode), '未知展示效果: $mode');
    await _db
        .into(_db.basicInfo)
        .insertOnConflictUpdate(
          BasicInfoCompanion.insert(key: _kDisplayKey, value: Value(mode)),
        );
  }

  // ===================== 周期规则（未完成的一轮如何处置） =====================
  //
  // 规则存 basic_info（与展示效果同表，用户拍板「写入基础表」）。规则**只作用于专注阶段**：
  //   restart = 未完成重新开始（默认）：丢弃进度，下次进页面从专注满时长起；
  //   resume  = 未完成继续上一轮：把专注阶段的剩余秒数存 basic_info，下次进页面接着。
  // 未完成进度**只在「离开页面 / 切后台」时写入**，「走完一轮 / 点重新开始 / 规则切回 restart」时清除。

  /// 未完成 → 重新开始（默认）
  static const String kCycleRuleRestart = 'restart';

  /// 未完成 → 继续上一轮
  static const String kCycleRuleResume = 'resume';

  /// 合法取值（页面侧中文标签见 pomodoro_page 的 kCycleRuleLabels）
  static const List<String> kCycleRules = [kCycleRuleRestart, kCycleRuleResume];

  static const String _kCycleRuleKey = 'pomodoro_cycle_rule';
  static const String _kProgressKey = 'pomodoro_progress';

  /// 读取周期规则（未配置/非法值回退 restart）
  Future<String> loadCycleRule() async {
    final row = await (_db.select(
      _db.basicInfo,
    )..where((t) => t.key.equals(_kCycleRuleKey))).getSingleOrNull();
    final v = row?.value;
    return kCycleRules.contains(v) ? v! : kCycleRuleRestart;
  }

  /// 保存周期规则（幂等 upsert）
  Future<void> saveCycleRule(String rule) async {
    assert(kCycleRules.contains(rule), '未知周期规则: $rule');
    await _db
        .into(_db.basicInfo)
        .insertOnConflictUpdate(
          BasicInfoCompanion.insert(key: _kCycleRuleKey, value: Value(rule)),
        );
  }

  /// 读取未完成的专注进度（无记录/非法/非专注阶段返回 null）
  Future<PomodoroProgress?> loadProgress() async {
    final row = await (_db.select(
      _db.basicInfo,
    )..where((t) => t.key.equals(_kProgressKey))).getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final phase = (decoded['phase'] as num?)?.toInt() ?? -1;
      final remaining = (decoded['remaining'] as num?)?.toInt() ?? 0;
      // 只在专注阶段（phase=0）且剩余为正时有效
      if (phase != 0 || remaining <= 0) return null;
      return PomodoroProgress(remainingSeconds: remaining);
    } catch (_) {
      return null;
    }
  }

  /// 保存未完成的专注进度（remaining ≤ 0 视为「无可续进度」→ 直接清除）
  Future<void> saveProgress({required int remainingSeconds}) async {
    if (remainingSeconds <= 0) return clearProgress();
    await _db
        .into(_db.basicInfo)
        .insertOnConflictUpdate(
          BasicInfoCompanion.insert(
            key: _kProgressKey,
            value: Value(
              jsonEncode({'phase': 0, 'remaining': remainingSeconds}),
            ),
          ),
        );
  }

  /// 清除未完成的专注进度
  Future<void> clearProgress() async {
    await (_db.delete(
      _db.basicInfo,
    )..where((t) => t.key.equals(_kProgressKey))).go();
  }

  /// 读取当前 states 定义（页面取时长 / 设置弹窗回显用）；行缺失返回空表
  Future<List<PomodoroStateDef>> loadStates() async {
    final row = await (_db.select(
      _db.reminders,
    )..where((tbl) => tbl.id.equals('pomodoro'))).getSingleOrNull();
    if (row == null) return const [];
    return parsePomodoroStates(row.states);
  }

  /// 更新阶段时长配置（番茄钟页设置入口）。
  ///
  /// 配置源 = reminders.id='pomodoro' 行的 states JSON（与桌面端同构，duration 单位 min）：
  /// 按 key 覆盖 work/rest 的 duration，其余状态保持原时长，字段形状归一化重写；
  /// 行不存在则直接按给定时长落种子。
  Future<void> updateDurations({
    required int workMinutes,
    required int restMinutes,
  }) async {
    final row = await (_db.select(
      _db.reminders,
    )..where((tbl) => tbl.id.equals('pomodoro'))).getSingleOrNull();
    final states = row == null
        ? const <PomodoroStateDef>[]
        : parsePomodoroStates(row.states);
    final jsonList = [
      for (final s in states)
        {
          'key': s.key,
          'label': s.label,
          'content': s.content,
          'duration': s.key == 'work'
              ? workMinutes
              : s.key == 'rest'
              ? restMinutes
              : (s.durationSeconds ~/ 60).clamp(1, 1 << 30),
          'unit': 'min',
        },
      // 原配置缺 work/rest 时按缺省补齐（保持「专注→休息」两段循环）
      if (!states.any((s) => s.key == 'work'))
        {
          'key': 'work',
          'label': '专注',
          'content': '',
          'duration': workMinutes,
          'unit': 'min',
        },
      if (!states.any((s) => s.key == 'rest'))
        {
          'key': 'rest',
          'label': '休息',
          'content': '',
          'duration': restMinutes,
          'unit': 'min',
        },
    ];
    final statesJson = jsonEncode(jsonList);
    if (row == null) {
      await _db
          .into(_db.reminders)
          .insert(
            RemindersCompanion.insert(
              id: 'pomodoro',
              mode: const Value('stateful'),
              title: const Value('番茄钟'),
              enabled: const Value('1'),
              states: Value(statesJson),
              loop: const Value('1'),
            ),
          );
    } else {
      await (_db.update(_db.reminders)
            ..where((tbl) => tbl.id.equals('pomodoro')))
          .write(RemindersCompanion(states: Value(statesJson)));
    }
  }

  /// 记录一条状态流水（label/value/mode 与桌面端约定一致）。
  /// 由页面在**阶段完成**时调用（value = work/rest）。
  Future<void> recordStatus({
    required String label,
    required String value,
    required String mode,
  }) async {
    final now = DateTime.now();
    final nowStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await _db
        .into(_db.pomodoroStatus)
        .insert(
          PomodoroStatusCompanion.insert(
            label: Value(label),
            value: Value(value),
            mode: Value(mode),
            createTime: Value(nowStr),
          ),
        );
  }
}
