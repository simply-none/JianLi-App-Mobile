// 基础 UI 原子组件（forui token 驱动，shadcn 卡片化视觉语言）
//
// 全 App 复用的小颗粒组件收敛于此；每个组件保持无业务依赖，
// 只吃数据与回调，保证「原子化、组件化」约定。
// 取色一律 context.theme.colors.*，字体一律 context.theme.typography.*，严禁硬编码。
//
// Phase 1 升级：AppCard 默认加悬浮阴影 + 按压缩放（TapScale）；StatBlock 可选
// 数字滚动（AnimatedStat）；EmptyState 可选插画。全部向后兼容，旧调用方零改动。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../theme/app_theme.dart';
import 'animated_stat.dart';
import 'squircle_box.dart';
import 'tap_scale.dart';

/// 通用圆角卡片 —— card 底色 + 1px border + 轻阴影（shadcn 观感），可点击缩放
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.elevation = 1,
    this.radius = AppTokens.radiusMd,
    this.haptic,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 内边距
  final EdgeInsetsGeometry padding;

  /// 外边距
  final EdgeInsetsGeometry margin;

  /// 阴影等级 0..3（0 = 无）
  final int elevation;

  /// 圆角（默认 AppTokens.radiusMd）
  final double radius;

  /// 点击触感（null = 不触发）
  final HapticType? haptic;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.colors.border),
        boxShadow: AppTokens.elevation(context, level: elevation),
      ),
      child: child,
    );
    if (onTap == null) return Padding(padding: margin, child: card);
    return Padding(
      padding: margin,
      child: TapScale(onTap: onTap, haptic: haptic, child: card),
    );
  }
}

/// 区块标题（左侧色条 + 标题 + 尾部动作）
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: t.colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: t.typography.body.md.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: t.typography.body.sm.copyWith(color: t.colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// 空态提示（图标 / 插画 + 主/副标题）
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.illustration,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// 可选插画（优先级高于 icon），用于更「暖」的空态
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration != null)
            illustration!
          else
            // 图标盘升级：主色软底超椭圆，替代裸描边色图标（空态也有色彩个性）
            SquircleBox(
              size: 76,
              radius: 26,
              color: AppTokens.accentSoft(context, t.colors.primary),
              alignment: Alignment.center,
              child: Icon(icon, size: 32, color: t.colors.primary),
            ),
          const SizedBox(height: 14),
          Text(title, style: t.typography.body.md),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: t.typography.body.sm.copyWith(
                color: t.colors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 统计块（数字 + 标签，用于首页聚合与统计页）
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.animate = false,
  });

  final String value;
  final String label;
  final Color? color;

  /// 数字滚动：仅当 value 为纯数字时生效（含小数自动 1 位）
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final numeric = double.tryParse(value) != null;
    final valueStyle = t.typography.body.lg.copyWith(
      color: color ?? t.colors.primary,
      fontWeight: FontWeight.w700,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (animate && numeric)
          AnimatedStat(
            value: double.parse(value),
            style: valueStyle,
            decimals: value.contains('.') ? 1 : 0,
          )
        else
          Text(value, style: valueStyle),
        const SizedBox(height: 2),
        Text(
          label,
          style: t.typography.body.xs.copyWith(
            color: color ?? t.colors.foreground,
          ),
        ),
      ],
    );
  }
}
