// 待办导出 Markdown（D4）—— 把待办列表组稿为 Markdown 纯文本。
//
// 职责切分：本文件只做「纯文本组稿」，不碰 IO——落盘统一走
// lib/app/ui/file_export.dart 的 exportTextToDownloadDir（权限申请 / 写共享 Download /
// MediaStore 索引 / toast 提示全内聚），与习惯打卡、番茄钟记录导出同一条链路。
//
// 分组口径：参照 PC 的 dueGroup（已逾期 / 今天 / 明天 / 本周 / 更晚 / 无日期），
// 直接复用 todo_filter.dart 的 groupTodos(…, TodoGroupBy.due)，避免两端口径漂移。
import '../models/todo.dart';
import '../models/todo_filter.dart';

/// 生成待办 Markdown 文本。
///
/// [todos] 调用方通常已按「当前筛选 + 状态范围」裁剪（与用户所见一致）；
/// 若同时传 [filter]，会在此再筛一次作兜底。[tags] 用于把标签 key 解析成名称，
/// 缺省时标签段不渲染（导出里不直出 UUID）。
///
/// 结构：文件头（导出时间 + 总数）→ 按 dueGroup 分节 → 每条一行
/// （标题 + 状态中文 + 优先级 + 截止时间 + 标签名 + 子任务进度），有描述时缩进续行。
String buildTodoMarkdown(
  List<TodoItem> todos, {
  TodoFilterState? filter,
  List<TodoTagView> tags = const [],
}) {
  final items = filter == null
      ? List<TodoItem>.of(todos)
      : applyTodoFilters(todos, filter);
  final tagMap = {for (final tg in tags) tg.key: tg};

  String p2(int v) => v.toString().padLeft(2, '0');
  final now = DateTime.now();

  final buf = StringBuffer();
  buf.writeln('# 待办导出');
  buf.writeln();
  buf.writeln(
    '- 导出时间：${now.year}-${p2(now.month)}-${p2(now.day)} '
    '${p2(now.hour)}:${p2(now.minute)}:${p2(now.second)}',
  );
  buf.writeln('- 共 ${items.length} 项');
  buf.writeln();
  if (items.isEmpty) {
    buf.writeln('（无待办）');
    return buf.toString();
  }

  // 纯逻辑（无 context，出文本不走 UI）→ 按 #19 允许用常量版 statusMeta 取中文名
  final groups = groupTodos(items, TodoGroupBy.due);
  for (final group in groups) {
    final label = group.$1.isEmpty ? '待办' : group.$1;
    buf.writeln('## $label（${group.$2.length}）');
    buf.writeln();
    for (final it in group.$2) {
      buf.write('- ${it.title}（${statusMeta(effectiveStatus(it)).label}');
      buf.write(' · 优先级 ${priorityLabel(it.priority)}');
      // 截止时间写绝对日期（导出文件要脱离导出时刻可读，不用「今天/明天」相对口径）
      final due = parseTodoDateTime(it.dueDate);
      if (due != null) {
        buf.write(
          ' · 截止 ${due.year}-${p2(due.month)}-${p2(due.day)} '
          '${p2(due.hour)}:${p2(due.minute)}',
        );
      }
      final tagNames = [
        for (final k in it.tags)
          if (tagMap[k] != null) tagMap[k]!.name,
      ];
      if (tagNames.isNotEmpty) buf.write(' · 标签：${tagNames.join('、')}');
      // 子任务进度：以本次导出集合为全域（与用户所见一致）
      final progress = subtaskProgress(items, it.key);
      if (progress != null) {
        buf.write(' · 子任务 ${progress.done}/${progress.total}');
      }
      buf.writeln('）');
      final desc = it.description.trim();
      if (desc.isNotEmpty) {
        // 描述缩进两格续行，保持条目归属
        for (final line in desc.split('\n')) {
          buf.writeln('  $line');
        }
      }
    }
    buf.writeln();
  }
  return buf.toString();
}
