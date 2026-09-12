// 习惯模块 Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/habit.dart';
import '../repositories/habit_repository.dart';

/// 习惯仓库
final Provider<HabitRepository> habitRepositoryProvider =
    Provider<HabitRepository>(
      (ref) => HabitRepository(ref.watch(appDatabaseProvider)),
    );

/// 习惯定义流
final StreamProvider<List<HabitItem>> habitListProvider =
    StreamProvider<List<HabitItem>>(
      (ref) => ref.watch(habitRepositoryProvider).watchHabits(),
    );

/// 今日（本地时区）日期串，如 2026-09-05
final Provider<String> todayProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

/// 今日已打卡的 habitKey 集合流
final StreamProvider<Set<String>> todayCheckedProvider =
    StreamProvider<Set<String>>(
      (ref) => ref
          .watch(habitRepositoryProvider)
          .watchCheckedKeys(ref.watch(todayProvider)),
    );

/// 近 7 天打卡（index 0 = 今天），按 habitKey 取，供卡片底部 7 天记录条。
final last7CheckedProvider =
    StreamProvider.family<List<bool>, String>((ref, key) {
  return ref.watch(habitRepositoryProvider).watchRecentCheckin(key, 7);
});
