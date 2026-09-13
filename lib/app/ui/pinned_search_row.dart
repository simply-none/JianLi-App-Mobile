// 吸顶搜索行（列表页通用原子）—— 从待办页 todo_page.dart 原样抽出，供各列表页复用
//
// 规格（画布 07 / 5:420）：
//   行 padding  左右 16 / 上 12 / 下 8（三个常量与吸顶高度 [kSearchRowExtent] 同源推导）
//   输入框      高 40 · 卡色底 · 1px 描边 · r10 · 左右内边距 12 · search 15 图标
//   筛选按钮    28×28 · muted 底 · r8 · listFilter 15（[onFilter] 为 null 时整钮不渲染）
//
// ⚠️ 吸顶规则（interaction-patterns.md §4 / SKILL.md 红线 #13，全 App 统一）：
//   列表页滚动吸顶**以搜索行为锚点** —— 搜索框常驻视口顶部（滚动中随时可改关键词），
//   横幅 / 条件 chip / Tab 栏都随滚动移出。❌ 禁止把锚点放在 Tab 栏
//   （待办旧实现即「Tab 栏吸顶」，2026-09-12 用户明确纠正）。
//   配套吸顶 delegate 见 [PinnedSearchHeader]。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'tap_scale.dart';

/// 搜索框高（画布 5:420）
const double kSearchBoxHeight = 40;

/// 搜索行上留白
const double kSearchRowTopGap = 12;

/// 搜索行下留白（让内容从框下方 8px 处开始被遮住，而不是贴着框底消失）
const double kSearchRowBottomGap = 8;

/// 搜索行总高 = 上留白 + 搜索框 + 下留白。
///
/// ⚠️ **搜索行是列表页的吸顶元素**（`SliverPersistentHeader` 必须显式给高度），
/// 由上面三个常量推导，避免「搜索行自身」与「吸顶高度」两处各写一套数导致吸顶瞬间跳动。
const double kSearchRowExtent =
    kSearchRowTopGap + kSearchBoxHeight + kSearchRowBottomGap;

/// 页内搜索行（吸顶锚点本体）。
///
/// [controller] 归**持有它的 State**（caller 负责创建与 dispose，见 architecture.md #14）；
/// [onChanged] 实时回调关键词做页内过滤；[onFilter] 传 null 即隐藏右侧筛选按钮。
class PinnedSearchRow extends StatelessWidget {
  const PinnedSearchRow({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onFilter,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        kSearchRowTopGap,
        AppTokens.pagePadding,
        kSearchRowBottomGap,
      ),
      child: Container(
        height: kSearchBoxHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.colors.border),
        ),
        child: Row(
          spacing: 8,
          children: [
            Icon(
              FLucideIcons.search,
              size: 15,
              color: t.colors.mutedForeground,
            ),
            Expanded(
              // ⚠️ 原生 Material TextField 需要 Material 祖先；forui 的 FScaffold 不提供，
              // 这里显式补一层透明 Material（同待办页先例）。
              child: Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.foreground,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    // 边框由外层 Container 提供，内部必须 none 否则双重描边（§4.5）
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            if (onFilter != null)
              TapScale(
                onTap: onFilter,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.colors.muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FLucideIcons.listFilter,
                    size: 15,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 吸顶头（通用）：列表页把**搜索行**作为滚动吸顶锚点，滚过横幅后搜索框常驻顶部。
///
/// - [extent] 必须与实际子节点高度（搜索行上留白 + 框高 + 下留白）完全一致
///   —— 直接传 [kSearchRowExtent]，否则吸顶瞬间会跳一下；
/// - 覆盖色走 [AppTokens.pinnedCover]（背板同源渐变），**只在有内容滚过时才画**。
class PinnedSearchHeader extends SliverPersistentHeaderDelegate {
  PinnedSearchHeader({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  /// ⚠️ 背景**只在「吸顶后（下方内容从缝里滚过）」才画**——用 [shrinkOffset] > 0 判断。
  ///
  /// pinned 头的 `build(overlapsContent:)` 那个 `overlapsContent` 是「前方是否有 floating sliver
  /// 压着自己」（本布局前方是 banner，永远为 false），**不是**「下方内容是否滚到了头下面」。
  /// 所以不能直接用 `overlapsContent`，否则它永远 false → 吸顶后透明 → 列表文字从缝里透出来
  /// （2026-09-12 用户实指：滚动时灰色列表文字出现在间隙里）。
  ///
  /// 正确信号是 [shrinkOffset]：它 = 已滚过的量，> 0 即已滚动、头已吸顶、下方内容正从缝下经过。
  /// - shrinkOffset == 0（静止在顶部，banner 还在上方）→ **完全透明**，透出页面渐变背板，无额外色块；
  /// - shrinkOffset > 0（已滚动）→ 铺背板同源渐变（`AppTokens.pinnedCover`）：盖住内容且与背板无缝。
  ///
  /// ❌ 早期实现无条件刷 `colors.background` 纯色，静止时也是一块灰白挡板
  /// （上半屏紫渐变、往下突然灰白 = 背景被内容区切断，2026-09-12 用户实指）。
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      DecoratedBox(
        decoration: shrinkOffset > 0
            ? AppTokens.pinnedCover(context, extent)
            : const BoxDecoration(),
        child: child,
      );

  @override
  bool shouldRebuild(covariant PinnedSearchHeader oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}
