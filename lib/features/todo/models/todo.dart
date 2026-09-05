// 待办模型 —— 包装桌面端 todo_list 行的解析结果
//
// 桌面端约定：completed='1'/'0'；tags 为 JSON 数组文本（todo_tags.key 列表）；
// 父子任务用 parentId 关联；重复任务字段（recurrence*）原样透传，移动端 P2 消费。
import '../../../core/db/app_database.dart';
import '../../habit/models/habit.dart' show parseStringList;

/// 待办条目
class TodoItem {
  const TodoItem({
    required this.key,
    required this.title,
    required this.description,
    required this.completed,
    required this.priority,
    required this.dueDate,
    required this.tags,
    required this.parentId,
    required this.sortOrder,
  });

  factory TodoItem.fromRow(TodoListData row) {
    return TodoItem(
      key: row.key,
      title: row.title ?? '（无标题）',
      description: row.description ?? '',
      completed: row.completed == '1',
      priority: row.priority ?? 'none',
      dueDate: row.dueDate,
      tags: parseStringList(row.tags),
      parentId: row.parentId,
      sortOrder: row.sortOrder,
    );
  }

  final String key;
  final String title;
  final String description;
  final bool completed;
  final String priority;

  /// 截止时间（yyyy-MM-dd HH:mm:ss 文本，桌面端原样）
  final String? dueDate;

  /// 标签 key 列表（展示名需关联 todo_tags，列表页暂以数量提示）
  final List<String> tags;
  final String? parentId;
  final String? sortOrder;

  /// 是否子任务
  bool get isChild => parentId != null && parentId!.isNotEmpty;
}

/// 待办标签展示模型
class TodoTagView {
  const TodoTagView({required this.key, required this.color});

  /// 行类型为 TodoTag（drift 对 s 结尾表名单数化，注意不是 TodoTagsData）
  factory TodoTagView.fromRow(TodoTag row) => TodoTagView(
        key: row.key ?? '',
        color: row.color ?? '#8b5cf6',
      );

  final String key;
  final String color;
}

/// 待办列表过滤模式
enum TodoFilter { active, completed, all }

/// 过滤 todo 列表
List<TodoItem> applyTodoFilter(List<TodoItem> items, TodoFilter filter) {
  switch (filter) {
    case TodoFilter.active:
      return items.where((t) => !t.completed).toList();
    case TodoFilter.completed:
      return items.where((t) => t.completed).toList();
    case TodoFilter.all:
      return items;
  }
}
