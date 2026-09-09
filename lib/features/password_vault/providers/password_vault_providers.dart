// 密码库状态管理（Riverpod AsyncNotifier，范式与 2FA 一致）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../models/password_entry.dart';
import '../repositories/password_vault_repository.dart';

/// 密码库仓库
final Provider<PasswordVaultRepository> passwordVaultRepositoryProvider =
    Provider<PasswordVaultRepository>(
      (ref) => PasswordVaultRepository(ref.watch(appDatabaseProvider)),
    );

/// 是否已建库
final FutureProvider<bool> passwordVaultExistsProvider = FutureProvider<bool>(
  (ref) => ref.watch(passwordVaultRepositoryProvider).hasVault(),
);

/// 已解锁的条目控制器（内存态；锁定即清空）
class PasswordVaultController extends AsyncNotifier<List<PasswordEntry>> {
  @override
  Future<List<PasswordEntry>> build() async => const [];

  bool _unlocked = false;
  bool get isUnlocked => _unlocked;

  Future<bool> createVault(String passphrase) async {
    await ref.read(passwordVaultRepositoryProvider).createVault(passphrase);
    _unlocked = true;
    ref.invalidate(passwordVaultExistsProvider);
    state = const AsyncData([]);
    return true;
  }

  Future<void> unlock(String passphrase) async {
    final entries = await ref
        .read(passwordVaultRepositoryProvider)
        .unlock(passphrase);
    _unlocked = true;
    state = AsyncData(entries);
  }

  void lock() {
    _unlocked = false;
    state = const AsyncData([]);
  }

  Future<void> _persist(String passphrase) async {
    final entries = state.value ?? const <PasswordEntry>[];
    await ref
        .read(passwordVaultRepositoryProvider)
        .saveAll(passphrase, entries);
  }

  /// 新增/编辑条目（passphrase 由 UI 保存的内存口令提供，不落任何状态）
  Future<void> upsertEntry({
    required String passphrase,
    String? key,
    required String title,
    required String username,
    required String password,
    required String url,
    required String note,
  }) async {
    final now = DateTime.now().toIso8601String();
    final entries = [...(state.value ?? const <PasswordEntry>[])];
    final idx = key == null ? -1 : entries.indexWhere((e) => e.key == key);
    final entry = PasswordEntry(
      key: idx >= 0 ? entries[idx].key : const Uuid().v4(),
      title: title,
      username: username,
      password: password,
      url: url,
      note: note,
      updatedAt: now,
    );
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    state = AsyncData(entries);
    await _persist(passphrase);
  }

  Future<void> deleteEntry({
    required String passphrase,
    required String key,
  }) async {
    final entries = (state.value ?? const <PasswordEntry>[])
        .where((e) => e.key != key)
        .toList();
    state = AsyncData(entries);
    await _persist(passphrase);
  }
}

final AsyncNotifierProvider<PasswordVaultController, List<PasswordEntry>>
passwordVaultEntriesProvider =
    AsyncNotifierProvider<PasswordVaultController, List<PasswordEntry>>(
      PasswordVaultController.new,
    );

/// 密码库是否已解锁（UI 开关，页面 watch 它；全局/路由锁会置 false 即时回到门禁）。
/// 与 controller 的明文条目列表解耦，单独成开关以保证「锁态」可响应。
class PasswordVaultUnlocked extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
  void lock() => state = false;
}
final passwordVaultUnlockedProvider =
    NotifierProvider<PasswordVaultUnlocked, bool>(PasswordVaultUnlocked.new);
