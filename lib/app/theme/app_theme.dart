// 应用主题 —— 桌面端 25 套主题 token 向 Flutter ThemeData 的映射入口
//
// 约定（对应桌面端 references/theme.md）：
// 1. 严禁在组件里硬编码颜色；所有视觉走 token（此处收敛为 ThemeData / ColorScheme）。
// 2. 桌面端 token 体系（--el-* 替代品、color-mix 派生色）分批映射到 ColorScheme + 扩展 token；
//    当前先提供 1 套默认种子色亮/暗主题保证可运行，25 套全量映射列为 P2 任务。
import 'package:flutter/material.dart';

/// 应用主题构建器
class AppTheme {
  AppTheme._();

  /// 亮色主题（种子色占位，后续替换为桌面端默认主题 token）
  static ThemeData light() => _build(Brightness.light);

  /// 暗色主题
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
