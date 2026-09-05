// 提醒仓库 + 本地通知调度（reminders → awesome_notifications）
//
// 对齐桌面端 newReminder 引擎语义的移动端映射：
// - time 模式：每天/按星期 → NotificationCalendar 定时通知；一次性 → 指定日期时刻；
// - interval 模式：TODO(P2) awesome_intervals 的周期通知需要与桌面端 unit 语义逐一对齐；
// - stateful 模式：番茄钟状态机由 App 前台驱动，不走系统通知；
// - 用户列表过滤 source==='todo'（桌面端 get-tips 同款规则）。
import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/reminder_item.dart';

/// 提醒仓库
class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;

  /// 用户提醒流（过滤引擎托管的待办提醒；番茄钟 stateful 保留展示）
  Stream<List<ReminderItem>> watchUserReminders() {
    return (_db.select(_db.reminders)
          ..where((tbl) => tbl.source.isNull() | tbl.source.equals(''))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.title)]))
        .watch()
        .map((rows) => rows.map(ReminderItem.fromRow).toList());
  }

  /// 启停提醒（同步增删本地通知计划）
  Future<void> toggleEnabled(ReminderItem item, bool enabled) async {
    await (_db.update(_db.reminders)..where((tbl) => tbl.id.equals(item.id)))
        .write(RemindersCompanion(enabled: Value(enabled ? '1' : '0')));
    if (enabled) {
      await scheduleNotification(item);
    } else {
      await NotificationService.cancel(item.id.hashCode);
    }
  }

  /// 新建定点提醒（对齐桌面端 time 模式字段；id 加 mobile: 前缀防与桌面端冲突）
  Future<void> createReminder({
    required String title,
    String content = '',
    required String time,
    List<int> weekDays = const [],
  }) async {
    final id = 'mobile:${DateTime.now().millisecondsSinceEpoch}';
    await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            id: id,
            mode: const Value('time'),
            weekDays: Value(weekDays.isEmpty ? '[]' : _toJson(weekDays)),
            loop: const Value('1'),
            title: Value(title),
            content: Value(content),
            enabled: const Value('1'),
            time: Value(time),
          ),
        );
    await scheduleNotification(
      ReminderItem(
        id: id,
        mode: 'time',
        title: title,
        content: content,
        enabled: true,
        weekDays: weekDays,
        time: time,
        date: null,
        repeat: null,
        interval: null,
        unit: null,
        idleTime: null,
        source: '',
        statesSummary: null,
      ),
    );
  }

  static String _toJson(List<int> v) => v.isEmpty ? '[]' : '[${v.join(',')}]';

  /// 按 mode 把提醒翻译为本地通知计划
  Future<void> scheduleNotification(ReminderItem item) async {
    if (item.isStateful) return; // 状态机不走系统通知
    if (item.mode == 'interval') {
      // TODO(P2): interval 模式按桌面端 unit 语义（分/时/天）映射 awesome 通知
      return;
    }
    // time 模式
    final timeParts = (item.time ?? '').split(':');
    if (timeParts.length < 2) return;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return;

    await NotificationService.cancel(item.id.hashCode);
    if (item.weekDays.isEmpty) {
      // 每天定点
      await NotificationService.scheduleDaily(
        id: item.id.hashCode,
        channelKey: NotificationChannels.todo,
        title: item.title,
        body: item.content,
        hour: hour,
        minute: minute,
      );
    } else {
      // 按星期定点
      for (final weekday in item.weekDays) {
        await NotificationService.scheduleWeekly(
          id: item.id.hashCode + weekday,
          channelKey: NotificationChannels.todo,
          title: item.title,
          body: item.content,
          hour: hour,
          minute: minute,
          weekday: weekday,
        );
      }
    }
  }
}
