// 密码保险库仓库 —— 移动端本地 vault（用户口令 + 与桌面端同套信封加密）
//
// vault 文件：沙盒 Documents/password-vault.jlv（JSON 信封，与 2FA vault 同格式）；
// 路径记录在 basic_info(key='mobilePasswordVaultPath')，便于未来同步/迁移。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/crypto/vault_codec.dart';
import '../../../core/db/app_database.dart';
import '../models/password_entry.dart';

/// 密码保险库仓库
class PasswordVaultRepository {
  PasswordVaultRepository(this._db);

  final AppDatabase _db;

  Future<String> _vaultPath() async {
    // 优先读 basic_info 记录，保证路径稳定
    final row = await (_db.select(_db.basicInfo)
          ..where((tbl) => tbl.key.equals('mobilePasswordVaultPath')))
        .getSingleOrNull();
    if (row?.value != null && row!.value!.isNotEmpty) return row.value!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'password-vault.jlv');
    await _db.into(_db.basicInfo).insert(BasicInfoCompanion.insert(
          key: 'mobilePasswordVaultPath',
          value: Value(path),
        ));
    return path;
  }

  /// 是否已建库
  Future<bool> hasVault() => _vaultPath().then((path) => File(path).existsSync());

  /// 首次建库（写入空数组）
  Future<void> createVault(String passphrase) async {
    final path = await _vaultPath();
    final envelope = await encryptVaultEnvelope(<Object?>[], passphrase);
    File(path).writeAsStringSync(envelope);
  }

  /// 解锁：返回全部条目（口令错抛异常）
  Future<List<PasswordEntry>> unlock(String passphrase) async {
    final path = await _vaultPath();
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('尚未创建密码库');
    }
    final list = await decryptVaultEnvelope(file.readAsStringSync(), passphrase);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PasswordEntry.fromJson)
        .toList();
  }

  /// 用加密回写保存全部条目（信封文件是唯一真相源，与桌面端 2FA 同范式）
  Future<void> saveAll(String passphrase, List<PasswordEntry> entries) async {
    final path = await _vaultPath();
    final envelope =
        await encryptVaultEnvelope(entries.map((e) => e.toJson()).toList(), passphrase);
    File(path).writeAsStringSync(envelope);
  }
}
