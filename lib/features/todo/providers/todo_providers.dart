// 待办模块 Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/todo.dart';
import '../repositories/todo_repository.dart';

/// 待办仓库
final Provider<TodoRepository> todoRepositoryProvider = Provider<TodoRepository>(
  (ref) => TodoRepository(ref.watch(appDatabaseProvider)),
);

/// 待办列表流
final StreamProvider<List<TodoItem>> todoListProvider = StreamProvider<List<TodoItem>>(
  (ref) => ref.watch(todoRepositoryProvider).watchTodos(),
);

/// 标签流
final StreamProvider<List<TodoTagView>> todoTagsProvider = StreamProvider<List<TodoTagView>>(
  (ref) => ref.watch(todoRepositoryProvider).watchTags(),
);
