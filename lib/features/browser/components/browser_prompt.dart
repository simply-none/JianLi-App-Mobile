// 浏览器功能域的文本输入抽屉（新建文件夹 / 重命名 / 加入固定标签 / 填订阅地址 …共用）
//
// 为什么单独一件：Phase 2 有 5 处「弹一个输入框、拿一个字符串回来」的需求，
// 若各写一遍 showFSheet + SheetScaffold + 控制器生命周期，很容易出现
// 「忘了 dispose」「高度档位传错导致被键盘盖住」这类重复事故。
//
// 档位：**md（50%）** —— 输入态要留键盘位置，sm(30%) 会被盖住（高度三档制）。
// ⚠️ 必须 `resizeToAvoidBottomInset: true`（见下方 showFSheet）：SheetScaffold 用
// `sheetMaxHeight` =（屏高 − 键盘高）× 档位 把抽屉抬到键盘上方；若设 false，MediaQuery
// 读不到键盘高，抽屉按全屏高算、被键盘盖住输入框。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
// SheetSize（高度三档）定义在 sheet_surface，不在 sheet_form —— 两个都要导
import '../../../app/ui/sheet_surface.dart';

/// 单行文本输入抽屉。返回 null = 取消 / 关掉；返回**非空串** = 用户确认。
Future<String?> showBrowserPrompt(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  String confirmLabel = '确定',
  String? helper,
  TextInputType? keyboardType,
}) {
  return showFSheet<String>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    // 输入抽屉必须 true：让 SheetScaffold 的 sheetMaxHeight 读到键盘高度、把抽屉抬到键盘上方，
    // 否则键盘盖住输入框（sm/md 输入档规范；与 lg 详情档的 false 相反）
    resizeToAvoidBottomInset: true,
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.md,
      body: _PromptBody(
        initial: initial,
        hint: hint,
        helper: helper,
        confirmLabel: confirmLabel,
        keyboardType: keyboardType,
      ),
    ),
  );
}

/// 输入体（自带控制器与确认按钮 —— 确认时要把文本带回去，所以按钮必须在这里）
class _PromptBody extends StatefulWidget {
  const _PromptBody({
    required this.initial,
    required this.hint,
    required this.helper,
    required this.confirmLabel,
    required this.keyboardType,
  });

  final String? initial;
  final String? hint;
  final String? helper;
  final String confirmLabel;
  final TextInputType? keyboardType;

  @override
  State<_PromptBody> createState() => _PromptBodyState();
}

class _PromptBodyState extends State<_PromptBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) return; // 空值不上交（调用方拿到 null 即视为取消）
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetInputBox(
          controller: _controller,
          hintText: widget.hint,
          keyboardType: widget.keyboardType,
          onSubmitted: (_) => _submit(),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.helper!,
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              height: 1.5,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.outline,
                onPress: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            Expanded(
              child: GradientButton(label: widget.confirmLabel, onPress: _submit),
            ),
          ],
        ),
      ],
    );
  }
}
