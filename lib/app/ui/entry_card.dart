// 功能入口卡（2026 视觉：专属强调色渐变底盘 + 大圆角 + 按压缩放）
//
// 首页分组入口与三个 Hub 分组页共用；取代旧的「白卡描边 + 紫色小图标」朴素样式。
// 取色一律 AppTokens / context.theme，强调色按 accentIndex 从色板取。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../theme/app_theme.dart';
import 'squircle_box.dart';
import 'tap_scale.dart';

/// 功能入口卡：渐变图标底盘 + 标题 + 描述 + 箭头
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentIndex = 0,
    this.onTap,
    this.haptic,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 专属强调色索引（AppTokens.accents）
  final int accentIndex;
  final VoidCallback? onTap;
  final HapticType? haptic;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(accentIndex);
    return Padding(
      padding: margin,
      child: TapScale(
        onTap: onTap,
        haptic: haptic,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.colors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            boxShadow: AppTokens.elevation(context, level: 1),
          ),
          child: Row(
            children: [
              SquircleBox(
                size: 46,
                radius: 16,
                gradient: AppTokens.accentGradient(accent),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.typography.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                FLucideIcons.chevronRight,
                size: 18,
                color: t.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
