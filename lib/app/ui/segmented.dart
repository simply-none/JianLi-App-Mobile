// 滑块分段控件（UI 现代化 Phase 1）
//
// 替代裸 FButton 组（如待办过滤）：选中项下方有渐变指示块以 emphasize 曲线滑动。
// 约束：import material_ui；取色走 context.theme / AppTokens。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 带滑块指示的分段控件
class JianliSegmented extends StatelessWidget {
  JianliSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.height = 40,
    this.hapticType = HapticType.medium,
  }) : assert(items.isNotEmpty, 'items 不能为空');

  final List<(IconData? icon, String label)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;
  final HapticType? hapticType;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final align = items.length > 1
        ? -1 + 2 * selected / (items.length - 1)
        : 0.0;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(align, 0),
            duration: JianliMotion.duration(context, AppTokens.base),
            curve: AppTokens.emphasize,
            child: FractionallySizedBox(
              widthFactor: 1 / items.length,
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: t.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (hapticType != null) haptic(hapticType!, context);
                      onSelect(i);
                    },
                    child: Center(child: _itemLabel(i, selected == i, t)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemLabel(int i, bool active, FThemeData t) {
    final icon = items[i].$1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: active ? t.colors.primary : t.colors.mutedForeground,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          items[i].$2,
          style: t.typography.body.sm.copyWith(
            color: active ? t.colors.primary : t.colors.mutedForeground,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
