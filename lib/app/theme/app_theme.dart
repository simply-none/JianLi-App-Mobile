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

import 'jianli_palette.dart';

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
      lightPrimary: Color(0xFF9D5CFF),
      darkPrimary: Color(0xFF5B3FD6),
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
    // —— 以下 4 套：正色 vivid（取消莫兰迪灰调回调，2026-09-10）；亮度/饱和度与前 5 套对齐，
    //    颜色贴合主题名；霜月白用月光银蓝主色（纯白无法做按钮底色，白字不可见）——
    ThemeStyle(
      id: 'red',
      name: '丹枫红',
      lightPrimary: Color(0xFFE5484D),
      darkPrimary: Color(0xFFF26A70),
    ),
    ThemeStyle(
      id: 'yellow',
      name: '秋香黄',
      lightPrimary: Color(0xFFF4B400),
      darkPrimary: Color(0xFFF8C95A),
    ),
    ThemeStyle(
      id: 'cyan',
      name: '远山青',
      lightPrimary: Color(0xFF0EA5A4),
      darkPrimary: Color(0xFF4FD1C5),
    ),
    ThemeStyle(
      id: 'white',
      name: '霜月白',
      lightPrimary: Color(0xFF9DB4CC),
      darkPrimary: Color(0xFFC3D2E2),
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
    final isZi = style.id == 'zi';
    // 外观色系：每套主题都有自己的「渐离紫同构」调色板（亮/暗各一），由主题主色
    // 派生；渐离紫用画布手工微调的精确值。切外观 + 切深浅时分层与氛围都跟着走。
    final pal = isLight
        ? JianliPalette.light(style.lightPrimary, zi: isZi)
        : JianliPalette.dark(style.darkPrimary, zi: isZi);
    final primary = isLight ? style.lightPrimary : style.darkPrimary;
    // 基准缩放：目标 md 像素 / forui 默认 md 像素（运行时取默认值，不硬编码版本号）
    final defaultMd = base.typography.body.md.fontSize ?? 14;
    final k = baseFontSize / defaultMd;
    // 页面底色：统一走当前外观色系的 pageBg（单一事实来源）。
    final tint = pal.pageBg;
    // 外框内边距随字号等比缩放：先在 base 样式实例上 copyWith 出缩放后的
    // FScaffoldStyle，再传入 FThemeData（构造器的 scaffoldStyle 参数是样式实例，
    // 不是回调；childPadding 的 delta 用官方 EdgeInsetsGeometryDelta.scale）。
    // backgroundColor 透明：全局渐变背板（渐变 + 简单图案）由 app.dart 根容器绘制，
    // scaffold/头部（decoration 默认透明）/页面全部透出背板 → 无任何色差分割与白边。
    // footerDecoration 置空：forui 默认给 footer 加一条通栏顶边线，会横穿悬浮胶囊
    // 底部导航（画布 navPill 无此线），故显式去掉。
    final scaledScaffold = base.scaffoldStyle.copyWith(
      backgroundColor: Colors.transparent,
      footerDecoration: DecorationDelta.value(const BoxDecoration()),
      childPadding: EdgeInsetsGeometryDelta.scale(k),
    );
    // 统一 FHeader 左右内边距为全局 AppTokens.pagePadding（12，固定、不随字号缩放），
    // 与所有页面正文左右边距一致；其余标题样式（字重/动作样式）沿用 base 派生。
    // 统一表面层 / 文字色：卡片、次级底、边界、主/次文字全部取自当前外观的调色板
    // （每套外观一套色系），禁止页面硬编码。
    final scaledColors = base.colors.copyWith(
      primary: primary,
      primaryForeground: Colors.white,
      background: tint,
      foreground: pal.onSurfaceTitle,
      card: pal.surface,
      muted: pal.surfaceElevated,
      mutedForeground: pal.onSurfaceSub,
      border: pal.surfaceElevated,
    );
    final scaledType = base.typography.scale(sizeScalar: k);
    final baseStyle = FStyle.inherit(colors: scaledColors, typography: scaledType, touch: true);
    // 输入框边框色（**可见**）—— 只换给文字输入框用的颜色副本，不动全局 colors.border
    // （卡片/chip/分割线仍用浅边界，避免整套 UI 变重）。
    // ⚠️ 为什么必须单独提亮：forui 的 FTextField 默认边框取 colors.border = 调色板
    // surfaceElevated（#F1F2F5），压在 #F7F9FA 的抽屉底上几乎看不出边框
    //（2026-09-12 用户实指「新增待办输入框没显示边框」）；聚焦态 forui 自带
    // 切成 colors.primary 的变体，提亮默认色后「聚焦高亮主题色」自动成立。
    final fieldColors = scaledColors.copyWith(
      border: AppTokens.inputBorderColor(scaledColors),
    );
    final headerFStyle = FStyle(
      formFieldStyle: baseStyle.formFieldStyle,
      focusedOutlineStyle: baseStyle.focusedOutlineStyle,
      iconStyle: baseStyle.iconStyle,
      sizes: baseStyle.sizes,
      tappableStyle: baseStyle.tappableStyle,
      pagePadding: EdgeInsets.symmetric(horizontal: AppTokens.pagePadding, vertical: 8),
    );
    final headerStyles = FHeaderStyles.inherit(
      colors: scaledColors,
      typography: scaledType,
      style: headerFStyle,
      touch: true,
    );
    return FThemeData(
      touch: true,
      debugLabel: 'Jianli ${style.id} ${isLight ? 'L' : 'D'}',
      colors: scaledColors,
      typography: scaledType,
      scaffoldStyle: scaledScaffold,
      headerStyles: headerStyles,
      // 输入框：可见边框 + 聚焦主题色（forui 的 focused 变体本就是 colors.primary）
      textFieldStyles: FTextFieldSizeStyles.inherit(
        colors: fieldColors,
        typography: scaledType,
        style: baseStyle,
        touch: true,
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

  // —— 全局排版与布局配置（2026-09-05：统一调参入口，改这里全 App 生效） ——

  /// 基准字号体系（阅览模式）：普通文本（typography md）的目标像素值。
  /// 普通 = 12 / 大号 = 18；其他字型（xs/sm/lg/xl…）按 forui 默认比例随基准等比缩放。
  static const double baseFontSizeNormal = 12;
  static const double baseFontSizeLarge = 18;

  /// 页面左右边距（**全局唯一边距变量**，固定 16px，不随字号缩放；改这里全 App 生效）。
  ///
  /// 2026-09-12 由 12 收口到 16：原先 `FHeader`（标题）用 12、各页正文硬编码 16，
  /// 同一屏里标题比正文更靠边、左边缘对不齐；画布列表页正文标注也是 16，故统一 16。
  ///
  /// 弹窗（底部抽屉）的左右内边距**也引用本常量**（= 页面正文，天然一致）——
  /// 用户规则：「弹窗的左右 padding 应该和全局保持一致」。
  /// ⚠️ 弹窗内只允许**应用一次**：`SheetSurface` 曾给键盘型弹窗再叠一层 16，
  /// 骨架内部又写一层 16 → 实际 32（2026-09-12 实踩）。
  static const double pagePadding = 16;

  // —— 弹窗（底部抽屉）规格（2026-09-12 定，全 App 弹窗必须遵循） ——
  //
  // ⚠️ 弹窗标题字号 = 画布 09/10 规格的绝对像素值（17/Bold）。
  // **规则：弹窗内任何字段的字号都不得大于它**（详情/编辑里的「条目标题」同用此值）。
  // 为什么用绝对值：主题把 forui 字型整体按 baseFontSizeNormal 缩放过（body.lg ≈ 13.7），
  // 若标题直接用 body.lg 会比正文还小 —— 这正是「待办详情比待办标题【xxx】小」的成因。
  static const double sheetTitleFontSize = 17;

  /// 弹窗内「条目标题」字号（详情标题 / 编辑标题输入框）。
  /// 比弹窗标题 [sheetTitleFontSize] 小 2 号，保证「弹窗标题字号 > 弹窗任何内容字号」。
  /// 2026-09-12 由「与弹窗标题同 17」改为 15。
  static const double sheetFieldTitleFontSize = 15;

  /// 弹窗高度规格：只有三档，**禁止第四种**。比例相对「可用高度」＝屏幕高 − 键盘高
  /// （键盘弹起时不改档、按可用高度收缩，保证弹窗完整落在键盘上方）。
  /// 消费方：`SheetSize` / `sheetMaxHeight()`（`lib/app/ui/sheet_surface.dart`）。
  static const double sheetHeightSm = 0.30;
  static const double sheetHeightMd = 0.50;
  static const double sheetHeightLg = 0.80;

  /// 列表页顶部缝隙（贴横幅/首元素）
  static const double listTopGap = 4;

  /// 列表页底部留白（滚动余量基准值；实际用 pageBottomGapOf 随字号缩放）
  static const double pageBottomGap = 24;

  // —— 间距缩放（阅览模式切换时仅「垂直缝隙」随字号联动；左右边距固定，见 pagePadding） ——

  /// 间距缩放系数：当前主题 md 字号 / 基准字号（普通 = 1.0；大号 = 18/12 = 1.5）。
  /// 仅用于 listTopGap / pageBottomGap 等垂直缝隙；页面左右边距用固定常量 [pagePadding]，不随字号缩放。
  static double spacingScale(BuildContext context) {
    final md = context.theme.typography.body.md.fontSize ?? baseFontSizeNormal;
    return md / baseFontSizeNormal;
  }

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

  // —— 页面渐变背板（画布「02 导航重设计」的 `背景装饰` 层，全 App 唯一实现） ——
  //
  // 画布规格是三段渐变：顶部 7% → 中段(50%) 2% → 底部 0（暗色 8% / 5.5% / 0），
  // 底色为当前外观的 pageBg。根容器画它；**任何「要盖住滚动内容」的吸顶条也必须由它派生**
  // —— 早期吸顶条直接刷 `colors.background` 纯色，结果上半屏是渐变紫、吸顶条是一块灰白，
  // 背景被硬生生切断（2026-09-12 用户实指「背景下部分被内容区遮盖」）。
  static LinearGradient pageGradientOf(FThemeData data, Brightness brightness) {
    Color at(double alpha) =>
        Color.lerp(data.colors.background, data.colors.primary, alpha)!;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        at(JianliPalette.gradientTopAlphaOf(brightness)),
        at(JianliPalette.gradientMidAlphaOf(brightness)),
        data.colors.background,
      ],
      stops: const [0, 0.5, 1],
    );
  }

  /// 当前主题的页面渐变背板（等同根容器画的那一层）
  static LinearGradient pageGradient(BuildContext context) =>
      pageGradientOf(context.theme, Theme.brightnessOf(context));

  /// 背板顶部色 —— 也是吸顶条「盖住滚过内容」时的取色起点（同源 → 看不到接缝）
  static Color pageGradientTop(BuildContext context) =>
      pageGradient(context).colors.first;

  /// 吸顶条覆盖层：背板同源渐变。
  ///
  /// [extent] = 吸顶条高度。用它把背板的**衰减率**按比例映射到吸顶条自身高度上：
  /// 条内从「背板顶部色」按同一速率衰减到对应位置，所以条内渐变不会比背板更陡/更平，
  /// 吸顶条顶边与其上方的页面头部同色 → 接缝不可见。
  static BoxDecoration pinnedCover(BuildContext context, double extent) {
    final t = context.theme;
    final brightness = Theme.brightnessOf(context);
    final top = pageGradientTop(context);
    final mid = Color.lerp(
      t.colors.background,
      t.colors.primary,
      JianliPalette.gradientMidAlphaOf(brightness),
    )!;
    // 背板在 50% 处到达 mid；条内衰减到 mid 的比例 = 2 × 条高 / 屏高
    final f = (2 * extent / MediaQuery.sizeOf(context).height).clamp(0.0, 1.0);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, Color.lerp(top, mid, f)!],
      ),
    );
  }

  /// 输入框边框色（**必须可见**）
  ///
  /// ⚠️ 不要直接用 `colors.border`：它 = 调色板 surfaceElevated（#F1F2F5），
  /// 与抽屉底/页面底（#F7F9FA）几乎同色，等于「没有边框」（2026-09-12 实踩）。
  /// 这里往次字色方向压一档：既轻，又能一眼看出输入框的边界。
  /// 聚焦态不在这里——统一用 `colors.primary`（forui 输入框自带该变体）。
  static Color inputBorderColor(FColors colors) =>
      Color.lerp(colors.border, colors.mutedForeground, 0.28)!;

  /// 输入框边框色（按当前主题取）
  static Color inputBorder(BuildContext context) =>
      inputBorderColor(context.theme.colors);

  /// 输入框聚焦边框色 = 主题主色
  static Color inputBorderFocused(BuildContext context) =>
      context.theme.colors.primary;
}
