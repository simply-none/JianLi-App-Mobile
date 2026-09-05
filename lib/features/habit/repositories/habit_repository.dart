// 习惯仓库 —— 定义读取 + 打卡幂等切换 + 近 7 天打卡查询
//
// 幂等约定（与桌面端一致）：打卡记录主键 key = 'habitKey#yyyy-MM-dd'，
// 重复打卡不产生新行，直接按主键删/插，天然利于双端同步合并。
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
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

  /// 近 [days] 天内每天是否打卡（连续天数展示用），key → [bool x days]
  Future<Map<String, List<bool>>> recentCheckinMap(
    List<String> habitKeys,
    int days,
  ) async {
    final today = DateTime.now();
    final dates = List.generate(
      days,
      (i) => _formatDate(today.subtract(Duration(days: i))),
    );
    final result = <String, List<bool>>{};
    for (final key in habitKeys) {
      final checked = <bool>[];
      for (final date in dates) {
        final row =
            await (_db.select(_db.habitCheckin)..where(
                  (tbl) => tbl.habitKey.equals(key) & tbl.date.equals(date),
                ))
                .getSingleOrNull();
        checked.add(row != null);
      }
      result[key] = checked;
    }
    return result;
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

  /// 调度习惯提醒的本地通知（每天/按星期）
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
    if (weekDays.isEmpty) {
      await NotificationService.scheduleDaily(
        id: id.hashCode,
        channelKey: NotificationChannels.habit,
        title: '习惯提醒',
        body: title,
        hour: hour,
        minute: minute,
      );
    } else {
      for (final wd in weekDays) {
        await NotificationService.scheduleWeekly(
          id: id.hashCode + wd,
          channelKey: NotificationChannels.habit,
          title: '习惯提醒',
          body: title,
          hour: hour,
          minute: minute,
          weekday: wd,
        );
      }
    }
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
      await NotificationService.cancel(r.id.hashCode);
    }
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
