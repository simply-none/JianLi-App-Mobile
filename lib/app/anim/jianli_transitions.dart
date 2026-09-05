// 页面转场（UI 现代化 Phase 0）
//
// 刻意【不引】`animations` 包（其 Material 耦合重，易与 material_ui 的平行
// Material 类冲突、断 Theme 继承链）。改用 go_router 的 CustomTransitionPage 自建：
// 纯 flutter/widgets 的 FadeTransition + SlideTransition，无 Material 依赖。
//
// 用法：在 app_router.dart 的全屏 push 路由用 `pageBuilder` 包 [fadeSlidePage]。
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// 推送 / 详情页转场：共享轴横向滑入（6% 位移）+ 淡入。
///
/// 返回 CustomTransitionPage，配合 go_router 的 pageBuilder 使用；
/// 时长/曲线走 AppTokens，与全局动效节律一致。
CustomTransitionPage<dynamic> fadeSlidePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<dynamic>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppTokens.base,
    reverseTransitionDuration: AppTokens.base,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppTokens.standard)).animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// Tab 分支切换转场：纯淡入（轻量，不重建子树）。
///
/// StatefulShellRoute 分支间切换用，避免导航壳抖动。
CustomTransitionPage<dynamic> fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<dynamic>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppTokens.fast,
    reverseTransitionDuration: AppTokens.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
