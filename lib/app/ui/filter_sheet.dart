// 通用查询抽屉（页面操作规范：查询/筛选统一走底部抽屉）
//
// 结构固定（见 SKILL.md「页面操作规范」）：
//   顶部：左侧「查询」标题 + 右侧关闭图标（关闭 = 不应用更改）
//   中部：选项区，可滚动（调用方通过 body 提供，refresh 用于重置后刷新草稿 UI）
//   底部：固定「重置 / 查询」两按钮（重置 = 清空选项不关闭；查询 = 应用并关闭）
//
// 用法：调用方维护「草稿」选项状态（打开前从已生效条件初始化），
// onReset 里清空草稿并调 refresh()，onConfirm 里组装结果并作为 pop 值返回。
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
}) {
  return showFSheet<R>(
    context: context,
    side: FLayout.btt,
    builder: (context) => _FilterSheet<R>(
      title: title,
      body: body,
      onReset: onReset,
      onConfirm: onConfirm,
      confirmLabel: confirmLabel,
      resetLabel: resetLabel,
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
  });

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
    // 页面规范：查询抽屉**固定高度 50vh**——「重置 / 查询」绝对贴底不浮动，
    // 选项超出时中部滚动（minHeight 方案在 forui Sheet 的松约束下按钮会随
    // 内容收起，实踩后改为定高）。要调抽屉高度改这里的 0.5。
    final sheetHeight = MediaQuery.of(context).size.height * 0.5;
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
                        style: t.typography.body.lg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
