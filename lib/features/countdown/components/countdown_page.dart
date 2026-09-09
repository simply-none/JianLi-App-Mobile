// 倒计时页（forui 化）—— 列表 + 新建弹层（时长/指定时刻两种模式）
//
// 对齐桌面端 countdown 页心智：大计时器展示最近的一个 running 计时，
// 列表卡片带进度环 + 暂停/恢复/重置/删除。
// forui 改造点：FScaffold+FHeader.nested 骨架、RingProgress 进度环、FButton.icon 行内
// 操作、showFSheet 新建弹层（FButton 模式切换 + FTextField）；计时与仓储调用原样保留。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ring_progress.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/countdown_repository.dart';

/// 倒计时页
class CountdownPage extends ConsumerStatefulWidget {
  const CountdownPage({super.key});

  @override
  ConsumerState<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends ConsumerState<CountdownPage> {
  Timer? _ticker;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    // 每秒刷新（基于 end_time 时间戳计算，与桌面端同构）
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 新建倒计时弹层（时长 / 指定时刻两种模式）
  Future<void> _showCreateSheet() async {
    final nameController = TextEditingController();
    final minutesController = TextEditingController(text: '10');
    final mode = ValueNotifier<String>('duration');

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: mode,
        builder: (context, modeValue, _) => SheetSurface(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 模式切换（滑块分段，选中态下方渐变指示块）
              JianliSegmented(
                items: const [(null, '倒计时长'), (null, '到某时刻')],
                selected: modeValue == 'duration' ? 0 : 1,
                onSelect: (i) => mode.value = i == 0 ? 'duration' : 'datetime',
              ),
              const SizedBox(height: 12),
              FTextField(
                control: FTextFieldControl.managed(controller: nameController),
                label: const Text('名称'),
                hint: '给这个倒计时起个名字',
              ),
              const SizedBox(height: 12),
              // 时长模式：分钟；到时刻模式：简化为「再过 N 分钟到达」的具体时刻选择器 TODO(P2)
              FTextField(
                control: FTextFieldControl.managed(
                  controller: minutesController,
                ),
                label: Text(modeValue == 'duration' ? '时长（分钟）' : '距离目标时刻（分钟）'),
                hint: '10',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FButton(
                onPress: () {
                  final minutes = int.tryParse(minutesController.text) ?? 10;
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  ref
                      .read(countdownRepositoryProvider)
                      .create(
                        name: nameController.text.trim().isEmpty
                            ? '倒计时'
                            : nameController.text.trim(),
                        mode: modeValue,
                        endMs: nowMs + minutes * 60 * 1000,
                        durationMs: minutes * 60 * 1000,
                      );
                  Navigator.pop(context);
                },
                child: const Text('开始'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(countdownListProvider);
    final rows = listAsync.value ?? const <CountdownData>[];
    // 大计时器：最临近结束的 running 项
    CountdownData? active;
    for (final r in rows) {
      if (r.status == 'running' &&
          (active == null || (r.endTime ?? 0) < (active.endTime ?? 0))) {
        active = r;
      }
    }

    return FScaffold(
      header: FHeader.nested(
        title: const Text('倒计时'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        // 右上角「新建」入口（替代原 FloatingActionButton.extended）
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.alarmClockPlus),
            onPress: _showCreateSheet,
            semanticsLabel: '新建倒计时',
          ),
        ],
      ),
      child: rows.isEmpty
          ? const EmptyState(
              icon: FLucideIcons.hourglass,
              title: '暂无倒计时',
              subtitle: '点击右上角新建一个',
            )
          : ColoredBox(
              color: AppTokens.pageTint(context),
              child: ListView(
                padding: EdgeInsets.only(
                  top: AppTokens.listTopGapOf(context),
                  bottom: AppTokens.pageBottomGapOf(context),
                ),
                children: [
                  if (active != null) _buildActiveTimer(active),
                  const SectionHeader(title: '全部'),
                  for (final row in rows)
                    _CountdownCard(
                      row: row,
                      nowMs: _nowMs,
                      isCurrent: row.key == active?.key,
                    ),
                ],
              ),
            ),
    );
  }

  /// 顶部大计时器：专属紫渐变英雄卡（装饰圆 + 白色进度环 + 白字大时间），
  /// 与效率分组页「倒计时」入口色对齐
  Widget _buildActiveTimer(CountdownData active) {
    final t = context.theme;
    final total = active.duration ?? 1;
    final remaining = ((active.endTime ?? 0) - _nowMs).clamp(0, total);
    final progress = total <= 0 ? 0.0 : 1 - remaining / total;
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        4,
        AppTokens.pagePadding,
        8,
      ),
      decoration: BoxDecoration(
        gradient: AppTokens.accentGradient(AppTokens.accent(0)),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: AppTokens.elevation(context, level: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: Stack(
          children: [
            Positioned(right: -30, top: -30, child: _decoCircle(100, 0.12)),
            Positioned(right: 48, bottom: -40, child: _decoCircle(80, 0.10)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SquircleBox(
                        size: 34,
                        radius: 11,
                        color: Colors.white.withValues(alpha: 0.22),
                        alignment: Alignment.center,
                        child: const Icon(
                          FLucideIcons.hourglass,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        active.name ?? '倒计时',
                        style: t.typography.body.md.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RingProgress(
                    progress: progress,
                    size: 190,
                    strokeWidth: 9,
                    color: Colors.white,
                    trackColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      _format(remaining),
                      style: t.typography.body.lg.copyWith(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '进行中 · 到点自动提醒',
                    style: t.typography.body.xs.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
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

  /// 渐变底上的白色装饰圆（同首页英雄卡）
  Widget _decoCircle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  String _format(int ms) {
    final s = (ms / 1000).ceil();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

/// 倒计时卡片（列表行：进度环 + 名称/剩余 + 暂停/重置/删除）
class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({
    required this.row,
    required this.nowMs,
    this.isCurrent = false,
  });

  final CountdownData row;
  final int nowMs;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(countdownRepositoryProvider);
    final t = context.theme;
    final running = row.status == 'running';
    final remaining = row.status == 'paused'
        ? (row.pausedRemaining ?? 0)
        : ((row.endTime ?? 0) - nowMs);
    final total = (row.duration ?? 1).clamp(1, 1 << 31);
    final progress = row.status == 'finished'
        ? 1.0
        : (1 - remaining.clamp(0, total) / total).clamp(0.0, 1.0);

    final s = (remaining / 1000).ceil();
    final label = row.status == 'finished'
        ? '已完成'
        : running || row.status == 'paused'
        ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'
        : row.status ?? '';

    return AppCard(
      onTap: isCurrent ? null : () {},
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: RingProgress(
              progress: progress,
              size: 44,
              strokeWidth: 4,
              child: Icon(
                row.status == 'finished'
                    ? FLucideIcons.circleCheck
                    : FLucideIcons.hourglass,
                size: 18,
                color: t.colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name ?? '倒计时',
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          // 暂停 / 继续（已结束禁用）
          FButton.icon(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.sm,
            onPress: row.status == 'finished'
                ? null
                : () => running ? repo.pause(row) : repo.resume(row),
            semanticsLabel: running ? '暂停' : '继续',
            child: Icon(
              running ? FLucideIcons.pause : FLucideIcons.play,
              size: 18,
              color: t.colors.primary,
            ),
          ),
          // 重置
          FButton.icon(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.sm,
            onPress: () => repo.reset(row),
            semanticsLabel: '重置',
            child: Icon(
              FLucideIcons.rotateCcw,
              size: 18,
              color: t.colors.mutedForeground,
            ),
          ),
          // 删除
          FButton.icon(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.sm,
            onPress: () => repo.delete(row.key),
            semanticsLabel: '删除',
            child: Icon(
              FLucideIcons.trash2,
              size: 18,
              color: t.colors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}
