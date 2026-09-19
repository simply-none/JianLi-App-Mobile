// 统一输入框（JianliField）—— 全 App 文本输入的单一实现
//
// 规格（2026-09-12 用户拍板，全 App 强制，见 SKILL.md 红线 #14）：
//   1. **边框必须可见**：默认边 = `AppTokens.inputBorder`（比 colors.border 深一档）。
//   2. **聚焦高亮主题色**：边 = `AppTokens.inputBorderFocused`（主题主色）+ 加粗到 1.5。
//   3. **点空白 / 拖动 / 滑动即失焦**：靠 `onTapOutside`（Flutter 在移动端默认**不**处理
//      tap-outside，必须显式给）。抽屉内的滚动收起键盘另见 `sheetScrollUnfocus`。
//   4. **随内容增高**：`maxLines: null` 时输入越多、容器越高（描述类输入用这个）。
//
// 为什么不用裸 material `TextField`：默认无边框、无聚焦高亮、移动端点了别处不收键盘，
// 三个坑都要一个个补 —— 收口到本组件，页面里只剩「声明式」用法。
// 与 forui `FTextField` 的关系：forui 输入框的边框/聚焦色已在主题层调好（同样走这两条色），
// 所以两者观感一致；本组件主要用于**原生 TextField 场景**（需要自定义字号/单行标题输入等）。
//
// ⚠️ 原生 Material 组件需要 `Material` 祖先：抽屉里由 `SheetSurface` 提供，
// 但页面里 `FScaffold` **不提供**，故本组件自带一层透明 Material，任何地方都能直接用。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// 统一输入框（可见边框 + 聚焦主题色 + 点空白/滑动收键盘 + 可选随内容增高）
class JianliField extends StatefulWidget {
  const JianliField({
    super.key,
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.autofocus = false,
    this.enabled = true,
    this.textStyle,
    this.hintStyle,
    this.contentPadding,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;

  /// 最少行数（多行输入用，如描述 3 行）
  final int minLines;

  /// 最多行数；**传 null = 随输入内容无限增高**（容器跟着长）
  final int? maxLines;

  final bool autofocus;
  final bool enabled;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? contentPadding;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<JianliField> createState() => _JianliFieldState();
}

class _JianliFieldState extends State<JianliField> {
  late final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final multiline = widget.maxLines == null || widget.maxLines! > 1;
    final radius = BorderRadius.circular(AppTokens.radiusSm);
    final border = _focused
        ? AppTokens.inputBorderFocused(context)
        : AppTokens.inputBorder(context);
    final width = _focused ? 1.5 : 1.0;

    OutlineInputBorder side(Color c, double w) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c, width: w),
        );

    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        minLines: multiline ? widget.minLines : 1,
        maxLines: widget.maxLines,
        keyboardType:
            widget.keyboardType ??
            (multiline ? TextInputType.multiline : TextInputType.text),
        textInputAction: widget.textInputAction,
        cursorColor: t.colors.primary,
        // ⚠️ 移动端 Flutter 默认不处理 tap-outside（桌面端才自动 unfocus），
        // 必须显式给：点输入框以外任何地方（含开始拖动/滑动）→ 主动失焦、收起键盘。
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style:
            widget.textStyle ??
            t.typography.body.sm.copyWith(color: t.colors.foreground),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: widget.hint,
          hintStyle:
              widget.hintStyle ??
              t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
          contentPadding:
              widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: side(border, width),
          enabledBorder: side(border, width),
          focusedBorder: side(AppTokens.inputBorderFocused(context), 1.5),
          disabledBorder: side(t.colors.border, 1),
        ),
      ),
    );
  }
}

/// 「开始滚动即收起键盘」的通知器 —— 套在抽屉的滚动区外面。
///
/// 配合 [JianliField] 的 `onTapOutside`：拖动/滑动本身就会触发 tap-outside，
/// 但**滚动条/惯性滚动**（无 pointer-down）不会，所以这里再兜一层，
/// 保证「滑动 → 聚焦失效、键盘关闭」这条规则在任何输入框上都成立。
class SheetScrollUnfocus extends StatelessWidget {
  const SheetScrollUnfocus({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (n) {
      if (n is ScrollStartNotification) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
      return false;
    },
    child: child,
  );
}
