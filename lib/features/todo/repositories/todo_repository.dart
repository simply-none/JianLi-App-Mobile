// 待办仓库 —— 列表流 + 新增 + 完成切换 + 删除
//
// 与桌面端字段约定一致：
// - key 为 UUID；completed='1'/'0'；
// - createTime/updateTime 格式 yyyy-MM-dd HH:mm:ss；
// - 删除为物理删除（桌面端同样为物理删除）。
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../models/todo.dart';

/// 待办仓库
class TodoRepository {
  TodoRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 全部待办流（updateTime 倒序）
  Stream<List<TodoItem>> watchTodos() {
    return (_db.select(_db.todoList)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]))
        .watch()
        .map((rows) => rows.map(TodoItem.fromRow).toList());
  }

  /// 标签流（供展示映射）
  Stream<List<TodoTagView>> watchTags() {
    return _db.select(_db.todoTags).watch().map((rows) => rows.map(TodoTagView.fromRow).toList());
  }

  /// 新增待办（title 必填，其余走默认值）
  Future<void> addTodo({required String title, String? description}) async {
    final now = DateTime.now();
    final nowStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await _db.into(_db.todoList).insert(TodoListCompanion.insert(
          key: _uuid.v4(),
          title: Value(title),
          description: Value(description),
          completed: const Value('0'),
          createTime: Value(nowStr),
          updateTime: Value(nowStr),
        ));
  }

  /// 切换完成状态
  Future<void> toggleComplete(String key, bool completed) async {
    final now = DateTime.now();
    final nowStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await (_db.update(_db.todoList)..where((tbl) => tbl.key.equals(key))).write(
      TodoListCompanion(
        completed: Value(completed ? '1' : '0'),
        completedTime: Value(completed ? nowStr : null),
        updateTime: Value(nowStr),
      ),
    );
  }

  /// 删除待办（含其子任务）
  Future<void> deleteTodo(String key) async {
    await (_db.delete(_db.todoList)..where((tbl) => tbl.parentId.equals(key))).go();
    await (_db.delete(_db.todoList)..where((tbl) => tbl.key.equals(key))).go();
  }
}
