// 应用根组件 —— MaterialApp.router + forui 主题装配
//
// 结构：material_ui 的 MaterialApp.router（forui 建立在 material_ui 之上，
//       勿改回 flutter/material——两套平行 Material 类，混用会断 Theme 继承链）
//       └─ builder 注入 FTheme（跟随系统亮暗）+ FToaster（全局 toast）+ FTooltipGroup
// 本地化：FLocalizations.localizationsDelegates 已内置 Global Material/Cupertino/Widgets
//       三件套，且支持 zh（115 种语言），无需再单独引 flutter_localizations。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// 渐离移动端根组件
class JianliApp extends StatelessWidget {
  const JianliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '渐离',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      theme: AppTheme.materialLight(),
      darkTheme: AppTheme.materialDark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        // 主题切换时背景色平滑过渡（AppTokens.base 时长）；减弱动效时退回零时长直出。
        final data = Theme.brightnessOf(context) == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark();
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
