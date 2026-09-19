// 阅读设置（主题配色 / 自定义色 / 排版 / 翻页）持久化
//
// 配色规则：
//   - 预设主题 8 档，前 3 档（day/night/eye）取值与 PC 端
//     `src/views/ebookReader/themePresets.ts` 的 READING_PRESET_BG/TEXT 逐字一致；
//   - 自定义背景色 / 文字色语义对齐 PC 的 `bgType='color'` + `textColor`：
//     **只作用于阅读区正文**（不影响工具栏与抽屉），空串 = 跟随主题预设。
//
// 持久化走 shared_preferences（无需建表）。
// ⚠️ Riverpod 3：用新版 Notifier / NotifierProvider（核心包已移除 StateNotifierProvider）。
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// 枚举
// =============================================================================

/// 阅读主题预设（8 档；前三档对齐 PC 端预设）
enum ReaderTheme { day, night, eye, sepia, kraft, gray, ink, navy }

/// 正文字体
enum ReaderFont { system, serif, sans, mono }

/// 首行缩进
enum ReaderIndent { none, two }

/// 正文对齐
enum ReaderAlign { left, justify }

/// 翻页方式（epub.js flow）
enum ReaderFlow { paginated, scrolled }

/// 阅读方向
enum ReaderDirection { ltr, rtl }

// =============================================================================
// 连续数值取值范围（滑块 / provider 共用，避免两处硬编码漂移）
// =============================================================================

/// 字号（px）
const double kReaderFontSizeMin = 12;
const double kReaderFontSizeMax = 36;

/// 行距（倍数）
const double kReaderLineHeightMin = 1.2;
const double kReaderLineHeightMax = 3.0;

/// 页边距（左右内边距 px；上下取其 ~0.55 倍）
const double kReaderMarginMin = 8;
const double kReaderMarginMax = 40;

/// 段间距（em，相对字号；0 = 无间距）
const double kReaderSpacingMin = 0;
const double kReaderSpacingMax = 2.0;

/// 把 [v] 限制到 [min, max]
double _clamp(double v, double min, double max) => v < min ? min : v > max ? max : v;

// =============================================================================
// 预设配色表
// =============================================================================

const Map<ReaderTheme, int> _kPresetBg = {
  ReaderTheme.day: 0xFFFFFFFF,
  ReaderTheme.night: 0xFF1A1A1A,
  ReaderTheme.eye: 0xFFC7EDCC,
  ReaderTheme.sepia: 0xFFF5EFE0,
  ReaderTheme.kraft: 0xFFE8DCC8,
  ReaderTheme.gray: 0xFFE9E9E9,
  ReaderTheme.ink: 0xFF000000,
  ReaderTheme.navy: 0xFF1B2430,
};

const Map<ReaderTheme, int> _kPresetFg = {
  ReaderTheme.day: 0xFF333333,
  ReaderTheme.night: 0xFFCCCCCC,
  ReaderTheme.eye: 0xFF2C3E50,
  ReaderTheme.sepia: 0xFF4A3F35,
  ReaderTheme.kraft: 0xFF4A3B2A,
  ReaderTheme.gray: 0xFF3F3F3F,
  ReaderTheme.ink: 0xFFD8D8D8,
  ReaderTheme.navy: 0xFFC9D3E0,
};

/// 主题中文名（设置抽屉色卡、菜单用）
const Map<ReaderTheme, String> kReaderThemeLabels = {
  ReaderTheme.day: '日间',
  ReaderTheme.night: '夜间',
  ReaderTheme.eye: '护眼',
  ReaderTheme.sepia: '羊皮纸',
  ReaderTheme.kraft: '牛皮纸',
  ReaderTheme.gray: '淡灰',
  ReaderTheme.ink: '墨黑',
  ReaderTheme.navy: '深蓝夜',
};

/// 自定义色板（背景）
const List<String> kReaderBgPool = [
  '#FFFFFF', '#F5EFE0', '#E8DCC8', '#C7EDCC', '#DCE6F0', '#E7F0E3',
  '#EFE3F0', '#F1EFEA', '#E9E9E9', '#1A1A1A', '#1B2430', '#000000',
];

/// 自定义色板（文字）
const List<String> kReaderTextPool = [
  '#333333', '#000000', '#4A3F35', '#2C3E50',
  '#4B4B4B', '#7A7A7A', '#CCCCCC', '#FFFFFF',
];

/// 预设主题背景色（PC 端同名函数同义）
Color readerBg(ReaderTheme t) => Color(_kPresetBg[t]!);

/// 预设主题正文色（PC 端同名函数同义）
Color readerText(ReaderTheme t) => Color(_kPresetFg[t]!);

/// 主题是否暗色（决定顶栏 / 状态栏图标与页面外框取色）
bool readerThemeIsDark(ReaderTheme t) => switch (t) {
      ReaderTheme.day ||
      ReaderTheme.eye ||
      ReaderTheme.sepia ||
      ReaderTheme.kraft ||
      ReaderTheme.gray =>
        false,
      ReaderTheme.night || ReaderTheme.ink || ReaderTheme.navy => true,
    };

/// 阅读区实际背景色（自定义色优先，否则回退预设）
Color resolveReaderBg(ReaderSettings s) =>
    s.bgColor.isEmpty ? readerBg(s.theme) : hexToColor(s.bgColor);

/// 阅读区实际正文色（自定义色优先，否则回退预设）
Color resolveReaderText(ReaderSettings s) =>
    s.textColor.isEmpty ? readerText(s.theme) : hexToColor(s.textColor);

/// `#RRGGBB` / `#AARRGGBB` → [Color]（非法值回退黑色）
Color hexToColor(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? const Color(0xFF000000) : Color(v);
}

/// [Color] → `#RRGGBB`（epub.js 主题注入用）
String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// CSS font-family
///
/// ⚠️ **必须恒返回非空串**：epub.js `addStylesheetRules` 是往同一个 `<style>` 里
///    **追加**规则（`insertRule`）而不是替换（详见 epub.js dist 5701 行），
///    所以「某个属性本次不注入」=「上一次的值永久残留」。想关掉某效果只能显式
///    注入它的中性值（如 `inherit` / `0`），不能省略键。
String readerFontFamily(ReaderFont f) => switch (f) {
      ReaderFont.system => 'system-ui, -apple-system, "PingFang SC", sans-serif',
      ReaderFont.serif => 'serif, "Noto Serif CJK SC", "Songti SC"',
      ReaderFont.sans => 'sans-serif, "Noto Sans CJK SC"',
      ReaderFont.mono => 'monospace, "Noto Sans Mono CJK SC"',
    };

/// CSS body padding（页边距）
///
/// [margin] = 左右内边距（px），上下取约 0.55 倍，保证窄→宽两端观感连续。
/// ⚠️ 同 [readerFontFamily]：返回类型恒为非空 `String`。
String readerBodyPadding(double margin) {
  final h = _clamp(margin, kReaderMarginMin, kReaderMarginMax).round();
  final v = (h * 0.55).round();
  return '${v}px ${h}px';
}

/// CSS 段间距（margin，em 相对字号；0 = 无间距）
///
/// ⚠️ 同 [readerFontFamily]：返回类型恒为非空 `String`（「关掉」= 注入 `'0'`）。
///    阅读器注入侧若拿到 `null` 只会拼出 `null !important` 这种废 CSS，
///    且 epub.js 的规则是追加不替换，废规则会永久残留。
String readerParagraphMargin(double spacing) {
  final s = _clamp(spacing, kReaderSpacingMin, kReaderSpacingMax);
  return s <= 0 ? '0' : '${s.toStringAsFixed(2)}em 0';
}

/// CSS 首行缩进（关闭 = `'0'`，不是 null）
String readerTextIndent(ReaderIndent i) => switch (i) {
      ReaderIndent.none => '0',
      ReaderIndent.two => '2em',
    };

/// CSS 对齐
String readerTextAlign(ReaderAlign a) => switch (a) {
      ReaderAlign.left => 'left',
      ReaderAlign.justify => 'justify',
    };

/// enum 中文标签
const Map<ReaderFont, String> kReaderFontLabels = {
  ReaderFont.system: '系统',
  ReaderFont.serif: '衬线',
  ReaderFont.sans: '无衬线',
  ReaderFont.mono: '等宽',
};
const Map<ReaderIndent, String> kReaderIndentLabels = {
  ReaderIndent.none: '无',
  ReaderIndent.two: '2 字符',
};
const Map<ReaderAlign, String> kReaderAlignLabels = {
  ReaderAlign.left: '左对齐',
  ReaderAlign.justify: '两端对齐',
};
const Map<ReaderFlow, String> kReaderFlowLabels = {
  ReaderFlow.paginated: '翻页',
  ReaderFlow.scrolled: '滚动',
};
const Map<ReaderDirection, String> kReaderDirectionLabels = {
  ReaderDirection.ltr: '从左到右',
  ReaderDirection.rtl: '从右到左',
};

// =============================================================================
// 设置模型
// =============================================================================

/// 阅读设置
class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.theme = ReaderTheme.day,
    this.bgColor = '',
    this.textColor = '',
    this.font = ReaderFont.system,
    this.margin = 18,
    this.spacing = 0.5,
    this.indent = ReaderIndent.none,
    this.align = ReaderAlign.justify,
    this.flow = ReaderFlow.paginated,
    this.direction = ReaderDirection.ltr,
  });

  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;

  /// 自定义阅读区背景色（'' = 跟随主题）
  final String bgColor;

  /// 自定义阅读区正文色（'' = 跟随主题）
  final String textColor;

  /// 页边距（左右内边距，px；上下取其 ~0.55 倍）
  final double margin;

  /// 段间距（em，相对字号；0 = 无间距）
  final double spacing;

  final ReaderFont font;
  final ReaderIndent indent;
  final ReaderAlign align;

  /// 翻页方式 / 方向：变更需重建阅读器（位置靠 CFI 续接）
  final ReaderFlow flow;
  final ReaderDirection direction;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderTheme? theme,
    String? bgColor,
    String? textColor,
    double? margin,
    double? spacing,
    ReaderFont? font,
    ReaderIndent? indent,
    ReaderAlign? align,
    ReaderFlow? flow,
    ReaderDirection? direction,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        theme: theme ?? this.theme,
        bgColor: bgColor ?? this.bgColor,
        textColor: textColor ?? this.textColor,
        font: font ?? this.font,
        margin: margin ?? this.margin,
        spacing: spacing ?? this.spacing,
        indent: indent ?? this.indent,
        align: align ?? this.align,
        flow: flow ?? this.flow,
        direction: direction ?? this.direction,
      );

  /// 影响「样式」的指纹：变更走热更新（updateTheme，不重载书）
  String get styleFingerprint => [
        theme.name,
        bgColor,
        textColor,
        fontSize.toStringAsFixed(1),
        lineHeight.toStringAsFixed(2),
        font.name,
        margin.toStringAsFixed(0),
        spacing.toStringAsFixed(2),
        indent.name,
        align.name,
      ].join('|');

  /// 影响「结构」的指纹：变更需重建 EpubViewer
  String get structureFingerprint => [flow.name, direction.name].join('|');

  static const _kFont = 'ebook_reader_font_size';
  static const _kLine = 'ebook_reader_line_height';
  static const _kTheme = 'ebook_reader_theme';
  static const _kBg = 'ebook_reader_bg_color';
  static const _kText = 'ebook_reader_text_color';
  static const _kFamily = 'ebook_reader_font_family';
  static const _kMargin = 'ebook_reader_margin_px';
  static const _kSpacing = 'ebook_reader_spacing_em';
  static const _kIndent = 'ebook_reader_indent';
  static const _kAlign = 'ebook_reader_align';
  static const _kFlow = 'ebook_reader_flow';
  static const _kDirection = 'ebook_reader_direction';

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble(_kFont, fontSize);
    await prefs.setDouble(_kLine, lineHeight);
    await prefs.setString(_kTheme, theme.name);
    await prefs.setString(_kBg, bgColor);
    await prefs.setString(_kText, textColor);
    await prefs.setString(_kFamily, font.name);
    await prefs.setDouble(_kMargin, margin);
    await prefs.setDouble(_kSpacing, spacing);
    await prefs.setString(_kIndent, indent.name);
    await prefs.setString(_kAlign, align.name);
    await prefs.setString(_kFlow, flow.name);
    await prefs.setString(_kDirection, direction.name);
  }

  static ReaderSettings fromPrefs(SharedPreferences prefs) {
    const d = ReaderSettings();
    return ReaderSettings(
      fontSize: prefs.getDouble(_kFont) ?? d.fontSize,
      lineHeight: prefs.getDouble(_kLine) ?? d.lineHeight,
      theme: _pick(ReaderTheme.values, prefs.getString(_kTheme), d.theme),
      bgColor: prefs.getString(_kBg) ?? d.bgColor,
      textColor: prefs.getString(_kText) ?? d.textColor,
      font: _pick(ReaderFont.values, prefs.getString(_kFamily), d.font),
      margin: prefs.getDouble(_kMargin) ?? d.margin,
      spacing: prefs.getDouble(_kSpacing) ?? d.spacing,
      indent: _pick(ReaderIndent.values, prefs.getString(_kIndent), d.indent),
      align: _pick(ReaderAlign.values, prefs.getString(_kAlign), d.align),
      flow: _pick(ReaderFlow.values, prefs.getString(_kFlow), d.flow),
      direction: _pick(
        ReaderDirection.values,
        prefs.getString(_kDirection),
        d.direction,
      ),
    );
  }

  static T _pick<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.firstWhere((e) => e.name == name, orElse: () => fallback);
}

// =============================================================================
// Provider
// =============================================================================

/// 阅读设置 provider（构造时异步从 shared_preferences 恢复，写入即时持久化）
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
    state = state.copyWith(fontSize: _clamp(v, kReaderFontSizeMin, kReaderFontSizeMax).roundToDouble());
    _persist();
  }

  void setLineHeight(double v) {
    // 行距范围 1.2~3.0，步进 0.1
    final stepped = (v * 10).round() / 10;
    state = state.copyWith(lineHeight: _clamp(stepped, kReaderLineHeightMin, kReaderLineHeightMax));
    _persist();
  }

  void setTheme(ReaderTheme v) {
    state = state.copyWith(theme: v);
    _persist();
  }

  /// 自定义阅读区背景色（'' = 跟随主题）
  void setBgColor(String hex) {
    state = state.copyWith(bgColor: hex);
    _persist();
  }

  /// 自定义阅读区正文色（'' = 跟随主题）
  void setTextColor(String hex) {
    state = state.copyWith(textColor: hex);
    _persist();
  }

  void setFont(ReaderFont v) {
    state = state.copyWith(font: v);
    _persist();
  }

  void setMargin(double v) {
    state = state.copyWith(margin: _clamp(v, kReaderMarginMin, kReaderMarginMax).roundToDouble());
    _persist();
  }

  void setSpacing(double v) {
    final stepped = (v * 10).round() / 10;
    state = state.copyWith(spacing: _clamp(stepped, kReaderSpacingMin, kReaderSpacingMax));
    _persist();
  }

  void setIndent(ReaderIndent v) {
    state = state.copyWith(indent: v);
    _persist();
  }

  void setAlign(ReaderAlign v) {
    state = state.copyWith(align: v);
    _persist();
  }

  void setFlow(ReaderFlow v) {
    state = state.copyWith(flow: v);
    _persist();
  }

  void setDirection(ReaderDirection v) {
    state = state.copyWith(direction: v);
    _persist();
  }

  /// 恢复默认（设置抽屉「恢复默认」）
  void reset() {
    state = const ReaderSettings();
    _persist();
  }
}
