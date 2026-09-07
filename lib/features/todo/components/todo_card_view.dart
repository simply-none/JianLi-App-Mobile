// 待办卡片网格视图（对齐 PC 卡片视图）—— 2 列卡片，含状态/优先级/到期/标签/子任务进度/父任务
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';

/// 卡片网格
class TodoCardView extends StatelessWidget {
  const TodoCardView({
    super.key,
    required this.items,
    required this.allTodos,
    required this.tags,
    this.selectable = false,
    this.selectedKeys = const {},
    this.onToggle,
    this.onMore,
    this.onSelect,
    this.onTap,
  });

  final List<TodoItem> items;
  final List<TodoItem> allTodos;
  final List<TodoTagView> tags;
  final bool selectable;
  final Set<String> selectedKeys;
  final void Function(TodoItem)? onToggle;
  final void Function(TodoItem)? onMore;
  final void Function(TodoItem)? onSelect;
  final void Function(TodoItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final tagMap = {for (final tg in tags) tg.key: tg};
    return GridView.builder(
      padding: EdgeInsets.only(
        top: AppTokens.listTopGapOf(context),
        bottom: AppTokens.pageBottomGapOf(context),
        left: AppTokens.pagePaddingOf(context),
        right: AppTokens.pagePaddingOf(context),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final meta = statusMeta(effectiveStatus(item));
        final overdue = dueGroupOf(item) == 'overdue' && effectiveStatus(item) != 'completed';
        final progress = subtaskProgress(allTodos, item.key);
        final selected = selectedKeys.contains(item.key);
        return AppCard(
          onTap: selectable
              ? (onSelect == null ? null : () => onSelect!(item))
              : (onTap == null ? null : () => onTap!(item)),
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (selectable)
                        Icon(
                          selected ? FLucideIcons.circleDot : FLucideIcons.circle,
                          size: 18,
                          color: selected ? t.colors.primary : t.colors.mutedForeground,
                        )
                      else
                        FCheckbox(
                          value: effectiveStatus(item) == 'completed',
                          onChange: (_) => onToggle?.call(item),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.body.md.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: effectiveStatus(item) == 'completed'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  if (item.dueDate != null)
                    Row(
                      children: [
                        Icon(FLucideIcons.clock, size: 13,
                            color: overdue ? t.colors.destructive : t.colors.mutedForeground),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _fmtDue(item.dueDate!),
                            style: t.typography.body.xs.copyWith(
                              color: overdue ? t.colors.destructive : t.colors.mutedForeground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(FLucideIcons.listChecks, size: 13, color: t.colors.mutedForeground),
                        const SizedBox(width: 4),
                        Text('${progress.done}/${progress.total}',
                            style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground)),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final k in item.tags)
                        if (tagMap.containsKey(k))
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _parseColor(tagMap[k]!.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
              if (!selectable && onMore != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => onMore!(item),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(FLucideIcons.ellipsis,
                          size: 18, color: t.colors.mutedForeground),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDue(String s) {
    final d = parseTodoDateTime(s);
    if (d == null) return s;
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
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
