// 待办列表行（forui 化）—— 勾选完成 + 状态/优先级/到期/标签/子任务进度/父任务 + 操作入口
//
// 列表视图与（按父任务分组时的）子项复用同一行。selectable 模式下点击整行=选择，
// 不再弹出操作菜单；非选择模式点击行=打开编辑，行尾「⋯」=操作菜单（编辑/记录/删除）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';

/// 列表行
class TodoListTile extends StatelessWidget {
  const TodoListTile({
    super.key,
    required this.item,
    required this.allTodos,
    required this.tags,
    this.selectable = false,
    this.selected = false,
    this.onToggle,
    this.onMore,
    this.onSelect,
    this.onTap,
    this.indent = false,
  });

  final TodoItem item;
  final List<TodoItem> allTodos;
  final List<TodoTagView> tags;
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onMore;
  final VoidCallback? onSelect;
  final VoidCallback? onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final meta = statusMeta(effectiveStatus(item));
    final overdue = dueGroupOf(item) == 'overdue' && effectiveStatus(item) != 'completed';
    final progress = subtaskProgress(allTodos, item.key);
    final tagMap = {for (final tg in tags) tg.key: tg};

    final checkbox = FCheckbox(
      value: effectiveStatus(item) == 'completed',
      onChange: (_) => onToggle?.call(),
    );

    final metaRow = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 状态 chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: meta.bg,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Text(
            meta.label,
            style: t.typography.body.xs.copyWith(
              color: meta.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // 优先级旗标
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.flag, size: 13, color: priorityColor(item.priority)),
            const SizedBox(width: 2),
            Text(
              priorityLabel(item.priority),
              style: t.typography.body.xs
                  .copyWith(color: priorityColor(item.priority)),
            ),
          ],
        ),
        // 到期
        if (item.dueDate != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FLucideIcons.clock, size: 13, color: overdue ? t.colors.destructive : t.colors.mutedForeground),
              const SizedBox(width: 2),
              Text(
                _fmtDue(item.dueDate!),
                style: t.typography.body.xs.copyWith(
                  color: overdue ? t.colors.destructive : t.colors.mutedForeground,
                ),
              ),
            ],
          ),
        // 子任务进度
        if (progress != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FLucideIcons.listChecks, size: 13, color: t.colors.mutedForeground),
              const SizedBox(width: 2),
              Text(
                '${progress.done}/${progress.total}',
                style: t.typography.body.xs
                    .copyWith(color: t.colors.mutedForeground),
              ),
            ],
          ),
        // 父任务
        if (item.isChild)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FLucideIcons.cornerDownRight, size: 13, color: t.colors.mutedForeground),
              const SizedBox(width: 2),
              Text(
                item.parentIds
                    .map((k) => allTodos.firstWhere((e) => e.key == k,
                        orElse: () => item).title)
                    .join('、'),
                style: t.typography.body.xs
                    .copyWith(color: t.colors.mutedForeground),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        // 标签色点
        for (final k in item.tags)
          if (tagMap.containsKey(k))
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _parseColor(tagMap[k]!.color),
                shape: BoxShape.circle,
              ),
            ),
      ],
    );

    final content = AppCard(
      onTap: selectable
          ? onSelect
          : onTap,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectable)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Icon(
                selected ? FLucideIcons.circleDot : FLucideIcons.circle,
                size: 20,
                color: selected ? t.colors.primary : t.colors.mutedForeground,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: checkbox,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (indent)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(FLucideIcons.cornerDownRight,
                            size: 14, color: t.colors.mutedForeground),
                      ),
                    Expanded(
                      child: Text(
                        item.title,
                        style: t.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: effectiveStatus(item) == 'completed'
                              ? TextDecoration.lineThrough
                              : null,
                          color: effectiveStatus(item) == 'completed'
                              ? t.colors.mutedForeground
                              : t.colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                metaRow,
              ],
            ),
          ),
          if (!selectable && onMore != null)
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Icon(FLucideIcons.ellipsis,
                    size: 18, color: t.colors.mutedForeground),
              ),
            ),
        ],
      ),
    );

    return content;
  }

  String _fmtDue(String s) {
    final d = parseTodoDateTime(s);
    if (d == null) return s;
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      return '今天 ${_pad(d.hour)}:${_pad(d.minute)}';
    }
    return '${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF8b5cf6);
  try {
    return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) |
        (hex.length == 7 ? 0xFF000000 : 0));
  } catch (_) {
    return const Color(0xFF8b5cf6);
  }
}
