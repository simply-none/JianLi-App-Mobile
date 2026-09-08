// 2FA 状态管理（Riverpod）
//
// 解锁后的账户列表为内存态（AsyncNotifier 管理），口令不进任何状态；
// 出码由 UI 层定时器按秒刷新，不放进全局状态。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../models/two_factor_account.dart';
import '../repositories/two_factor_repository.dart';

/// 2FA 仓库（依赖全局数据库）
final Provider<TwoFactorRepository> twoFactorRepositoryProvider =
    Provider<TwoFactorRepository>(
      (ref) => TwoFactorRepository(ref.watch(appDatabaseProvider)),
    );

/// vault 文件路径状态（null = 未配置）
final FutureProvider<String?> twoFactorVaultPathProvider =
    FutureProvider<String?>(
      (ref) => ref.watch(twoFactorRepositoryProvider).getVaultPath(),
    );

/// 已解锁的 2FA 账户列表（未解锁时为空列表）
class TwoFactorAccountsController
    extends AsyncNotifier<List<TwoFactorAccount>> {
  @override
  Future<List<TwoFactorAccount>> build() async => const [];

  String? _vaultPath;

  /// 用口令解锁 vault；失败抛异常由 UI 捕获展示
  Future<void> unlock(String passphrase) async {
    final repo = ref.read(twoFactorRepositoryProvider);
    final accounts = await repo.unlockAccounts(passphrase);
    _vaultPath = await repo.getVaultPath();
    state = AsyncData(accounts);
  }

  /// 是否已解锁（有 vaultPath 记录即视为解锁过）
  bool get isUnlocked => _vaultPath != null;

  /// 追加账户（解锁态；secret 为 base32，或直接给 otpauth:// URI 自动解析）
  Future<void> addAccount({
    required String passphrase,
    required TwoFactorAccount account,
  }) async {
    final entries = [...(state.value ?? const <TwoFactorAccount>[])];
    entries.add(account);
    state = AsyncData(entries);
    final vaultPath =
        _vaultPath ??
        await ref.read(twoFactorRepositoryProvider).getVaultPath();
    if (vaultPath == null) throw StateError('vault 路径缺失');
    _vaultPath = vaultPath;
    await ref
        .read(twoFactorRepositoryProvider)
        .saveAccounts(vaultPath, passphrase, entries);
  }

  /// 锁定（清空内存态）
  void lock() {
    _vaultPath = null;
    state = const AsyncData([]);
  }
}

final AsyncNotifierProvider<TwoFactorAccountsController, List<TwoFactorAccount>>
twoFactorAccountsProvider =
    AsyncNotifierProvider<TwoFactorAccountsController, List<TwoFactorAccount>>(
      TwoFactorAccountsController.new,
    );

/// 2FA 是否已解锁（UI 开关，页面 watch 它；全局/路由锁会置 false 即时回到门禁）。
/// 与 controller 的明文账户列表解耦，单独成开关以保证「锁态」可响应。
final StateProvider<bool> twoFactorUnlockedProvider = StateProvider<bool>(
  (ref) => false,
);
