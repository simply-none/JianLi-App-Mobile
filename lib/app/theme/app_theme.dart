// 应用主题 —— forui（shadcn 风格）主题构建入口
//
// 约定（对应桌面端 references/theme.md 的移动端落地）：
// 1. 严禁在组件里硬编码颜色；所有视觉走 `context.theme.colors.*` token。
// 2. Material 导入统一用 material_ui（Flutter Material 库的独立发行版，forui 建于其上，
//    与 flutter/material 是两套平行类，勿混用——否则 Theme 继承链断裂、类型不兼容）。
// 3. MaterialApp 的 theme/darkTheme 用 toApproximateMaterialTheme() 生成，
//    让残留 Material 组件（日期选择、文本选择菜单等）与 forui 观感一致。
// 4. 多套主题样式（AppTheme.styles，5 套流行配色）在此集中定义；运行时由
//    themeStyleProvider 驱动切换，themeModeProvider 驱动 浅/暗/跟随系统。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 主题样式（5 套流行配色）——主色 + 暗色提亮主色
class ThemeStyle {
  const ThemeStyle({
    required this.id,
    required this.name,
    required this.lightPrimary,
    required this.darkPrimary,
  });

  final String id;
  final String name;
  final Color lightPrimary;
  final Color darkPrimary;
}

/// 应用主题构建器（forui）
class AppTheme {
  AppTheme._();

  /// 5 套流行主题样式（主色 / 暗色提亮主色）
  static const List<ThemeStyle> styles = [
    ThemeStyle(
      id: 'zi',
      name: '渐离紫',
      lightPrimary: Color(0xFF6C5CE7),
      darkPrimary: Color(0xFF8B7CF7),
    ),
    ThemeStyle(
      id: 'blue',
      name: '远峰蓝',
      lightPrimary: Color(0xFF3B82F6),
      darkPrimary: Color(0xFF60A5FA),
    ),
    ThemeStyle(
      id: 'green',
      name: '森野绿',
      lightPrimary: Color(0xFF10B981),
      darkPrimary: Color(0xFF34D399),
    ),
    ThemeStyle(
      id: 'orange',
      name: '落日橙',
      lightPrimary: Color(0xFFF59E0B),
      darkPrimary: Color(0xFFFBBF24),
    ),
    ThemeStyle(
      id: 'pink',
      name: '樱粉',
      lightPrimary: Color(0xFFEC4899),
      darkPrimary: Color(0xFFF472B6),
    ),
  ];

  /// 按 id 取样式（缺省回落首套「渐离紫」）
  static ThemeStyle styleById(String id) =>
      styles.firstWhere((s) => s.id == id, orElse: () => styles.first);

  /// 亮色主题（指定样式）
  static FThemeData light([ThemeStyle? style]) =>
      build(style: style ?? styles.first, brightness: Brightness.light);

  /// 暗色主题（指定样式）
  static FThemeData dark([ThemeStyle? style]) =>
      build(style: style ?? styles.first, brightness: Brightness.dark);

  /// MaterialApp 用：亮色 Material 主题（指定样式）
  static ThemeData materialLight([ThemeStyle? style]) =>
      light(style).toApproximateMaterialTheme();

  /// MaterialApp 用：暗色 Material 主题（指定样式）
  static ThemeData materialDark([ThemeStyle? style]) =>
      dark(style).toApproximateMaterialTheme();

  /// 构建一套 forui 主题：中性底色（shadcn 观感）+ 指定样式主色
  ///
  /// 官方模式（同 FTheme.neutral 源码）：FThemeData(touch, colors) 只传这两个，
  /// typography/style/icons 自动从 colors + touch 推导继承。
  static FThemeData build({
    required ThemeStyle style,
    required Brightness brightness,
  }) {
    final isLight = brightness == Brightness.light;
    // touch 变体 = 移动端触控尺寸（desktop 变体控件更紧凑，移动端勿用错）
    final base = isLight ? FTheme.neutral.light.touch : FTheme.neutral.dark.touch;
    return FThemeData(
      touch: true,
      debugLabel: 'Jianli ${style.id} ${isLight ? 'L' : 'D'}',
      colors: base.colors.copyWith(
        primary: isLight ? style.lightPrimary : style.darkPrimary,
        primaryForeground: Colors.white,
      ),
    );
  }
}

/// 设计 token（UI 现代化 + 动效体系地基，Phase 0）
///
/// 收口所有「形状 / 阴影 / 渐变 / 语义软底 / 动效节律」，组件一律取这里，
/// 严禁在页面里写死颜色、阴影、圆角、时长。所有方法吃 BuildContext，
/// 颜色优先 forui `context.theme.colors`，暗色按 brightness 派生分层。
class AppTokens {
  AppTokens._();

  // —— 形状（圆角档位，替代散落的 12/16/24 魔法数） ——
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  // —— 动效节律（统一时长与曲线，组件复用保持一致手感） ——
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasize = Curves.easeOutBack;

  /// 柔和阴影（轻量、低透明度，避免 iOS 重阴影观感）
  ///
  /// level: 0=无 1=卡片悬浮 2=弹层 3=置顶/FAB。
  static List<BoxShadow> elevation(BuildContext context, {int level = 1}) {
    final t = context.theme;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final alpha = isDark ? 0.45 : 0.08;
    const offsets = [Offset.zero, Offset(0, 2), Offset(0, 6), Offset(0, 12)];
    const blurs = [0.0, 4.0, 12.0, 24.0];
    final i = level.clamp(0, 3);
    if (i == 0) return const [];
    return [
      BoxShadow(
        color: (isDark ? Colors.black : t.colors.foreground)
            .withValues(alpha: alpha * (i + 1) / 4),
        offset: offsets[i],
        blurRadius: blurs[i],
      ),
    ];
  }

  /// 主色渐变（品牌氛围：横幅 / 关键 CTA）
  static LinearGradient primaryGradient(BuildContext context) {
    final c = context.theme.colors.primary;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c, Color.lerp(c, Colors.black, 0.22)!],
    );
  }

  /// 语义软底（success / warn / info 等状态底，叠在主色上是低密度提示）
  static Color soft(BuildContext context, Color base) =>
      base.withValues(alpha: Theme.brightnessOf(context) == Brightness.dark ? 0.22 : 0.12);

  // —— 专属强调色板（2026 视觉个性来源：每个功能域一个专属色，磁贴/图标底盘用） ——
  static const List<Color> accents = [
    Color(0xFF6C5CE7), // 0 紫（主色系）
    Color(0xFF3B82F6), // 1 蓝
    Color(0xFF10B981), // 2 绿
    Color(0xFFF59E0B), // 3 琥珀
    Color(0xFFEC4899), // 4 粉
    Color(0xFF06B6D4), // 5 青
    Color(0xFFEF4444), // 6 红
  ];

  /// 取强调色（自动取模，越界安全）
  static Color accent(int index) => accents[index % accents.length];

  /// 强调色软底（入口磁贴底色，亮/暗自适应）
  static Color accentSoft(BuildContext context, Color base) => base.withValues(
      alpha: Theme.brightnessOf(context) == Brightness.dark ? 0.16 : 0.10);

  /// 强调色渐变（图标底盘 / 小面积强调）
  static LinearGradient accentGradient(Color base) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, Color.lerp(base, Colors.black, 0.25)!],
      );

  /// 页面底色：在 background 上叠一点主色冷调，去「纯白苍白」感
  static Color pageTint(BuildContext context) {
    final t = context.theme;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    return Color.lerp(t.colors.background, t.colors.primary, isDark ? 0.06 : 0.04)!;
  }
}
