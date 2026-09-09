// 页面转场（UI 现代化 Phase 0）
//
// 刻意【不引】`animations` 包（其 Material 耦合重，易与 material_ui 的平行
// Material 类冲突、断 Theme 继承链）。改用 go_router 的 CustomTransitionPage 自建。
//
// ⚠️ 【2026-09-09 去动画】用户要求「彻底去除所有页面的转场动画」→ [slidePage]
// 改为零时长、transitionsBuilder 直接返回 child，页面切换瞬间完成、无任何位移/淡入。
// 页面内微动效（StaggerList / AnimatedCheck / AnimatedStat 等）不受影响，按既有约定保留。
//
// 用法：在 app_router.dart 的全屏 push 路由用 `pageBuilder` 包 [slidePage]。
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 全屏 push / 详情页转场：**零动画**（页面瞬间切换）。
///
/// 仅保留 CustomTransitionPage 的壳以兼容 app_router.dart 的 20 处 pageBuilder
/// 调用；transitionDuration 设为 0、transitionsBuilder 直接返回 child。
CustomTransitionPage<dynamic> slidePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<dynamic>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}
