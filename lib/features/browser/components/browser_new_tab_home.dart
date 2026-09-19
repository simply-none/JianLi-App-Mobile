// 浏览器极简首页（新标签页）—— 通用浏览器新标签页布局
//
// 结构（用户定案，对齐画布 6·极简首页）：
//   ① 图标标题：72×72 白底圆角块内嵌真实 App 图标 + 小字「渐离App」
//   ② 搜索栏：点它 = 让顶部地址栏进入输入态（不在这里做输入框，避免双输入）
//   ③ 固定标签：九宫格（默认 8 个，可在设置里开关 / 编辑）
//
// ⚠️ 首页自己没有输入框，只是一个「点击区」——搜索与输入统一由地址栏承担，
//    这样「同一个输入在不同入口行为不同」的问题不会出现。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import 'browser_speed_dial.dart';

/// App 图标资源（与开屏同源；`assets/images/` 已在 pubspec 声明）
const String kBrowserBrandLogo = 'assets/images/app_logo.png';

class BrowserNewTabHome extends StatelessWidget {
  const BrowserNewTabHome({
    super.key,
    required this.sites,
    required this.onOpenSite,
    required this.onTapSearch,
    this.onLongPressSite,
    this.showPinned = true,
  });

  final List<BrowserPinnedData> sites;
  final void Function(BrowserPinnedData site) onOpenSite;

  /// 点搜索栏 → 顶部地址栏进入输入态
  final VoidCallback onTapSearch;
  final void Function(BrowserPinnedData site)? onLongPressSite;

  /// 首页是否显示固定标签（设置项「首页显示固定标签页」）
  final bool showPinned;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 整块做透明命中层：WebView 仍在它下面活着（单 WebView 多标签），
      // 不 absorb 的话空白处的点击会穿透到网页上。
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: context.theme.colors.background,
        child: Column(
          children: [
            const SizedBox(height: 80),
            const _Brand(),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.pagePadding,
              ),
              child: _SearchEntry(onTap: onTapSearch),
            ),
            if (showPinned && sites.isNotEmpty) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.pagePadding,
                ),
                child: BrowserSpeedDial(
                  sites: sites,
                  onOpen: onOpenSite,
                  onLongPressSite: onLongPressSite,
                ),
              ),
            ],
            const Spacer(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 品牌块：App 图标 + 「渐离App」
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.colors.border),
          ),
          // App 图标本身是白底 PNG，故外面套白底圆角块才是标准 App 图标观感
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              kBrowserBrandLogo,
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => Icon(
                FLucideIcons.globe,
                size: 30,
                color: t.colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '渐离App',
          style: t.typography.body.md.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: t.colors.foreground,
          ),
        ),
      ],
    );
  }
}

/// 搜索入口（外观与地址栏同规格：h48 / r14 / 卡片底 + 发丝线 + 紫放大镜）
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd - 2),
          border: Border.all(color: t.colors.border),
        ),
        child: Row(
          children: [
            Icon(FLucideIcons.search, size: 22, color: t.colors.primary),
            const SizedBox(width: 12),
            Text(
              '搜索或输入网址',
              style: t.typography.body.md.copyWith(
                fontSize: 15,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
