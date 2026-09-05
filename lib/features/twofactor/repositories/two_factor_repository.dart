// 2FA 仓库 —— 从 basic_info 找 vault 路径 → 读文件 → 解密出账户列表
//
// 数据链路（与桌面端一致）：
//   basic_info(key='twoFactorVaultPath').value  →  vault 文件路径
//   vault 文件 = JSON 信封（AES-256-GCM + PBKDF2 口令派生）
//   明文 = TwoFactorAccount JSON 数组
// 口令由用户输入（2FA 用用户口令派生密钥，见 deviceKey.ts），绝不持久化。
import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/crypto/vault_codec.dart';
import '../../../core/db/app_database.dart';
import '../models/two_factor_account.dart';

/// 2FA 数据仓库
class TwoFactorRepository {
  TwoFactorRepository(this._db);

  final AppDatabase _db;

  /// 读取 vault 文件路径；未配置时返回 null（移动端尚未导入 vault 的场景）
  Future<String?> getVaultPath() async {
    final row = await (_db.select(_db.basicInfo)
          ..where((tbl) => tbl.key.equals('twoFactorVaultPath')))
        .getSingleOrNull();
    final path = row?.value;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// 记录 vault 文件路径（移动端 PoC：用户通过文件选择器导入桌面端 vault 后写入）
  Future<void> setVaultPath(String path) async {
    final existing = await (_db.select(_db.basicInfo)
          ..where((tbl) => tbl.key.equals('twoFactorVaultPath')))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.basicInfo).insert(
            BasicInfoCompanion.insert(key: 'twoFactorVaultPath', value: Value(path)),
          );
    } else {
      await (_db.update(_db.basicInfo)
            ..where((tbl) => tbl.key.equals('twoFactorVaultPath')))
          .write(BasicInfoCompanion(value: Value(path)));
    }
  }

  /// 用口令解锁并返回全部 2FA 账户（口令错误时 GCM 认证失败抛异常）
  Future<List<TwoFactorAccount>> unlockAccounts(String passphrase) async {
    final path = await getVaultPath();
    if (path == null) {
      throw StateError('尚未配置 2FA vault（basic_info.twoFactorVaultPath 不存在）');
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('vault 文件不存在：$path（移动端需先通过同步/导入把 vault 拷入可达路径）');
    }
    final plainList = await decryptVaultEnvelope(file.readAsStringSync(), passphrase);
    return plainList
        .whereType<Map<String, dynamic>>()
        .map(TwoFactorAccount.fromJson)
        .toList();
  }

  /// 把账户列表重新加密写回 vault 文件（移动端编辑后调用；布局与桌面端一致）
  Future<void> saveAccounts(String vaultPath, String passphrase, List<TwoFactorAccount> accounts) async {
    final envelope = await encryptVaultEnvelope(
      accounts.map((a) => a.toJson()).toList(),
      passphrase,
    );
    File(vaultPath).writeAsStringSync(envelope);
  }
}
