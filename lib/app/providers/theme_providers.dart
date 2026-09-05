// 主题偏好持久化（Riverpod 3 AsyncNotifier）
//
// 两个独立维度：
//   1. 主题「样式」——多套流行配色（AppTheme.styles），存 id。
//   2. 主题「模式」——跟随系统 / 浅色 / 深色，存枚举名。
// 均用 shared_preferences 持久化，AppTheme + app.dart 启动时读取。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式：跟随系统 / 浅色 / 深色
enum AppThemeMode {
  system,
  light,
  dark,
}

/// 当前主题样式 id（持久化，缺省 'zi' 渐离紫）
final themeStyleProvider =
    AsyncNotifierProvider<ThemeStyleNotifier, String>(ThemeStyleNotifier.new);

class ThemeStyleNotifier extends AsyncNotifier<String> {
  static const _key = 'jianli.themeStyle';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'zi';
  }

  Future<void> set(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
    state = AsyncData(id);
  }
}

/// 当前主题模式（持久化，缺省 system）
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  static const _key = 'jianli.themeMode';

  @override
  Future<AppThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return AppThemeMode.values.firstWhere(
      (e) => e.name == v,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> set(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

/// 转 Material 的 ThemeMode
ThemeMode toMaterialMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}
