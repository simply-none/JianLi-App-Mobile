// 电子书仓库 —— 书架 / 进度（content_hash 为跨端稳定键，不依赖桌面路径）
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/android/media_scan.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

/// 电子书仓库
class EbookRepository {
  EbookRepository(this._db);

  final AppDatabase _db;

  /// 一次性迁移守卫：旧沙盒 /books 已在启动时搬入固定 jianli-books 目录后不再重复
  bool _migrated = false;

  /// 原始 drift 库句柄（传书服务需要直接查书架表暴露本机书目）
  AppDatabase get db => _db;

  /// 电子书传书固定保存目录名（公共 Download 子目录，与文件互传同样走系统 Download、可见）
  static const String kEbookTransferDirName = '渐离App传书';

  /// 公共 Download 可写判定。
  /// ⚠️ 关键修正（2026-09-10）：Android 11+(API 30+) 起，普通 READ/WRITE_EXTERNAL_STORAGE
  /// 已**不再**授予「写共享 Download 目录」的权限，只有「所有文件访问」(MANAGE_EXTERNAL_STORAGE)
  /// 才行。旧代码把 `Permission.storage.isGranted` 当成可写，导致 API 30+ 上 `createSync`
  /// 抛 Permission denied → 静默回退沙盒（文件管理器看不到）。
  /// 因此：API 30+ 必须 manageExternalStorage；≤29 才允许传统 storage 权限。
  static Future<bool> hasPublicDownloadsAccess() async {
    if (!Platform.isAndroid) return false;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await getAndroidSdkInt() <= 29) {
      return Permission.storage.isGranted;
    }
    return false;
  }

  /// 申请公共 Download 写权限（与文件互传一致的可见保存目录）。
  /// API 30+ 只有「所有文件访问」才能写共享 Download，申请 storage 无效且误导，故只申请前者；
  /// ≤29 才弹传统授权框。拒绝时 [booksDir] 自动回退沙盒。应在传书页打开时调用一次。
  static Future<void> ensurePublicDownloadsPermission() async {
    if (!Platform.isAndroid) return;
    if (await hasPublicDownloadsAccess()) return;
    if (await getAndroidSdkInt() >= 30) {
      await Permission.manageExternalStorage.request();
    } else {
      await [Permission.manageExternalStorage, Permission.storage].request();
    }
  }

  /// 接收目录（不存在则创建）：
  /// - Android 且已授权 → 系统 `Download/渐离App传书/`，系统文件管理器可直接浏览打开；
  /// - 未授权或创建失败（权限被收回/ROM 限制）→ 回退沙盒 `Documents/渐离App传书/`。
  static Future<Directory> get booksDir async {
    if (Platform.isAndroid && await hasPublicDownloadsAccess()) {
      try {
        final d = Directory('/storage/emulated/0/Download/$kEbookTransferDirName');
        if (!d.existsSync()) d.createSync(recursive: true);
        return d;
      } catch (_) {
        // 公共目录创建失败（运行中权限被收回/ROM 限制）→ 沙盒回退
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(dir.path, kEbookTransferDirName));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// 可读文件名：`<书名>_<内容hash前8位>.<ext>`，避免重名冲突且能直接认出内容
  /// （旧版用随机 uuid 命名，文件管理器里完全无法辨识，已弃用）
  static String _bookFileName(String name, String format, String hash) {
    final ext = format == 'epub' ? '.epub' : '.txt';
    final safe = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .trim();
    final base = safe.isEmpty ? 'book' : safe;
    final tail = hash.length >= 8 ? hash.substring(0, 8) : hash;
    return '${base}_$tail$ext';
  }

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

    final dir = await EbookRepository.booksDir;
    final localPath = p.join(dir.path, _bookFileName(name, format, hash));

    // 同内容去重：仅在「本机文件已位于目标公开路径」时跳过落盘复用；
    // 若记录存在但本机文件缺失 / 在沙盒 / 路径不符（如同步来的 PC 端记录、旧沙盒路径失效），
    // 必须重新落盘到 booksDir（公开 Download），否则会「传书成功却文件管理器看不到」。
    // 文件互传无此去重门故始终可见，本次对齐其行为。
    final existing = await (_db.select(
      _db.ebookBookshelf,
    )..where((t) => t.contentHash.equals(hash))).getSingleOrNull();
    if (existing != null &&
        existing.filePath == localPath &&
        File(existing.filePath).existsSync()) {
      return existing;
    }

    await File(localPath).writeAsBytes(bytes);
    // 落盘后触发 MediaStore 索引，使文件管理器/系统媒体立即可见（静默，失败不影响已写入）
    await scanFileInMediaStore(localPath);

    final now = DateTime.now().toIso8601String();
    if (existing != null) {
      // 命中同内容记录：旧记录可能是「沙盒路径 / id 为 NULL 的异常行 / 已占用目标路径的重复行」。
      // 直接 UPDATE 会因 id 为 NULL（WHERE id IS NULL 匹配不到）或 UNIQUE(file_path) 冲突而失败/抛错。
      // 统一按 content_hash 去重重写：删掉所有同 hash 行 + 任何占用目标路径的行，再插入一条规范行，
      // 既避开可空的 id，又根除重复行导致的 UNIQUE 冲突。书签/批注按 content_hash 关联，不受删行影响。
      final keptPercent = existing.percent ?? 0.0;
      final keptAddedAt = existing.addedAt ?? now;
      await (_db.delete(_db.ebookBookshelf)
            ..where((t) => t.contentHash.equals(hash)))
          .go();
      await (_db.delete(_db.ebookBookshelf)
            ..where((t) => t.filePath.equals(localPath)))
          .go();
      // 清理失效旧副本文件（不在目标路径上的那份）
      if (existing.filePath != localPath &&
          File(existing.filePath).existsSync()) {
        try {
          File(existing.filePath).delete();
        } catch (_) {}
      }
      final key = await _db.into(_db.ebookBookshelf).insert(
        EbookBookshelfCompanion.insert(
          filePath: localPath,
          name: Value(name),
          format: Value(format),
          percent: Value(keptPercent),
          lastReadAt: Value(now),
          addedAt: Value(keptAddedAt),
          title: Value(name),
          contentHash: Value(hash),
        ),
      );
      return (_db.select(
        _db.ebookBookshelf,
      )..where((t) => t.id.equals(key))).getSingleOrNull();
    }

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

  /// 一次性迁移：把旧版存于应用私有沙盒 `/books`（随机 uuid 文件名）的书，
  /// 搬进固定 `jianli-books` 目录并重命名为可读文件名（`<书名>_<hash8>.<ext>`），
  /// 同步更新书架表 filePath。best-effort：任何单本失败都保留旧路径（旧目录仍在，不丢书），
  /// 其它本照常迁移。启动即触发一次（见 ebookRepositoryProvider）。
  Future<void> migrateLegacyBooksDir() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final legacy = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'books'),
      );
      if (!legacy.existsSync()) return;
      final target = await EbookRepository.booksDir;
      final rows = await _db.select(_db.ebookBookshelf).get();
      for (final r in rows) {
        if (!r.filePath.startsWith(legacy.path) || !File(r.filePath).existsSync()) {
          continue;
        }
        try {
          final bytes = await File(r.filePath).readAsBytes();
          final hash = sha256.convert(bytes).toString();
          final fileName = _bookFileName(
            r.title ?? r.name ?? 'book',
            r.format ?? 'epub',
            hash,
          );
          final newPath = p.join(target.path, fileName);
          if (File(newPath).existsSync()) {
            await File(r.filePath).delete(); // 新目录已有同名，旧文件冗余
          } else {
            await File(r.filePath).copy(newPath);
            await File(r.filePath).delete();
          }
          await (_db.update(_db.ebookBookshelf)
                ..where((t) => t.filePath.equals(r.filePath)))
              .write(EbookBookshelfCompanion(filePath: Value(newPath)));
        } catch (_) {
          // 保留旧路径，不影响其它本
        }
      }
      try {
        if (legacy.listSync().isEmpty) legacy.deleteSync(recursive: true);
      } catch (_) {}
    } catch (_) {
      // 迁移整体失败不影响正常导入（新导入仍走 jianli-books）
    }
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
      (ref) {
        final repo = EbookRepository(ref.watch(appDatabaseProvider));
        // 启动即把旧沙盒 /books 书迁移到固定 jianli-books 目录（一次性、best-effort，不阻塞）
        unawaited(repo.migrateLegacyBooksDir());
        return repo;
      },
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
