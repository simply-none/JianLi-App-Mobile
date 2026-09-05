// 应用根组件 —— MaterialApp.router 装配主题与路由
import 'package:flutter/material.dart';

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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
