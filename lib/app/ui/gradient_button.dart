// 主色渐变按钮（UI 现代化 Phase 1）
//
// 关键 CTA 用：主色渐变 + 轻阴影 + 按压缩放 + 触感。自定义实现（不包 FButton），
// 以便完全掌控渐变背景。约束：import material_ui；取色走 AppTokens / context.theme。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../theme/app_theme.dart';
import 'tap_scale.dart';

/// 渐变按钮
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPress,
    this.height = 48,
    this.haptic = HapticType.medium,
    this.fullWidth = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPress;
  final double height;
  final HapticType? haptic;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final child = Container(
      height: height,
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppTokens.primaryGradient(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        boxShadow: AppTokens.elevation(context, level: 2),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: t.colors.primaryForeground, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: t.typography.body.md.copyWith(
              color: t.colors.primaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return TapScale(onTap: onPress, haptic: haptic, scale: 0.96, child: child);
  }
}
