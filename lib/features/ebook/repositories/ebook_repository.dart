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

  /// 原始 drift 库句柄（传书服务需要直接查书架表暴露本机书目）
  AppDatabase get db => _db;

  /// 书架流（⚠️ 跨端同步后按 content_hash 去重，见方法内说明）
  Stream<List<EbookBookshelfData>> watchBookshelf() {
    return (_db.select(
      _db.ebookBookshelf,
    )..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)])).watch().map(_dedupeByHash);
  }

  /// 同一本书去重：同步会把对端的书架行也拉过来，而对端 file_path 是它自己的
  /// 绝对路径（PC）≠ 本机沙盒路径 → 同一 content_hash 出现两条，UI 会重复显示。
  /// 规则：按 content_hash 归并，**优先保留本机文件实际存在的那条**（保留原排序）。
  List<EbookBookshelfData> _dedupeByHash(List<EbookBookshelfData> rows) {
    final kept = <EbookBookshelfData>[];
    final indexByHash = <String, int>{};
    for (final r in rows) {
      final hash = r.contentHash;
      if (hash == null || hash.isEmpty) {
        kept.add(r); // 无哈希（老数据）原样保留
        continue;
      }
      final at = indexByHash[hash];
      if (at == null) {
        indexByHash[hash] = kept.length;
        kept.add(r);
        continue;
      }
      // 已收过同 hash：仅当「已有那条文件不存在、当前这条存在」时替换
      final prevExists = File(kept[at].filePath).existsSync();
      final curExists = File(r.filePath).existsSync();
      if (!prevExists && curExists) kept[at] = r;
    }
    return kept;
  }

  /// 导入书籍到沙盒（epub/txt），以内容 sha256 做身份键（对齐桌面端 content_hash 约定）
  Future<EbookBookshelfData?> importBook(String sourcePath) async {
    final src = File(sourcePath);
    if (!src.existsSync()) return null;
    final ext = p.extension(sourcePath).toLowerCase();
    if (ext != '.epub' && ext != '.txt') return null;
    final bytes = await src.readAsBytes();
    return importBookBytes(
      name: p.basenameWithoutExtension(sourcePath),
      format: ext == '.epub' ? 'epub' : 'txt',
      bytes: bytes,
    );
  }

  /// 从字节流导入（跨端传书：对端只给文件名 + 字节，本机没有源文件路径）
  Future<EbookBookshelfData?> importBookBytes({
    required String name,
    required String format,
    required List<int> bytes,
  }) async {
    final hash = sha256.convert(bytes).toString();

    // 同内容已存在（跨路径去重）
    final existing = await (_db.select(
      _db.ebookBookshelf,
    )..where((t) => t.contentHash.equals(hash))).getSingleOrNull();
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(dir.path, 'books'));
    if (!booksDir.existsSync()) booksDir.createSync(recursive: true);
    final ext = format == 'epub' ? '.epub' : '.txt';
    final localPath = p.join(booksDir.path, '${_uuid.v4()}$ext');
    await File(localPath).writeAsBytes(bytes);

    final now = DateTime.now().toIso8601String();
    final companion = EbookBookshelfCompanion.insert(
      filePath: localPath,
      name: Value(name),
      format: Value(format),
      percent: const Value(0.0),
      lastReadAt: Value(now),
      addedAt: Value(now),
      title: Value(name),
      contentHash: Value(hash),
    );
    final key = await _db.into(_db.ebookBookshelf).insert(companion);
    return (_db.select(
      _db.ebookBookshelf,
    )..where((t) => t.id.equals(key))).getSingleOrNull();
  }

  /// 按沙盒路径找书架行（阅读器恢复进度用）
  Future<EbookBookshelfData?> findBookByPath(String filePath) {
    return (_db.select(
      _db.ebookBookshelf,
    )..where((t) => t.filePath.equals(filePath))).getSingleOrNull();
  }

  /// 移除书籍（沙盒文件与共享进度/标注保留，与桌面端语义一致）
  Future<void> removeBook(EbookBookshelfData book) async {
    final f = File(book.filePath);
    if (f.existsSync()) f.deleteSync();
    await (_db.delete(
      _db.ebookBookshelf,
    )..where((t) => t.filePath.equals(book.filePath))).go();
  }

  /// 读进度（按 content_hash 优先，回退 file_path）
  Future<EbookProgressData?> getProgress(EbookBookshelfData book) async {
    if (book.contentHash != null && book.contentHash!.isNotEmpty) {
      final byHash =
          await (_db.select(_db.ebookProgress)
                ..where((t) => t.contentHash.equals(book.contentHash!)))
              .getSingleOrNull();
      if (byHash != null) return byHash;
    }
    return (_db.select(
      _db.ebookProgress,
    )..where((t) => t.filePath.equals(book.filePath))).getSingleOrNull();
  }

  /// 保存进度（章节索引折算进 cfi 字段：`chapter:<index>`，双端互通列 P2 对齐）
  Future<void> saveProgress(
    EbookBookshelfData book,
    int chapterIndex,
    double percent,
  ) async {
    final now = DateTime.now().toIso8601String();
    final existing = await getProgress(book);
    if (existing == null) {
      await _db
          .into(_db.ebookProgress)
          .insert(
            EbookProgressCompanion.insert(
              filePath: book.filePath,
              format: Value(book.format),
              cfi: Value('chapter:$chapterIndex'),
              percent: Value(percent),
              updatedAt: Value(now),
              contentHash: Value(book.contentHash),
            ),
          );
    } else {
      await (_db.update(
        _db.ebookProgress,
      )..where((t) => t.filePath.equals(existing.filePath))).write(
        EbookProgressCompanion(
          cfi: Value('chapter:$chapterIndex'),
          percent: Value(percent),
          updatedAt: Value(now),
        ),
      );
    }
    await (_db.update(
      _db.ebookBookshelf,
    )..where((t) => t.filePath.equals(book.filePath))).write(
      EbookBookshelfCompanion(percent: Value(percent), lastReadAt: Value(now)),
    );
  }

  // ---- 书签（ebook_bookmark，按章节索引锚点 chapter:<i>）----

  /// 某书的书签流（按创建时间升序）
  Stream<List<EbookBookmarkData>> watchBookmarks(String contentHash) {
    return (_db.select(
      _db.ebookBookmark,
    )..where((t) => t.contentHash.equals(contentHash))
     ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  /// 是否存在某章节的书签
  Future<EbookBookmarkData?> findBookmark(
    String contentHash,
    int chapterIndex,
  ) async {
    return (_db.select(
      _db.ebookBookmark,
    )..where(
      (t) =>
          t.contentHash.equals(contentHash) &
          t.cfi.equals('chapter:$chapterIndex'),
    )).getSingleOrNull();
  }

  /// 新增书签（按当前章节）
  Future<EbookBookmarkData> addBookmark({
    required String filePath,
    required String contentHash,
    required String format,
    required int chapterIndex,
    required String label,
    required double percent,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.into(_db.ebookBookmark).insert(
      EbookBookmarkCompanion.insert(
        filePath: Value(filePath),
        contentHash: Value(contentHash),
        format: Value(format),
        cfi: Value('chapter:$chapterIndex'),
        label: Value(label),
        percent: Value(percent.toStringAsFixed(1)),
        createdAt: Value(now),
      ),
    );
    return (_db.select(
      _db.ebookBookmark,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  /// 删除书签
  Future<void> removeBookmark(int id) async {
    await (_db.delete(
      _db.ebookBookmark,
    )..where((t) => t.id.equals(id))).go();
  }

  // ---- 批注 / 划线（ebook_annotation，anchor 锚定 chapter:<i>）----

  /// 某书的批注流（按创建时间升序）
  Stream<List<EbookAnnotationData>> watchAnnotations(String contentHash) {
    return (_db.select(
      _db.ebookAnnotation,
    )..where((t) => t.contentHash.equals(contentHash))
     ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  /// 新增批注（type=markStrong 表示划线高亮；note 为可选笔记内容）
  Future<int> addAnnotation({
    required String filePath,
    required String contentHash,
    required String format,
    required String anchor,
    required String annotatedText,
    String? note,
    required String color,
    required String type,
  }) async {
    final now = DateTime.now().toIso8601String();
    return _db.into(_db.ebookAnnotation).insert(
      EbookAnnotationCompanion.insert(
        filePath: Value(filePath),
        contentHash: Value(contentHash),
        format: Value(format),
        anchor: Value(anchor),
        annotatedText: Value(annotatedText),
        note: Value(note),
        color: Value(color),
        type: Value(type),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// 删除批注
  Future<void> removeAnnotation(int id) async {
    await (_db.delete(
      _db.ebookAnnotation,
    )..where((t) => t.id.equals(id))).go();
  }

  // ---- 分类（ebook_category + ebook_book_category）----

  /// 全部分类流
  Stream<List<EbookCategoryData>> watchCategories() {
    return (_db.select(
      _db.ebookCategory,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  /// 全部书-分类关联流（前端据此构建 book_path -> categoryIds 映射）
  Stream<List<EbookBookCategoryData>> watchAllBookCategories() {
    return _db.select(_db.ebookBookCategory).watch();
  }

  /// 新增分类（重名忽略），返回分类 id
  Future<int> addCategory(String name, {String? color}) async {
    final now = DateTime.now().toIso8601String();
    return _db.into(_db.ebookCategory).insert(
      EbookCategoryCompanion.insert(
        name: name,
        createdAt: Value(now),
        color: Value(color),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 给书打分类标签（复合主键，重复写入幂等）
  Future<void> assignCategory(String bookPath, int categoryId) async {
    await _db.into(_db.ebookBookCategory).insertOnConflictUpdate(
      EbookBookCategoryCompanion.insert(
        bookPath: bookPath,
        categoryId: categoryId,
      ),
    );
  }

  /// 取消书的某分类标签
  Future<void> unassignCategory(String bookPath, int categoryId) async {
    await (_db.delete(
      _db.ebookBookCategory,
    )..where(
      (t) => t.bookPath.equals(bookPath) & t.categoryId.equals(categoryId),
    )).go();
  }

  /// 删除分类（同时清理关联）
  Future<void> removeCategory(int id) async {
    await (_db.delete(
      _db.ebookBookCategory,
    )..where((t) => t.categoryId.equals(id))).go();
    await (_db.delete(
      _db.ebookCategory,
    )..where((t) => t.id.equals(id))).go();
  }
}

/// 仓库 provider
final Provider<EbookRepository> ebookRepositoryProvider =
    Provider<EbookRepository>(
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
  final pattern = RegExp(
    r'^\s*(第[一二三四五六七八九十百千0-9]+[章节卷回]|Chapter\s+\d+).*$',
    multiLine: true,
  );
  final matches = pattern.allMatches(content).toList();
  if (matches.isEmpty) {
    return [BookChapter(title: '全文', html: '<p>${_escapeHtml(content)}</p>')];
  }
  final chapters = <BookChapter>[];
  // 首段（封面/前言）
  if (matches.first.start > 0) {
    final head = content.substring(0, matches.first.start).trim();
    if (head.isNotEmpty) {
      chapters.add(
        BookChapter(title: '前言', html: '<p>${_escapeHtml(head)}</p>'),
      );
    }
  }
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = i + 1 < matches.length ? matches[i + 1].start : content.length;
    final chunk = content.substring(start, end);
    final title = matches[i].group(0)?.trim() ?? '第 ${i + 1} 章';
    final body = chunk.substring(chunk.indexOf('\n') + 1).trim();
    chapters.add(
      BookChapter(
        title: title,
        html: body.isEmpty
            ? ''
            : body
                  .split('\n')
                  .map((l) => '<p>${_escapeHtml(l)}</p>')
                  .join('\n'),
      ),
    );
  }
  return chapters;
}

String _escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
