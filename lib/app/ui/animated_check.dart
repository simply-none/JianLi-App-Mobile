// 弹簧对勾（UI 现代化 Phase 1）
//
// 完成态指示：checked 时环形进度 + 对勾描边以强调曲线弹出；未选中显示淡环。
// 用于习惯打卡 / 待办完成等「达成」反馈。约束：import material_ui。
import 'dart:math';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 动画对勾
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.checked,
    this.size = 28,
    this.color,
    this.duration = AppTokens.base,
  });

  final bool checked;
  final double size;
  final Color? color;
  final Duration duration;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _initialized = false;

  // initState 里不能读 MediaQuery（JianliMotion.duration 内部依赖它）→ 放 didChangeDependencies。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _ctrl = AnimationController(
      vsync: this,
      duration: JianliMotion.duration(context, widget.duration),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: AppTokens.emphasize);
    if (widget.checked) _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant AnimatedCheck old) {
    super.didUpdateWidget(old);
    if (widget.checked != old.checked) {
      widget.checked ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, animation) => CustomPaint(
      size: Size.square(widget.size),
      painter: _CheckPainter(
        progress: _anim.value,
        color: widget.color ?? context.theme.colors.primary,
      ),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke;

    // 淡底环
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius, ring);

    // 进度环
    final ringP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      ringP,
    );

    // 对勾描边（进度 0.05 后开始）
    if (progress > 0.05) {
      final path = Path()
        ..moveTo(size.width * 0.28, size.height * 0.52)
        ..lineTo(size.width * 0.45, size.height * 0.68)
        ..lineTo(size.width * 0.74, size.height * 0.36);
      final metric = path.computeMetrics().first;
      final local = ((progress - 0.05) / 0.95).clamp(0.0, 1.0);
      final drawn = metric.extractPath(0, metric.length * local);
      final check = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      canvas.drawPath(drawn, check);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
