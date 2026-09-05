// 番茄钟记录页 —— 统计头（今日/本周/累计）+ 流水列表
//
// 对齐桌面端 pomodoroRecord 页面（列表视图为主；图表视图列 P2）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/pomodoro_records_repository.dart';

/// 番茄钟记录页
class PomodoroRecordsPage extends ConsumerStatefulWidget {
  const PomodoroRecordsPage({super.key});

  @override
  ConsumerState<PomodoroRecordsPage> createState() => _PomodoroRecordsPageState();
}

class _PomodoroRecordsPageState extends ConsumerState<PomodoroRecordsPage> {
  Future<PomodoroStats>? _stats;

  @override
  void initState() {
    super.initState();
    _stats = ref.read(appDatabaseProvider).loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('番茄钟记录')),
      body: FutureBuilder<PomodoroStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          return Column(
            children: [
              if (stats != null)
                Card(
                  margin: const EdgeInsets.all(12),
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StatBlock(
                          value: '${stats.todayWorkCount}',
                          label: '今日专注',
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        StatBlock(
                          value: '${stats.weekWorkCount}',
                          label: '近 7 天',
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        StatBlock(
                          value: '${stats.totalCount}',
                          label: '累计记录',
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              const SectionHeader(title: '最近记录'),
              Expanded(
                child: StreamBuilder<List<PomodoroStatusData>>(
                  stream: db.watchRecords(),
                  builder: (context, snap) {
                    final records = snap.data ?? const [];
                    if (records.isEmpty) {
                      return const EmptyState(
                        icon: Icons.history,
                        title: '暂无记录',
                      );
                    }
                    return ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, i) {
                        final r = records[i];
                        return ListTile(
                          leading: Icon(
                            r.value == 'work'
                                ? Icons.work_history
                                : Icons.self_improvement,
                            color: r.value == 'work'
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.tertiary,
                          ),
                          title: Text(r.label ?? r.value ?? '-'),
                          subtitle: Text(r.createTime ?? ''),
                          trailing: Text(r.mode ?? ''),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
