// 页面转场（UI 现代化 Phase 0）
//
// 刻意【不引】`animations` 包（其 Material 耦合重，易与 material_ui 的平行
// Material 类冲突、断 Theme 继承链）。改用 go_router 的 CustomTransitionPage 自建：
// 纯 flutter/widgets 的 SlideTransition，无 Material 依赖。
//
// ⚠️ 【重影雷区，2026-09-08 修复】原 `fadeSlidePage` 用 FadeTransition 给新页做
// 淡入，但旧页（secondaryAnimation）不做任何处理 → 转场期间旧页 100% 不透明留在
// 原位、新页半透明叠在上面，两页文字/卡片互相透出 = 肉眼可见的「重影」。
// 结论：**push 转场统一只用位移，禁止再给全屏页加淡入淡出**。
//
// 用法：在 app_router.dart 的全屏 push 路由用 `pageBuilder` 包 [slidePage]。
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// 全屏 push / 详情页转场：纯横向滑入（6% 位移），**不带淡入**。
///
/// 无透明度动画 → 转场期间不会出现新旧两页半透明叠加的重影；
/// 同时也规避了 PlatformView（WebView、相机等）在淡入过程中空白/黑屏的问题。
/// 时长/曲线走 AppTokens，与全局动效节律一致。
CustomTransitionPage<dynamic> slidePage(Widget child, GoRouterState state) {
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
      return SlideTransition(position: slide, child: child);
    },
  );
}
