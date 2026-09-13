// 笔记 - 导出 Markdown 工具（纯函数，不碰数据库，便于复用与单测）
//
// 导出格式：`.md`。**正文若带 HTML 标签（note.html 富文本），一律转为纯文本**（用户定案）：
// 只保留文字与换行，不保留加粗/标题等 Markdown 标记 —— 因为详情页用 flutter_widget_from_html
// 渲染的就是 note.html，导出时需把它拍平成可读纯文本。
//
// 对外：
//   htmlToPlainText(html)                     富文本 HTML → 纯文本
//   buildNotesMarkdown(notes, tagNameByKey)   多篇笔记合并为单个 .md
import '../models/note_item.dart';

/// 解码常见 HTML 实体
String _decodeEntities(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');

/// 富文本 HTML → **纯文本**（仅保留文字 + 换行，不做任何 Markdown 标记）。
/// 覆盖 vue-quill 常见输出：块级标签 / `<br>` → 换行，其余标签一律剥离，实体解码。
String htmlToPlainText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  var s = _decodeEntities(html);
  // 块级结尾 → 换行
  s = s.replaceAllMapped(
    RegExp(r'</(p|div|li|h[1-6]|blockquote|pre|tr)>', caseSensitive: false),
    (_) => '\n',
  );
  // 列表项前补一个换行，避免「项目 1项目 2」粘连
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  // 剥离所有剩余标签
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  // 归一化：行尾空格、3+ 连续换行 → 2，去首尾
  s = s
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return s;
}

/// 单篇笔记正文纯文本：优先富文本 html（转纯文本）→ 纯文本 content → markdown mdText。
String _plainBody(NoteItem n) {
  if (n.html.trim().isNotEmpty) return htmlToPlainText(n.html);
  if (n.content.trim().isNotEmpty) return n.content.trim();
  return n.mdText.trim();
}

/// 多篇笔记 → 单个 `.md` 文本（各篇以 `##` 标题 + 元信息 + 正文分隔）。
///
/// [tagNameByKey] = 标签 key → 名称（note_tags 定义）；[exportedAt] 导出时间戳（缺省取当前）。
String buildNotesMarkdown(
  List<NoteItem> notes,
  Map<String, String> tagNameByKey, {
  String? exportedAt,
}) {
  final stamp = exportedAt ?? _timestamp();
  final lines = <String>[
    '# 笔记导出',
    '',
    '导出时间：$stamp ｜ 共 ${notes.length} 篇',
  ];
  for (final n in notes) {
    lines.add('');
    lines.add('---');
    lines.add('');
    lines.add('## ${n.title}');
    final meta = <String>[];
    if (n.categories.isNotEmpty) meta.add('分类：${n.categories.join('、')}');
    final tagNames = n.tags
        .map((k) => tagNameByKey[k] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (tagNames.isNotEmpty) meta.add('标签：${tagNames.join('、')}');
    if (n.updateTime.isNotEmpty) meta.add('更新：${n.updateTime}');
    if (meta.isNotEmpty) {
      lines.add('');
      lines.add('> ${meta.join(' ｜ ')}');
    }
    lines.add('');
    final body = _plainBody(n);
    lines.add(body.isEmpty ? '（空笔记）' : body);
  }
  return '${lines.join('\n').trimRight()}\n';
}

/// 文件名时间戳：yyyyMMdd_HHmmss
String _timestamp() {
  final n = DateTime.now();
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
}
