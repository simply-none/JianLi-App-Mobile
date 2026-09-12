// 待办卡片视图 —— 字段集 1:1 对齐列表瓦片（todo_tile.dart）：
//   勾选 → 标题 → 状态 chip + 优先级 → 标签 chips → 到期 ⇄ 子任务进度。
// 与列表瓦片共用 todo_chips.dart 的状态/标签 chip，避免两侧渲染口径漂移。
//
// ⚠️ 布局：用双列瀑布式（左右 Column）替代固定 childAspectRatio 的 GridView，
// 让每张卡片高度跟随自身内容，消灭内容少时的大片留白。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import 'todo_chips.dart';

/// 卡片视图（双列瀑布式，卡片高度 hug 内容）
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
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final card = _buildCard(context, items[i], tagMap, t);
      (i.isEven ? left : right).add(card);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: AppTokens.listTopGapOf(context),
        bottom: AppTokens.pageBottomGapOf(context),
        left: AppTokens.pagePadding,
        right: AppTokens.pagePadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              spacing: 12,
              children: left,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              spacing: 12,
              children: right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    TodoItem item,
    Map<String, TodoTagView> tagMap,
    FThemeData t,
  ) {
    final done = effectiveStatus(item) == 'completed';
    final meta = statusMeta(effectiveStatus(item));
    final progress = subtaskProgress(allTodos, item.key);
    final selected = selectedKeys.contains(item.key);
    final tagViews = [
      for (final k in item.tags)
        if (tagMap.containsKey(k)) tagMap[k]!,
    ];
    final dueText = formatTodoDue(item.dueDate);
    // 底部行：时间 ⇄ 子任务进度（都没有则整行不渲染，对齐列表瓦片）
    final hasFooter = dueText != null || progress != null;

    return AppCard(
      onTap: selectable
          ? (onSelect == null ? null : () => onSelect!(item))
          : (onTap == null ? null : () => onTap!(item)),
      margin: EdgeInsets.zero,
      elevation: 2,
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 行1：勾选 + 标题（2 行）—— 对齐列表瓦片行1 前半
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectable)
                    Icon(
                      selected ? FLucideIcons.circleDot : FLucideIcons.circle,
                      size: 18,
                      color: selected ? t.colors.primary : t.colors.mutedForeground,
                    )
                  else
                    FCheckbox(
                      value: done,
                      onChange: (_) => onToggle?.call(item),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      // 避免标题滑到右上角 ⋯ 下面
                      padding: EdgeInsets.only(
                        right: (!selectable && onMore != null) ? 14 : 0,
                      ),
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.typography.body.md.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 行2：状态 chip + 优先级 —— 对齐列表瓦片行1 后半
              Row(
                children: [
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
              // 行3：标签 chips（带名字）—— 对齐列表瓦片行2
              if (tagViews.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tagViews)
                      TodoTagChip(
                        name: tag.name,
                        color: parseTodoTagColor(tag.color),
                      ),
                  ],
                ),
              ],
              // 行4：时间 ⇄ 子任务进度 —— 对齐列表瓦片行3
              if (hasFooter) ...[
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
  }
}
