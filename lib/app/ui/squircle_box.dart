// 超椭圆底盘（UI 现代化 Phase 1）
//
// 用 ContinuousRectangleBorder 近似 iOS squircle，比普通圆角更柔和。供图标底盘 /
// 头像使用，支持纯色 / 渐变填充，可选点击按压 + 触感。约束：import material_ui。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../theme/app_theme.dart';
import 'tap_scale.dart';

/// 超椭圆容器
class SquircleBox extends StatelessWidget {
  const SquircleBox({
    super.key,
    this.child,
    this.color,
    this.gradient,
    this.size,
    this.radius = AppTokens.radiusMd,
    this.padding,
    this.alignment,
    this.onTap,
    this.haptic,
  });

  final Widget? child;

  /// 纯色填充（gradient 优先）
  final Color? color;

  /// 渐变填充（优先于 color）
  final Gradient? gradient;

  final double? size;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// 子组件对齐（图标底盘传 Alignment.center 居中）
  final AlignmentGeometry? alignment;

  final VoidCallback? onTap;
  final HapticType? haptic;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final box = Container(
      width: size,
      height: size,
      padding: padding,
      alignment: alignment,
      decoration: ShapeDecoration(
        color: gradient == null
            ? (color ?? t.colors.primary.withValues(alpha: 0.12))
            : null,
        gradient: gradient,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return TapScale(onTap: onTap, haptic: haptic, child: box);
  }
}
