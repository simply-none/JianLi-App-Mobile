// 笔记模块 Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/note_item.dart';
import '../models/note_tag.dart';
import '../repositories/note_repository.dart';

/// 笔记仓库
final Provider<NoteRepository> noteRepositoryProvider =
    Provider<NoteRepository>(
      (ref) => NoteRepository(ref.watch(appDatabaseProvider)),
    );

/// 笔记列表流（family 参数为多分类的编码串：'\u0001'.join(cats)，空串 = 全部。
/// 用稳定字符串做 key——List 直接做 family 参数每次新实例都会换 provider）
final notesStreamProvider = StreamProvider.family<List<NoteItem>, String>((
  ref,
  categoryKey,
) {
  final categories = categoryKey.isEmpty
      ? const <String>[]
      : categoryKey.split('\u0001');
  return ref.watch(noteRepositoryProvider).watchNotes(categories: categories);
});

/// 分类列表（一次性加载）
final FutureProvider<List<String>> noteCategoriesProvider =
    FutureProvider<List<String>>(
      (ref) => ref.watch(noteRepositoryProvider).loadCategories(),
    );

/// 标签定义流（basic_info.note_tags；PC 同步写入后自动重发）
final StreamProvider<List<NoteTag>> noteTagsProvider =
    StreamProvider<List<NoteTag>>(
      (ref) => ref.watch(noteRepositoryProvider).watchTagDefs(),
    );
