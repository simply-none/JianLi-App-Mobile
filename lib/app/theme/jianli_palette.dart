// 统一颜色变量文件 —— 全 App「外观色系」的单一事实来源（Single Source of Truth）。
//
// 每套外观（渐离紫 / 远峰蓝 / 森野绿 … 9 套）都拥有一整套同构的调色板：
// 页面底 / 表面层 / 抬升面 / 导航胶囊 / 标题字 / 次字 + 光晕与渐变透明度，
// 亮 / 暗各一。这样「切换外观 + 切换深浅」时整屏分层与氛围都跟着主色走，
// 不会出现「换了主色但底色还是紫」的割裂。
//
// 生成规则（与画布「渐离紫 Tokens」同构）：
//   · 亮色：底色近中性（微混主色 4%），表面纯白，抬升面浅灰微混，
//          导航胶囊为 ~17% 主色的浅色（画布 navPill 观感）；
//   · 暗色：以深墨基底按 10% / 24% / 34% / 44% 逐级混入主色，得到「同色系深色分层」，
//          标题字 ~10% 主色的近白、次字为 ~18% 主色的中性灰。
// 渐离紫（id='zi'）保留画布手工微调的精确值，作为整套体系的参照样张。
//
// 严禁在组件里硬编码下列颜色；一律取 JianliPalette.light(...) / dark(...) 的对应字段。
import 'package:flutter/material.dart';

/// 一套配色方案（亮 / 暗各一例）
class Scheme {
  const Scheme({
    required this.pageBg,
    required this.surface,
    required this.surfaceElevated,
    required this.navPill,
    required this.onSurfaceTitle,
    required this.onSurfaceSub,
    required this.glowAlpha,
    required this.glowLeftAlpha,
    required this.glowRingAlpha,
    required this.gradientTopAlpha,
    required this.gradientMidAlpha,
  });

  /// 页面底色（全局背板基底）
  final Color pageBg;

  /// 卡片 / 表面层
  final Color surface;

  /// 抬升面（次级底 / 边界）
  final Color surfaceElevated;

  /// 底部导航胶囊底色
  final Color navPill;

  /// 标题 / 主文字
  final Color onSurfaceTitle;

  /// 次要文字
  final Color onSurfaceSub;

  /// 右上光晕透明度
  final double glowAlpha;

  /// 左侧光晕透明度
  final double glowLeftAlpha;

  /// 右下圆环透明度
  final double glowRingAlpha;

  /// 背板渐变顶部浓度
  final double gradientTopAlpha;

  /// 背板渐变中段浓度
  final double gradientMidAlpha;
}

/// 全 App 外观色系统一调色板
class JianliPalette {
  const JianliPalette._();

  // —— 页面渐变背板浓度（全 App 所有外观一致，仅按深浅区分）——
  //
  // 出处：画布「02 导航重设计」的 `背景装饰` 层 —— 三段渐变（顶浓 → 中淡 → 底透明）：
  //   亮色 7% → 2% → 0%；暗色 8% → 5.5% → 0%。
  // ⚠️ 根背板（app.dart）与**列表页吸顶行的覆盖色**必须同源取这里的两组值，
  //    否则吸顶条会与背板出现色差断层（2026-09-12 实踩）。不要在任何地方内联这两个数。
  static const double gradientTopAlphaLight = 0.07;
  static const double gradientTopAlphaDark = 0.08;
  static const double gradientMidAlphaLight = 0.02;
  static const double gradientMidAlphaDark = 0.055;

  /// 背板渐变顶部浓度（按深浅取）
  static double gradientTopAlphaOf(Brightness brightness) =>
      brightness == Brightness.dark
      ? gradientTopAlphaDark
      : gradientTopAlphaLight;

  /// 背板渐变中段（50%）浓度（按深浅取）
  static double gradientMidAlphaOf(Brightness brightness) =>
      brightness == Brightness.dark
      ? gradientMidAlphaDark
      : gradientMidAlphaLight;

  /// 品牌主色（亮）—— 英雄卡 / 统计横幅同源
  static const Color brandPurple = Color(0xFF9D5CFF);

  /// 品牌主色（暗渐变止点）
  static const Color purpleDeep = Color(0xFF5B3FD6);

  // —— 派生用的中性锚点 ——
  static const Color _ink = Color(0xFF0A0A0C); // 暗面基底（近黑）
  static const Color _paper = Color(0xFFF7F9FA); // 亮面基底（近白）
  static const Color _paperElevated = Color(0xFFF1F2F5);
  static const Color _titleLight = Color(0xFF1A1A1F);
  static const Color _subLight = Color(0xFF6B707D);
  static const Color _subDarkAnchor = Color(0xFFB0B0B8);

  /// 渐离紫 · 亮（画布手工微调，1:1 参照）
  static const Scheme ziLight = Scheme(
    pageBg: Color(0xFFF7F9FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F2F5),
    navPill: Color(0xFFECE2FF),
    onSurfaceTitle: _titleLight,
    onSurfaceSub: _subLight,
    glowAlpha: 0.05,
    glowLeftAlpha: 0.035,
    glowRingAlpha: 0.025,
    gradientTopAlpha: gradientTopAlphaLight,
    gradientMidAlpha: gradientMidAlphaLight,
  );

  /// 渐离紫 · 暗（紫调暗面，非纯黑/纯灰，画布手工微调）
  static const Scheme ziDark = Scheme(
    pageBg: Color(0xFF120D1C),
    surface: Color(0xFF261C38),
    surfaceElevated: Color(0xFF33264A),
    navPill: Color(0xFF3D2E57),
    onSurfaceTitle: Color(0xFFEDE8F7),
    onSurfaceSub: Color(0xFFA394BD),
    glowAlpha: 0.08,
    glowLeftAlpha: 0.055,
    glowRingAlpha: 0.04,
    gradientTopAlpha: gradientTopAlphaDark,
    gradientMidAlpha: gradientMidAlphaDark,
  );

  /// 亮色方案：由主题「亮色主色」派生；[zi] 为真时返回画布精确值。
  static Scheme light(Color seed, {bool zi = false}) {
    if (zi) return ziLight;
    return Scheme(
      pageBg: Color.lerp(_paper, seed, 0.04)!,
      surface: const Color(0xFFFFFFFF),
      surfaceElevated: Color.lerp(_paperElevated, seed, 0.04)!,
      navPill: Color.lerp(const Color(0xFFFFFFFF), seed, 0.17)!,
      onSurfaceTitle: _titleLight,
      onSurfaceSub: _subLight,
      glowAlpha: 0.05,
      glowLeftAlpha: 0.035,
      glowRingAlpha: 0.025,
      gradientTopAlpha: gradientTopAlphaLight,
      gradientMidAlpha: gradientMidAlphaLight,
    );
  }

  /// 暗色方案：由主题「暗色主色」派生（深墨基底逐级混主色 → 同色系深色分层）；
  /// [zi] 为真时返回画布精确值。
  static Scheme dark(Color seed, {bool zi = false}) {
    if (zi) return ziDark;
    return Scheme(
      pageBg: Color.lerp(_ink, seed, 0.10)!,
      surface: Color.lerp(_ink, seed, 0.24)!,
      surfaceElevated: Color.lerp(_ink, seed, 0.34)!,
      navPill: Color.lerp(_ink, seed, 0.44)!,
      onSurfaceTitle: Color.lerp(const Color(0xFFFFFFFF), seed, 0.10)!,
      onSurfaceSub: Color.lerp(_subDarkAnchor, seed, 0.18)!,
      glowAlpha: 0.08,
      glowLeftAlpha: 0.055,
      glowRingAlpha: 0.04,
      gradientTopAlpha: gradientTopAlphaDark,
      gradientMidAlpha: gradientMidAlphaDark,
    );
  }
}
