// 按压缩放辅助（UI 现代化 Phase 1）
//
// 轻量封装：在保持 tappable 语义（GestureDetector 自带 semantics tap）的同时，
// 点击时做一次 0.97 缩放反馈，可选触发触感。供 AppCard / GradientButton /
// SquircleBox 复用，统一「轻爽触感」手感。
// 约束：UI 文件继续 import material_ui；不引 flutter/material。
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 点击缩放容器
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 按下缩放比（默认 0.97）
  final double scale;

  /// 点击触感类型（null = 不触发）
  final HapticType? haptic;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dur = JianliMotion.duration(context, AppTokens.fast);
    final tappable = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: tappable
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
              if (widget.haptic != null) haptic(widget.haptic!, context);
            }
          : null,
      onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: dur,
        curve: AppTokens.standard,
        child: widget.child,
      ),
    );
  }
}
