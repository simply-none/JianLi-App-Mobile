// 待办页（forui 化）—— 过滤切换 + 复选完成 + 新增对话框
//
// 移动端第一批：单层列表 + 增/删/勾选；父子任务缩进与重复任务编辑列入 P2。
// forui 改造点：FScaffold+FHeader.nested 骨架、FButton 过滤切换、FCheckbox 勾选、
// showFDialog 新增、Dismissible 滑动删除（无 forui 等价物，material_ui 版保留）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
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
    const filters = [TodoFilter.active, TodoFilter.completed, TodoFilter.all];
    const filterLabels = ['进行中', '已完成', '全部'];

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
          // 过滤切换（滑块分段，选中态下方渐变指示块）
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: JianliSegmented(
              items: [for (final l in filterLabels) (null, l)],
              selected: filters.indexOf(_filter),
              onSelect: (i) => setState(() => _filter = filters[i]),
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
                // 横幅统计基于全量（不随过滤切换跳变）
                final activeCount = todos.where((t) => !t.completed).length;
                final doneCount = todos.length - activeCount;
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: FLucideIcons.listTodo,
                    title: '这里空空如也',
                  );
                }
                return ColoredBox(
                  color: AppTokens.pageTint(context),
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: AppTokens.listTopGapOf(context),
                      bottom: AppTokens.pageBottomGapOf(context),
                    ),
                    children: [
                      StaggerList(
                        children: [
                          // 页面专属蓝渐变横幅（与效率分组页「待办」入口色对齐）
                          PageBanner(
                            icon: FLucideIcons.listTodo,
                            title: '待办',
                            subtitle: '专注当下，一件一件来',
                            accentIndex: 1,
                            stats: [
                              ('$activeCount', '进行中'),
                              ('$doneCount', '已完成'),
                            ],
                          ),
                          for (var i = 0; i < items.length; i++)
                            _TodoTile(
                              todo: items[i],
                              accentIndex: i,
                              tagCount: tagsAsync.value?.length ?? 0,
                              onToggle: () => ref
                                  .read(todoRepositoryProvider)
                                  .toggleComplete(
                                    items[i].key,
                                    !items[i].completed,
                                  ),
                              onDelete: () => ref
                                  .read(todoRepositoryProvider)
                                  .deleteTodo(items[i].key),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 新增待办（底部抽屉——小功能新增统一抽屉化；第一批仅采集标题）
  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '新增待办',
              style: c.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '今天要完成什么？',
              style: c.theme.typography.body.sm.copyWith(
                color: c.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 14),
            FTextField(
              control: FTextFieldControl.managed(controller: controller),
              hint: '要做什么？',
              autofocus: true,
              onSubmit: (v) => Navigator.pop(c, v),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: '添加',
              icon: FLucideIcons.plus,
              onPress: () => Navigator.pop(c, controller.text),
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
    required this.accentIndex,
    required this.tagCount,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem todo;
  final int accentIndex;
  final int tagCount;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(accentIndex);
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
            SquircleBox(
              size: 40,
              radius: 12,
              gradient: AppTokens.accentGradient(accent),
              alignment: Alignment.center,
              child: Icon(FLucideIcons.listTodo, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            FCheckbox(value: todo.completed, onChange: (_) => onToggle()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: t.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if ((todo.dueDate?.isNotEmpty ?? false) ||
                      todo.tags.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (todo.dueDate?.isNotEmpty ?? false)
                          '截止 ${todo.dueDate}',
                        if (todo.tags.isNotEmpty) '${todo.tags.length} 个标签',
                      ].join(' · '),
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (todo.isChild)
              Icon(
                FLucideIcons.cornerDownRight,
                size: 16,
                color: t.colors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
