// 磨砂玻璃卡（UI 现代化 Phase 1）
//
// ClipRRect + BackdropFilter 磨砂 + 半透明填充 + 1px 高光描边 + 轻阴影。
// 用于首页横幅、弹层、置顶卡等需要「质感」的位置；列表区避免大范围 blur 以防掉帧。
// 约束：import material_ui；取色走 context.theme / AppTokens。
import 'dart:ui';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../theme/app_theme.dart';
import 'tap_scale.dart';

/// 磨砂玻璃卡片
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.radius = AppTokens.radiusMd,
    this.blur = 16,
    this.haptic,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;
  final HapticType? haptic;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final fill = (isDark ? Colors.white : t.colors.primary)
        .withValues(alpha: isDark ? 0.06 : 0.10);
    final stroke = (isDark ? Colors.white : t.colors.foreground)
        .withValues(alpha: 0.12);

    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke),
        boxShadow: AppTokens.elevation(context, level: 2),
      ),
      child: child,
    );

    final blurred = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: box,
      ),
    );

    if (onTap == null) return Padding(padding: margin, child: blurred);
    return Padding(
      padding: margin,
      child: TapScale(onTap: onTap, haptic: haptic, child: blurred),
    );
  }
}
