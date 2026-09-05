// 笔记模块 Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/note_item.dart';
import '../repositories/note_repository.dart';

/// 笔记仓库
final Provider<NoteRepository> noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(appDatabaseProvider)),
);

/// 笔记列表流（family 参数为分类过滤；null = 全部）
/// 注：不显式声明 family 类型名（Riverpod 3 的 family 类型命名与 2.x 不同），交给推断。
final notesStreamProvider = StreamProvider.family<List<NoteItem>, String?>((ref, category) {
  return ref.watch(noteRepositoryProvider).watchNotes(category: category);
});

/// 分类列表（一次性加载）
final FutureProvider<List<String>> noteCategoriesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(noteRepositoryProvider).loadCategories(),
);
