// 电子书解析服务 —— epubx 解析 EPUB；TXT 分章
//
// epubx 4.x 字段为 PascalCase（EpubBook.Title / Chapters / ContentHtml 等）；
// 章节走 book.Chapters 树（Title + HtmlContent），比 spine/manifest 直取更稳。
// PDF 需原生渲染管线，TODO(P2)。
import 'dart:io';

import 'package:epubx/epubx.dart' as epub;

import '../repositories/ebook_repository.dart';

/// 解析 EPUB 文件为章节列表（目录树扁平化）
Future<ParsedBook> parseEpub(File file) async {
  final bytes = await file.readAsBytes();
  final book = await epub.EpubReader.readBook(bytes);

  final title = book.Title ?? '未命名书籍';
  final chapters = <BookChapter>[];

  void walk(List<epub.EpubChapter>? subs) {
    if (subs == null) return;
    for (final ch in subs) {
      final html = ch.HtmlContent;
      if (html != null && html.trim().isNotEmpty) {
        chapters.add(BookChapter(title: ch.Title ?? '第 ${chapters.length + 1} 节', html: html));
      }
      walk(ch.SubChapters);
    }
  }

  walk(book.Chapters);

  // 兜底：目录树无内容时退回全部 XHTML
  if (chapters.isEmpty) {
    final htmls = book.Content?.Html ?? const {};
    for (final c in htmls.values) {
      if (c.Content?.isNotEmpty ?? false) {
        chapters.add(BookChapter(title: c.FileName ?? '章节', html: c.Content!));
      }
    }
  }
  return ParsedBook(title: title, chapters: chapters);
}

/// 按扩展名解析（入口统一）
Future<ParsedBook> parseBook(String path) async {
  final file = File(path);
  if (path.toLowerCase().endsWith('.epub')) {
    return parseEpub(file);
  }
  final content = await file.readAsString();
  return ParsedBook(title: _fileName(path), chapters: splitTxtChapters(content));
}

String _fileName(String path) {
  final base = path.split(Platform.pathSeparator).last;
  final dot = base.lastIndexOf('.');
  return dot > 0 ? base.substring(0, dot) : base;
}
