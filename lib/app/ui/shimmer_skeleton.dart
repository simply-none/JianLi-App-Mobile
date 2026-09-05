// 骨架屏（UI 现代化 Phase 1，自实现，不引 shimmer 包）
//
// 加载占位：渐变扫光循环。减弱动效时退化为静态半透明占位。约束：import material_ui。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_motion.dart';

/// 单条骨架占位
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    this.height = 14,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!JianliMotion.enabled(context)) return _box(0.5);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, animation) => _box(_ctrl.value),
    );
  }

  Widget _box(double p) {
    final t = context.theme;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final base = t.colors.muted;
    final hi = (isDark ? Colors.white : t.colors.foreground).withValues(
      alpha: isDark ? 0.18 : 0.12,
    );
    final a = (p - 0.5).clamp(0.0, 1.0);
    final b = p.clamp(0.0, 1.0);
    final c = (p + 0.5).clamp(0.0, 1.0);
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [a, b, c],
          colors: [base, hi, base],
        ),
      ),
    );
  }
}
