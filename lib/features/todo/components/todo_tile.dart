// 待办列表卡片 —— 1:1 对齐画布「07 待办·列表页 主态」卡片节点（5:456 / 5:473 / 5:491）
//
// 画布结构（白卡：底 t.colors.card · 描边 t.colors.border · 圆角 16 · 内边距 14 · 子项间距 10）：
//   勾选(20×20 · r6 · 描边) → 内容(纵向 · 间距 6) → ⋯(16)
//   内容三行：
//     行1  标题(15/SemiBold) + 状态 chip(11/SemiBold · 色底 15%) + 优先级(11/SemiBold · 红/琥珀/绿)
//     行2  标签 chips（11/SemiBold · 各自色底 14% · r10）
//     行3  时间(11/次要) ⇄ 子任务进度(11/次要) —— SPACE_BETWEEN
// 时间/子任务都没有时整行不渲染；标签为空时行2不渲染。
//
// 颜色一律走主题 token / 数据色 + alpha（画布给的 #D1D5DB / #6B7280 / #9CA3AF 等中性色，
// 取值与主题 mutedForeground / border 基本一致），暗色主题下自动跟随，不硬编码。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/tap_scale.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import 'todo_chips.dart';

/// 列表卡片
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
    this.onLongPress,
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

  /// 长按（页面用它进入多选模式）
  final VoidCallback? onLongPress;

  /// 是否为「按父任务」分组下的子项（标题前加一个缩进箭头）
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final done = effectiveStatus(item) == 'completed';
    final meta = statusMeta(effectiveStatus(item));
    final progress = subtaskProgress(allTodos, item.key);
    final tagMap = {for (final tg in tags) tg.key: tg};
    final tagViews = [
      for (final k in item.tags)
        if (tagMap.containsKey(k)) tagMap[k]!,
    ];
    final dueText = formatTodoDue(item.dueDate);
    // 行3：时间 ⇄ 子任务进度（都没有则整行不渲染）
    final hasRow3 = dueText != null || progress != null;

    return TapScale(
      onTap: selectable ? onSelect : onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: t.colors.border),
          boxShadow: AppTokens.elevation(context, level: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 勾选（20×20 · r6）：完成态主色实底 + 白勾
            SizedBox(
              width: 20,
              height: 20,
              child: selectable
                  ? Icon(
                      selected ? FLucideIcons.circleDot : FLucideIcons.circle,
                      size: 20,
                      color: selected
                          ? t.colors.primary
                          : t.colors.mutedForeground,
                    )
                  : GestureDetector(
                      onTap: onToggle,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        decoration: BoxDecoration(
                          color: done ? t.colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: done
                              ? null
                              : Border.all(color: t.colors.border, width: 1.5),
                        ),
                        child: done
                            ? Icon(
                                FLucideIcons.check,
                                size: 13,
                                color: t.colors.primaryForeground,
                              )
                            : null,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 行1：标题 + 状态 + 优先级
                  Row(
                    children: [
                      if (indent)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            FLucideIcons.cornerDownRight,
                            size: 14,
                            color: t.colors.mutedForeground,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.body.md.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: done ? TextDecoration.lineThrough : null,
                            color: done
                                ? t.colors.mutedForeground
                                : t.colors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TodoStatusChip(label: meta.label, color: meta.color),
                      const SizedBox(width: 6),
                      Text(
                        priorityLabel(item.priority),
                        style: t.typography.body.xs.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: priorityColor(item.priority),
                        ),
                      ),
                    ],
                  ),
                  // 行2：标签
                  if (tagViews.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tagViews)
                          TodoTagChip(name: tag.name, color: parseTodoTagColor(tag.color)),
                      ],
                    ),
                  ],
                  // 行3：时间 ⇄ 子任务
                  if (hasRow3) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dueText ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.typography.body.xs.copyWith(
                              fontSize: 11,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                        ),
                        if (progress != null)
                          Text(
                            '子任务 ${progress.done}/${progress.total}',
                            style: t.typography.body.xs.copyWith(
                              fontSize: 11,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 行尾操作（画布 ⋯ 16）
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Icon(
                  FLucideIcons.ellipsis,
                  size: 16,
                  color: t.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
