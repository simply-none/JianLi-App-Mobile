// 主题偏好持久化（Riverpod 3 AsyncNotifier）
//
// 三个独立维度：
//   1. 主题「样式」——多套流行配色（AppTheme.styles），存 id。
//   2. 主题「模式」——跟随系统 / 浅色 / 深色，存枚举名。
//   3. 「阅览模式」——基准字号档位（普通 12px / 大号 18px），存枚举名；
//      由 app.dart 读出后传给 AppTheme.build，驱动全 App 字号等比缩放。
// 横幅纹理两个维度：
//   4. 「功能页横幅纹理」——除首页外所有功能页统计横幅背景统一使用的纹理（默认 texture11）。
//   5. 「首页英雄卡纹理」——首页英雄卡背景纹理（默认 heroAsset），与功能页纹理相互独立。
// 均用 shared_preferences 持久化，AppTheme + app.dart 启动时读取。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/card_textures.dart';

/// 主题模式：跟随系统 / 浅色 / 深色
enum AppThemeMode { system, light, dark }

/// 当前主题样式 id（持久化，缺省 'zi' 渐离紫）
final themeStyleProvider = AsyncNotifierProvider<ThemeStyleNotifier, String>(
  ThemeStyleNotifier.new,
);

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
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(
      ThemeModeNotifier.new,
    );

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

/// 阅览模式（基准字号档位）：normal 普通字体 12px（默认）/ large 大号字体 18px
enum ReadingMode { normal, large }

/// 当前阅览模式（持久化，缺省 normal）
final readingModeProvider =
    AsyncNotifierProvider<ReadingModeNotifier, ReadingMode>(
      ReadingModeNotifier.new,
    );

class ReadingModeNotifier extends AsyncNotifier<ReadingMode> {
  static const _key = 'jianli.readingMode';

  @override
  Future<ReadingMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return ReadingMode.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ReadingMode.normal,
    );
  }

  Future<void> set(ReadingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

/// 当前功能页横幅背景纹理（除首页外所有功能页统一使用；持久化，缺省 texture11）
final bannerTextureProvider =
    AsyncNotifierProvider<BannerTextureNotifier, String>(
      BannerTextureNotifier.new,
    );

class BannerTextureNotifier extends AsyncNotifier<String> {
  static const _key = 'jianli.bannerTexture';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? CardTextures.texture11;
  }

  Future<void> set(String asset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, asset);
    state = AsyncData(asset);
  }
}

/// 当前首页英雄卡背景纹理（与功能页横幅纹理相互独立；持久化，缺省 heroAsset）
final homeHeroTextureProvider =
    AsyncNotifierProvider<HomeHeroTextureNotifier, String>(
      HomeHeroTextureNotifier.new,
    );

class HomeHeroTextureNotifier extends AsyncNotifier<String> {
  static const _key = 'jianli.homeHeroTexture';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? CardTextures.heroAsset;
  }

  Future<void> set(String asset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, asset);
    state = AsyncData(asset);
  }
}
