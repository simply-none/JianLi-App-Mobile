// 倒计时页 —— 列表 + 新建弹层（时长/指定时刻两种模式）
//
// 对齐桌面端 countdown 页心智：大计时器展示最近的一个 running 计时，
// 列表卡片带进度环 + 暂停/恢复/重置/删除。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/ring_progress.dart';
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
      if (mounted) setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _showCreateSheet() async {
    final nameController = TextEditingController();
    final minutesController = TextEditingController(text: '10');
    final mode = ValueNotifier<String>('duration');

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: mode,
        builder: (context, modeValue, _) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'duration', label: Text('倒计时长')),
                  ButtonSegment(value: 'datetime', label: Text('到某时刻')),
                ],
                selected: {modeValue},
                onSelectionChanged: (s) => mode.value = s.first,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              // 时长模式：分钟；到时刻模式：简化为「再过 N 分钟到达」的具体时刻选择器 TODO(P2)
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: modeValue == 'duration' ? '时长（分钟）' : '距离目标时刻（分钟）',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final minutes = int.tryParse(minutesController.text) ?? 10;
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  ref.read(countdownRepositoryProvider).create(
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
      if (r.status == 'running' && (active == null || (r.endTime ?? 0) < (active.endTime ?? 0))) {
        active = r;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('倒计时')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add_alarm),
        label: const Text('新建'),
      ),
      body: rows.isEmpty
          ? const EmptyState(
              icon: Icons.hourglass_empty,
              title: '暂无倒计时',
              subtitle: '点击右下角新建一个',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
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
    );
  }

  /// 顶部大计时器（进度环 + 大数字）
  Widget _buildActiveTimer(CountdownData active) {
    final total = active.duration ?? 1;
    final remaining = ((active.endTime ?? 0) - _nowMs).clamp(0, total);
    final progress = total <= 0 ? 0.0 : 1 - remaining / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(active.name ?? '倒计时', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          RingProgress(
            progress: progress,
            size: 210,
            child: Text(
              _format(remaining),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }

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

/// 倒计时卡片（列表行）
class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({required this.row, required this.nowMs, this.isCurrent = false});

  final CountdownData row;
  final int nowMs;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(countdownRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
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
                row.status == 'finished' ? Icons.check : Icons.hourglass_top,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name ?? '倒计时', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: running ? '暂停' : '继续',
            icon: Icon(running ? Icons.pause_circle_outline : Icons.play_circle_outline),
            onPressed: row.status == 'finished'
                ? null
                : () => running ? repo.pause(row) : repo.resume(row),
          ),
          IconButton(
            tooltip: '重置',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => repo.reset(row),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => repo.delete(row.key),
          ),
        ],
      ),
    );
  }
}
