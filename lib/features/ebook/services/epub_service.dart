// 电子书解析服务 —— epubx 解析 EPUB；TXT 分章 + 编码检测
//
// epubx 4.x 字段为 PascalCase（EpubBook.Title / Chapters / ContentHtml 等）；
// 章节走 book.Chapters 树（Title + HtmlContent），比 spine/manifest 直取更稳。
// TXT 编码对齐桌面端 chardet + iconv-lite（BOM + UTF-8 严格 + GBK 回退）。
// PDF 需原生渲染管线，TODO(P2)。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:fast_gbk/fast_gbk.dart' show gbk;
import 'package:xml/xml.dart';

import '../repositories/ebook_repository.dart';

/// 解析 EPUB 文件为章节列表（目录树扁平化）
///
/// ⚠️ 不规范 EPUB 兼容（2026-09-09 修「EPUB parsing error: TOC item, not found in
/// EPUB manifest」）：epubx 4.x 的 `readBook` **和** `openBook` 都会经过
/// `NavigationReader` 解析 TOC/导航，而 EPUB3 分支要求 manifest 里存在
/// `properties="nav"` 的条目且为精确字符串相等——真实 EPUB 常见 nav 文档漏标该属性
/// （或写成 `properties="nav scripted"`），于是整本书打不开。
/// 对策：主路径保持 epubx 完整解析（能拿到目录树）；一旦失败，转 `_parseEpubWithoutToc`
/// ——**完全不经过 epubx**，自己解 zip：`container.xml → OPF → manifest(href) +
/// spine(idref) → 按阅读顺序取 XHTML 正文`，不碰 TOC，故不受该问题影响。
Future<ParsedBook> parseEpub(File file) async {
  final bytes = await file.readAsBytes();

  // ---- 主路径：epubx 完整解析（含 TOC 目录树）----
  try {
    final book = await epub.EpubReader.readBook(bytes);
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

    if (chapters.isNotEmpty) {
      return ParsedBook(title: book.Title ?? '未命名书籍', chapters: chapters);
    }
  } catch (_) {
    // TOC 解析失败（或文件结构异常）：落到下方宽容解析
  }

  // ---- 宽容解析：不解析 TOC，按 spine 顺序取章节 ----
  return _parseEpubWithoutToc(bytes);
}

/// 宽容 EPUB 解析 —— **完全绕过 epubx**，自己解 zip 按阅读顺序拼章节。
///
/// 触发场景：epubx 因 TOC/导航不规范而整体抛异常时。
/// 流程：container.xml → OPF 路径 → manifest(id→href) + spine(idref 顺序)
/// → 按阅读顺序取 XHTML 正文，跳过 nav/toc/cover 页。不碰 TOC，故不受该问题影响。
Future<ParsedBook> _parseEpubWithoutToc(List<int> bytes) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = <String, List<int>>{};
  for (final f in archive.files) {
    if (f.isFile) files[f.name] = f.content as List<int>;
  }

  // 1) container.xml → OPF 路径
  final containerBytes = files['META-INF/container.xml'];
  if (containerBytes == null) {
    throw Exception('不是有效的 EPUB：缺少 META-INF/container.xml');
  }
  final container = XmlDocument.parse(_decodeBytes(containerBytes));
  String? opfPath;
  for (final el in container.findAllElements('rootfile')) {
    final fp = el.getAttribute('full-path');
    if (fp != null && fp.isNotEmpty) {
      opfPath = fp;
      break;
    }
  }
  if (opfPath == null || opfPath.isEmpty) {
    throw Exception('不是有效的 EPUB：container.xml 未声明 rootfile');
  }

  final opfBytes = files[opfPath];
  if (opfBytes == null) throw Exception('EPUB 缺少 OPF：$opfPath');
  final opf = XmlDocument.parse(_decodeBytes(opfBytes));
  final opfDir = _dirOf(opfPath);

  // 2) 书名（dc:title，忽略命名空间前缀）
  var title = '未命名书籍';
  final titleEl = opf.findAllElements('title', namespace: '*').firstOrNull;
  if (titleEl != null) {
    final t = titleEl.innerText.trim();
    if (t.isNotEmpty) title = t;
  }

  // 3) manifest: id → (href, properties)
  final hrefById = <String, String>{};
  final propById = <String, String>{};
  for (final el in opf.findAllElements('item')) {
    final id = el.getAttribute('id');
    final href = el.getAttribute('href');
    if (id == null || href == null) continue;
    hrefById[id] = href;
    propById[id] = el.getAttribute('properties') ?? '';
  }

  // 4) spine：idref 阅读顺序
  final spineIds = <String>[];
  for (final el in opf.findAllElements('itemref')) {
    final idref = el.getAttribute('idref');
    if (idref != null) spineIds.add(idref);
  }

  bool isNavLike(String href, String properties) {
    if (properties.toLowerCase().contains('nav')) return true;
    // 只看文件名，避免目录名（如 OEBPS/nav/）误伤
    final b = _baseName(href).toLowerCase();
    return b.startsWith('nav') || b.startsWith('toc') || b.startsWith('cover');
  }

  String? resolve(String href) {
    final target = _normalize(_join(opfDir, href));
    if (files.containsKey(target)) return target;
    // 回退：按文件名匹配（路径前缀不一致时）
    final base = _baseName(href);
    for (final k in files.keys) {
      if (_baseName(k) == base) return k;
    }
    return null;
  }

  final chapters = <BookChapter>[];
  final used = <String>{};

  // 按 spine（阅读顺序）
  for (final id in spineIds) {
    final href = hrefById[id];
    if (href == null) continue;
    if (isNavLike(href, propById[id] ?? '')) continue; // 跳过导航/目录/封面页
    final key = resolve(href);
    if (key == null || !used.add(key)) continue;
    final html = _decodeBytes(files[key]!);
    if (html.trim().isEmpty) continue;
    chapters.add(
      BookChapter(title: _titleFromHtml(html) ?? _stripExt(_baseName(href)), html: html),
    );
  }

  // spine 为空/没匹配上：退回全部 XHTML（按名排序，顺序稳定）
  if (chapters.isEmpty) {
    final keys = files.keys
        .where((k) {
          final l = k.toLowerCase();
          return l.endsWith('.xhtml') ||
              l.endsWith('.html') ||
              l.endsWith('.htm') ||
              l.endsWith('.xml');
        })
        .toList()
      ..sort();
    for (final k in keys) {
      if (isNavLike(k, '')) continue;
      final html = _decodeBytes(files[k]!);
      if (html.trim().isEmpty) continue;
      chapters.add(
        BookChapter(title: _titleFromHtml(html) ?? _baseName(k), html: html),
      );
    }
  }

  if (chapters.isEmpty) {
    throw Exception('EPUB 中未找到任何可读正文（XHTML）内容');
  }

  return ParsedBook(title: title, chapters: chapters);
}

/// 从 HTML 里猜章节标题：<title> 优先，其次首个 h1/h2
String? _titleFromHtml(String html) {
  String clean(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();

  String? pick(RegExp re) {
    final m = re.firstMatch(html);
    if (m == null) return null;
    final t = clean(m.group(1)!);
    return t.isEmpty ? null : t;
  }

  return pick(RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true)) ??
      pick(RegExp(r'<h[123][^>]*>(.*?)</h[123]>', caseSensitive: false, dotAll: true));
}

/// 把 zip 内文件字节解码为字符串：优先 UTF-8，失败回退 latin1（避免非法序列直接崩）
String _decodeBytes(List<int> b) {
  try {
    return utf8.decode(b);
  } on FormatException {
    return latin1.decode(b);
  }
}

/// OPF 所在目录（用于解析 spine/manifest 的相对 href）
String _dirOf(String p) {
  final i = p.lastIndexOf('/');
  return i <= 0 ? '' : p.substring(0, i);
}

String _join(String dir, String href) =>
    dir.isEmpty ? href : '$dir/$href';

/// 归一化路径（处理 ./ 与 ../，避免越界）
String _normalize(String p) {
  final out = <String>[];
  for (final s in p.split('/')) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(s);
  }
  return out.join('/');
}

String _baseName(String href) {
  final noAnchor = href.split('#').first;
  final decoded = Uri.decodeFull(noAnchor);
  final parts = decoded.split('/');
  return parts.isEmpty ? decoded : parts.last;
}

String _stripExt(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
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
