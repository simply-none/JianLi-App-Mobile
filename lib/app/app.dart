// 应用根组件 —— MaterialApp.router + forui 主题装配
//
// 结构：material_ui 的 MaterialApp.router（forui 建立在 material_ui 之上，
//       勿改回 flutter/material——两套平行 Material 类，混用会断 Theme 继承链）
//       └─ builder 注入 FTheme（跟随 themeMode + 选中样式）+ FToaster（全局 toast）+ FTooltipGroup
// 本地化：FLocalizations.localizationsDelegates 已内置 Global Material/Cupertino/Widgets
//       三件套，且支持 zh（115 种语言），无需再单独引 flutter_localizations。
// 主题：样式与主色取自 themeStyleProvider，模式取自 themeModeProvider（均持久化）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers/theme_providers.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';

/// 渐离移动端根组件
class JianliApp extends ConsumerWidget {
  const JianliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = AppTheme.styleById(
      ref.watch(themeStyleProvider).value ?? 'zi',
    );
    final mode = ref.watch(themeModeProvider).value ?? AppThemeMode.system;
    // 阅览模式（基准字号体系）：普通 12px / 大号 18px，其他字型按比例缩放。
    // 在根组件读取并传进主题构建 → 切换时 MaterialApp.theme + FTheme 全树重渲，必然生效。
    final reading = ref.watch(readingModeProvider).value ?? ReadingMode.normal;
    final baseFontSize = reading == ReadingMode.large
        ? AppTokens.baseFontSizeLarge
        : AppTokens.baseFontSizeNormal;

    return MaterialApp.router(
      title: '渐离',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      theme: AppTheme.materialLight(style, baseFontSize),
      darkTheme: AppTheme.materialDark(style, baseFontSize),
      themeMode: toMaterialMode(mode),
      routerConfig: appRouter,
      builder: (context, child) {
        final isDark = Theme.brightnessOf(context) == Brightness.dark;
        final data = AppTheme.build(
          style: style,
          brightness: Theme.brightnessOf(context),
          baseFontSize: baseFontSize,
        );
        // 全局渐变背板 + 简单图案（大圆/圆环）：所有页面透明（pageTint/FScaffold
        // 均不画底色），背板统一透出——头部/外框/内容无色差、无白边；
        // 主题切换经 AnimatedContainer 平滑过渡（Decoration 渐变可 lerp）。
        final strongTint = Color.lerp(
          data.colors.background,
          data.colors.primary,
          isDark ? 0.10 : 0.07,
        )!;
        return FTheme(
          data: data,
          child: AnimatedContainer(
            duration: AppTokens.base,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [strongTint, data.colors.background],
              ),
            ),
            child: CustomPaint(
              painter: _BackdropPainter(
                primary: data.colors.primary,
                isDark: isDark,
              ),
              child: FToaster(child: FTooltipGroup(child: child!)),
            ),
          ),
        );
      },
    );
  }
}

/// 全局背板的简单图案：右上探出大圆 + 左侧中圆 + 右下圆环（极低透明度，
/// 只做氛围不做视觉焦点）。painter 在 child 之下，随主题色/亮暗重绘。
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.primary, required this.isDark});

  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = isDark ? 0.06 : 0.05;
    // 右上探出大圆
    canvas.drawCircle(
      Offset(size.width - 36, -48),
      150,
      Paint()..color = primary.withValues(alpha: alpha),
    );
    // 左侧中圆
    canvas.drawCircle(
      Offset(-40, size.height * 0.42),
      90,
      Paint()..color = primary.withValues(alpha: alpha * 0.7),
    );
    // 右下圆环
    canvas.drawCircle(
      Offset(size.width - 70, size.height - 140),
      64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = primary.withValues(alpha: alpha * 0.5),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.isDark != isDark;
}
