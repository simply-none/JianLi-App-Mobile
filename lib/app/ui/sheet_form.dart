// 弹窗表单原子（底部抽屉共用骨架 + 字段件）—— 对齐待办 _sheetScaffold 先例
//
// 把「图2 新增待办」弹层的骨架与字段件抽成共享原子，供倒计时新建 / 提醒编辑等
// 新弹窗复用（待办 todo_sheets.dart 的私有 _sheetScaffold 保持不动，先例唯一实现
// 的完全收口留给后续统一迁移）：
//   - [SheetScaffold]  定高骨架：居中把手 + 17/Bold 标题 + 裸 X 关闭 + 中间滚动体 + 底部条
//   - [SheetHandle]    把手 36×4 · r2 · 居中（2026-09-12 强制居中，禁 centerLeft）
//   - [SheetChoiceChip] 选择 chip：选中 = 色 14% 底 + 同色描边 + check 14；未选 = muted 底
//   - [SheetFieldLabel] 字段标签 14/mutedForeground（与字段值同大，§1.4）
//   - [SheetInputBox]   单行输入盒 h40（搜索栏同款：卡色底 + 1px 描边 + r10 + 14px，§4.5）
//   - [SheetMultilineBox] 多行输入盒（随内容增长，maxLines:null；内部直接 TextField 禁套 Row）
//   - [SheetSwitchRow]  开关行：muted 底 · r14 · 左图标 + 文字 + 右 FSwitch
//
// ⚠️ 高度三档制（interaction-patterns.md §一）：[SheetScaffold] 的 size 只许传
// SheetSize.sm/md/lg；调用点 showFSheet 必须配对
// `mainAxisMaxRatio: AppTokens.sheetHeightLg + resizeToAvoidBottomInset: false`。
// ⚠️ 左右内边距 = AppTokens.pagePadding 且**只在这里应用一次**（SheetSurface 不再传 padding）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'gradient_button.dart';
import 'sheet_surface.dart';

/// 弹窗定高骨架：把手 + 标题行 + 中间滚动体 + （可选）底部固定条。
///
/// lg（新增/编辑/详情）走全屏高 `sheetMaxHeightFull`（键盘覆盖不折叠）；
/// sm/md（确认/单选）走可用高度 `sheetMaxHeight`（扣键盘，防被键盘盖住）。
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.size,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final SheetSize size;

  /// 底部固定操作条（取消/保存等，**永不随内容滚动**，§1.8）
  final List<Widget>? bottomBar;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final h = size == SheetSize.lg
        ? sheetMaxHeightFull(context, size)
        : sheetMaxHeight(context, size);
    const hpad = AppTokens.pagePadding;
    return SheetSurface(
      // 定高（不是上限）：同档弹窗必然等高；内容超出由中间滚动区承担（§1.5）
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: SheetHandle(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(hpad, 14, hpad, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: sheetTitleStyle(context))),
                  // 右上角关闭：裸图标，不带背景色块（2026-09-12 强制）
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(hpad, 14, hpad, 8),
                child: body,
              ),
            ),
            if (bottomBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(hpad, 8, hpad, 16),
                child: Row(spacing: 10, children: bottomBar!),
              ),
          ],
        ),
      ),
    );
  }
}

/// 顶部把手：36×4 · r2 · **居中**（三处先例同源规格）
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          // mutedForeground 压 26% 叠在 muted 轨上 = 「抬升一档」的把手灰（_stepUp 口径）
          color: t.colors.mutedForeground.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 选择型 chip（左侧可带前置件；选中态显示勾）
class SheetChoiceChip extends StatelessWidget {
  const SheetChoiceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.color,
    this.leading,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color? color;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final c = color ?? t.colors.primary;
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.14) : t.colors.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: selected ? c : t.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            if (selected) ...[
              Icon(FLucideIcons.check, size: 14, color: c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: t.typography.body.sm.copyWith(
                color: selected ? c : t.colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 字段标签：14 / mutedForeground（与字段值同大，label↔输入框组内间距 6，§1.4）
class SheetFieldLabel extends StatelessWidget {
  const SheetFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: context.theme.typography.body.sm.copyWith(
        fontSize: 14,
        color: context.theme.colors.mutedForeground,
      ),
    ),
  );
}

/// 单行输入盒：h40 · 卡色底 · 1px 描边 · r10 · 14px（= 待办列表搜索栏同款，§4.5）。
/// 内部 Row(默认 center) + Expanded 保证文字垂直居中；[textAlign] 数字类短输入可传 center。
class SheetInputBox extends StatelessWidget {
  const SheetInputBox({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;

  /// 输入回调（页内实时预览等场景；弹窗表单一般不传）
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                textAlign: textAlign,
                onChanged: onChanged,
                style: t.typography.body.sm.copyWith(
                  fontSize: 14,
                  color: t.colors.foreground,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  // 边框由外层盒子提供，内部必须 none 否则双重描边（§4.5）
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 多行输入盒：随内容增长（maxLines:null + minLines）。
/// ⚠️ 绝不能套 Row/Expanded —— 无定高 + stretch 会产生约束死循环崩溃（§4.5 实踩）。
class SheetMultilineBox extends StatelessWidget {
  const SheetMultilineBox({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines = 2,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final int minLines;

  /// 输入回调（页内实时预览等场景）
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.colors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: controller,
          maxLines: null,
          minLines: minLines,
          onChanged: onChanged,
          style: t.typography.body.sm.copyWith(
            fontSize: 14,
            color: t.colors.foreground,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: hintText,
            hintStyle: t.typography.body.sm.copyWith(
              fontSize: 14,
              color: t.colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// 开关行：muted 底 · r14 · 左图标 + 文字（14）+ 右 FSwitch（待办 _switchRow 同款）
class SheetSwitchRow extends StatelessWidget {
  const SheetSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.icon,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChange;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: t.colors.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                color: t.colors.foreground,
              ),
            ),
          ),
          FSwitch(value: value, onChange: onChange),
        ],
      ),
    );
  }
}

/// 弹窗底部「取消 + 主操作」标准组合（取消 = outline、主操作 = 渐变按钮，各占一半）
List<Widget> sheetBottomActions(
  BuildContext context, {
  required String actionLabel,
  required VoidCallback? onAction,
  IconData? actionIcon,
  String cancelLabel = '取消',
  VoidCallback? onCancel,
  bool destructive = false,
}) {
  return [
    Expanded(
      child: FButton(
        variant: FButtonVariant.outline,
        onPress: onCancel ?? () => Navigator.pop(context),
        child: Text(cancelLabel),
      ),
    ),
    Expanded(
      child: destructive
          ? FButton(
              variant: FButtonVariant.destructive,
              onPress: onAction,
              child: Text(actionLabel),
            )
          : GradientButton(
              label: actionLabel,
              icon: actionIcon,
              onPress: onAction,
            ),
    ),
  ];
}

// ===================== 长按操作菜单 / 危险确认（sm 档通用） =====================

/// 操作菜单项（值由调用方定义，如枚举 / 字符串）
class SheetAction<T> {
  const SheetAction(
    this.value,
    this.label, {
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// 危险动作（删除等）：图标与文字用 destructive 红
  final bool destructive;
}

/// 底部操作菜单（sm 档）：条目长按 / ⋯ 菜单通用（对齐待办 `showTodoActionSheet` 先例）。
/// 点任意项立即 pop 返回其 [SheetAction.value]；点遮罩/关闭返回 null。
Future<T?> showSheetActionMenu<T>(
  BuildContext context, {
  required String title,
  required List<SheetAction<T>> actions,
}) {
  final t = context.theme;
  return showFSheet<T>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.sm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FTappable(
                onPress: () => Navigator.pop(c, action.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: t.colors.muted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (action.icon != null) ...[
                        Icon(
                          action.icon,
                          size: 18,
                          color: action.destructive
                              ? t.colors.destructive
                              : t.colors.foreground,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        action.label,
                        style: t.typography.body.sm.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: action.destructive
                              ? t.colors.destructive
                              : t.colors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// 危险确认抽屉（sm 档，对齐待办 `showTodoConfirmSheet` 先例）：返回 true = 确认。
Future<bool> showSheetConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  String cancelLabel = '取消',
}) async {
  final ok = await showFSheet<bool>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.sm,
      body: Text(
        message,
        style: c.theme.typography.body.sm.copyWith(
          fontSize: 14,
          color: c.theme.colors.mutedForeground,
        ),
      ),
      bottomBar: sheetBottomActions(
        c,
        actionLabel: confirmLabel,
        onAction: () => Navigator.pop(c, true),
        cancelLabel: cancelLabel,
        destructive: true,
      ),
    ),
  );
  return ok ?? false;
}
