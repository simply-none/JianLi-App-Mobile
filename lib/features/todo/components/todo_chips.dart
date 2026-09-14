// 待办状态 / 标签 chip —— 列表卡片与卡片网格共用同一套渲染，
// 避免两侧各写一份后口径漂移（画布「07 待办·列表」与「卡片视图」字段必须一致）。
//
// 视觉核心已抽出为共享原子 `lib/app/ui/soft_chip.dart`（底色 = color × alpha · r10 ·
// 11/SemiBold）；本文件只保留待办语义包装与配色解析。
//
// 配色口径（与画布一致，主题自适应、不硬编码中性色）：
//   状态 chip  色底 15% · r10 · 内边距 4 · 11/SemiBold
//   标签 chip  各自色底 14% · r10 · 内边距 4 · 11/SemiBold
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/soft_chip.dart';
import '../models/todo.dart' show TodoStatusMeta, statusMeta;

/// 状态 chip（未开始/进行中/阻塞/已完成/已取消/重新开始）
class TodoStatusChip extends StatelessWidget {
  const TodoStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
    this.height,
    this.padding,
  });

  final String label;
  final Color color;

  /// 字号（默认 11；高密度列表可传入更小字号）
  final double fontSize;

  /// 行高倍数（null = 默认；传 1 与同行标题精确垂直居中）
  final double? height;

  /// 内边距（null = SoftChip 默认 all(4)；列表卡片族传 h8/v3 对齐提醒卡片）
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => SoftChip(
        label: label,
        color: color,
        alpha: 0.15,
        fontSize: fontSize,
        height: height,
        padding: padding ?? const EdgeInsets.all(4),
      );
}

/// 标签 chip（带标签名，配色走标签自身颜色）
///
/// [dot] = true 时在标签名前加 6px 色点：列表卡片里「状态 chip / 标签 chip」同排时，
/// 色点是与状态 chip 区分的第二重信号（底色之外的形状差）。
class TodoTagChip extends StatelessWidget {
  const TodoTagChip({
    super.key,
    required this.name,
    required this.color,
    this.padding,
    this.dot = false,
  });

  final String name;
  final Color color;

  /// 内边距（null = SoftChip 默认 all(4)）
  final EdgeInsetsGeometry? padding;

  /// 标签名前是否加 6px 色点
  final bool dot;

  @override
  Widget build(BuildContext context) => SoftChip(
        label: name,
        color: color,
        alpha: 0.14,
        padding: padding ?? const EdgeInsets.all(4),
        leading: dot
            ? Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            : null,
      );
}

/// 主题感知的状态元信息 —— **UI 渲染一律用这个，不要用 [statusMeta]**。
///
/// 画布「轴线式方案（定稿）」要求「进行中」切合主题色：`statusMeta` 是常量配色，
/// 换肤后仍会停在默认紫；本函数对 `in_progress` 取 `t.colors.primary`，
/// 9 套皮肤下都成立。其余状态与 [statusMeta] 完全一致。
///
/// 无 context 的纯逻辑场景（如分组标题只取 label）继续用 [statusMeta]。
TodoStatusMeta statusMetaOf(BuildContext context, String? s) =>
    statusMetaFor(context.theme, s);

/// 同上，但吃 `FThemeData`——供已经拿到 theme（没有 BuildContext）的渲染函数使用
/// （如日历视图的格子构建）。
TodoStatusMeta statusMetaFor(FThemeData t, String? s) {
  final base = statusMeta(s);
  if ((s ?? 'not_started') != 'in_progress') return base;
  final primary = t.colors.primary;
  return TodoStatusMeta(base.label, primary, primary.withValues(alpha: 0.15));
}

/// 标签 hex → Color（缺省/异常回退紫色）
Color parseTodoTagColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF8b5cf6);
  try {
    return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) |
        (hex.length == 7 ? 0xFF000000 : 0));
  } catch (_) {
    return const Color(0xFF8b5cf6);
  }
}
