// 列表入场 stagger（UI 现代化 Phase 1）
//
// 子项依次淡入 + 上滑，形成「逐条浮现」的入场节奏。每项自带 AnimationController，
// 挂载后按 index 延迟启动；减弱动效时直出。约束：import material_ui。
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_motion.dart';
import '../theme/app_theme.dart';

/// 入场 stagger 列表包装
class StaggerList extends StatelessWidget {
  const StaggerList({
    super.key,
    required this.children,
    this.delayStep = 40,
    this.offset = 8,
    this.direction = Axis.vertical,
    this.padding,
  });

  final List<Widget> children;
  final double delayStep;
  final double offset;
  final Axis direction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < children.length; i++)
        _StaggerItem(
          delay: Duration(milliseconds: (delayStep * i).round()),
          offset: offset,
          child: children[i],
        ),
    ];
    return direction == Axis.vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          )
        : Row(children: items);
  }
}

class _StaggerItem extends StatefulWidget {
  const _StaggerItem({
    required this.delay,
    required this.offset,
    required this.child,
  });

  final Duration delay;
  final double offset;
  final Widget child;

  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppTokens.base,
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: AppTokens.standard,
  );
  bool _started = false;

  // 注意：不能在 initState 里读 MediaQuery（JianliMotion.enabled 内部依赖它，
  // initState 禁止 dependOnInheritedWidget）→ 统一放 didChangeDependencies，守卫只跑一次。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!JianliMotion.enabled(context)) {
      _ctrl.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, widget.offset),
        end: Offset.zero,
      ).animate(_anim),
      child: widget.child,
    ),
  );
}
