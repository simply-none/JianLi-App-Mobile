// 浏览器设置页的行原子（分组标题 / 分组卡片 / 导航行 / 开关行 / 说明行）
//
// 抽出来的理由：设置页有 6 个分组、十几行，若各写一遍 Row+样式，
// 高度、间距、描边很快就会不一致。这里把「一行长什么样」定死，页面只负责列内容。
//
// 规格（与设计稿一致）：行高 52 · 卡片白底 r16 + 1px border · 页边距 16 · 行内边距 H16
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';

/// 分组标题（12 / w600 / mutedForeground）
class SettingsGroupLabel extends StatelessWidget {
  const SettingsGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: t.typography.body.xs.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.colors.mutedForeground,
        ),
      ),
    );
  }
}

/// 分组 = 标题 + 卡片；[children] 之间自动插 1px 分隔线。
/// [title] 传 null 表示不渲染标题（用于「标题已由外部单独渲染」的场景）。
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null && title!.isNotEmpty) SettingsGroupLabel(title!),
        AppCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(height: 1, color: t.colors.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 导航行（点击进下一层 / 弹选择器）：图标 + 文字 + 当前值 + 右箭头
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.hint,
    this.onTap,
  });

  final String label;
  final IconData? icon;

  /// 右侧当前值（如「百度」「3 个订阅」）
  final String? value;

  /// 行下方的补充说明（可选，用于长文案）
  final String? hint;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: t.colors.mutedForeground),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 15,
                      color: t.colors.foreground,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      hint!,
                      style: t.typography.body.xs.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value!,
                style: t.typography.body.xs.copyWith(
                  fontSize: 13,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              FLucideIcons.chevronRight,
              size: 18,
              color: t.colors.mutedForeground.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 开关行：图标 + 文字 + 右侧 FSwitch
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.icon,
    this.hint,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChange;
  final IconData? icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: t.colors.mutedForeground),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 15,
                    color: t.colors.foreground,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    hint!,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      height: 1.4,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          FSwitch(value: value, onChange: onChange),
        ],
      ),
    );
  }
}

/// 说明行（卡片内的灰色小字段落 / 一条规则）
class SettingsHintRow extends StatelessWidget {
  const SettingsHintRow(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14, color: t.colors.mutedForeground),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.6,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 危险行（清空 / 删除）：文字与图标都用 destructive 红
class SettingsDangerRow extends StatelessWidget {
  const SettingsDangerRow({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: t.colors.destructive),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: t.typography.body.sm.copyWith(
                  fontSize: 15,
                  color: t.colors.destructive,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 页面小标题（带左侧主色竖条）——规则页 / 管理页的分区用
class BrowserSectionTitle extends StatelessWidget {
  const BrowserSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              gradient: AppTokens.primaryGradient(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: t.typography.body.md.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.colors.foreground,
              ),
            ),
          ),
          // 可空尾随件：用集合里的 null-aware 元素（`?x`）而非 if 判空
          ?trailing,
        ],
      ),
    );
  }
}
