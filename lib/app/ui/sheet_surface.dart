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
// 📌 规则（2026-09-12 定，**全 App 强制**；同日下午修订「新增/编辑/查看」高度条款）：
//   1. 抽屉高度**只有三档** —— [SheetSize.sm] 30% / [SheetSize.md] 50% / [SheetSize.lg] 80%，
//      **禁止第四种**；新增/编辑/查看弹窗必须挂到其中一档，不要在调用点写裸比例。
//   2. **【新增/编辑/查看】**类抽屉（详情、长表单）高度 = 屏幕高 × 档位（见 [sheetMaxHeightFull]），
//      键盘从底部覆盖时抽屉**不重排、不折叠**：内容由中间滚动区承担，焦点字段会自动滚入可视区。
//      ⚠️ 这是 2026-09-12 下午起的新规：此前 lg 用「可用高度（扣键盘）」，会导致键盘开合时
//      抽屉反复收缩/展开、影响输入体验，故改为全屏高固定比例。
//   3. **sm / md** 类抽屉（确认、操作菜单、单选/多选、日期时间、输入等）仍走 [sheetMaxHeight]
//      （屏幕高 − 键盘高）× 档位，保证内容少、一眼看完时不被键盘盖住。
//   4. 弹窗标题一律用 [sheetTitleStyle]（17/Bold，画布 09/10 规格）；
//      **弹窗内任何字段的字号都不得大于它**。
//   5. 内容超出档位由**中间滚动区**承担，绝不撑高抽屉。
//   6. ⚠️ **调用点必须配套 `showFSheet` 参数**，否则上面的高度档位会失效：
//      `mainAxisMaxRatio: AppTokens.sheetHeightLg`（forui 默认是 9/16≈56%，不写就到不了 80%）
//      + `resizeToAvoidBottomInset: false`（让键盘从底部**覆盖**抽屉，而不是把它挤小/顶满；
//      与「80vh 固定、键盘不影响」的观感是同一件事）。两参数配套才是完整规范，缺一不可。
//      参考实现：todo 的 `_showTodoSheet`、habit 的 `_showCreateSheet`/`_showDetailSheet`。
//   7. **lg 弹层内部必须是「定高」而不是「最大高度」**：外壳里用 `BoxConstraints.tightFor(height: maxH)`
//      或 `SizedBox(height: maxH)`，不能只用 `BoxConstraints(maxHeight: maxH)`。否则内容少时
//      抽屉会 hug 内容，根本到不了 80%（实测坑：habit 新建弹层只到 ~30%）。sm/md 仍可只设上限、
//      让内容少时自适应。

/// 弹窗高度规格：**只有这三档，禁止第四种**。
///
/// | 档位 | 高度 | 用在哪 |
/// |---|---|---|
/// | [sm] | 30% | 确认、操作菜单、单选 —— 内容少、一眼看完（走 [sheetMaxHeight] 可用高度） |
/// | [md] | 50% | 多选、日期时间、输入、按天列表 —— 需要滚动（走 [sheetMaxHeight] 可用高度） |
/// | [lg] | 80% | 详情、新增/编辑表单 —— 长表单；**详情与编辑必须同档**；走 [sheetMaxHeightFull] 全屏高 |
enum SheetSize {
  sm(AppTokens.sheetHeightSm),
  md(AppTokens.sheetHeightMd),
  lg(AppTokens.sheetHeightLg);

  const SheetSize(this.ratio);

  final double ratio;
}

/// 档位对应的实际高度 =（屏幕高 − 键盘高）× 档位。
///
/// 供 **sm / md** 类抽屉使用：内容少、一眼看完，按可用高度算 → 抽屉永远完整落在键盘上方，
/// 永远到不了 100vh（forui `ShiftedSheet` 用 `dy = max(0, H − 抽屉高 − 键盘高)` 摆放，
/// 超过「H − 键盘高」会被夹到 0、被键盘盖住）。
///
/// 读 `MediaQuery` 而非直接用屏高：键盘开合时本值自动变化，抽屉跟着重建到正确高度。
double sheetMaxHeight(BuildContext context, SheetSize size) {
  final mq = MediaQuery.of(context);
  return (mq.size.height - mq.viewInsets.bottom) * size.ratio;
}

/// 档位对应的实际高度 = 屏幕高 × 档位（**不扣键盘**）。
///
/// 供 **新增/编辑/查看（lg）** 类抽屉使用（设计规范 2026-09-12 下午起强制）：
/// 键盘从底部覆盖时抽屉高度**保持全屏固定比例、不收缩、不折叠**，输入体验不被键盘开合打断；
/// 抽屉内容在中间滚动区，焦点字段（如输入框）会自动滚入可视区，底部按钮在键盘收起后可见。
///
/// ⚠️ 不用本函数时请注意：固定全屏高 + 键盘可能盖住抽屉底部，故调用方必须把内容放
/// 进可滚动容器（[SingleChildScrollView]），且关键操作按钮不要死贴在抽屉最底部可视区外。
double sheetMaxHeightFull(BuildContext context, SheetSize size) {
  final mq = MediaQuery.of(context);
  return mq.size.height * size.ratio;
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

