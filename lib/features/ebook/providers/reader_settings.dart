// 阅读设置（字号 / 行距 / 主题）持久化 —— 对齐 PC 端 themePresets.ts（day/night/eye）
//
// 主题配色权威值（来自 PC src/views/ebookReader/themePresets.ts）：
//   day  : 背景 #ffffff 文字 #333333
//   night: 背景 #1a1a1a 文字 #cccccc
//   eye  : 背景 #c7edcc 文字 #2c3e50
// 持久化走 shared_preferences（无需新建表，与全局阅读设置同层）。
// ⚠️ Riverpod 3：用新版 Notifier / NotifierProvider（核心包已移除 StateNotifierProvider）。
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读主题（三档，对齐 PC 端预设）
enum ReaderTheme { day, night, eye }

/// 阅读设置
class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.theme = ReaderTheme.day,
  });

  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderTheme? theme,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        theme: theme ?? this.theme,
      );

  static const _kFont = 'ebook_reader_font_size';
  static const _kLine = 'ebook_reader_line_height';
  static const _kTheme = 'ebook_reader_theme';

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble(_kFont, fontSize);
    await prefs.setDouble(_kLine, lineHeight);
    await prefs.setString(_kTheme, theme.name);
  }

  static ReaderSettings fromPrefs(SharedPreferences prefs) {
    final themeName = prefs.getString(_kTheme) ?? ReaderTheme.day.name;
    return ReaderSettings(
      fontSize: prefs.getDouble(_kFont) ?? 18,
      lineHeight: prefs.getDouble(_kLine) ?? 1.8,
      theme: ReaderTheme.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ReaderTheme.day,
      ),
    );
  }
}

/// 阅读设置 provider（Riverpod 3 Notifier；构造时异步从 shared_preferences 恢复，写入即时持久化）
final NotifierProvider<ReaderSettingsNotifier, ReaderSettings>
    readerSettingsProvider = NotifierProvider<ReaderSettingsNotifier,
        ReaderSettings>(ReaderSettingsNotifier.new);

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() {
    // 先给默认值，异步从 shared_preferences 恢复后再写回 state
    _init();
    return const ReaderSettings();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    // provider 可能在预取完成前被销毁，用 ref.mounted 防「dispose 后写 state」
    if (ref.mounted) state = ReaderSettings.fromPrefs(prefs);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await state.save(prefs);
  }

  void setFontSize(double v) {
    // 字号范围 12~36，步进 1
    state = state.copyWith(fontSize: v < 12 ? 12 : v > 36 ? 36 : v);
    _persist();
  }

  void setLineHeight(double v) {
    // 行距范围 1.2~3.0，步进 0.1
    state = state.copyWith(lineHeight: v < 1.2 ? 1.2 : v > 3.0 ? 3.0 : v);
    _persist();
  }

  void setTheme(ReaderTheme v) {
    state = state.copyWith(theme: v);
    _persist();
  }
}

/// 阅读背景色（对齐 PC themePresets）
Color readerBg(ReaderTheme t) {
  switch (t) {
    case ReaderTheme.day:
      return const Color(0xFFFFFFFF);
    case ReaderTheme.night:
      return const Color(0xFF1A1A1A);
    case ReaderTheme.eye:
      return const Color(0xFFC7EDCC);
  }
}

/// 阅读正文色（对齐 PC themePresets）
Color readerText(ReaderTheme t) {
  switch (t) {
    case ReaderTheme.day:
      return const Color(0xFF333333);
    case ReaderTheme.night:
      return const Color(0xFFCCCCCC);
    case ReaderTheme.eye:
      return const Color(0xFF2C3E50);
  }
}
