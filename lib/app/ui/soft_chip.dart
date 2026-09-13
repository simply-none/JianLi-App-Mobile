// 软底 chip（通用原子）—— 待办状态 / 标签 chip 的泛化，供各功能域统一口径
//
// 规格（画布 07 / todo_chips.dart 同源）：
//   底色 = [color] × [alpha] · r10 · 内边距 4（可调）· 文字 11/SemiBold 同色
//   [onRemove] 非空时右侧追加 × 删除钮（生效条件 chip 形态：内边距 6 · alpha 0.12）
// 严禁硬编码中性色 —— 颜色一律由调用方传主题色 / AppTokens.accent(i) / 业务语义色。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'tap_scale.dart';

class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    required this.color,
    this.alpha = 0.14,
    this.padding = const EdgeInsets.all(4),
    this.fontSize = 11,
    this.height,
    this.leading,
    this.onRemove,
    this.onTap,
  });

  final String label;
  final Color color;

  /// 底色透明度（状态 chip 0.15 / 标签 chip 0.14 / 条件 chip 0.12）
  final double alpha;

  final EdgeInsetsGeometry padding;

  /// 字号（默认 11；卡片内高密度场景可传入更小字号）
  final double fontSize;

  /// 行高倍数（null = 沿用主题 typography 默认；高密度卡片传 1 让盒子紧贴字形，
  /// 与同行标题精确垂直居中对齐）。
  final double? height;

  /// 左侧前置件（小图标 / 色点）
  final Widget? leading;

  /// 删除回调（非空时显示 ×；可点击移除的摘要 chip 用）
  final VoidCallback? onRemove;

  /// 整体点击回调（选择型 chip 用；无 ×；与 [onRemove] 互斥使用）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final labelStyle = t.typography.body.xs.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
    final chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(
            label,
            style: labelStyle.copyWith(height: height),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            Icon(FLucideIcons.x, size: 11, color: color),
          ],
        ],
      ),
    );
    if (onRemove == null && onTap == null) return chip;
    return TapScale(onTap: onRemove ?? onTap, child: chip);
  }
}
