// 进度环组件 —— 对齐桌面端 CountdownRing / 番茄钟进度环的移动端实现
//
// 纯 CustomPainter 绘制，无第三方依赖；倒计时 / 番茄钟 / 2FA 周期复用。
import 'dart:math';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 环形进度
class RingProgress extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.theme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: t.colors.muted,
              progressColor: color ?? t.colors.primary,
              strokeWidth: strokeWidth,
            ),
          ),
          Center(child: child),
        ],
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
