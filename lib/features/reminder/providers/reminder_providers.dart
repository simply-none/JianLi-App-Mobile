// 提醒模块 Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/reminder_item.dart';
import '../repositories/reminder_repository.dart';

/// 提醒仓库
final Provider<ReminderRepository> reminderRepositoryProvider =
    Provider<ReminderRepository>(
      (ref) => ReminderRepository(ref.watch(appDatabaseProvider)),
    );

/// 用户提醒列表流
final StreamProvider<List<ReminderItem>> reminderListProvider =
    StreamProvider<List<ReminderItem>>(
      (ref) => ref.watch(reminderRepositoryProvider).watchUserReminders(),
    );
