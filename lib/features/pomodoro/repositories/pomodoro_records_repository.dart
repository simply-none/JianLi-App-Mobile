// 番茄钟记录统计 —— 对齐桌面端 pomodoroRecord 页（列表 + 今日/本周统计）
import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

/// 今日 / 本周聚合结果
class PomodoroStats {
  const PomodoroStats({
    required this.todayWorkCount,
    required this.weekWorkCount,
    required this.totalCount,
  });

  final int todayWorkCount;
  final int weekWorkCount;
  final int totalCount;
}

extension PomodoroRecordsQuery on AppDatabase {
  /// 记录流水流（最新在前，默认 200 条）
  Stream<List<PomodoroStatusData>> watchRecords({int limit = 200}) {
    return (select(pomodoroStatus)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  /// 今日 / 本周 工作时段统计（value='work'）
  Future<PomodoroStats> loadStats() async {
    final now = DateTime.now();
    final todayPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekPrefix =
        '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';

    final total = await countWhere(value: 'work');
    final today = await countWhere(
      value: 'work',
      createTimePrefix: todayPrefix,
    );
    final week = await countWhere(
      value: 'work',
      createTimeFromPrefix: weekPrefix,
      createTimeToPrefix: todayPrefix,
    );
    return PomodoroStats(
      todayWorkCount: today,
      weekWorkCount: week,
      totalCount: total,
    );
  }

  /// 按条件计数（create_time 为 'yyyy-MM-dd HH:mm:ss' 文本，用前缀匹配）
  Future<int> countWhere({
    String? value,
    String? createTimePrefix,
    String? createTimeFromPrefix,
    String? createTimeToPrefix,
  }) {
    final query = selectOnly(pomodoroStatus)
      ..addColumns([pomodoroStatus.id.count()]);
    if (value != null) {
      query.where(pomodoroStatus.value.equals(value));
    }
    if (createTimePrefix != null) {
      query.where(pomodoroStatus.createTime.like('$createTimePrefix%'));
    }
    final conds = <Expression<bool>>[];
    if (createTimeFromPrefix != null) {
      conds.add(
        pomodoroStatus.createTime.isBiggerOrEqualValue(createTimeFromPrefix),
      );
    }
    if (createTimeToPrefix != null) {
      // 含今日当天：以日期前缀上界（<'明日'）近似
      final parts = createTimeToPrefix.split('-').map(int.parse).toList();
      final tomorrow = DateTime(parts[0], parts[1], parts[2] + 1);
      final tomorrowStr =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      conds.add(pomodoroStatus.createTime.isSmallerThanValue(tomorrowStr));
    }
    if (conds.isNotEmpty) {
      query.where(conds.reduce((a, b) => a & b));
    }
    return query.getSingle().then(
      (row) => row.read(pomodoroStatus.id.count()) ?? 0,
    );
  }
}
