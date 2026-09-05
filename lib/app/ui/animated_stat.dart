// 数字滚动统计（UI 现代化 Phase 1）
//
// 数字 count-up：进入视野时从 0 滚到目标值。减弱动效时直出终值。
// 用于首页聚合、番茄流水等需要「活」的统计。约束：import material_ui。
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 动画数字
class AnimatedStat extends StatelessWidget {
  const AnimatedStat({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.prefix,
    this.suffix,
    this.duration = AppTokens.base,
  });

  final num value;
  final TextStyle? style;
  final int decimals;
  final String? prefix;
  final String? suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: Tween<num>(begin: 0, end: value),
      duration: JianliMotion.duration(context, duration),
      curve: AppTokens.standard,
      builder: (_, v, child) => Text(
        '${prefix ?? ''}${v.toStringAsFixed(decimals)}${suffix ?? ''}',
        style: style,
      ),
    );
  }
}
