// 待办列表卡片 —— 1:1 对齐画布「轴线式方案（定稿）」
// 画布：https://ardot.tencent.com/file/725472927339363
//
// 用户定稿的三条硬约束：
//   1. 左侧 3.5px 色轴**跟随状态色**（不跟随优先级）；
//   2. 状态由「灰底胶囊」降级为「圆点 + 彩色小字」，进行中取主题主色；
//   3. 优先级只在**时间行行尾**表达（旗帜图标 + 文字）。
//
// 骨架（白卡 · r16 · 描边 1px · elevation(level 2) · 无外 padding）：
//   Stack
//     ├ 左侧 3.5px 状态色轴（left/top/bottom = 0，随卡片满高，圆角由外层裁切）
//     └ 内容（start 让位 3.5 → 四周 padding 12 · Row gap 10 · 垂直居中）
//         勾选(20 圆环 · 描边 1.5) → 内容列(gap 7) → ⋯(16)
//   内容列三行：
//     行1  标题(15/SemiBold · 最多 2 行) + ⋯(16)
//     行2  状态点(6) + 状态字(11/SemiBold) + 标签 chips ┈┈ 子任务 n/m(11/Medium)
//     行3  ⏱ 时间(11) · ⟳ 重复(11) ┈┈┈┈┈ ⚑ 优先级(11/SemiBold · 高红/中琥珀/低绿)
//
// 字段缺失自动收缩：无重复 → 行3 只留时间 + 行尾优先级；
//                   无标签无子任务 → 行2 只剩状态点 + 状态字。
// 已完成 / 已取消：标题灰化 + 删除线；已完成勾选框 = 状态色实心圆 + 白勾。
//
// 颜色一律走主题 token / 状态色，暗色与换肤自动跟随，不硬编码中性色。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/tap_scale.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import 'todo_chips.dart';

/// 左侧状态色轴宽度（画布 3.5px）
const double _kRailWidth = 3.5;

/// 状态圆点直径
const double _kDotSize = 6;

/// 勾选框尺寸（画布 20×20 圆环）
const double _kCheckSize = 20;

/// 卡片内容内边距（画布 12）
const double _kCardPadding = 12;

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
    final muted = t.colors.mutedForeground;
    final status = effectiveStatus(item);
    final done = status == 'completed';
    final cancelled = status == 'cancelled';
    // 状态色：进行中取主题主色（换肤联动），其余取数据色
    final meta = statusMetaOf(context, status);
    final statusColor = meta.color;
    final faded = done || cancelled;

    final progress = subtaskProgress(allTodos, item.key);
    final tagMap = {for (final tg in tags) tg.key: tg};
    final tagViews = [
      for (final k in item.tags)
        if (tagMap.containsKey(k)) tagMap[k]!,
    ];
    final dueText = formatTodoDue(item.dueDate);
    final repeatText = formatRecurrence(
      item.recurrenceRule,
      item.recurrenceInterval,
      item.recurrenceWeekdays,
    );

    return TapScale(
      onTap: selectable ? onSelect : onTap,
      onLongPress: onLongPress,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: t.colors.border),
          boxShadow: AppTokens.elevation(context, level: 2),
        ),
        child: Stack(
          children: [
            // 左侧状态色轴（跟随状态色，与优先级无关）
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _kRailWidth,
              child: ColoredBox(color: statusColor),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _kRailWidth),
              child: Padding(
                padding: const EdgeInsets.all(_kCardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TodoCheck(
                      done: done,
                      statusColor: statusColor,
                      // 进行中的勾选环也用状态色，让「进行中」在左侧有三重表达
                      emphasized: status == 'in_progress',
                      selectable: selectable,
                      selected: selected,
                      onToggle: onToggle,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 行1：标题 + ⋯
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (indent)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 6,
                                  ),
                                  child: Icon(
                                    FLucideIcons.cornerDownRight,
                                    size: 14,
                                    color: muted,
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
                                    decoration: faded
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: faded ? muted : t.colors.foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onMore,
                                behavior: HitTestBehavior.opaque,
                                child: Icon(
                                  FLucideIcons.ellipsis,
                                  size: 16,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          // 行2：状态点 + 状态字 + 标签 ┈┈ 子任务 n/m
                          Row(
                            children: [
                              Container(
                                width: _kDotSize,
                                height: _kDotSize,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                meta.label,
                                style: t.typography.body.xs.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                              for (final tag in tagViews) ...[
                                const SizedBox(width: 8),
                                TodoTagChip(
                                  name: tag.name,
                                  color: parseTodoTagColor(tag.color),
                                ),
                              ],
                              if (progress != null) ...[
                                const Spacer(),
                                Text(
                                  '${progress.done}/${progress.total}',
                                  style: t.typography.body.xs.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 7),
                          // 行3：⏱ 时间 · ⟳ 重复 ┈┈┈ ⚑ 优先级
                          Row(
                            children: [
                              if (dueText != null && dueText.isNotEmpty)
                                _MetaText(
                                  icon: FLucideIcons.clock,
                                  text: dueText,
                                  color: muted,
                                ),
                              if (repeatText.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _MetaText(
                                  icon: FLucideIcons.repeat,
                                  text: repeatText,
                                  color: muted,
                                ),
                              ],
                              const Spacer(),
                              _MetaText(
                                icon: FLucideIcons.flag,
                                text: priorityLabel(item.priority),
                                color: priorityColor(item.priority),
                                bold: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 勾选框：未完成 = 圆环（进行中用状态色描边）；已完成 = 状态色实心圆 + 白勾；
/// 多选模式 = 圆点 / 实心点图标（沿用旧口径）。
class _TodoCheck extends StatelessWidget {
  const _TodoCheck({
    required this.done,
    required this.statusColor,
    required this.emphasized,
    required this.selectable,
    required this.selected,
    required this.onToggle,
  });

  final bool done;
  final Color statusColor;
  final bool emphasized;
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    if (selectable) {
      return Icon(
        selected ? FLucideIcons.circleDot : FLucideIcons.circle,
        size: _kCheckSize,
        color: selected ? AppTokens.accent(1) : t.colors.mutedForeground,
      );
    }

    final Widget box;
    if (done) {
      box = Container(
        width: _kCheckSize,
        height: _kCheckSize,
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(_kCheckSize / 2),
        ),
        child: Icon(
          FLucideIcons.check,
          size: 13,
          color: t.colors.primaryForeground,
        ),
      );
    } else {
      box = Container(
        width: _kCheckSize,
        height: _kCheckSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kCheckSize / 2),
          border: Border.all(
            color: emphasized ? statusColor : t.colors.border,
            width: 1.5,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _kCheckSize,
        height: _kCheckSize,
        child: box,
      ),
    );
  }
}

/// 行内「图标 + 文字」元信息（时钟 / 循环 / 旗帜）。
/// ⚠️ 宽度必须 hug：用 Row(mainAxisSize: min)，绝不写 Container(alignment:)——
///    Align 在有界松约束下会撑满整行，把后面的优先级顶飞。
class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: context.theme.typography.body.xs.copyWith(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      );
}
