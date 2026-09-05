// 完成庆祝彩带（UI 现代化 Phase 1，自实现，不引 confetti 包）
//
// 覆盖层：彩色碎片自顶部下落 + 旋转 + 末尾淡出，播完回调 onDone。减弱动效时
// 退化为零时长（几乎不可见）。约束：import material_ui；随机用 dart:math。
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 庆祝彩带覆盖层（一次性播放）
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.onDone,
    this.duration = AppTokens.slow,
    this.count = 28,
  });

  final VoidCallback? onDone;
  final Duration duration;
  final int count;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppTokens.slow,
  );
  final _rng = Random();
  late final List<_Piece> _pieces = List.generate(
    widget.count,
    (_) => _Piece(_rng),
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 不在这里读 context：_ctrl.duration 依赖 JianliMotion.duration（内部读 MediaQuery），
    // initState 禁止 dependOnInheritedWidget → 放 didChangeDependencies。
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _ctrl.duration = JianliMotion.duration(context, widget.duration);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, animation) => LayoutBuilder(
      builder: (c, constraints) {
        final h = constraints.maxHeight;
        final prog = _ctrl.value;
        return Stack(
          children: _pieces.map((p) {
            final top = prog * (h + 40) - 20;
            final left = p.x * constraints.maxWidth;
            final opacity = (prog < 0.85 ? 1.0 : (1 - (prog - 0.85) / 0.15))
                .clamp(0.0, 1.0);
            return Positioned(
              top: top,
              left: left,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: p.rot * prog * 6.28,
                  child: Container(
                    width: p.w,
                    height: p.h * 1.6,
                    decoration: BoxDecoration(
                      color: p.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

class _Piece {
  _Piece(Random r)
    : x = r.nextDouble(),
      w = 6 + r.nextDouble() * 6,
      h = 8 + r.nextDouble() * 8,
      rot = r.nextDouble() * 2 - 1,
      color = const [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.pink,
      ][r.nextInt(6)];
  final double x;
  final double w;
  final double h;
  final double rot;
  final Color color;
}
