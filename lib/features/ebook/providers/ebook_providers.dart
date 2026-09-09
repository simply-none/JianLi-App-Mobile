// 电子书模块 providers —— 书架/阅读相关流的统一出口
//
// ⚠️ provider 一律声明为顶层变量（与其它功能域一致）。禁止在 build 里内联
// `StreamProvider(...)`——Riverpod 会把每次重建都当作全新 provider（初始态
// loading），导致「打开页面永远转圈」（书架页实踩）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../repositories/ebook_repository.dart';

/// 书架流 provider（last_read_at 倒序）
final StreamProvider<List<EbookBookshelfData>> bookshelfStreamProvider =
    StreamProvider<List<EbookBookshelfData>>(
      (ref) => ref.watch(ebookRepositoryProvider).watchBookshelf(),
    );

/// 书签流（按 content_hash 区分书）
final bookmarksStreamProvider = StreamProvider.family<List<EbookBookmarkData>, String>(
  (ref, contentHash) =>
      ref.watch(ebookRepositoryProvider).watchBookmarks(contentHash),
);

/// 批注流（按 content_hash 区分书）
final annotationsStreamProvider =
    StreamProvider.family<List<EbookAnnotationData>, String>(
      (ref, contentHash) =>
          ref.watch(ebookRepositoryProvider).watchAnnotations(contentHash),
    );

/// 全部分类流
final StreamProvider<List<EbookCategoryData>> categoriesStreamProvider =
    StreamProvider<List<EbookCategoryData>>(
      (ref) => ref.watch(ebookRepositoryProvider).watchCategories(),
    );

/// 全部书-分类关联流（前端构建 book_path -> categoryIds 映射）
final StreamProvider<List<EbookBookCategoryData>> bookCategoriesStreamProvider =
    StreamProvider<List<EbookBookCategoryData>>(
      (ref) => ref.watch(ebookRepositoryProvider).watchAllBookCategories(),
    );
