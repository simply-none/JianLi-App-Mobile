// 2FA 仓库 —— 从 basic_info 找 vault 路径 → 读文件 → 解密出账户列表
//
// 数据链路（与桌面端一致）：
//   basic_info(key='twoFactorVaultPath').value  →  vault 文件路径
//   vault 文件 = JSON 信封（AES-256-GCM + PBKDF2 口令派生）
//   明文 = TwoFactorAccount JSON 数组
// 口令由用户输入（2FA 用用户口令派生密钥，见 deviceKey.ts），绝不持久化。
//
// 两条入口（对齐桌面端 twoFactor.ts 的 open-vault / create-vault）：
//   - 导入：用户经文件选择器指定桌面端导出的 vault，setVaultPath 记录其路径；
//   - 新建：resolveDefaultPath 给沙盒固定落位 <Documents>/twofactor-vault.jlv，
//           createVault 写入空数组并记录路径（此后 unlock 走同一条链路）。
// 同一时刻只有一个活动 vault（basic_info 单键），故 unlockAccounts 无需区分来源。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/crypto/vault_codec.dart';
import '../../../core/db/app_database.dart';
import '../models/two_factor_account.dart';

/// vault 文件名（新建时的固定落位文件名；与桌面端加密格式完全一致，可互导）
const String kTwoFactorVaultFileName = 'twofactor-vault.jlv';

/// 2FA 数据仓库
class TwoFactorRepository {
  TwoFactorRepository(this._db);

  final AppDatabase _db;

  /// 读取 vault 文件路径；未配置时返回 null（移动端尚未导入/新建 vault 的场景）
  Future<String?> getVaultPath() async {
    final row = await (_db.select(
      _db.basicInfo,
    )..where((tbl) => tbl.key.equals('twoFactorVaultPath'))).getSingleOrNull();
    final path = row?.value;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// 是否已建库（有路径记录且文件确实存在）
  Future<bool> hasVault() async {
    final path = await getVaultPath();
    if (path == null) return false;
    return File(path).existsSync();
  }

  /// 新建 vault 的默认落位（沙盒 `Documents/twofactor-vault.jlv`），仅解析不落库；
  /// 实际写库由 [createVault] 完成（避免「只解析即留下路径记录」的脏状态）。
  Future<String> resolveDefaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, kTwoFactorVaultFileName);
  }

  /// 首次建库：写入空数组（口令派生密钥加密），并记录路径到 basic_info
  Future<void> createVault(String passphrase) async {
    final path = await resolveDefaultPath();
    final envelope = await encryptVaultEnvelope(<Object?>[], passphrase);
    File(path).writeAsStringSync(envelope);
    await setVaultPath(path);
  }

  /// 记录 vault 文件路径（移动端 PoC：用户通过文件选择器导入桌面端 vault 后写入）
  Future<void> setVaultPath(String path) async {
    final existing = await (_db.select(
      _db.basicInfo,
    )..where((tbl) => tbl.key.equals('twoFactorVaultPath'))).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.basicInfo)
          .insert(
            BasicInfoCompanion.insert(
              key: 'twoFactorVaultPath',
              value: Value(path),
            ),
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
    final plainList = await decryptVaultEnvelope(
      file.readAsStringSync(),
      passphrase,
    );
    return plainList
        .whereType<Map<String, dynamic>>()
        .map(TwoFactorAccount.fromJson)
        .toList();
  }

  /// 把账户列表重新加密写回 vault 文件（移动端编辑后调用；布局与桌面端一致）
  Future<void> saveAccounts(
    String vaultPath,
    String passphrase,
    List<TwoFactorAccount> accounts,
  ) async {
    final envelope = await encryptVaultEnvelope(
      accounts.map((a) => a.toJson()).toList(),
      passphrase,
    );
    File(vaultPath).writeAsStringSync(envelope);
  }
}
