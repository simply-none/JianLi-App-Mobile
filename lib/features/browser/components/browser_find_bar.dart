// 页内查找条（覆盖在 WebView 顶部）
//
// 实时查找由 `BrowserPage` 里 `_findQuery` 的 listener 驱动（forui 的 FTextField 没有
// onChanged，只有 onSubmit），这里只负责渲染输入框 + 上一处/下一处/关闭 + 命中计数。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/tap_scale.dart';

/// 页内查找条
class FindInPageBar extends StatelessWidget {
  const FindInPageBar({
    super.key,
    required this.controller,
    required this.count,
    required this.active,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;

  /// 命中总数（来自 onFindResultReceived）
  final int count;

  /// 当前命中序号（1-based，用于「3/12」展示）
  final int active;

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return ColoredBox(
      color: AppTokens.pageTint(context),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.colors.border)),
          ),
          child: Row(
            children: [
              TapScale(
                onTap: onClose,
                child: Icon(
                  FLucideIcons.x,
                  size: 20,
                  color: t.colors.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
              child: Material(
                type: MaterialType.transparency,
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration.collapsed(
                      hintText: '查找',
                      hintStyle: t.typography.body.sm.copyWith(
                        fontSize: 14,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                    style: t.typography.body.sm.copyWith(fontSize: 14),
                    onSubmitted: (_) => onNext(),
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$active/$count',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 12,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              TapScale(
                onTap: onPrev,
                child: Icon(
                  FLucideIcons.chevronUp,
                  size: 20,
                  color: t.colors.foreground,
                ),
              ),
              TapScale(
                onTap: onNext,
                child: Icon(
                  FLucideIcons.chevronDown,
                  size: 20,
                  color: t.colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
