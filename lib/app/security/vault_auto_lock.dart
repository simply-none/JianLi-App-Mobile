// 隐私保险箱统一自动锁（2026-09-08 新增）
//
// 三个隐私域的「解锁态」原本各自为政：
//   - 密码库：PasswordVaultController._unlocked（Riverpod 单例，路由切走/切后台都不清）
//   - 文件保险箱：FileVaultService._dataKey（单例，同上）
//   - 2FA：页面局部 State（路由切走会重置，但切后台不清）
// 任一都会造成「应用隐藏 / 路由切换时没有锁住」的安全缺口。
//
// 本文件提供 lockAllVaults(ref)：一次性同时锁掉三域——既清内存明文，又把各自的
// unlocked 开关置 false（页面 watch 该开关，锁态能即时反映到 UI）。
// 调用点：① 根组件 JianliApp 的 AppLifecycleState.paused/hidden/detached（应用隐藏）；
//        ② 三个隐私页 dispose（路由切走）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/file_vault/repositories/file_vault_repository.dart';
import '../../features/password_vault/providers/password_vault_providers.dart';
import '../../features/twofactor/providers/two_factor_providers.dart';

/// 应用切后台 / 各隐私页路由切走时，锁掉全部隐私保险箱。
///
/// 同时清内存明文（controller/service.lock）与置反 unlocked 开关（页面据此回到门禁）。
void lockAllVaults(WidgetRef ref) {
  // 清内存态（明文/密钥清零）
  ref.read(passwordVaultEntriesProvider.notifier).lock();
  ref.read(fileVaultServiceProvider).lock();
  ref.read(twoFactorAccountsProvider.notifier).lock();
  // 置反 UI 开关（让仍挂载的页面即时回到门禁态）
  ref.read(passwordVaultUnlockedProvider.notifier).lock();
  ref.read(fileVaultUnlockedProvider.notifier).lock();
  ref.read(twoFactorUnlockedProvider.notifier).lock();
}
