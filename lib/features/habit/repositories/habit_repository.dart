// 习惯仓库 —— 定义读取 + 打卡幂等切换 + 近 7 天打卡查询
//
// 幂等约定（与桌面端一致）：打卡记录主键 key = 'habitKey#yyyy-MM-dd'，
// 重复打卡不产生新行，直接按主键删/插，天然利于双端同步合并。
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/native_notify.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/habit.dart';

/// 习惯仓库
class HabitRepository {
  HabitRepository(this._db);

  final AppDatabase _db;

  /// 习惯定义流（仅启用项）
  Stream<List<HabitItem>> watchHabits() {
    return (_db.select(_db.habitDef)..where((tbl) => tbl.enabled.equals('1')))
        .watch()
        .map((rows) => rows.map(HabitItem.fromRow).toList());
  }

  /// 指定日期已打卡的 habitKey 集合流
  Stream<Set<String>> watchCheckedKeys(String date) {
    return (_db.select(_db.habitCheckin)..where((tbl) => tbl.date.equals(date)))
        .watch()
        .map((rows) => rows.map((r) => r.habitKey ?? '').toSet());
  }

  /// 近 [days] 天每天是否打卡（index 0 = 今天），流式供 7 天记录条展示。
  /// 单次查询近 N 天记录；返回顺序与 [dates] 一致（index 0 = 今天）。
  Stream<List<bool>> watchRecentCheckin(String habitKey, int days) {
    final today = DateTime.now();
    final dates = List.generate(
      days,
      (i) => _formatDate(today.subtract(Duration(days: i))),
    );
    return (_db.select(_db.habitCheckin)
          ..where(
            (tbl) => tbl.habitKey.equals(habitKey) & tbl.date.isIn(dates),
          ))
        .watch()
        .map((rows) {
          final checked = rows.map((r) => r.date ?? '').toSet();
          return List.generate(days, (i) => checked.contains(dates[i]));
        });
  }

  /// 全部打卡记录（供导出使用；行含 habitKey / date / time / source）
  Future<List<HabitCheckinData>> loadAllCheckins() {
    return _db.select(_db.habitCheckin).get();
  }

  /// 切换某习惯在指定日期的打卡状态（幂等）
  Future<void> toggleCheckin(String habitKey, DateTime date) async {
    final dateStr = _formatDate(date);
    final checkinKey = '$habitKey#$dateStr';
    final existing = await (_db.select(
      _db.habitCheckin,
    )..where((tbl) => tbl.key.equals(checkinKey))).getSingleOrNull();

    if (existing != null) {
      // 已打卡 → 取消
      await (_db.delete(
        _db.habitCheckin,
      )..where((tbl) => tbl.key.equals(checkinKey))).go();
      return;
    }

    // 未打卡 → 写入（与桌面端字段约定一致：source=manual，time=HH:mm:ss）
    final now = DateTime.now();
    await _db
        .into(_db.habitCheckin)
        .insert(
          HabitCheckinCompanion.insert(
            key: Value(checkinKey),
            habitKey: Value(habitKey),
            date: Value(dateStr),
            source: const Value('manual'),
            time: Value(_formatTime(now)),
          ),
        );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime t) => '${_formatDate(t)} ${_formatTime(t)}';

  /// 新建习惯（字段约定对齐桌面端 useHabit.saveHabit）
  /// 同时按桌面端 syncReminders 语义写入 time 型提醒行并调度本地通知。
  Future<String> createHabit({
    required String name,
    List<int> weekDays = const [],
    String reminderTime = '',
    String freqType = 'daily',
  }) async {
    final now = DateTime.now();
    final key = 'habit:${_randId()}';
    final nowStr = _formatDateTime(now);
    final nameU = name.trim();

    await _db
        .into(_db.habitDef)
        .insert(
          HabitDefCompanion.insert(
            name: Value(nameU),
            value: const Value(null),
            createdAt: const Value(null),
            key: Value(key),
            createTime: Value(nowStr),
            updateTime: Value(nowStr),
            chainActions: const Value('[]'),
            weekDays: Value(jsonEncode(weekDays)),
            enabled: const Value('1'),
            reminderTimes: Value(
              jsonEncode(reminderTime.isEmpty ? <String>[] : [reminderTime]),
            ),
            remark: Value(nameU),
            freqType: Value(freqType),
          ),
        );

    // 提醒联动（桌面端 id 形如 habit:<key>#<序号>）
    if (reminderTime.isNotEmpty) {
      final reminderId = '$key#1';
      await _db
          .into(_db.reminders)
          .insert(
            RemindersCompanion.insert(
              id: reminderId,
              mode: const Value('time'),
              weekDays: Value(jsonEncode(weekDays)),
              loop: const Value('1'),
              title: Value(nameU),
              content: const Value(''),
              enabled: const Value('1'),
              time: Value(reminderTime),
              source: const Value('habit'),
            ),
          );
      await _scheduleHabitNotification(
        reminderId,
        nameU,
        reminderTime,
        weekDays,
      );
    }
    return key;
  }

  /// 调度习惯提醒的本地通知（每天/按星期）。
  ///
  /// 2026-09-19 起与提醒模块同构：**优先原生 setAlarmClock（mode=notify）**——
  /// 计划由系统持有，息屏/Doze/厂商冻结下不再被推迟（此前整条走 awesome 的
  /// NotificationCalendar，真机 Android 15 切后台/锁屏不响、回 App 才集中补发）；
  /// 原生失败才回退 awesome 兜底。⚠️ 排/取消共用同一份请求码（baseId / baseId+wd）。
  Future<void> _scheduleHabitNotification(
    String id,
    String title,
    String time,
    List<int> weekDays,
  ) async {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (hour == null || minute == null) return;
    final baseId = NotificationService.stableId(id);

    // —— 原生优先 ——
    final nativeOk = weekDays.isEmpty
        ? await scheduleNativeNotifyDaily(
            code: baseId,
            title: '习惯提醒',
            body: title,
            hour: hour,
            minute: minute,
          )
        : await scheduleNativeNotifyWeekly(
            code: baseId,
            title: '习惯提醒',
            body: title,
            hour: hour,
            minute: minute,
            weekDaysPc: weekDays,
          );
    if (nativeOk) return;

    // —— awesome 兜底（原生桥失败时保证至少排得上）——
    if (weekDays.isEmpty) {
      // 每天：scheduleCalendar 只给 hour/minute 即每日重复
      await NotificationService.scheduleCalendar(
        id: baseId,
        channelKey: NotificationChannels.habit,
        title: '习惯提醒',
        body: title,
        hour: hour,
        minute: minute,
        repeats: true,
      );
    } else {
      for (final wd in weekDays) {
        // 按星期：awesome weekday 1=周日…7=周六，PC 约定 0=周日…6=周六 → +1
        await NotificationService.scheduleCalendar(
          id: baseId + wd,
          channelKey: NotificationChannels.habit,
          title: '习惯提醒',
          body: title,
          weekday: wd + 1,
          hour: hour,
          minute: minute,
          repeats: true,
        );
      }
    }
  }

  /// 取消习惯提醒的原生闹钟（与排程同一份请求码口径：每天=baseId，每周=baseId+wd）
  Future<void> _cancelHabitNative(String id, List<int> weekDays) async {
    final baseId = NotificationService.stableId(id);
    try {
      await cancelNativeAlarms(
        weekDays.isEmpty ? [baseId] : [for (final w in weekDays) baseId + w],
      );
    } catch (_) {}
  }

  /// 删除习惯（联动清理提醒行与本地通知）
  Future<void> deleteHabit(HabitItem habit) async {
    await (_db.delete(
      _db.habitDef,
    )..where((t) => t.key.equals(habit.key))).go();
    final rows = await (_db.select(
      _db.reminders,
    )..where((t) => t.id.like('${habit.key}#%'))).get();
    for (final r in rows) {
      await (_db.delete(_db.reminders)..where((t) => t.id.equals(r.id))).go();
      await NotificationService.cancel(NotificationService.stableId(r.id));
      await _cancelHabitNative(r.id, _parseWeekDays(r.weekDays));
    }
  }

  /// 更新习惯定义（字段约定对齐 createHabit）：更新名称 / 星期 / 提醒时间，
  /// 联动清理旧提醒行与通知后按新提醒时间重建（与 createHabit 同语义）。
  Future<void> updateHabit({
    required HabitItem habit,
    required String name,
    List<int> weekDays = const [],
    String reminderTime = '',
  }) async {
    final nowStr = _formatDateTime(DateTime.now());
    final nameU = name.trim();
    await (_db.update(_db.habitDef)
          ..where((t) => t.key.equals(habit.key)))
        .write(
          HabitDefCompanion(
            name: Value(nameU),
            remark: Value(nameU),
            weekDays: Value(jsonEncode(weekDays)),
            reminderTimes: Value(
              jsonEncode(reminderTime.isEmpty ? <String>[] : [reminderTime]),
            ),
            updateTime: Value(nowStr),
          ),
        );

    // 清理旧提醒行与通知
    final rows = await (_db.select(_db.reminders)
          ..where((t) => t.id.like('${habit.key}#%')))
        .get();
    for (final r in rows) {
      await (_db.delete(_db.reminders)..where((t) => t.id.equals(r.id))).go();
      await NotificationService.cancel(NotificationService.stableId(r.id));
      await _cancelHabitNative(r.id, _parseWeekDays(r.weekDays));
    }

    // 重建提醒（与 createHabit 同源）
    if (reminderTime.isNotEmpty) {
      final reminderId = '${habit.key}#1';
      await _db
          .into(_db.reminders)
          .insert(
            RemindersCompanion.insert(
              id: reminderId,
              mode: const Value('time'),
              weekDays: Value(jsonEncode(weekDays)),
              loop: const Value('1'),
              title: Value(nameU),
              content: const Value(''),
              enabled: const Value('1'),
              time: Value(reminderTime),
              source: const Value('habit'),
            ),
          );
      await _scheduleHabitNotification(
        reminderId,
        nameU,
        reminderTime,
        weekDays,
      );
    }
  }

  /// 自愈重排：App 启动 / 回前台时按库重建全部启用习惯提醒的原生通知（覆盖系统清理/重启失效）。
  /// 同步取消旧版用 `id.hashCode` 排期的残留通知，避免重复弹出。逐条保护，单条失败不影响其余。
  Future<void> rescheduleAll() async {
    final rows = await (_db.select(_db.reminders)
          ..where(
            (tbl) => tbl.source.equals('habit') & tbl.enabled.equals('1'),
          ))
        .get();
    for (final r in rows) {
      try {
        // 取消旧版 hashCode 排期的残留（每天 + 每周变体），防止与新 stableId 计划重复
        await NotificationService.cancel(r.id.hashCode);
        for (final wd in _parseWeekDays(r.weekDays)) {
          await NotificationService.cancel(r.id.hashCode + wd);
        }
        // 取消旧原生计划（周几集合可能已缩小，缩小掉的码必须显式取消；
        // 未缩小的码由 setAlarmClock 同码覆盖，不取消也安全）
        await _cancelHabitNative(r.id, _parseWeekDays(r.weekDays));
      } catch (_) {}
      try {
        final wds = _parseWeekDays(r.weekDays);
        await _scheduleHabitNotification(r.id, r.title ?? '', r.time ?? '', wds);
      } catch (_) {}
    }
  }

  /// 把 reminders.weekDays（JSON 字符串）解析为周几列表；空/非法 → []
  List<int> _parseWeekDays(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is List) return list.whereType<int>().toList();
    } catch (_) {}
    return const [];
  }

  /// 随机 id（桌面端格式 aaaaaaaa-bbbbbbbb）
  String _randId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    String part() => String.fromCharCodes(
      List.generate(8, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
    );
    return '${part()}-${part()}';
  }
}
