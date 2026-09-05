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
    final style =
        AppTheme.styleById(ref.watch(themeStyleProvider).value ?? 'zi');
    final mode =
        ref.watch(themeModeProvider).value ?? AppThemeMode.system;

    return MaterialApp.router(
      title: '渐离',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      theme: AppTheme.materialLight(style),
      darkTheme: AppTheme.materialDark(style),
      themeMode: toMaterialMode(mode),
      routerConfig: appRouter,
      builder: (context, child) {
        // 主题切换时背景色平滑过渡（AppTokens.base 时长）；减弱动效时退回零时长直出。
        final data = AppTheme.build(
          style: style,
          brightness: Theme.brightnessOf(context),
        );
        return FTheme(
          data: data,
          child: AnimatedContainer(
            duration: AppTokens.base,
            color: data.colors.background,
            child: FToaster(child: FTooltipGroup(child: child!)),
          ),
        );
      },
    );
  }
}
