// 习惯 - 导出 Markdown 工具（纯函数，不碰数据库，便于复用与单测）
//
// 导出格式：`.md`。每个习惯：`## 名称` + 引用元信息行（频次 / 生效星期 / 提醒 / 累计打卡）
// + 打卡记录列表（`- yyyy-MM-dd HH:mm:ss`，最近在前）。
//
// 对外：
//   habitWeekLabel(weekDays)                   生效星期中文（空 = 每天）
//   buildHabitsMarkdown(habits, checkinsByKey) 多习惯合并为单个 .md
import '../../../core/db/app_database.dart';
import '../models/habit.dart';

/// Dart weekday 中文名（Monday=1 … Sunday=7）
const List<String> _kWeekNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 生效星期展示：空 = 每天；否则按周一到周日排序后顿号连接。
String habitWeekLabel(List<int> weekDays) {
  if (weekDays.isEmpty) return '每天';
  final sorted = [...weekDays]..sort();
  return sorted
      .where((d) => d >= 1 && d <= 7)
      .map((d) => _kWeekNames[d - 1])
      .join('、');
}

/// 多习惯 → 单个 `.md` 文本。
///
/// [checkinsByKey] = habitKey → 该习惯的打卡记录（顺序不限，内部按日期+时间倒序，最近在前）。
/// [exportedAt] 导出时间戳（缺省取当前）。
String buildHabitsMarkdown(
  List<HabitItem> habits,
  Map<String, List<HabitCheckinData>> checkinsByKey, {
  String? exportedAt,
}) {
  final stamp = exportedAt ?? _timestamp();
  final lines = <String>[
    '# 习惯打卡导出',
    '',
    '导出时间：$stamp ｜ 共 ${habits.length} 个习惯',
  ];
  for (final h in habits) {
    final records = [
      ...(checkinsByKey[h.key] ?? const <HabitCheckinData>[]),
    ]..sort((a, b) {
      final da = '${a.date ?? ''} ${a.time ?? ''}';
      final db = '${b.date ?? ''} ${b.time ?? ''}';
      return db.compareTo(da); // 最近在前
    });
    lines.add('');
    lines.add('---');
    lines.add('');
    lines.add('## ${h.name}');
    lines.add('');
    lines.add(
      '> 频次：${h.freqLabel} ｜ 生效：${habitWeekLabel(h.weekDays)} ｜ '
      '提醒：${h.reminderTimes.isEmpty ? '无' : h.reminderTimes.join('、')} ｜ '
      '累计打卡：${records.length} 次',
    );
    lines.add('');
    if (records.isEmpty) {
      lines.add('（暂无打卡记录）');
    } else {
      for (final r in records) {
        final date = (r.date ?? '').trim();
        final time = (r.time ?? '').trim();
        lines.add('- $date${time.isEmpty ? '' : ' $time'}');
      }
    }
  }
  return '${lines.join('\n').trimRight()}\n';
}

/// 文件名时间戳：yyyyMMdd_HHmmss
String _timestamp() {
  final n = DateTime.now();
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
}
