// 抽屉表面（SheetSurface）—— showFSheet 的 builder 内容必须自绘背景
//
// ⚠️ forui 的 Sheet 链路（FModalSheetRoute → Sheet → ShiftedSheet）不画任何
// surface，builder 直接给 Padding 会露出灰色 barrier（「透明灰」实踩）。
// 统一用本组件包住抽屉内容：主题 background 底色（已在主题构建时叠主色冷调，
// 跟随亮暗与主题样式）+ 顶部圆角；padding 参数与原 Padding 同名直换。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// 抽屉表面
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// 圆角覆盖（缺省顶部圆角，适配底部抽屉；右侧抽屉传左侧圆角）
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      decoration: BoxDecoration(
        color: t.colors.background,
        borderRadius:
            borderRadius ??
            const BorderRadius.vertical(
              top: Radius.circular(AppTokens.radiusLg),
            ),
      ),
      padding: padding,
      child: child,
    );
  }
}
