// EPUB 解析容错回归测试
//
// 覆盖 2026-09-09 的「EPUB parsing error: TOC item, not found in EPUB manifest」：
// EPUB3 的 nav 文档若漏标 `properties="nav"`，epubx 的 `readBook` 会直接抛异常，
// 导致整本书打不开。修复后应落到 `_parseEpubWithoutToc`（不解析 TOC）并正常出章节。
//
// 夹具 `test/fixtures/bad_nav.epub` 是手工构造的最小 EPUB3：
// manifest 里有 nav.xhtml 但**没有** properties="nav"，spine 为 c1 → c2。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:epubx/epubx.dart' as epub;

import 'package:jianli_mobile_app/features/ebook/services/epub_service.dart';

void main() {
  final file = File('test/fixtures/bad_nav.epub');

  test('夹具存在', () {
    expect(file.existsSync(), isTrue);
  });

  test('复现：epubx readBook 在该 EPUB 上确实抛 TOC 异常', () async {
    final bytes = await file.readAsBytes();
    Object? err;
    try {
      await epub.EpubReader.readBook(bytes);
    } catch (e) {
      err = e;
    }
    // 这一步证明修复确实针对真实故障（若哪天 epubx 放宽了校验，此断言会提示）
    expect(err, isNotNull, reason: '预期 epubx 抛异常，夹具可能已失效');
    expect(err.toString(), contains('TOC item'));
  });

  test('修复：parseEpub 仍能解析出全部章节且顺序正确', () async {
    final book = await parseEpub(file);
    expect(book.chapters.length, 2, reason: '应按 spine 得到 2 章，且不含导航页');
    // 顺序即阅读顺序（spine: c1 → c2）
    expect(book.chapters[0].title, contains('第一章'));
    expect(book.chapters[1].title, contains('第二章'));
    // 正文确实取到了
    expect(book.chapters[0].html, contains('第一章正文'));
    expect(book.chapters[1].html, contains('第二章正文'));
  });
}
