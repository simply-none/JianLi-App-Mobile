// 待办仓库 —— 列表流 + 新增/编辑 + 完成切换 + 级联删除 + 标签 + 重复实例生成 + 截止提醒调度
//
// 与桌面端字段约定一致：
// - key 为 UUID；completed='1'/'0'；createTime/updateTime 格式 yyyy-MM-dd HH:mm:ss；
// - 父子/重复字段与 PC 同列；upsert 走 INSERT OR REPLACE（按 key 主键，对齐同步幂等写）。
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/native_notify.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/todo.dart';

/// 待办标签调色板（对齐 PC TagSelectPopover）
const List<String> kTodoTagPalette = [
  '#6366f1', '#8b5cf6', '#ec4899', '#f43f5e', '#f97316',
  '#eab308', '#22c55e', '#14b8a6', '#06b6d4', '#3b82f6',
];

/// E3 番茄钟联动：SharedPreferences 键（值为关联待办的 key，空串 = 未关联）。
/// 读写集中在待办仓库 / 番茄钟页两处，排/取消共用同一份码口径的思路同样适用这里。
const String kTodoPomodoroLinkKey = 'todo.pomodoroLink';

/// 待办仓库
class TodoRepository {
  TodoRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 全部待办流（updateTime 倒序）。
  /// E5 软删除：回收站行（deleted='1'）不进常规列表（updateTime 倒序不变）。
  Stream<List<TodoItem>> watchTodos() {
    return (_db.select(_db.todoList)
          ..where((tbl) => tbl.deleted.isNull() | tbl.deleted.equals('1').not())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]))
        .watch()
        .map((rows) => rows.map(TodoItem.fromRow).toList());
  }

  /// 回收站流（E5）：仅软删除行，updateTime 倒序（删除时间 = updateTime）。
  Stream<List<TodoItem>> watchDeletedTodos() {
    return (_db.select(_db.todoList)
          ..where((tbl) => tbl.deleted.equals('1'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]))
        .watch()
        .map((rows) => rows.map(TodoItem.fromRow).toList());
  }

  /// 标签流（供展示映射）
  Stream<List<TodoTagView>> watchTags() {
    return _db
        .select(_db.todoTags)
        .watch()
        .map((rows) => rows.map(TodoTagView.fromRow).toList());
  }

  /// 新增待办（title 必填，其余走默认值）；返回新建 key
  Future<String> addTodo({required String title, String? description}) async {
    final key = _uuid.v4();
    final now = _now();
    await _db.into(_db.todoList).insert(
          TodoListCompanion.insert(
            // key 是非空必填列，insert() 构造器这里要传原始值（不能包 Value）
            key: key,
            title: Value(title),
            description: Value(description),
            completed: const Value('0'),
            priority: const Value('medium'),
            createTime: Value(now),
            updateTime: Value(now),
          ),
        );
    return key;
  }

  /// 切换完成状态。除 completed / completedTime / updateTime 外还须同步写 status：
  /// effectiveStatus 以「status 非空优先」，只写 completed 会导致勾选后界面仍显示原状态；
  /// 取消完成时仅当原 status == 'completed' 才回落 'not_started'，其余状态（进行中/阻塞等）
  /// 原样保留（否则「进行中」任务点掉勾再勾回会丢失状态）。首页 todosActive 口径是
  /// !completed，不受本次改动影响。
  /// F2（on_complete）：置 completed 后若完成行是实例、且其模板为「完成后生成下一次」，
  /// 则按模板规则补生成下一期实例（对齐 PC recurrence.ts generateOnCompleteNext）。
  Future<void> toggleComplete(String key, bool completed) async {
    final now = _now();
    String? status;
    if (completed) {
      status = 'completed';
    } else {
      // 先查原行：仅原状态是 completed 才回写 not_started，否则不碰 status 列
      final rows = await (_db.select(_db.todoList)
            ..where((tbl) => tbl.key.equals(key)))
          .get();
      if (rows.isNotEmpty && rows.first.status == 'completed') {
        status = 'not_started';
      }
    }
    await (_db.update(_db.todoList)..where((tbl) => tbl.key.equals(key))).write(
      TodoListCompanion(
        completed: Value(completed ? '1' : '0'),
        completedTime: Value(completed ? now : null),
        // Value.absent = 不写该列、保留原 status
        status: status == null ? const Value.absent() : Value(status),
        updateTime: Value(now),
      ),
    );
    // F2：完成后按需补生成下一期实例（失败不阻塞完成切换）
    if (completed) {
      try {
        await _generateOnCompleteNext(key);
      } catch (_) {}
    }
  }

  /// 全字段 upsert（新增/编辑通用）。按 key 主键 INSERT OR REPLACE，对齐 PC new-sql:upsert。
  /// 会按需生成重复实例、调度截止提醒。
  Future<void> upsertTodo(TodoItem item) async {
    await _db.into(_db.todoList).insert(
          TodoListCompanion(
            key: Value(item.key),
            name: const Value(null),
            value: const Value(null),
            createdAt: const Value(null),
            priority: Value(item.priority),
            dueDate: Value(item.dueDate),
            createTime: Value(item.createTime),
            completedTime: Value(item.completedTime),
            tags: Value(jsonEncode(item.tags)),
            updateTime: Value(item.updateTime),
            completed: Value(item.completed ? '1' : '0'),
            title: Value(item.title),
            description: Value(item.description),
            deadlineReminder: Value(item.deadlineReminder.toString()),
            remindCount: Value(item.remindCount.toString()),
            remindInterval: Value(item.remindInterval.toString()),
            remindIntervalUnit: Value(item.remindIntervalUnit),
            status: Value(item.status),
            parentId: Value(item.parentIds.isNotEmpty ? item.parentIds.first : null),
            recurrenceEnd: Value(item.recurrenceEnd),
            recurrenceId: Value(item.recurrenceId),
            recurrenceInterval: Value(item.recurrenceInterval.toString()),
            isRecurrenceInstance: Value(item.isRecurrenceInstance.toString()),
            recurrenceRule: Value(item.recurrenceRule),
            recurrenceWeekdays: Value(
              item.recurrenceWeekdays.isNotEmpty
                  ? jsonEncode(item.recurrenceWeekdays)
                  : null,
            ),
            sortOrder: Value(item.sortOrder.toString()),
            parentIds: Value(
              item.parentIds.isNotEmpty ? jsonEncode(item.parentIds) : null,
            ),
            // 2026-10-01 批次新列：INSERT OR REPLACE 会整行覆盖，三列必须随行写回，
            // 否则编辑保存会把 deleted / focusedMinutes / recurrenceMode 冲成 NULL
            deleted: Value(item.deleted.toString()),
            focusedMinutes: Value(item.focusedMinutes.toString()),
            recurrenceMode: Value(item.recurrenceMode),
          ),
          mode: InsertMode.replace,
        );

    // 重复模板：补生成下一个周期实例（对齐 PC recurrence:sync）。
    // F2：模板 recurrenceMode='on_complete' 时不自动生成（到点不出新实例，
    // 由完成动作驱动 _generateOnCompleteNext），与 PC getTemplates 的模式过滤一致。
    if (item.isTemplate && item.recurrenceMode != 'on_complete') {
      try {
        await _ensureNextRecurrenceInstance(item);
      } catch (_) {
        /* 生成失败不阻塞保存 */
      }
    }
    // 截止提醒：开启且填了到期时间则调度；否则取消既有提醒（对齐 PC update-todo-reminders）
    try {
      if (item.deadlineReminder == 1 && item.dueDate != null) {
        await scheduleDeadlineReminder(item);
      } else {
        await cancelDeadlineReminder(item.key);
      }
    } catch (_) {
      /* 通知调度失败不阻塞保存 */
    }
  }

  /// 新增标签（同名去重，取调色板顺序色），返回新建标签
  Future<TodoTagView> addTag(String name) async {
    final trimmed = name.trim();
    final existing = await (_db.select(_db.todoTags)
          ..where((t) => t.name.equals(trimmed)))
        .get();
    if (existing.isNotEmpty) {
      return TodoTagView.fromRow(existing.first);
    }
    final key = _uuid.v4();
    final all = await _db.select(_db.todoTags).get();
    final color = kTodoTagPalette[all.length % kTodoTagPalette.length];
    // ⚠️ drift 生成名：表名 TodoTags → 数据类 TodoTag（单数）、Companion 是 TodoTagsCompanion（复数）
    await _db.into(_db.todoTags).insert(
          TodoTagsCompanion.insert(
            key: Value(key),
            name: Value(trimmed),
            color: Value(color),
          ),
        );
    return TodoTagView(key: key, name: trimmed, color: color);
  }

  /// 更新标签（D5 标签管理）：按 key 更新 name/color。
  /// ⚠️ 只按 key 定位（key 是标签业务主键），入参行里其余列（id 等）不参与更新。
  Future<void> updateTag(TodoTag tag) async {
    final key = tag.key;
    if (key == null || key.isEmpty) return;
    await (_db.update(_db.todoTags)..where((t) => t.key.equals(key))).write(
      TodoTagsCompanion(name: Value(tag.name), color: Value(tag.color)),
    );
  }

  /// 删除标签（D5 标签管理）：先删 todo_tags 行，再清理 todo_list 的 tags 引用。
  /// tags 列是 JSON 数组文本，SQL LIKE 子串匹配有「key 互为子串」的误伤风险
  /// （同 deleteTodo 对 parentIds 的结论）→ 全表取出后在内存里解析、移除该 key，
  /// 仅对命中的行逐行 UPDATE tags 列（不动其它字段，量级 = 命中条数）。
  /// 走 drift update/delete 原语（非 customStatement）→ 自动通知 watch，
  /// 标签流与待办流都会刷新，无需手动 notifyUpdates。
  Future<void> deleteTag(String key) async {
    await (_db.delete(_db.todoTags)..where((t) => t.key.equals(key))).go();
    final rows = await _db.select(_db.todoList).get();
    for (final row in rows) {
      final raw = row.tags;
      if (raw == null || raw.isEmpty) continue;
      final List<dynamic> arr;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        arr = decoded;
      } catch (_) {
        continue; // 非 JSON 文本：跳过，不做清洗
      }
      if (!arr.any((e) => e.toString() == key)) continue;
      final next = [for (final e in arr) if (e.toString() != key) e];
      await (_db.update(_db.todoList)..where((t) => t.key.equals(row.key)))
          .write(TodoListCompanion(tags: Value(jsonEncode(next))));
    }
  }

  /// 删除待办（E5 软删除：UPDATE deleted='1' + updateTime，行进回收站，30 天后
  /// purgeExpiredDeleted 物理清理）。级联语义保留：命中的子任务一并置 deleted='1'
  /// （与 PC 端「删父连带子进站」同口径）。
  /// ⚠️ parentIds 是 JSON 数组文本，SQL `LIKE '%key%'` 子串匹配会把「某 key 恰好是
  /// 另一个 key 的子串」误判成父子关系而误删无关行；故先查全表行，在内存里用
  /// models/todo.dart 的解析函数（TodoItem.fromRow → _parseParentIds，含旧 parentId
  /// 兼容）做**精确包含**判断后再删。
  Future<void> deleteTodo(String key) async {
    final rows = await _db.select(_db.todoList).get();
    final doomed = <String>{key}; // 主 key 精确相等
    for (final row in rows) {
      if (row.key == key) continue;
      // 旧列 parentId 精确相等 + parentIds JSON 解析后精确包含，二者才视为子任务
      if (row.parentId == key ||
          TodoItem.fromRow(row).parentIds.contains(key)) {
        doomed.add(row.key);
      }
    }
    final now = _now();
    await (_db.update(_db.todoList)..where((tbl) => tbl.key.isIn(doomed))).write(
      TodoListCompanion(
        deleted: const Value('1'),
        updateTime: Value(now), // 回收站「删除时间」+ 30 天清理的判定依据
      ),
    );
    // 软删除的行不再到点响：截止提醒（含 #adv 提前条）一并取消
    for (final k in doomed) {
      try {
        await cancelDeadlineReminder(k);
      } catch (_) {}
    }
  }

  /// 回收站彻底删除（E5）：物理删行 + 取消截止提醒（排/取消同一份码口径）。
  Future<void> purgeTodo(String key) async {
    await (_db.delete(_db.todoList)..where((tbl) => tbl.key.equals(key))).go();
    try {
      await cancelDeadlineReminder(key);
    } catch (_) {}
  }

  /// 回收站恢复（E5）：deleted='0' + updateTime；若仍开启截止提醒且未完成，
  /// 按需重排提醒（在站期间被 deleteTodo 取消过）。
  Future<void> restoreTodo(String key) async {
    final now = _now();
    await (_db.update(_db.todoList)..where((tbl) => tbl.key.equals(key))).write(
      TodoListCompanion(deleted: const Value('0'), updateTime: Value(now)),
    );
    final rows = await (_db.select(_db.todoList)
          ..where((tbl) => tbl.key.equals(key)))
        .get();
    if (rows.isEmpty) return;
    final item = TodoItem.fromRow(rows.first);
    if (item.deadlineReminder == 1 &&
        !item.completed &&
        item.dueDate != null) {
      try {
        await scheduleDeadlineReminder(item);
      } catch (_) {}
    }
  }

  /// E5：物理删除进回收站超过 30 天的行（启动 / 回前台清扫，
  /// 与 PC recurrence.ts purgeExpiredDeleted 同口径：deleted='1' 且 updateTime 早于 30 天前）。
  Future<void> purgeExpiredDeleted() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    // updateTime 为 yyyy-MM-dd HH:mm:ss 定长格式，字典序即时间序（与 dedupe 同结论）
    final cutoffStr = _formatDateTime(cutoff);
    final rows = await (_db.select(_db.todoList)
          ..where((tbl) => tbl.deleted
              .equals('1')
              & tbl.updateTime.isNotNull()
              & tbl.updateTime.isSmallerThanValue(cutoffStr)))
        .get();
    if (rows.isEmpty) return;
    // 同步带来的在站行未必被本机取消过提醒，删行前按键兜底取消一次
    for (final r in rows) {
      try {
        await cancelDeadlineReminder(r.key);
      } catch (_) {}
    }
    await (_db.delete(_db.todoList)
          ..where((tbl) => tbl.key.isIn(rows.map((r) => r.key).toSet())))
        .go();
  }

  /// 批量删除（按 key 列表，含各自子任务）
  Future<void> deleteTodos(Iterable<String> keys) async {
    for (final k in keys) {
      await deleteTodo(k);
    }
  }

  // ===== 重复实例生成（对齐 PC recurrence 引擎，移动端单实例保底） =====
  // ⚠️ 与 PC recurrence.ts 公式逐字对齐，防止双端各自生成导致同步后双份实例。
  /// 为模板生成「下一个」周期实例（bounded，最多迭代 366 次避免死循环）。
  Future<void> _ensureNextRecurrenceInstance(TodoItem template) async {
    // 锚点与 PC anchorDate 一致：优先 dueDate，回退 createTime（都缺则无从推算）
    final anchorRaw = (template.dueDate != null && template.dueDate!.isNotEmpty)
        ? template.dueDate!
        : template.createTime;
    if (anchorRaw == null || anchorRaw.isEmpty) return;
    final base = _parseDateTime(anchorRaw);
    if (base == null) return;
    final next = _nextOccurrence(
      anchor: base,
      base: base,
      rule: template.recurrenceRule!,
      interval: template.recurrenceInterval,
      weekdays: template.recurrenceWeekdays,
    );
    if (next == null) return;
    // 重复结束日期限制
    if (template.recurrenceEnd != null && template.recurrenceEnd!.isNotEmpty) {
      final end = _parseDateTime(template.recurrenceEnd!);
      if (end != null && next.isAfter(end)) return;
    }
    // 若已存在同一 dueDate 的实例则跳过
    final existing = await (_db.select(_db.todoList)
          ..where((t) =>
              t.recurrenceId.equals(template.key) &
              t.dueDate.equals(_formatDateTime(next))))
        .get();
    if (existing.isNotEmpty) return;

    // 生成实例前先去重一次既有实例（防本机历史双份；同步引入的重复由
    // sync_service 写库后兜底再跑一遍，见 dedupeRecurrenceInstances）
    await dedupeRecurrenceInstances();

    final key = _uuid.v4();
    final now = _now();
    await _db.into(_db.todoList).insert(
          TodoListCompanion.insert(
            key: key,
            title: Value(template.title),
            description: Value(template.description),
            completed: const Value('0'),
            priority: Value(template.priority),
            dueDate: Value(_formatDateTime(next)),
            createTime: Value(now),
            updateTime: Value(now),
            tags: Value(jsonEncode(template.tags)),
            status: const Value('not_started'),
            recurrenceId: Value(template.key),
            recurrenceRule: const Value(null),
            isRecurrenceInstance: const Value('1'),
            sortOrder: Value(template.sortOrder.toString()),
            parentIds: const Value(null),
          ),
        );
  }

  /// 计算下一个周期触发时刻。
  /// ⚠️ 与 PC recurrence.ts ruleHit / nextHitDate 逐字对齐，防止双端各自生成导致同步后双份实例。
  ///
  /// [anchor] = 模板锚点（优先 dueDate 回退 createTime，PC anchorDate 同口径），命中判定一律相对锚点；
  /// [base] = 搜索下界（**日期级**，不含当天 —— PC nextHitDate 从 base+1 天起逐日扫）：
  /// fixed 到点生成传锚点本身（既有调用形态），F2 on_complete 传 max(今天, 实例 dueDate)。
  /// 候选一律方向向前且晚于当前时刻（fixed 形态下锚点可能在过去）。
  /// - daily：距锚点天数为间隔整数倍（按 +interval 天推进取第一个命中）；
  /// - weekly：落在选中周几（空则取锚点所在星期），且 floor(距锚点天数/7) % interval == 0；
  /// - monthly（E4）：候选日「几号」== 锚点几号，且 (年差*12+月差) % interval == 0
  ///   （31 号在小月不命中 —— 与 PC `d.date() !== anchor.date()` 同语义）；
  /// - yearly（E4）：候选「月-日」命中锚点，且 年差 % interval == 0
  ///   （2/29 锚点只在闰年命中 —— 平年 DateTime(y,2,29) 滚成 3/1 自然不命中）。
  /// 候选统一带锚点时刻（PC buildInstance 用模板 timeOfDay，同一口径）；扫描上限
  /// 730 天逐字对齐 PC nextHitDate（超出按「无命中」返回 null）。
  DateTime? _nextOccurrence({
    required DateTime anchor,
    required DateTime base,
    required String rule,
    required int interval,
    required List<int> weekdays,
  }) {
    final step = max(interval, 1);
    final now = DateTime.now();
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    final baseDay = DateTime(base.year, base.month, base.day);
    final horizon = anchorDay.add(const Duration(days: 730));
    // 命中条件 = 候选日在 base（日期级）之后且晚于当前时刻（方向向前）
    bool later(DateTime d) =>
        DateTime(d.year, d.month, d.day).isAfter(baseDay) && d.isAfter(now);
    // 候选日统一带锚点的时分秒（实例 dueDate 的时刻与模板一致）
    DateTime at(DateTime day) => DateTime(
          day.year,
          day.month,
          day.day,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        );

    if (rule == 'daily') {
      var d = anchor;
      for (var i = 0; i < 730; i++) {
        d = d.add(Duration(days: step));
        if (later(d)) return d;
      }
      return null;
    }
    if (rule == 'monthly') {
      // 逐月按 interval 步进；(年差*12+月差) % interval 由构造保证，保留判断逐字对齐 PC
      var y = anchor.year;
      var m = anchor.month;
      for (var i = 0; i < 64; i++) {
        m += step;
        while (m > 12) {
          m -= 12;
          y += 1;
        }
        final monthDiff = (y - anchor.year) * 12 + (m - anchor.month);
        if (monthDiff < 0 || monthDiff % step != 0) continue;
        final day = DateTime(y, m, anchor.day);
        // 小月无此「几号」→ 不命中（DateTime 会滚到下月，比对 day 拦住）
        if (day.day != anchor.day) continue;
        final hit = at(day);
        if (DateTime(hit.year, hit.month, hit.day).isAfter(horizon)) return null;
        if (later(hit)) return hit;
      }
      return null;
    }
    if (rule == 'yearly') {
      // 年差按 interval 步进；2/29 锚点遇平年自然不命中（见上方说明）
      for (var k = 1; k <= 3; k++) {
        final y = anchor.year + k * step;
        final day = DateTime(y, anchor.month, anchor.day);
        if (day.isAfter(horizon)) return null;
        final yearDiff = y - anchor.year;
        if (yearDiff < 0 || yearDiff % step != 0) continue;
        // 平年无 2/29：DateTime 滚成 3/1 →「月-日」不再命中锚点
        if (day.month != anchor.month || day.day != anchor.day) continue;
        final hit = at(day);
        if (later(hit)) return hit;
      }
      return null;
    }
    // weekly：weekdays 为 0-6（周日=0，与 PC d.day() 同口径）
    final days = weekdays.isNotEmpty
        ? weekdays.toSet()
        : {anchor.weekday % 7}; // 空则按锚点日自身周几（对齐 PC anchor.day()）
    DateTime? best;
    for (final w in days) {
      // 「base 之后（不含当天）的第一个该周几」：base 本身即该周几时严格取 +7
      final shift = (w - base.weekday % 7) % 7;
      var cand = at(base.add(Duration(days: shift == 0 ? 7 : shift)));
      for (var i = 0; i < 366; i++) {
        final daysDiff = DateTime(cand.year, cand.month, cand.day)
            .difference(anchorDay)
            .inDays;
        // PC weekly 公式（recurrence.ts ruleHit）：daysDiff >= 0 恒成立（向前扫描），
        // 保留判断以逐字对齐；floor(daysDiff/7) 对 interval 取模为 0 才生成
        if (daysDiff >= 0 &&
            (daysDiff ~/ 7) % step == 0 &&
            later(cand)) {
          if (best == null || cand.isBefore(best)) best = cand;
          break;
        }
        cand = cand.add(const Duration(days: 7));
      }
    }
    return best;
  }

  /// F2「完成后生成下一次」（对齐 PC recurrence.ts generateOnCompleteNext）：
  /// 完成行是实例、且其模板 recurrenceMode='on_complete' 时，按模板规则算
  /// 「严格晚于 max(今天, 实例 dueDate)」的第一个命中日（复用 _nextOccurrence 的
  /// daily/weekly/monthly/yearly 分支，方向向前）；同（recurrenceId + dueDate 前 10 位）
  /// 已存在则跳过；超出 recurrenceEnd 不生成。命中则按既有实例字段构造插入
  /// （status='not_started'、completed='0'、recurrenceMode 沿用模板）。
  Future<void> _generateOnCompleteNext(String instKey) async {
    final instRows = await (_db.select(_db.todoList)
          ..where((tbl) => tbl.key.equals(instKey)))
        .get();
    if (instRows.isEmpty) return;
    final inst = TodoItem.fromRow(instRows.first);
    // 只处理「实例」行（模板行没有 recurrenceId，不驱动补生成）
    if (inst.isRecurrenceInstance != 1 ||
        inst.recurrenceId == null ||
        inst.recurrenceId!.isEmpty) {
      return;
    }
    if (!inst.completed) return; // 仅「完成」动作触发
    // 模板行：规则 / 结束日期 / 生成方式都以模板为准（实例行不落 recurrenceRule）
    final tplRows = await (_db.select(_db.todoList)
          ..where((tbl) => tbl.key.equals(inst.recurrenceId!)))
        .get();
    if (tplRows.isEmpty) return;
    final tpl = TodoItem.fromRow(tplRows.first);
    if (tpl.recurrenceMode != 'on_complete' ||
        tpl.recurrenceRule == null ||
        tpl.recurrenceRule!.isEmpty) {
      return;
    }
    // 锚点与 PC anchorDate 一致：优先模板 dueDate，回退 createTime（都缺则无从推算）
    final anchorRaw = (tpl.dueDate != null && tpl.dueDate!.isNotEmpty)
        ? tpl.dueDate!
        : tpl.createTime;
    if (anchorRaw == null || anchorRaw.isEmpty) return;
    final anchor = _parseDateTime(anchorRaw);
    if (anchor == null) return;
    // 基准日 = max(今天, 已完成实例的截止日)，均取日期级（PC startOf('day') 同口径）
    final nowDt = DateTime.now();
    final todayDay = DateTime(nowDt.year, nowDt.month, nowDt.day);
    final instDue = _parseDateTime(inst.dueDate ?? '');
    final instDueDay = instDue == null
        ? null
        : DateTime(instDue.year, instDue.month, instDue.day);
    final baseDay = (instDueDay != null && instDueDay.isAfter(todayDay))
        ? instDueDay
        : todayDay;
    final next = _nextOccurrence(
      anchor: anchor,
      base: baseDay,
      rule: tpl.recurrenceRule!,
      interval: tpl.recurrenceInterval,
      weekdays: tpl.recurrenceWeekdays,
    );
    if (next == null) return;
    // 超出重复结束日期不生成
    if (tpl.recurrenceEnd != null && tpl.recurrenceEnd!.isNotEmpty) {
      final end = _parseDateTime(tpl.recurrenceEnd!);
      if (end != null && next.isAfter(end)) return;
    }
    // 同（recurrenceId + dueDate 前 10 位）已存在则跳过（对齐 PC 的按日去重）
    final dayPrefix = _formatDateTime(next).substring(0, 10);
    final existing = await (_db.select(_db.todoList)
          ..where((t) =>
              t.recurrenceId.equals(tpl.key) &
              t.dueDate.like('$dayPrefix%')))
        .get();
    if (existing.isNotEmpty) return;

    final key = _uuid.v4();
    final nowStr = _now();
    await _db.into(_db.todoList).insert(
          TodoListCompanion.insert(
            key: key,
            title: Value(tpl.title),
            description: Value(tpl.description),
            completed: const Value('0'),
            priority: Value(tpl.priority),
            dueDate: Value(_formatDateTime(next)),
            createTime: Value(nowStr),
            updateTime: Value(nowStr),
            tags: Value(jsonEncode(tpl.tags)),
            status: const Value('not_started'),
            recurrenceId: Value(tpl.key),
            recurrenceRule: const Value(null),
            isRecurrenceInstance: const Value('1'),
            // recurrenceMode 沿用模板（PC buildInstance 同字段；否则下期完成后不再续生成）
            recurrenceMode: Value(tpl.recurrenceMode),
            sortOrder: Value(tpl.sortOrder.toString()),
            parentIds: const Value(null),
          ),
        );
  }

  /// 周期实例去重：同一 (recurrenceId, dueDate 前 10 位) 只保留一条。
  /// 双端各自生成 / 新旧算法交替（含同步引入的行）可能产生同日双份实例，
  /// 按组保留 updateTime 最大的一条，其余物理删除（实例无子任务，直接删行）。
  /// ⚠️ 删除后必须手动 notifyUpdates —— 参照 sync_service.dart 的结论：
  /// 走 customStatement/底层写路径不会自动通知 drift watch，漏了会导致列表停留在旧快照。
  Future<void> dedupeRecurrenceInstances() async {
    final rows = await (_db.select(_db.todoList)
          ..where((t) =>
              t.isRecurrenceInstance.equals('1') & t.recurrenceId.isNotNull()))
        .get();
    // 分组键：recurrenceId + dueDate 前 10 位（yyyy-MM-dd）
    final groups = <String, List<TodoListData>>{};
    for (final r in rows) {
      final rid = r.recurrenceId;
      if (rid == null || rid.isEmpty) continue;
      final due = r.dueDate ?? '';
      final dayKey = due.length >= 10 ? due.substring(0, 10) : due;
      groups.putIfAbsent('$rid|$dayKey', () => []).add(r);
    }
    var removed = 0;
    for (final g in groups.values) {
      if (g.length <= 1) continue;
      // updateTime 为 yyyy-MM-dd HH:mm:ss 定长格式，字典序即时间序
      g.sort((a, b) => (a.updateTime ?? '').compareTo(b.updateTime ?? ''));
      for (final victim in g.take(g.length - 1)) {
        await (_db.delete(_db.todoList)
              ..where((tbl) => tbl.key.equals(victim.key)))
            .go();
        removed++;
      }
    }
    if (removed > 0) {
      // 与 deleteTodo 相同的删除原语不通知 watch，这里手动触发待办流刷新
      _db.notifyUpdates({TableUpdate.onTable(_db.todoList)});
    }
  }

  // ===== 截止提醒 → 本地通知（对齐 PC update-todo-reminders） =====
  /// 调度截止提醒（F1 折中版：最多两条 ——
  /// ① 提前提醒：截止前 remindInterval×unit 的一条（键加 `#adv` 后缀，仅当该时刻在未来）；
  /// ② 截止时刻一条。提前点取「最近一条」= due − 1×interval，**不按 remindCount 排多条**
  /// （避免通知轰炸；PC 的 count×interval 全量提前仍由 PC 端负责）。
  ///
  /// 2026-09-19 起优先原生 setAlarmClock（mode=notify）——awesome 的 scheduleOnce 在
  /// 切后台/锁屏/Doze 下会被系统推迟到回 App 才补发（真机 Android 15 实证），原生失败才回退；
  /// F1 起两条各自「原生优先、失败回退 awesome」（红线 #21：回退不能只兜一条）。
  /// repeatSpec=null 一次性；已过期的时刻不排也不取消（已排的原生计划留着「回 App 补响」）。
  Future<void> scheduleDeadlineReminder(TodoItem item) async {
    final due = _parseDateTime(item.dueDate!);
    if (due == null || due.isBefore(DateTime.now())) return;
    final title = '待办即将到期：${item.title}';
    final body = '截止时间 ${item.dueDate}';
    final advAt = _advanceAt(item, due);
    if (advAt != null) {
      await _scheduleOneDeadline(
        key: '${item.key}#adv',
        title: title,
        body: '距截止还有 ${_advanceLabel(item)}（截止 ${item.dueDate}）',
        at: advAt,
      );
    }
    await _scheduleOneDeadline(key: item.key, title: title, body: body, at: due);
  }

  /// F1 提前提醒时刻 = due − 1×remindInterval×unit（minute/hour）；
  /// 无效间隔或提前点已过期返回 null（不排）。
  DateTime? _advanceAt(TodoItem item, DateTime due) {
    if (item.deadlineReminder != 1) return null;
    final minutes = item.remindIntervalUnit == 'hour'
        ? item.remindInterval * 60
        : item.remindInterval;
    if (minutes <= 0) return null;
    final adv = due.subtract(Duration(minutes: minutes));
    return adv.isAfter(DateTime.now()) ? adv : null;
  }

  String _advanceLabel(TodoItem item) =>
      '${item.remindInterval} ${item.remindIntervalUnit == 'hour' ? '小时' : '分钟'}';

  /// 单条截止提醒：原生 setAlarmClock 优先（mode=notify），失败回退 awesome；
  /// 排/取消共用 [cancelDeadlineReminder] 的同一份码口径（stableId(key)）。
  Future<void> _scheduleOneDeadline({
    required String key,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (at.isBefore(DateTime.now())) return; // 已过期不排
    final nativeOk = await scheduleNativeNotifyOnce(
      code: NotificationService.stableId(key),
      title: title,
      body: body,
      at: at,
    );
    if (nativeOk) return;
    await NotificationService.scheduleOnce(
      id: NotificationService.stableId(key),
      channelKey: NotificationChannels.todo,
      title: title,
      body: body,
      dateTime: at,
    );
  }

  /// 取消某待办的截止提醒（awesome + 原生两条链都取消；F1：`#adv` 提前条一并取消，
  /// 与排程共用同一份码口径，漏一条就会「删了还响」）。
  Future<void> cancelDeadlineReminder(String key) async {
    try {
      await cancelNativeAlarms([
        NotificationService.stableId(key),
        NotificationService.stableId('$key#adv'),
      ]);
    } catch (_) {}
    await NotificationService.cancel(NotificationService.stableId(key));
    await NotificationService.cancel(NotificationService.stableId('$key#adv'));
  }

  /// 自愈重排：App 启动 / 回前台时按库重建全部启用待办的截止提醒原生通知（覆盖系统清理失效）。
  /// 同步取消旧版用 `key.hashCode` 排期的残留通知，避免重复弹出。逐条保护，单条失败不影响其余。
  /// E5：回收站行（deleted='1'）不参与重排（软删除时已取消提醒，重排会把它们复活）。
  Future<void> rescheduleAll() async {
    final rows = await (_db.select(_db.todoList)
          ..where(
            (tbl) =>
                tbl.deadlineReminder.equals('1') &
                tbl.dueDate.isNotNull() &
                (tbl.deleted.isNull() | tbl.deleted.equals('1').not()),
          ))
        .get();
    for (final r in rows) {
      final item = TodoItem.fromRow(r);
      if (item.completed) continue;
      try {
        // 取消旧版 hashCode 排期的残留，防止与新 stableId 计划重复
        await NotificationService.cancel(item.key.hashCode & 0x7fffffff);
      } catch (_) {}
      try {
        await scheduleDeadlineReminder(item);
      } catch (_) {}
    }
  }

  // ===== E3 番茄钟联动 =====
  /// 把一轮完整专注的分钟数累加到指定待办的 focusedMinutes（文本数字列，内存读改写
  /// UPDATE 单列；不动 updateTime —— 避免专注一次就把卡片顶到 updateTime 倒序首位）。
  /// 待办不存在 / 已进回收站 / minutes<=0 时不写入并返回 null（页面据此跳过 toast）。
  /// 尊重 2026-09-13「页面内本地计时」拍板：本方法只做一次加法，不涉及任何计时状态机。
  Future<TodoItem?> addFocusedMinutes(String key, int minutes) async {
    if (minutes <= 0) return null;
    final rows = await (_db.select(_db.todoList)
          ..where((tbl) => tbl.key.equals(key)))
        .get();
    if (rows.isEmpty || rows.first.deleted == '1') return null;
    final current = int.tryParse(rows.first.focusedMinutes ?? '') ?? 0;
    await (_db.update(_db.todoList)..where((tbl) => tbl.key.equals(key))).write(
      TodoListCompanion(focusedMinutes: Value('${current + minutes}')),
    );
    // 保险起见手动通知一次（与 dedupeRecurrenceInstances 同款兜底，重复通知无害）
    _db.notifyUpdates({TableUpdate.onTable(_db.todoList)});
    return TodoItem.fromRow(
      // drift 生成的 copyWith 参数为 Value 包装（非空列写 Value(null) 即置空）
      rows.first.copyWith(focusedMinutes: Value('${current + minutes}')),
    );
  }

  // ===== 工具 =====
  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDateTime(String s) {
    try {
      return DateTime.parse(s.replaceAll('/', '-'));
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
