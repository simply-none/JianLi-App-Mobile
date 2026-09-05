// 笔记列表项模型 —— 包装桌面端 note_book 行，完成 TEXT 字段到 Dart 类型的解析
//
// 桌面端 note_book 关键字段：excerpt（摘要）/ html（富文本）/ category（分类）/
// tags（JSON 数组文本）/ createTime、updateTime（yyyy-MM-dd HH:mm:ss 文本）。
import 'dart:convert';

import '../../../core/db/app_database.dart';

/// note_book 行的轻量包装（解耦 UI 与原始行，便于复用与测试）
class NoteItem {
  const NoteItem({
    required this.key,
    required this.title,
    required this.excerpt,
    required this.html,
    required this.content,
    required this.mdText,
    required this.category,
    required this.tags,
    required this.updateTime,
    required this.createTime,
  });

  /// 从 drift 生成行（NoteBookData）构造
  factory NoteItem.fromRow(NoteBookData row) {
    return NoteItem(
      key: row.key,
      title: _firstLine(row.excerpt) ?? '无标题笔记',
      excerpt: row.excerpt ?? '',
      html: row.html ?? '',
      content: row.content ?? '',
      mdText: row.mdText ?? '',
      category: row.category,
      tags: parseNoteTags(row.tags),
      updateTime: row.updateTime ?? '',
      createTime: row.createTime ?? '',
    );
  }

  final String key;
  final String title;
  final String excerpt;
  final String html;

  /// 桌面端原始正文列（mdText = markdown 纯文本；content = 纯文本），搜索用
  final String content;
  final String mdText;

  /// 分类（桌面端直接存文本，无独立分类表）
  final String? category;
  final List<String> tags;
  final String updateTime;
  final String createTime;

  /// 内容搜索文本（标题/摘要/正文/markdown/富文本合并小写；对齐 PC 端
  /// mdText/content/html/excerpt 四列 LIKE 的搜索范围）
  String get searchText => ('$excerpt\n$content\n$mdText\n$html').toLowerCase();

  /// 摘要首行作为标题
  static String? _firstLine(String? excerpt) {
    if (excerpt == null || excerpt.trim().isEmpty) return null;
    return excerpt.trim().split('\n').first.trim();
  }
}

/// 解析 note_book.tags 的 JSON 数组文本（非 JSON 或解析失败一律返回空列表）
List<String> parseNoteTags(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((e) => e.toString()).toList();
    return const [];
  } catch (_) {
    return const [];
  }
}
