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

/// 主题样式（9 套配色）——主色 + 暗色提亮主色
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

  /// 9 套主题样式（主色 / 暗色提亮主色）
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
    // —— 以下 4 套：莫兰迪灰调（低饱和、灰度高，非正色）——
    ThemeStyle(
      id: 'red',
      name: '丹枫红',
      lightPrimary: Color(0xFFB06A72),
      darkPrimary: Color(0xFFCC8E96),
    ),
    ThemeStyle(
      id: 'yellow',
      name: '秋香黄',
      lightPrimary: Color(0xFFC2A24E),
      darkPrimary: Color(0xFFD9BE78),
    ),
    ThemeStyle(
      id: 'cyan',
      name: '远山青',
      lightPrimary: Color(0xFF6F9C99),
      darkPrimary: Color(0xFF92B8B5),
    ),
    ThemeStyle(
      id: 'gray',
      name: '霜月灰',
      lightPrimary: Color(0xFF8E9099),
      darkPrimary: Color(0xFFB0B2B9),
    ),
  ];

  /// 按 id 取样式（缺省回落首套「渐离紫」）
  static ThemeStyle styleById(String id) =>
      styles.firstWhere((s) => s.id == id, orElse: () => styles.first);

  /// 亮色主题（指定样式 + 基准字号）
  static FThemeData light([
    ThemeStyle? style,
    double baseFontSize = AppTokens.baseFontSizeNormal,
  ]) => build(
    style: style ?? styles.first,
    brightness: Brightness.light,
    baseFontSize: baseFontSize,
  );

  /// 暗色主题（指定样式 + 基准字号）
  static FThemeData dark([
    ThemeStyle? style,
    double baseFontSize = AppTokens.baseFontSizeNormal,
  ]) => build(
    style: style ?? styles.first,
    brightness: Brightness.dark,
    baseFontSize: baseFontSize,
  );

  /// MaterialApp 用：亮色 Material 主题（指定样式 + 基准字号）
  static ThemeData materialLight([
    ThemeStyle? style,
    double baseFontSize = AppTokens.baseFontSizeNormal,
  ]) => light(style, baseFontSize).toApproximateMaterialTheme();

  /// MaterialApp 用：暗色 Material 主题（指定样式 + 基准字号）
  static ThemeData materialDark([
    ThemeStyle? style,
    double baseFontSize = AppTokens.baseFontSizeNormal,
  ]) => dark(style, baseFontSize).toApproximateMaterialTheme();

  /// 构建一套 forui 主题：中性底色（shadcn 观感）+ 指定样式主色
  ///
  /// 官方模式（同 FTheme.neutral 源码）：FThemeData(touch, colors) 只传这两个，
  /// typography/style/icons 自动从 colors + touch 推导继承。
  ///
  /// [baseFontSize] 基准字号体系（阅览模式）：普通文本（md）对齐该像素值，
  /// 其余字型按 forui 默认比例等比缩放。必须构造期传入——copyWith(typography:)
  /// 不会让 forui 组件内部样式重推导（官方文档同款姿势：改 typography 要新建 FThemeData）。
  ///
  /// 额外两处全局处理（2026-09-05）：
  /// - background 预叠主色冷调（pageTint 同源），消除页面冷调内容与外框/头部的白边；
  /// - FScaffold.childPadding 随同一缩放系数缩放，字号切换时间距全局联动。
  static FThemeData build({
    required ThemeStyle style,
    required Brightness brightness,
    double baseFontSize = AppTokens.baseFontSizeNormal,
  }) {
    final isLight = brightness == Brightness.light;
    // touch 变体 = 移动端触控尺寸（desktop 变体控件更紧凑，移动端勿用错）
    final base = isLight
        ? FTheme.neutral.light.touch
        : FTheme.neutral.dark.touch;
    final primary = isLight ? style.lightPrimary : style.darkPrimary;
    // 基准缩放：目标 md 像素 / forui 默认 md 像素（运行时取默认值，不硬编码版本号）
    final defaultMd = base.typography.body.md.fontSize ?? 14;
    final k = baseFontSize / defaultMd;
    // 页面底色：background 叠 4%/6% 主色冷调（原 AppTokens.pageTint 逻辑上移至此）
    final tint = Color.lerp(
      base.colors.background,
      primary,
      isLight ? 0.04 : 0.06,
    )!;
    // 外框内边距随字号等比缩放：先在 base 样式实例上 copyWith 出缩放后的
    // FScaffoldStyle，再传入 FThemeData（构造器的 scaffoldStyle 参数是样式实例，
    // 不是回调；childPadding 的 delta 用官方 EdgeInsetsGeometryDelta.scale）。
    // backgroundColor 透明：全局渐变背板（渐变 + 简单图案）由 app.dart 根容器绘制，
    // scaffold/头部（decoration 默认透明）/页面全部透出背板 → 无任何色差分割与白边。
    final scaledScaffold = base.scaffoldStyle.copyWith(
      backgroundColor: Colors.transparent,
      childPadding: EdgeInsetsGeometryDelta.scale(k),
    );
    return FThemeData(
      touch: true,
      debugLabel: 'Jianli ${style.id} ${isLight ? 'L' : 'D'}',
      colors: base.colors.copyWith(
        primary: primary,
        primaryForeground: Colors.white,
        background: tint,
      ),
      typography: base.typography.scale(sizeScalar: k),
      scaffoldStyle: scaledScaffold,
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

  // —— 全局排版与布局配置（2026-09-05：统一调参入口，改这里全 App 生效） ——

  /// 基准字号体系（阅览模式）：普通文本（typography md）的目标像素值。
  /// 普通 = 12 / 大号 = 18；其他字型（xs/sm/lg/xl…）按 forui 默认比例随基准等比缩放。
  static const double baseFontSizeNormal = 12;
  static const double baseFontSizeLarge = 18;

  /// 页面水平边距（页面级 ListView / 横幅 / 全屏页统一水平值，与 FScaffold childPad 对齐）
  static const double pagePadding = 16;

  /// 列表页顶部缝隙（贴横幅/首元素）
  static const double listTopGap = 4;

  /// 列表页底部留白（滚动余量基准值；实际用 pageBottomGapOf 随字号缩放）
  static const double pageBottomGap = 24;

  // —— 间距缩放（阅览模式切换时全局空隙随字号联动） ——

  /// 间距缩放系数：当前主题 md 字号 / 基准字号（普通 = 1.0；大号 = 18/12 = 1.5）。
  /// 页面级 padding 必须用下方 *Of 系列取值，禁止直接用静态常量（那是基准值）。
  static double spacingScale(BuildContext context) {
    final md = context.theme.typography.body.md.fontSize ?? baseFontSizeNormal;
    return md / baseFontSizeNormal;
  }

  /// 页面水平边距（随字号缩放）
  static double pagePaddingOf(BuildContext context) =>
      pagePadding * spacingScale(context);

  /// 列表页顶部缝隙（随字号缩放）
  static double listTopGapOf(BuildContext context) =>
      listTopGap * spacingScale(context);

  /// 列表页底部留白（随字号缩放）
  static double pageBottomGapOf(BuildContext context) =>
      pageBottomGap * spacingScale(context);

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
        color: (isDark ? Colors.black : t.colors.foreground).withValues(
          alpha: alpha * (i + 1) / 4,
        ),
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
  static Color soft(BuildContext context, Color base) => base.withValues(
    alpha: Theme.brightnessOf(context) == Brightness.dark ? 0.22 : 0.12,
  );

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
    alpha: Theme.brightnessOf(context) == Brightness.dark ? 0.16 : 0.10,
  );

  /// 强调色渐变（图标底盘 / 小面积强调）
  static LinearGradient accentGradient(Color base) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [base, Color.lerp(base, Colors.black, 0.25)!],
  );

  /// 页面底色：全局渐变背板（渐变 + 简单图案）由 app.dart 根容器统一绘制，
  /// 页面保持透明即可透出背板——头部/外框/内容同源，无分割无白边。
  /// 保留函数兼容既有调用，返回透明色；新代码不要再包不透明底色。
  static Color pageTint(BuildContext context) => Colors.transparent;
}
