// 番茄钟页 —— 读取 reminders 状态机配置并展示当前阶段倒计时
//
// 第一批范围：只读展示（当前阶段/剩余时间/进度环）+ 手动记录流水按钮；
// 完整交互（启动/暂停/跳过/前台服务保活）列入 P2（iOS 后台受限，见 flutter-port.md §4）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/pomodoro_state_machine.dart';
import '../repositories/pomodoro_repository.dart';

/// 番茄钟页
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  PomodoroSnapshot? _snapshot;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // initState 里不能 read provider，首次加载放到首帧后（见 build 前 didChangeDependencies）
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    // 每秒重算快照（基于 startTime 的纯函数，无副作用）
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _reload());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    try {
      final snapshot = await repo.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// 手动记一条流水（演示写路径；自动化记录随 P2 完整交互接入）
  Future<void> _record() async {
    final snapshot = _snapshot;
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    await repo.recordStatus(
      label: snapshot?.currentState.label ?? '手动记录',
      value: snapshot?.currentState.key ?? 'work',
      mode: 'mobile',
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已写入番茄钟流水')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('番茄钟')),
      floatingActionButton: snapshot == null
          ? null
          : FloatingActionButton(
              onPressed: _record,
              child: const Icon(Icons.timer),
            ),
      body: Center(
        child: snapshot == null
            ? Text(
                _error ?? '未找到番茄钟配置（reminders.id=pomodoro）\n先在桌面端启用番茄钟并同步数据',
                textAlign: TextAlign.center,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    snapshot.currentState.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: snapshot.progress,
                          strokeWidth: 10,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                        Center(
                          child: Text(
                            _formatSeconds(snapshot.remainingSeconds),
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '周期 ${snapshot.cycleSeconds ~/ 60} 分钟 · 完成后自动进入下一阶段',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
