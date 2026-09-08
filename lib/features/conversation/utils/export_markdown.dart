// 主题对话 - 导出 Markdown 工具（对齐桌面端 utils/exportMarkdown.ts）
//
// 把指定主题（含其下全部对话）导出为 .md 文本：
// - 富文本（is_rich='1'）内容经轻量 HTML→Markdown 转换；纯文本原样保留换行。
// - 主题 / 消息标签经 tagById（conversation_tag id→名称）解析为彩色徽标文字。
// - 纯函数：data 由仓储层取好后传入，本文件不碰数据库，便于单测与复用。
//
// 对外：
//   buildThemeMarkdown(theme, messages, tagById)      单主题 Markdown
//   buildThemesMarkdown(themes, messagesByTheme, tagById)  多主题合并（单 .md）
import 'dart:convert';

import '../../../core/db/app_database.dart';

/// 解码常见 HTML 实体
String _decodeEntities(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');

/// 轻量 HTML → Markdown（覆盖 vue-quill 常见输出：标题/列表/引用/加粗/斜体/代码/链接/换行）
String htmlToMarkdown(String? html) {
  if (html == null || html.isEmpty) return '';
  var s = _decodeEntities(html);
  // 标题：<h1>..</h1> → # ..\n
  s = s.replaceAllMapped(RegExp(r'<(h[1-6])[^>]*>', caseSensitive: false), (m) {
    final level = int.tryParse(m.group(1)![1]) ?? 1;
    return '\n${'#' * level} ';
  });
  s = s.replaceAllMapped(RegExp(r'</(h[1-6])>', caseSensitive: false), (_) => '\n');
  // 列表
  s = s.replaceAll(RegExp(r'<(ul|ol)[^>]*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ');
  // 引用
  s = s.replaceAll(RegExp(r'<blockquote[^>]*>', caseSensitive: false), '\n> ');
  // 块级结尾 / 换行 → 换行
  s = s.replaceAllMapped(
    RegExp(r'</(p|div|li|h[1-6]|blockquote|pre|tr)>', caseSensitive: false),
    (_) => '\n',
  );
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  // 行内格式
  s = s.replaceAllMapped(RegExp(r'<(strong|b)[^>]*>', caseSensitive: false), (_) => '**');
  s = s.replaceAll(RegExp(r'</(strong|b)>', caseSensitive: false), '**');
  s = s.replaceAllMapped(RegExp(r'<(em|i)[^>]*>', caseSensitive: false), (_) => '*');
  s = s.replaceAll(RegExp(r'</(em|i)>', caseSensitive: false), '*');
  s = s.replaceAll(RegExp(r'<code[^>]*>', caseSensitive: false), '`');
  s = s.replaceAll('</code>', '`');
  // 链接：<a href="url">text</a> → [text](url)
  s = s.replaceAllMapped(
    RegExp(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>', caseSensitive: false),
    (m) => '[${m.group(2)}](${m.group(1)})',
  );
  // 清理剩余标签
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  // 换行压缩
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return s;
}

/// 解析 tags / ref_ids 等 JSON 字符串数组（异常返回空）
List<String> _tagIdsOf(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final v = jsonDecode(raw);
    return [if (v is List) for (final e in v) e.toString()];
  } catch (_) {
    return const [];
  }
}

/// 解析跨主题引用 JSON（[{themeId, convId}]）数量
int _crossCount(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  try {
    final v = jsonDecode(raw);
    return v is List ? v.length : 0;
  } catch (_) {
    return 0;
  }
}

/// 单条对话 → Markdown 片段
String _conversationToMd(
  ConversationData m,
  Map<String, ConversationTagData> tagById,
) {
  final content = m.isRich == '1'
      ? htmlToMarkdown(m.content)
      : (m.content ?? '').trim();
  final meta = <String>[];
  if ((m.annotateTime ?? '').isNotEmpty) meta.add('标注 ${m.annotateTime}');
  final tagNames = _tagIdsOf(m.tags)
      .map((id) => tagById[id]?.name ?? '')
      .where((n) => n.isNotEmpty)
      .toList();
  if (tagNames.isNotEmpty) meta.add('标签 ${tagNames.join('、')}');
  final refCount = _tagIdsOf(m.refIds).length;
  if (refCount > 0) meta.add('引用 $refCount 条');
  final cross = _crossCount(m.crossRefs);
  if (cross > 0) meta.add('跨主题 $cross 条');

  final parts = [
    '### 对话 · ${m.createTime ?? ''}',
    '',
    content.isEmpty ? '(空对话)' : content,
  ];
  if (meta.isNotEmpty) parts.addAll(['', '> ${meta.join(' ｜ ')}']);
  return parts.join('\n');
}

/// 单个主题 → Markdown（标题头 + 全部对话）
String buildThemeMarkdown(
  ConversationThemeData theme,
  List<ConversationData> messages,
  Map<String, ConversationTagData> tagById,
) {
  final themeTagNames = _tagIdsOf(theme.tags)
      .map((id) => tagById[id]?.name ?? '')
      .where((n) => n.isNotEmpty)
      .toList();
  final head = <String>[];
  if ((theme.createTime ?? '').isNotEmpty) {
    head.add('创建时间：${theme.createTime}');
  }
  if ((theme.updateTime ?? '').isNotEmpty) {
    head.add('更新时间：${theme.updateTime}');
  }
  if (themeTagNames.isNotEmpty) head.add('主题标签：${themeTagNames.join('、')}');
  head.add('对话数：${messages.length}');

  final lines = [
    '# ${theme.title ?? '未命名主题'}',
    '',
    head.join(' ｜ '),
    '',
    '---',
    '',
  ];
  if (messages.isEmpty) {
    lines.add('（该主题暂无对话）');
  } else {
    for (var i = 0; i < messages.length; i++) {
      lines.add(_conversationToMd(messages[i], tagById));
      if (i < messages.length - 1) lines.add('');
      lines.add('---');
    }
  }
  return lines.join('\n');
}

/// 批量导出多个主题：合并为单个 .md 文本，各主题以 `#` 大标题分隔。
String buildThemesMarkdown(
  List<ConversationThemeData> themes,
  Map<int, List<ConversationData>> messagesByTheme,
  Map<String, ConversationTagData> tagById,
) {
  final blocks = <String>[
    for (final theme in themes)
      buildThemeMarkdown(theme, messagesByTheme[theme.id] ?? const [], tagById),
  ];
  return blocks.join('\n\n---\n\n');
}
