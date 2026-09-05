// 待办页（forui 化）—— 过滤切换 + 复选完成 + 新增对话框
//
// 移动端第一批：单层列表 + 增/删/勾选；父子任务缩进与重复任务编辑列入 P2。
// forui 改造点：FScaffold+FHeader.nested 骨架、FButton 过滤切换、FCheckbox 勾选、
// showFDialog 新增、Dismissible 滑动删除（无 forui 等价物，material_ui 版保留）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/ui_atoms.dart';
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
    final t = context.theme;

    // 过滤项（与原 SegmentedButton 一一对应）
    const filters = [
      (TodoFilter.active, '进行中'),
      (TodoFilter.completed, '已完成'),
      (TodoFilter.all, '全部'),
    ];

    return FScaffold(
      header: FHeader.nested(
        title: const Text('待办'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        // 右上角「新增待办」入口（替代原 FloatingActionButton）
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _showAddDialog(context),
            semanticsLabel: '新增待办',
          ),
        ],
      ),
      child: Column(
        children: [
          // 过滤切换（选中 secondary / 未选 ghost）
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              spacing: 8,
              children: [
                for (final (value, label) in filters)
                  Expanded(
                    child: FButton(
                      variant: _filter == value
                          ? FButtonVariant.secondary
                          : FButtonVariant.ghost,
                      size: FButtonSizeVariant.sm,
                      onPress: () => setState(() => _filter = value),
                      child: Text(label),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: todosAsync.when(
              loading: () => const Center(child: FCircularProgress()),
              error: (e, _) => Center(
                child: Text(
                  '加载失败：$e',
                  style: t.typography.body.sm.copyWith(color: t.colors.error),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (todos) {
                final items = applyTodoFilter(todos, _filter);
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: FLucideIcons.listTodo,
                    title: '这里空空如也',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
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
    final title = await showFDialog<String>(
      context: context,
      builder: (c, style, _) => FDialog(
        builder: (c, style) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增待办', style: style.titleTextStyle),
            const SizedBox(height: 12),
            FTextField(
              control: FTextFieldControl.managed(controller: controller),
              hint: '要做什么？',
              autofocus: true,
              onSubmit: (v) => Navigator.pop(c, v),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.pop(c),
                  child: const Text('取消'),
                ),
                FButton(
                  onPress: () => Navigator.pop(c, controller.text),
                  child: const Text('添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      await ref.read(todoRepositoryProvider).addTodo(title: title.trim());
    }
  }
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
    final t = context.theme;
    // 滑动删除保留 Dismissible（forui 无等价物，material_ui 版已被主题着色）
    return Dismissible(
      key: ValueKey(todo.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: t.colors.destructive,
        child: Icon(FLucideIcons.trash2, color: t.colors.destructiveForeground),
      ),
      onDismissed: (_) => onDelete(),
      child: AppCard(
        onTap: onToggle,
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            FCheckbox(
              value: todo.completed,
              onChange: (_) => onToggle(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: t.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          todo.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if ((todo.dueDate?.isNotEmpty ?? false) || todo.tags.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (todo.dueDate?.isNotEmpty ?? false) '截止 ${todo.dueDate}',
                        if (todo.tags.isNotEmpty) '${todo.tags.length} 个标签',
                      ].join(' · '),
                      style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
            if (todo.isChild)
              Icon(FLucideIcons.cornerDownRight,
                  size: 16, color: t.colors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
