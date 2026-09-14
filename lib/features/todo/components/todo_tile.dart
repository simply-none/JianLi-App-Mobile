// 待办列表卡片 —— 1:1 对齐画布「待办列表卡片 · 方案 A」
// 画布：https://ardot.tencent.com/file/725720750360244
//
// 方案 A 三条改动（与提醒卡片 A 同一骨架，出于全 App 列表卡视觉统一）：
//   1. 去掉左侧 3.5px 状态色轴 → 状态改由 R1 的 40×40 状态色渐变图标盘承载；
//   2. 状态由「圆点 + 彩色小字」升格为 SoftChip（与标签 chip 同规格 · 底色 15%），
//      「状态 vs 标签」改由「无点 vs 6px 色点」区分；
//   3. 勾选框移到 R1 行尾（对齐提醒卡片的 FSwitch 槽位），⋯ 移到时间行行尾。
//
// 骨架（AppCard · padding 14 · r16 · elevation 1 · margin 0）：
//   Column(gap 8)
//     R1  Row(居中)   图标盘(40×40 r13 · 状态色渐变 · 白图标 20)
//                     └12┘ 标题(15/SemiBold · ≤2 行) └8┘ 勾选(22)
//     R2  Row(gap 6)  状态 chip + 标签 chips ┈┈ 子任务 n/m(11/Medium)
//     R3  Row(gap 6)  ⏱ 时间 · ⟳ 重复 ┈┈ ⚑ 优先级 └12┘ ⋯(16)
//
// 字段缺失自动收缩：无重复 → R3 只留时间 + 行尾优先级；无标签无子任务 → R2 只剩状态 chip。
// 已取消 / 已完成：标题灰化 + 删除线；图标盘仍用状态色（状态本身已经说明了结果）。
//
// 状态 →（图标盘色 / 白图标）：
//   未开始 #6B7280 circle · 进行中 主题主色 circlePlay · 阻塞 #EF4444 circleAlert
//   已完成 #22C55E circleCheck · 已取消 #9CA3AF circleSlash · 重新开始 #06B6D4 rotateCcw
//
// 颜色一律走主题 token / 状态色，暗色与换肤自动跟随，不硬编码中性色。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import 'todo_chips.dart';

/// 状态图标盘尺寸（画布 40×40）
const double _kIconDiskSize = 40;

/// 图标盘圆角（画布 13 ≈ 40 × 0.33，与首页快捷入口 / 提醒卡片同比例）
const double _kIconDiskRadius = 13;

/// 图标盘内白色图标尺寸（画布 20）
const double _kIconSize = 20;

/// 勾选框外框尺寸（画布 22）
const double _kCheckSize = 22;

/// 勾选圆环直径（画布 18.4）与描边（画布 1.8）
const double _kCheckRing = 18.4;
const double _kCheckStroke = 1.8;

/// 卡片内容内边距（画布 14）
const double _kCardPadding = 14;

/// chip 内边距（画布 h8/v3 —— 与提醒卡片族同规格）
const EdgeInsets _kChipPadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 3,
);

/// R2 最多平铺几个标签 chip（超出折成「+N」，避免单行 Row 撑爆）
const int _kMaxTags = 3;

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
    final allTagViews = [
      for (final k in item.tags)
        if (tagMap.containsKey(k)) tagMap[k]!,
    ];
    // 标签超量截断：R2 是单行 Row，放开了写会直接撑爆（与笔记卡片同口径给「+N」）
    final tagViews = allTagViews.take(_kMaxTags).toList();
    final tagOverflow = allTagViews.length - tagViews.length;
    final dueText = formatTodoDue(item.dueDate);
    final repeatText = formatRecurrence(
      item.recurrenceRule,
      item.recurrenceInterval,
      item.recurrenceWeekdays,
    );

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(_kCardPadding),
      elevation: 1,
      onTap: selectable ? onSelect : onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── R1：状态图标盘 + 标题 + 勾选 ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (indent) ...[
                Icon(FLucideIcons.cornerDownRight, size: 14, color: muted),
                const SizedBox(width: 6),
              ],
              // 状态图标盘：状态色渐变 + 白图标（替代旧的左侧 3.5px 色轴）
              Container(
                width: _kIconDiskSize,
                height: _kIconDiskSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTokens.accentGradient(statusColor),
                  borderRadius: BorderRadius.circular(_kIconDiskRadius),
                ),
                child: Icon(
                  _statusIcon(status),
                  size: _kIconSize,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.md.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: faded ? TextDecoration.lineThrough : null,
                    color: faded ? muted : t.colors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TodoCheck(
                done: done,
                statusColor: statusColor,
                // 进行中的勾选环也用状态色，让「进行中」在 R1 有两重表达
                emphasized: status == 'in_progress',
                selectable: selectable,
                selected: selected,
                onToggle: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── R2：状态 chip + 标签 chips ┈┈ 子任务 n/m ────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TodoStatusChip(
                label: meta.label,
                color: statusColor,
                padding: _kChipPadding,
              ),
              for (final tag in tagViews) ...[
                const SizedBox(width: 6),
                TodoTagChip(
                  name: tag.name,
                  color: parseTodoTagColor(tag.color),
                  padding: _kChipPadding,
                  dot: true,
                ),
              ],
              if (tagOverflow > 0) ...[
                const SizedBox(width: 6),
                FlatBadge(label: '+$tagOverflow'),
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
          const SizedBox(height: 8),
          // ── R3：⏱ 时间 · ⟳ 重复 ┈┈┈ ⚑ 优先级 · ⋯ ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (dueText != null && dueText.isNotEmpty)
                _MetaText(
                  icon: FLucideIcons.clock,
                  text: dueText,
                  color: muted,
                ),
              if (repeatText.isNotEmpty) ...[
                const SizedBox(width: 6),
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
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onMore,
                behavior: HitTestBehavior.opaque,
                child: Icon(FLucideIcons.ellipsis, size: 16, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 状态 → 图标盘里的白图标（6 态全覆盖，与状态语义同源）
IconData _statusIcon(String status) => switch (status) {
      'in_progress' => FLucideIcons.circlePlay,
      'blocked' => FLucideIcons.circleAlert,
      'completed' => FLucideIcons.circleCheck,
      'cancelled' => FLucideIcons.circleSlash,
      'restart' => FLucideIcons.rotateCcw,
      _ => FLucideIcons.circle, // not_started
    };

/// 勾选框：未完成 = 圆环（进行中用状态色描边，其余灰环）；已完成 = 状态色实心圆 + 白勾；
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
        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        child: const Icon(FLucideIcons.check, size: 13, color: Colors.white),
      );
    } else {
      // 外框 22 用于撑住点击热区，可见环只有 18.4（画布口径）
      box = Center(
        child: Container(
          width: _kCheckRing,
          height: _kCheckRing,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: emphasized ? statusColor : t.colors.border,
              width: _kCheckStroke,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(width: _kCheckSize, height: _kCheckSize, child: box),
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
