// 主壳：自绘「悬浮胶囊」底部导航 —— 1:1 对齐画布「01 首页·浅色 / navPill」
//
// 画布规格（390 视口，见 ardot 文件 724742991017068 节点 5:61/5:62）：
//   navPill 358×62 · 圆角 31 · 表面底色 · 左右内边距 8 · 距底 16；
//   选中 tab = 顶部 32×3 渐变指示条 + 64×44（圆角 22）渐变超椭圆底盘（白图标 22 / 白标签 11 SemiBold）；
//   未选中 tab = 图标 22 + 标签 11（弱化前景色）。
// forui 约定：导航放 FScaffold.footer（不是 Material Scaffold 的 bottomNavigationBar）；
// 内容区高度由 footer 自动预留，页面无需额外底部留白。footer 默认顶边线已在 app_theme 置空。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// 底部导航 destinations 顺序与路由 branches 一一对应
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (FLucideIcons.house, '首页'),
    (FLucideIcons.zap, '效率'),
    (FLucideIcons.bookOpen, '内容'),
    (FLucideIcons.wrench, '工具'),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      // childPad 关闭：各 Tab 页面用自身 FScaffold 的 childPad 管理内边距
      childPad: false,
      footer: _JianliBottomNav(
        index: navigationShell.currentIndex,
        onChange: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
      child: navigationShell,
    );
  }
}

/// 悬浮胶囊底部导航（1:1 画布 navPill）
class _JianliBottomNav extends StatelessWidget {
  const _JianliBottomNav({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SafeArea(
      top: false,
      child: Padding(
        // 画布：navWrapper 下留白 16，视口左右各 16（navPill 358 = 390-32）
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: t.colors.card,
            borderRadius: BorderRadius.circular(31),
          ),
          child: Row(
            children: [
              for (var i = 0; i < MainShell._destinations.length; i++)
                Expanded(child: _tab(context, i, t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, FThemeData t) {
    final (icon, label) = MainShell._destinations[i];
    final selected = i == index;
    final fg = t.colors.primaryForeground;
    final labelStyle = t.typography.body.xs.copyWith(
      fontSize: 11,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: selected ? fg : t.colors.mutedForeground,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChange(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected) ...[
            // 渐变超椭圆底盘（64×44 · r22），在 62px tab 高度内垂直居中
            Container(
              width: 64,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTokens.primaryGradient(context),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: fg),
                  const SizedBox(height: 2),
                  Text(label, style: labelStyle),
                ],
              ),
            ),
          ] else ...[
            Icon(icon, size: 22, color: t.colors.foreground),
            const SizedBox(height: 3),
            Text(label, style: labelStyle),
          ],
        ],
      ),
    );
  }
}
