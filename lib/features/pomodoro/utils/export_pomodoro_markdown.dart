// 番茄钟 - 导出 Markdown 工具（纯函数，不碰数据库，便于复用与单测）
//
// 导出格式：`.md`。头 = 标题 + 导出时间 + 计数（专注/休息）；正文 = 逐条流水
// （`- yyyy-MM-dd HH:mm:ss ｜ 专注/休息`，最近在前；入参顺序即输出顺序）。
//
// 对外：buildPomodoroMarkdown(records, {exportedAt})
import '../../../core/db/app_database.dart';

/// 单条流水的展示标签：work=专注 / rest=休息 / 其余回退库内 label 或 value
String pomodoroRecordLabel(PomodoroStatusData r) {
  return switch (r.value) {
    'work' => '专注',
    'rest' => '休息',
    _ => (r.label?.isNotEmpty ?? false)
        ? r.label!
        : (r.value?.isNotEmpty ?? false)
        ? r.value!
        : '记录',
  };
}

/// 多条流水 → 单个 `.md` 文本。
///
/// [records] 顺序即输出顺序（调用方已按时间倒序取回）。
/// [exportedAt] 导出时间戳（缺省取当前）。
String buildPomodoroMarkdown(
  List<PomodoroStatusData> records, {
  String? exportedAt,
}) {
  final stamp = exportedAt ?? _timestamp();
  final work = records.where((r) => r.value == 'work').length;
  final rest = records.where((r) => r.value == 'rest').length;
  final lines = <String>[
    '# 番茄钟记录导出',
    '',
    '导出时间：$stamp ｜ 共 ${records.length} 条（专注 $work ｜ 休息 $rest）',
  ];
  if (records.isEmpty) {
    lines
      ..add('')
      ..add('（暂无记录）');
  } else {
    for (final r in records) {
      lines.add('');
      lines.add('- ${r.createTime ?? ''} ｜ ${pomodoroRecordLabel(r)}');
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
