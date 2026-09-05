// 番茄钟记录页（forui 化）—— 统计头（今日/本周/累计）+ 流水列表
//
// 对齐桌面端 pomodoroRecord 页面（列表视图为主；图表视图列 P2）。
// forui 改造点：FScaffold+FHeader.nested 骨架、AppCard 统计/流水行、token 取色排版；
// FutureBuilder/StreamBuilder 数据流原样保留。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
    final t = context.theme;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('番茄钟记录'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: FutureBuilder<PomodoroStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          return Column(
            children: [
              if (stats != null)
                // 统计横幅：primary 底色 + 前景色数字（对齐首页概览卡视觉）
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: t.colors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatBlock(
                        value: '${stats.todayWorkCount}',
                        label: '今日专注',
                        color: t.colors.primaryForeground,
                      ),
                      StatBlock(
                        value: '${stats.weekWorkCount}',
                        label: '近 7 天',
                        color: t.colors.primaryForeground,
                      ),
                      StatBlock(
                        value: '${stats.totalCount}',
                        label: '累计记录',
                        color: t.colors.primaryForeground,
                      ),
                    ],
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
                        icon: FLucideIcons.history,
                        title: '暂无记录',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 24),
                      itemCount: records.length,
                      itemBuilder: (context, i) {
                        final r = records[i];
                        return _RecordTile(
                          record: r,
                          isWork: r.value == 'work',
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

/// 单条流水行（工作 / 休息）
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.isWork});

  final PomodoroStatusData record;
  final bool isWork;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            isWork ? FLucideIcons.briefcase : FLucideIcons.coffee,
            color: isWork ? t.colors.primary : t.colors.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.label ?? record.value ?? '-',
                  style: t.typography.body.md.copyWith(fontWeight: FontWeight.w600),
                ),
                if (record.createTime?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.createTime ?? '',
                    style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
          if (record.mode?.isNotEmpty ?? false)
            Text(
              record.mode ?? '',
              style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
            ),
        ],
      ),
    );
  }
}
