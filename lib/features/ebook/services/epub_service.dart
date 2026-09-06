// 电子书解析服务 —— epubx 解析 EPUB；TXT 分章 + 编码检测
//
// epubx 4.x 字段为 PascalCase（EpubBook.Title / Chapters / ContentHtml 等）；
// 章节走 book.Chapters 树（Title + HtmlContent），比 spine/manifest 直取更稳。
// TXT 编码对齐桌面端 chardet + iconv-lite（BOM + UTF-8 严格 + GBK 回退）。
// PDF 需原生渲染管线，TODO(P2)。
import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart' as epub;
import 'package:fast_gbk/fast_gbk.dart' show gbk;

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
        chapters.add(
          BookChapter(
            title: ch.Title ?? '第 ${chapters.length + 1} 节',
            html: html,
          ),
        );
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
  final content = await _decodeTxt(file);
  return ParsedBook(
    title: _fileName(path),
    chapters: splitTxtChapters(content),
  );
}

/// TXT 解码 —— 对齐桌面端 chardet + iconv-lite 方案（references/modules/ebook-reader.md）：
/// BOM 识别（UTF-8 / UTF-16LE / UTF-16BE）→ UTF-8 严格解码 → 失败回退 GBK（中文 GB2312/GBK/GB18030）。
/// 移动端此前只按 UTF-8 读，中文 GBK TXT 全文乱码（实踩对齐点）。
Future<String> _decodeTxt(File file) async {
  final bytes = await file.readAsBytes();
  // UTF-8 BOM
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3));
  }
  // UTF-16 LE / BE BOM（BMP 字符直接按码元重组）
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16Decode(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16Decode(bytes.sublist(2), littleEndian: false);
  }
  // 无 BOM：先按 UTF-8 严格解码（含非法序列即失败），失败回退 GBK；
  // GBK 再失败兜底 utf8 宽松解码（fast_gbk 不声称支持 GB18030，防生僻字崩溃）
  try {
    return utf8.decode(bytes);
  } on FormatException {
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

String _utf16Decode(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

String _fileName(String path) {
  final base = path.split(Platform.pathSeparator).last;
  final dot = base.lastIndexOf('.');
  return dot > 0 ? base.substring(0, dot) : base;
}
