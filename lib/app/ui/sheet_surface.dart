// 抽屉表面（SheetSurface）—— showFSheet 的 builder 内容必须自绘背景
//
// ⚠️ forui 的 Sheet 链路（FModalSheetRoute → Sheet → ShiftedSheet）不画任何
// surface，builder 直接给 Padding 会露出灰色 barrier（「透明灰」实踩）。
// 统一用本组件包住抽屉内容：主题 background 底色（已在主题构建时叠主色冷调，
// 跟随亮暗与主题样式）+ 顶部圆角；padding 参数与原 Padding 同名直换。
//
// ⚠️ 同时**提供 Material 祖先**（2026-09-12 实踩）：forui 的 Sheet 链路里没有
// `Material`，而 `material_ui` 的原生 `TextField` / InkWell 等都必须有 Material
// 祖先，否则抛 `No Material widget found`（新增/编辑待办抽屉「标题」输入框就这么崩的）。
// 这里统一包一层透明 Material，全 App 的抽屉一次修好；forui 自家控件在内部自建
// Material，多这一层无副作用、无视觉变化。
//
// ⚠️ 左右内边距**不要**同时写在 SheetSurface.padding 和抽屉内容里（2026-09-12 实踩）：
// 两处各写 16 → 实际 32，弹窗内容离屏幕边缘比页面正文远一倍。左右边距统一由
// 抽屉骨架内部（`AppTokens.sheetPaddingH`）提供；本组件的 padding 只用于确实需要的
// 通栏外框缝隙（一般不用传）。
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
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// 圆角覆盖（缺省顶部圆角，适配底部抽屉；右侧抽屉传左侧圆角）
  final BorderRadiusGeometry? borderRadius;

  /// 底色覆盖（缺省主题 background = 页面底色调；画布若要求「比页面更亮」的卡面色，
  /// 传 `context.theme.colors.card`）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? t.colors.background,
          borderRadius:
              borderRadius ??
              const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radiusLg),
              ),
        ),
        padding: padding,
        // 「一开始滚动就收起键盘」（全 App 抽屉统一，2026-09-12）：
        // 点空白收键盘由根组件的 Actions 覆盖负责（见 app.dart），但**惯性滚动**没有
        // pointer-down，手指落在内容区起滑时 pointer-down 也不一定落在「输入框以外的空白」，
        // 故这里再兜一层：抽屉内任何滚动开始 → 主动失焦、收键盘。
        // 收口在 SheetSurface（所有抽屉的公共外壳）→ 一处生效、全 App 抽屉行为一致。
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            return false;
          },
          child: child,
        ),
      ),
    );
  }
}

// ===================== 弹窗（底部抽屉）规格：三档制 =====================
//
// 📌 规则（2026-09-12 定，**全 App 强制**）：
//   1. 抽屉高度**只有三档** —— [SheetSize.sm] 30% / [SheetSize.md] 50% / [SheetSize.lg] 80%，
//      **禁止第四种**；新增弹窗必须挂到其中一档，不要在调用点写裸比例。
//   2. 比例相对**可用高度**（屏幕高 − 键盘高），不是屏幕高 —— 见 [sheetMaxHeight] 注释。
//   3. 弹窗标题一律用 [sheetTitleStyle]（17/Bold，画布 09/10 规格）；
//      **弹窗内任何字段的字号都不得大于它**。
//   4. 内容超出档位由**中间滚动区**承担，绝不撑高抽屉。

/// 弹窗高度规格：**只有这三档，禁止第四种**。
///
/// | 档位 | 高度 | 用在哪 |
/// |---|---|---|
/// | [sm] | 30% | 确认、操作菜单、单选 —— 内容少、一眼看完 |
/// | [md] | 50% | 多选、日期时间、输入、按天列表 —— 需要滚动 |
/// | [lg] | 80% | 详情、新增/编辑表单 —— 长表单；**详情与编辑必须同档** |
enum SheetSize {
  sm(AppTokens.sheetHeightSm),
  md(AppTokens.sheetHeightMd),
  lg(AppTokens.sheetHeightLg);

  const SheetSize(this.ratio);

  final double ratio;
}

/// 档位对应的实际高度 =（屏幕高 − 键盘高）× 档位。
///
/// ⚠️ **为什么必须减掉键盘高**（2026-09-12 实测，改前必读）：
/// forui 的 `ShiftedSheet` 用 `dy = max(0, H − 抽屉高 − 键盘高)` 摆放抽屉 ——
/// 抽屉高一旦超过「H − 键盘高」，dy 就被夹到 0 停止上移，抽屉**不会抬到键盘上方**，
/// 而是被键盘从底下盖住（现象：底部「保存」被键盘压住、点不到）。
/// 按可用高度算 → 抽屉永远完整落在键盘上方，且永远到不了 100vh。
///
/// 读 `MediaQuery` 而非直接用屏高：键盘开合时本值自动变化，抽屉跟着重建到正确高度。
double sheetMaxHeight(BuildContext context, SheetSize size) {
  final mq = MediaQuery.of(context);
  return (mq.size.height - mq.viewInsets.bottom) * size.ratio;
}

/// 弹窗标题样式（画布 09/10 规格：17/Bold，绝对像素）。
///
/// ⚠️ 不要用裸 `context.theme.typography.body.lg` 当标题：主题把 forui 字型整体按
/// `baseFontSizeNormal` 缩放过（body.lg ≈ 13.7），直接用会比正文字号还小 ——
/// 这正是「待办详情比待办标题【xxx】小」的成因。
TextStyle sheetTitleStyle(BuildContext context) =>
    context.theme.typography.body.lg.copyWith(
      fontSize: AppTokens.sheetTitleFontSize,
      fontWeight: FontWeight.w700,
    );

