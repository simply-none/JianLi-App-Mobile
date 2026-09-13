// 通用查询抽屉（页面操作规范：查询/筛选统一走底部抽屉）
//
// 结构固定（见 SKILL.md「页面操作规范」）：
//   顶部：左侧「查询」标题 + 右侧关闭图标（关闭 = 不应用更改）
//   中部：选项区，可滚动（调用方通过 body 提供，refresh 用于重置后刷新草稿 UI）
//   底部：固定「重置 / 查询」两按钮（重置 = 清空选项不关闭；查询 = 应用并关闭）
//
// 用法：调用方维护「草稿」选项状态（打开前从已生效条件初始化），
// onReset 里清空草稿并调 refresh()，onConfirm 里组装结果并作为 pop 值返回。
//
// 高度三档（2026-09-13 用户定案）：抽屉内含输入框的一律传 size: SheetSize.lg——
// 80vh 定高、键盘覆盖不折叠（对齐 SKILL.md 红线 #9 的 lg 口径）；纯选择/多选类
// 保持默认 md（50%，扣键盘）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'gradient_button.dart';
import 'sheet_surface.dart';

/// 打开通用查询抽屉；[onConfirm] 的返回值作为抽屉结果（pop 值）。
Future<R?> showFilterSheet<R>({
  required BuildContext context,
  String title = '查询',
  required Widget Function(BuildContext context, VoidCallback refresh) body,
  required void Function(VoidCallback refresh) onReset,
  R? Function()? onConfirm,
  String confirmLabel = '查询',
  String resetLabel = '重置',

  /// 档位：默认 md（50% 扣键盘）；含输入框的抽屉必须传 lg（80vh 定高不扣键盘）
  SheetSize size = SheetSize.md,
}) {
  return showFSheet<R>(
    context: context,
    side: FLayout.btt,
    // 三档制配对：定高 lg 必须挂 mainAxisMaxRatio=lg + 不随键盘收缩
    //（否则 forui 默认 9/16≈56% 会把 80vh 压住——与 SheetScaffold 同一套规则）
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (context) => _FilterSheet<R>(
      title: title,
      body: body,
      onReset: onReset,
      onConfirm: onConfirm,
      confirmLabel: confirmLabel,
      resetLabel: resetLabel,
      isLg: size == SheetSize.lg,
    ),
  );
}

class _FilterSheet<R> extends StatefulWidget {
  const _FilterSheet({
    required this.title,
    required this.body,
    required this.onReset,
    this.onConfirm,
    required this.confirmLabel,
    required this.resetLabel,
    required this.isLg,
  });

  /// lg = 80vh 全屏定高（不扣键盘）；md = 50% 可用定高（扣键盘）
  final bool isLg;

  final String title;
  final Widget Function(BuildContext context, VoidCallback refresh) body;
  final void Function(VoidCallback refresh) onReset;
  final R? Function()? onConfirm;
  final String confirmLabel;
  final String resetLabel;

  @override
  State<_FilterSheet<R>> createState() => _FilterSheetState<R>();
}

class _FilterSheetState<R> extends State<_FilterSheet<R>> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 弹窗三档制：查询抽屉 = md（50%）**定高**——「重置 / 查询」绝对贴底不浮动，
    // 选项超出时中部滚动（minHeight 方案在 forui Sheet 的松约束下按钮会随内容收起，
    // 实踩后改为定高）。高度不再手写比例，统一走共享规则（含键盘扣减）。
    final sheetHeight = widget.isLg
        ? sheetMaxHeightFull(context, SheetSize.lg)
        : sheetMaxHeight(context, SheetSize.md);
    return SheetSurface(
      child: SizedBox(
        height: sheetHeight,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部：标题 + 关闭（裸图标，无背景）
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  14,
                  AppTokens.pagePadding,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: sheetTitleStyle(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          FLucideIcons.x,
                          size: 18,
                          color: t.colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 中部：选项区（Expanded 定高填满 → 底部按钮恒贴抽屉底部；选项多时滚动）
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    14,
                    AppTokens.pagePadding,
                    8,
                  ),
                  child: widget.body(context, _refresh),
                ),
              ),
              // 底部：固定「重置 / 查询」
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  8,
                  AppTokens.pagePadding,
                  16,
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: () => widget.onReset(_refresh),
                        child: Text(widget.resetLabel),
                      ),
                    ),
                    Expanded(
                      child: GradientButton(
                        label: widget.confirmLabel,
                        icon: FLucideIcons.check,
                        onPress: () =>
                            Navigator.pop(context, widget.onConfirm?.call()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
