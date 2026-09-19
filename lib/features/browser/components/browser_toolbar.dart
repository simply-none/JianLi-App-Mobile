// 浏览器底部工具栏（返回 / 前进 / 首页 / 标签 / 菜单）
//
// 纯展示 + 回调。返回 / 前进在不可用时置灰（设计稿要求）。
// 标签项带数量角标（>1 才显示）。
//
// ⚠️ 中间位是**首页**（回新标签页），不是刷新 —— 刷新已移到菜单抽屉里
//    （2026-09-19 用户定案：中间位放最高频动作，而「回首页」比「刷新」常用）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';

/// 底栏高度（与画布一致；页面布局常量收口在这里，避免两处各写一套）
const double kBrowserToolbarHeight = 64;

class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({
    super.key,
    this.canGoBack = false,
    this.canGoForward = false,
    this.tabCount = 1,
    this.onBack,
    this.onForward,
    this.onHome,
    this.onTabs,
    this.onMenu,
  });

  final bool canGoBack;
  final bool canGoForward;
  final int tabCount;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  /// 回到首页（新标签页）。当前已是空白页时应传 null 置灰。
  final VoidCallback? onHome;

  final VoidCallback? onTabs;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      height: kBrowserToolbarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.pagePadding,
      ),
      decoration: BoxDecoration(
        color: t.colors.card,
        border: Border(top: BorderSide(color: t.colors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ToolbarItem(
            icon: FLucideIcons.arrowLeft,
            label: '返回',
            enabled: canGoBack,
            onTap: onBack,
          ),
          _ToolbarItem(
            icon: FLucideIcons.arrowRight,
            label: '前进',
            enabled: canGoForward,
            onTap: onForward,
          ),
          _ToolbarItem(
            icon: FLucideIcons.house,
            label: '首页',
            enabled: onHome != null,
            onTap: onHome,
          ),
          _ToolbarItem(
            icon: FLucideIcons.squareStack,
            label: '标签',
            badge: tabCount > 1 ? '$tabCount' : null,
            onTap: onTabs,
          ),
          _ToolbarItem(
            icon: FLucideIcons.menu,
            label: '菜单',
            onTap: onMenu,
          ),
        ],
      ),
    );
  }
}

/// 工具栏单项：22px 图标 + 11px 标签（禁用态整体降到 muted 前景）
class _ToolbarItem extends StatelessWidget {
  const _ToolbarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final active = enabled && onTap != null;
    final color =
        active ? t.colors.foreground : t.colors.mutedForeground.withValues(alpha: 0.45);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? onTap : null,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: t.colors.primary,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        badge!,
                        style: t.typography.body.xs.copyWith(
                          fontSize: 9,
                          height: 1.1,
                          color: t.colors.primaryForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
