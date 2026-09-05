// 私密文件保险箱数据表定义（file_vault_config / file_vault_files）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// 关键事实：密文文件本体在 ciphertext_path 指向的磁盘文件里，db 只存元数据；
// file_vault_config（key='vault'）的 value 是 {salt, wrappedKey,...} JSON——
// 用户口令经 PBKDF2 包装主密钥的配置，移动端解密文件时按此还原。
import 'package:drift/drift.dart';

/// 保险箱主密钥包装配置表 file_vault_config（key TEXT PRIMARY KEY）
class FileVaultConfig extends Table {
  /// 目前只有 'vault'
  TextColumn get key => text()();

  /// JSON：{"salt":"...","wrappedKey":"..."}（用户口令包装主密钥）
  TextColumn get value => text().nullable()();

  /// 旧层遗留可空整型列
  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 保险箱文件元数据表 file_vault_files（id TEXT PRIMARY KEY）
class FileVaultFiles extends Table {
  /// 文件 UUID 主键
  TextColumn get id => text()();

  // ---- 业务列（桌面端下划线风格，drift 默认对齐，named() 显式锁定） ----

  /// 加密后的文件名（桌面端即为密文 base64）
  TextColumn get name => text().nullable()();
  TextColumn get mime => text().nullable()();
  TextColumn get ext => text().nullable()();
  TextColumn get size => text().nullable()();

  /// 密文文件磁盘路径（桌面端路径；移动端需把密文拷进沙盒并重写）
  TextColumn get ciphertextPath => text().named('ciphertext_path').nullable()();

  TextColumn get createdAt => text().named('created_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
