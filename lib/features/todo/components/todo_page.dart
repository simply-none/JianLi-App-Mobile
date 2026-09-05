// 待办页 —— 过滤 tabs + 复选完成 + 新增对话框
//
// 移动端第一批：单层列表 + 增/删/勾选；父子任务缩进与重复任务编辑列入 P2。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo.dart';
import '../providers/todo_providers.dart';

/// 待办页
class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  TodoFilter _filter = TodoFilter.active;

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todoListProvider);
    final tagsAsync = ref.watch(todoTagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('待办')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 过滤 tabs
          SegmentedButton<TodoFilter>(
            segments: const [
              ButtonSegment(value: TodoFilter.active, label: Text('进行中')),
              ButtonSegment(value: TodoFilter.completed, label: Text('已完成')),
              ButtonSegment(value: TodoFilter.all, label: Text('全部')),
            ],
            selected: {_filter},
            onSelectionChanged: (set) => setState(() => _filter = set.first),
          ).paddingAll(12),
          Expanded(
            child: todosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (todos) {
                final items = applyTodoFilter(todos, _filter);
                if (items.isEmpty) {
                  return const Center(child: Text('这里空空如也'));
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final todo in items)
                      _TodoTile(
                        todo: todo,
                        tagCount: tagsAsync.value?.length ?? 0,
                        onToggle: () => ref
                            .read(todoRepositoryProvider)
                            .toggleComplete(todo.key, !todo.completed),
                        onDelete: () => ref.read(todoRepositoryProvider).deleteTodo(todo.key),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 新增待办对话框（第一批仅采集标题）
  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增待办'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '要做什么？'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      await ref.read(todoRepositoryProvider).addTodo(title: title.trim());
    }
  }
}

extension on Widget {
  /// 小工具：统一内边距
  Widget paddingAll(double v) => Padding(padding: EdgeInsets.all(v), child: this);
}

/// 单条待办
class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.tagCount,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem todo;
  final int tagCount;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(todo.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.errorContainer,
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: CheckboxListTile(
        value: todo.completed,
        onChanged: (_) => onToggle(),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: (todo.dueDate?.isNotEmpty ?? false) || todo.tags.isNotEmpty
            ? Text(
                [
                  if (todo.dueDate?.isNotEmpty ?? false) '截止 ${todo.dueDate}',
                  if (todo.tags.isNotEmpty) '${todo.tags.length} 个标签',
                ].join(' · '),
              )
            : null,
        secondary: todo.isChild ? const Icon(Icons.subdirectory_arrow_right) : null,
      ),
    );
  }
}
