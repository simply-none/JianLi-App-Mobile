// 应用主题 —— forui（shadcn 风格）主题构建入口
//
// 约定（对应桌面端 references/theme.md 的移动端落地）：
// 1. 严禁在组件里硬编码颜色；所有视觉走 `context.theme.colors.*` token。
// 2. Material 导入统一用 material_ui（Flutter Material 库的独立发行版，forui 建于其上，
//    与 flutter/material 是两套平行类，勿混用——否则 Theme 继承链断裂、类型不兼容）。
// 3. MaterialApp 的 theme/darkTheme 用 toApproximateMaterialTheme() 生成，
//    让残留 Material 组件（日期选择、文本选择菜单等）与 forui 观感一致。
// 4. 桌面端 25 套主题 token 的映射入口收敛在 _build：每套主题 = 一份主色
//    （+ 可选中性色覆盖），后续扩展多主题时在此加方案表，勿在页面里写死。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 应用主题构建器（forui）
class AppTheme {
  AppTheme._();

  /// 桌面端默认主题主色（与 jianli-app 的种子色一致）
  static const Color seedColor = Color(0xFF6C5CE7);

  /// 暗色下的主色（提亮一档保证对比度）
  static const Color seedColorDark = Color(0xFF8B7CF7);

  /// 亮色主题（forui）
  static FThemeData light() => _build(Brightness.light);

  /// 暗色主题（forui）
  static FThemeData dark() => _build(Brightness.dark);

  /// MaterialApp 用：把 forui 主题近似映射为 Material 主题（互操作）
  static ThemeData materialLight() => light().toApproximateMaterialTheme();

  /// MaterialApp 用：暗色 Material 主题
  static ThemeData materialDark() => dark().toApproximateMaterialTheme();

  /// 构建一套 forui 主题：中性底色（shadcn 观感）+ 渐离主色
  ///
  /// 官方模式（同 FTheme.neutral 源码）：FThemeData(touch, colors) 只传这两个，
  /// typography/style/icons 自动从 colors + touch 推导继承。
  static FThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    // touch 变体 = 移动端触控尺寸（desktop 变体控件更紧凑，移动端勿用错）
    final base = isLight ? FTheme.neutral.light.touch : FTheme.neutral.dark.touch;
    return FThemeData(
      touch: true,
      debugLabel: isLight ? 'Jianli Light Touch' : 'Jianli Dark Touch',
      colors: base.colors.copyWith(
        primary: isLight ? seedColor : seedColorDark,
        primaryForeground: Colors.white,
      ),
    );
  }
}
