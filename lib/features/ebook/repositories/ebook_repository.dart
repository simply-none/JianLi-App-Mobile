// 电子书仓库 —— 书架 / 进度（content_hash 为跨端稳定键，不依赖桌面路径）
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

/// 电子书仓库
class EbookRepository {
  EbookRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 书架流
  Stream<List<EbookBookshelfData>> watchBookshelf() {
    return (_db.select(_db.ebookBookshelf)
          ..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)]))
        .watch();
  }

  /// 导入书籍到沙盒（epub/txt），以内容 sha256 做身份键（对齐桌面端 content_hash 约定）
  Future<EbookBookshelfData?> importBook(String sourcePath) async {
    final src = File(sourcePath);
    if (!src.existsSync()) return null;
    final ext = p.extension(sourcePath).toLowerCase();
    if (ext != '.epub' && ext != '.txt') return null;

    final bytes = await src.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    // 同内容已存在（跨路径去重）
    final existing = await (_db.select(_db.ebookBookshelf)
          ..where((t) => t.contentHash.equals(hash)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(dir.path, 'books'));
    if (!booksDir.existsSync()) booksDir.createSync(recursive: true);
    final localPath = p.join(booksDir.path, '${_uuid.v4()}$ext');
    await File(localPath).writeAsBytes(bytes);

    final now = DateTime.now().toIso8601String();
    final name = p.basenameWithoutExtension(sourcePath);
    final companion = EbookBookshelfCompanion.insert(
      filePath: localPath,
      name: Value(name),
      format: Value(ext == '.epub' ? 'epub' : 'txt'),
      percent: const Value(0.0),
      lastReadAt: Value(now),
      addedAt: Value(now),
      title: Value(name),
      contentHash: Value(hash),
    );
    final key = await _db.into(_db.ebookBookshelf).insert(companion);
    return (_db.select(_db.ebookBookshelf)..where((t) => t.id.equals(key))).getSingleOrNull();
  }

  /// 按沙盒路径找书架行（阅读器恢复进度用）
  Future<EbookBookshelfData?> findBookByPath(String filePath) {
    return (_db.select(_db.ebookBookshelf)..where((t) => t.filePath.equals(filePath)))
        .getSingleOrNull();
  }

  /// 移除书籍（沙盒文件与共享进度/标注保留，与桌面端语义一致）
  Future<void> removeBook(EbookBookshelfData book) async {
    final f = File(book.filePath);
    if (f.existsSync()) f.deleteSync();
    await (_db.delete(_db.ebookBookshelf)..where((t) => t.filePath.equals(book.filePath))).go();
  }

  /// 读进度（按 content_hash 优先，回退 file_path）
  Future<EbookProgressData?> getProgress(EbookBookshelfData book) async {
    if (book.contentHash != null && book.contentHash!.isNotEmpty) {
      final byHash = await (_db.select(_db.ebookProgress)
            ..where((t) => t.contentHash.equals(book.contentHash!)))
          .getSingleOrNull();
      if (byHash != null) return byHash;
    }
    return (_db.select(_db.ebookProgress)
          ..where((t) => t.filePath.equals(book.filePath)))
        .getSingleOrNull();
  }

  /// 保存进度（章节索引折算进 cfi 字段：`chapter:<index>`，双端互通列 P2 对齐）
  Future<void> saveProgress(EbookBookshelfData book, int chapterIndex, double percent) async {
    final now = DateTime.now().toIso8601String();
    final existing = await getProgress(book);
    if (existing == null) {
      await _db.into(_db.ebookProgress).insert(EbookProgressCompanion.insert(
            filePath: book.filePath,
            format: Value(book.format),
            cfi: Value('chapter:$chapterIndex'),
            percent: Value(percent),
            updatedAt: Value(now),
            contentHash: Value(book.contentHash),
          ));
    } else {
      await (_db.update(_db.ebookProgress)
            ..where((t) => t.filePath.equals(existing.filePath)))
          .write(EbookProgressCompanion(
            cfi: Value('chapter:$chapterIndex'),
            percent: Value(percent),
            updatedAt: Value(now),
          ));
    }
    await (_db.update(_db.ebookBookshelf)
          ..where((t) => t.filePath.equals(book.filePath)))
        .write(EbookBookshelfCompanion(
          percent: Value(percent),
          lastReadAt: Value(now),
        ));
  }
}

/// 仓库 provider
final Provider<EbookRepository> ebookRepositoryProvider = Provider<EbookRepository>(
  (ref) => EbookRepository(ref.watch(appDatabaseProvider)),
);

/// 章节数据
class BookChapter {
  const BookChapter({required this.title, required this.html});

  final String title;
  final String html;
}

/// epub 解析结果
class ParsedBook {
  const ParsedBook({required this.title, required this.chapters});

  final String title;
  final List<BookChapter> chapters;
}

/// 简易 TXT 分章（第 X 章 / Chapter n 正则）
List<BookChapter> splitTxtChapters(String content) {
  final pattern = RegExp(r'^\s*(第[一二三四五六七八九十百千0-9]+[章节卷回]|Chapter\s+\d+).*$', multiLine: true);
  final matches = pattern.allMatches(content).toList();
  if (matches.isEmpty) {
    return [BookChapter(title: '全文', html: '<p>${_escapeHtml(content)}</p>')];
  }
  final chapters = <BookChapter>[];
  // 首段（封面/前言）
  if (matches.first.start > 0) {
    final head = content.substring(0, matches.first.start).trim();
    if (head.isNotEmpty) chapters.add(BookChapter(title: '前言', html: '<p>${_escapeHtml(head)}</p>'));
  }
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = i + 1 < matches.length ? matches[i + 1].start : content.length;
    final chunk = content.substring(start, end);
    final title = matches[i].group(0)?.trim() ?? '第 ${i + 1} 章';
    final body = chunk.substring(chunk.indexOf('\n') + 1).trim();
    chapters.add(BookChapter(
      title: title,
      html: body.isEmpty ? '' : body.split('\n').map((l) => '<p>${_escapeHtml(l)}</p>').join('\n'),
    ));
  }
  return chapters;
}

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
