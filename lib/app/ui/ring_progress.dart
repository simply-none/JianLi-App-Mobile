// 进度环组件 —— 对齐桌面端 CountdownRing / 番茄钟进度环的移动端实现
//
// 纯 CustomPainter 绘制，无第三方依赖；倒计时 / 番茄钟 / 2FA 周期复用。
// Phase 1 升级：改为带 AnimationController 的 StatefulWidget，progress 变化时从
// 当前值平滑过渡到新值（倒计时/番茄钟连续刷新时不再跳变）。减弱动效时退化为直出。
import 'dart:math';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 环形进度
class RingProgress extends StatefulWidget {
  const RingProgress({
    super.key,
    required this.progress,
    required this.child,
    this.size = 200,
    this.strokeWidth = 10,
    this.color,
  });

  /// 0.0 ~ 1.0
  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<RingProgress> createState() => _RingProgressState();
}

class _RingProgressState extends State<RingProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppTokens.base,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _ctrl,
    curve: AppTokens.standard,
  );
  late Tween<double> _tween = Tween(begin: 0, end: 0);
  late Animation<double> _anim = _tween.animate(_curve);
  bool _initialized = false;

  // initState 里不能读 MediaQuery（JianliMotion.duration 内部依赖它）→ 放 didChangeDependencies。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _ctrl.duration = JianliMotion.duration(context, AppTokens.base);
    _tween = Tween(
      begin: widget.progress.clamp(0, 1),
      end: widget.progress.clamp(0, 1),
    );
    _anim = _tween.animate(_curve);
    _ctrl.value = widget.progress.clamp(0, 1);
  }

  @override
  void didUpdateWidget(covariant RingProgress old) {
    super.didUpdateWidget(old);
    if (widget.progress != old.progress) {
      _tween = Tween(begin: _anim.value, end: widget.progress.clamp(0, 1));
      _anim = _tween.animate(_curve);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, animation) => Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RingPainter(
                progress: _anim.value.clamp(0, 1),
                trackColor: t.colors.muted,
                progressColor: widget.color ?? t.colors.primary,
                strokeWidth: widget.strokeWidth,
              ),
            ),
            Center(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = progressColor;

    canvas.drawCircle(center, radius, track);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.progressColor != progressColor;
}
