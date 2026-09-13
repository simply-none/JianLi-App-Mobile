// 番茄钟仓库 —— 读取 reminders(stateful) 配置 + 写状态流水 + 启动/阶段通知
//
// reminders.id='pomodoro' 行是番茄钟的唯一配置源（与桌面端一致）；
// pomodoro_status 每次状态变更写一行流水，供统计（桌面端 7119 行热力图数据同源）。
// 启动语义（2026-09-12 补齐，对齐 PC restartStatefulRound 持久版）：
//   写 reminders.startTime = now + enabled='1'，状态机即从 work 重开；
//   行不存在则按 PC 默认（专注 35 分钟 / 休息 5 分钟）本地落一条种子配置。
// 阶段到点通知：reschedulePhaseNotifications 排「下两个阶段边界」的一次性系统通知
// （pomodoro 渠道默认声；精确闹钟可用才 precise）—— 每次启动/进页/启动按钮后重排，
// 不做暂停语义（PC 无此约定，避免自创字段无法对齐）。
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/pomodoro_state_machine.dart';

/// 番茄钟仓库
class PomodoroRepository {
  PomodoroRepository(this._db);

  final AppDatabase _db;

  /// 移动端种子配置（行不存在时 startRound 落库；states JSON 与桌面端同构，duration 单位 min）
  static const String _seedStates =
      '[{"key":"work","label":"专注","content":"","duration":35,"unit":"min"},'
      '{"key":"rest","label":"休息","content":"","duration":5,"unit":"min"}]';

  /// 阶段通知的稳定 id（下两个边界各一条）
  static List<int> get _phaseIds => [
    NotificationService.stableId('pomodoro:phase-0'),
    NotificationService.stableId('pomodoro:phase-1'),
  ];

  // ===================== 展示效果（存 basic_info 基础键值表） =====================
  //
  // 展示效果是「页面观感」偏好，与 reminders 里的计时配置（states/startTime）无涉，
  // 按用户拍板放基础键值表 basic_info（key PRIMARY KEY），不与其他字段混存一表。
  // 取值：normal=普通（现效果）/ clean=清爽 / landscape=横屏翻页钟（后续多种模式再扩）。

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

  /// 读取番茄钟状态机配置（不存在/未启用返回 null）
  Future<PomodoroSnapshot?> loadSnapshot() async {
    final row = await _loadRow();
    if (row == null) return null;
    final states = parsePomodoroStates(row.states);
    final startMs = int.tryParse(row.startTime ?? '') ?? 0;
    return computePomodoroSnapshot(states, startMs, DateTime.now());
  }

  Future<Reminder?> _loadRow() async {
    final row = await (_db.select(
      _db.reminders,
    )..where((tbl) => tbl.id.equals('pomodoro'))).getSingleOrNull();
    if (row == null || row.enabled != '1') return null;
    return row;
  }

  /// 读取当前 states 定义（长按编辑弹层回显用）；行缺失/未启用返回空表
  Future<List<PomodoroStateDef>> loadStates() async {
    final row = await (_db.select(
      _db.reminders,
    )..where((tbl) => tbl.id.equals('pomodoro'))).getSingleOrNull();
    if (row == null) return const [];
    return parsePomodoroStates(row.states);
  }

  /// 启动 / 重新开始一轮：写 startTime = now + enabled='1'（PC 持久版启动等价）。
  /// 行不存在则先落种子配置（专注 35 / 休息 5，可在桌面端调整）。
  Future<void> startRound() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final row = await (_db.select(
      _db.reminders,
    )..where((tbl) => tbl.id.equals('pomodoro'))).getSingleOrNull();
    if (row == null) {
      await _db
          .into(_db.reminders)
          .insert(
            RemindersCompanion.insert(
              id: 'pomodoro',
              mode: const Value('stateful'),
              title: const Value('番茄钟'),
              enabled: const Value('1'),
              startTime: Value('$nowMs'),
              states: const Value(_seedStates),
              loop: const Value('1'),
            ),
          );
    } else {
      await (_db.update(
        _db.reminders,
      )..where((tbl) => tbl.id.equals('pomodoro'))).write(
        RemindersCompanion(
          startTime: Value('$nowMs'),
          enabled: const Value('1'),
        ),
      );
    }
    await reschedulePhaseNotifications();
  }

  /// 重排「下两个阶段边界」的一次性系统通知（启动/进页/启动按钮后调用）。
  ///
  /// 状态机按 states 顺序无限循环：以当前快照为基准，边界 1 = 当前状态结束时刻，
  /// 边界 2 = 下一状态结束时刻；每次重排先取消旧通知再排新的。
  /// App 被杀时由原生 AlarmManager 触发（与提醒/倒计时同一套底层）。
  Future<void> reschedulePhaseNotifications() async {
    for (final id in _phaseIds) {
      await NotificationService.cancel(id);
    }
    final row = await _loadRow();
    if (row == null) return;
    final states = parsePomodoroStates(row.states);
    final startMs = int.tryParse(row.startTime ?? '') ?? 0;
    final snapshot = computePomodoroSnapshot(states, startMs, DateTime.now());
    if (snapshot == null) return;
    // 当前状态在 states 中的索引（按 key 匹配）
    final idx = states.indexWhere((s) => s.key == snapshot.currentState.key);
    if (idx < 0) return;
    final precise = await NotificationService.exactAlarmAllowed;
    var cursorMs =
        DateTime.now().millisecondsSinceEpoch +
        snapshot.remainingSeconds * 1000;
    for (var k = 0; k < _phaseIds.length; k++) {
      final finished = states[(idx + k) % states.length];
      final next = states[(idx + k + 1) % states.length];
      await NotificationService.scheduleOnce(
        id: _phaseIds[k],
        channelKey: NotificationChannels.pomodoro,
        title: '${finished.label}结束',
        body: '进入「${next.label}」（约 ${next.durationSeconds ~/ 60} 分钟）',
        dateTime: DateTime.fromMillisecondsSinceEpoch(cursorMs),
        precise: precise,
      );
      cursorMs += next.durationSeconds * 1000;
    }
  }

  /// 更新阶段时长配置（番茄钟页长按编辑入口）。
  ///
  /// 配置源 = reminders.id='pomodoro' 行的 states JSON（与桌面端同构，duration 单位 min）：
  /// 按 key 覆盖 work/rest 的 duration，其余状态保持原时长，字段形状归一化重写；
  /// 行不存在则直接按给定时长落种子。startTime 不动 —— 改时长后状态机按新周期即时重算。
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
              startTime: Value('${DateTime.now().millisecondsSinceEpoch}'),
              states: Value(statesJson),
              loop: const Value('1'),
            ),
          );
    } else {
      await (_db.update(_db.reminders)
            ..where((tbl) => tbl.id.equals('pomodoro')))
          .write(RemindersCompanion(states: Value(statesJson)));
    }
    await reschedulePhaseNotifications();
  }

  /// 记录一条状态流水（label/value/mode 与桌面端约定一致）
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
