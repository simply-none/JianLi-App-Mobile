// 番茄钟页（forui 化）—— 读取 reminders 状态机配置并展示当前阶段倒计时
//
// 第一批范围：只读展示（当前阶段/剩余时间/进度环）+ 手动记录流水按钮；
// 完整交互（启动/暂停/跳过/前台服务保活）列入 P2（iOS 后台受限，见 flutter-port.md §4）。
// forui 改造点：FScaffold+FHeader.nested 骨架、RingProgress 进度环、token 排版、
// showFToast 替代 SnackBar；计时/快照业务逻辑原样保留。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/ring_progress.dart';
import '../../../app/ui/ui_atoms.dart';
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
      // forui 化：SnackBar → FToast
      showFToast(context: context, title: const Text('已写入番茄钟流水'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final snapshot = _snapshot;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('番茄钟'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        // 有配置时右上角提供「手动记录」入口（替代原 FloatingActionButton）
        suffixes: [
          if (snapshot != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.timer),
              onPress: _record,
              semanticsLabel: '手动记录流水',
            ),
        ],
      ),
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: snapshot == null
            ? Center(
                child: EmptyState(
                  icon: FLucideIcons.timer,
                  title: _error ?? '未找到番茄钟配置（reminders.id=pomodoro）',
                  subtitle: '先在桌面端启用番茄钟并同步数据',
                ),
              )
            : ListView(
                padding: EdgeInsets.only(
                  top: AppTokens.listTopGapOf(context),
                  bottom: AppTokens.pageBottomGapOf(context),
                ),
                children: [
                  // 页面专属红渐变横幅：当前阶段 + 剩余时间（与效率分组页「番茄钟」入口色对齐）
                  PageBanner(
                    icon: FLucideIcons.timer,
                    title: snapshot.currentState.label,
                    subtitle: '周期 ${snapshot.cycleSeconds ~/ 60} 分钟',
                    accentIndex: 6,
                    stats: [
                      (_formatSeconds(snapshot.remainingSeconds), '本阶段剩余'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 阶段进度环（白卡承托，避免渐变上叠渐变）
                  AppCard(
                    margin: EdgeInsets.fromLTRB(
                      AppTokens.pagePaddingOf(context),
                      8,
                      AppTokens.pagePaddingOf(context),
                      8,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        RingProgress(
                          progress: snapshot.progress,
                          size: 200,
                          strokeWidth: 10,
                          color: AppTokens.accent(6),
                          child: Text(
                            _formatSeconds(snapshot.remainingSeconds),
                            style: t.typography.body.lg.copyWith(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '完成后自动进入下一阶段',
                          style: t.typography.body.sm.copyWith(
                            color: t.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
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
