// 基础 UI 原子组件（forui token 驱动，shadcn 卡片化视觉语言）
//
// 全 App 复用的小颗粒组件收敛于此；每个组件保持无业务依赖，
// 只吃数据与回调，保证「原子化、组件化」约定。
// 取色一律 context.theme.colors.*，字体一律 context.theme.typography.*，严禁硬编码。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 通用圆角卡片 —— card 底色 + 1px border（shadcn 观感）
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: margin,
      child: FTappable(
        onPress: onTap,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: t.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.colors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 区块标题（左侧色条 + 标题 + 尾部动作）
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing, this.onTrailingTap});

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
              child: Text(trailing!, style: t.typography.body.sm.copyWith(color: t.colors.primary)),
            ),
        ],
      ),
    );
  }
}

/// 空态提示（图标 + 主/副标题）
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: t.colors.border),
          const SizedBox(height: 12),
          Text(title, style: t.typography.body.md),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
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
  const StatBlock({super.key, required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: t.typography.body.lg.copyWith(
            color: color ?? t.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: t.typography.body.xs.copyWith(color: color ?? t.colors.foreground)),
      ],
    );
  }
}
