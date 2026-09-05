// 文件保险箱仓库 —— 解包 dataKey / 列表 / 导入 / 解密（与桌面端 fileVault.ts 同构）
//
// 密钥层级（与桌面端一致）：
//   dataKey(32B 随机) --AES-GCM--> wrappedKey（KEK=PBKDF2(口令,salt) 包装）落 file_vault_config
//   每个文件用 dataKey 加密成 .jlv；文件名用 dataKey 加密存 file_vault_files.name
// 移动端密文目录：沙盒 Documents/渐离App保险箱/。
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/crypto/vault_codec.dart';
import '../../../core/db/app_database.dart';
import '../services/jlv_format.dart';

/// 内存态保险箱服务（dataKey 仅驻留内存，锁定清零 —— 与桌面端同策略）
class FileVaultService {
  FileVaultService(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();
  final Random _random = Random.secure();

  Uint8List? _dataKey; // 解锁后驻留内存
  bool get isUnlocked => _dataKey != null;

  /// 沙盒密文目录
  Future<String> _cipherDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(dir.path, '渐离App保险箱'));
    if (!vaultDir.existsSync()) vaultDir.createSync(recursive: true);
    return vaultDir.path;
  }

  /// 读取配置（null = 未建库）
  Future<Map<String, dynamic>?> _loadConfig() async {
    final row = await (_db.select(
      _db.fileVaultConfig,
    )..where((t) => t.key.equals('vault'))).getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _saveConfig(Map<String, dynamic> cfg) async {
    await _db
        .into(_db.fileVaultConfig)
        .insertOnConflictUpdate(
          FileVaultConfigCompanion.insert(
            key: 'vault',
            value: Value(jsonEncode(cfg)),
          ),
        );
  }

  /// 是否已建库
  Future<bool> hasVault() async => (await _loadConfig()) != null;

  /// 首次建库：生成 dataKey → KEK 包装（与桌面端 set-password 逐字节兼容）
  Future<void> setPassword(String password) async {
    final dataKey = Uint8List.fromList(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    final salt = Uint8List.fromList(
      List.generate(16, (_) => _random.nextInt(256)),
    );
    final kek = await deriveVaultKey(password, salt);
    final w = await encryptVaultBytes(dataKey, await kek.extractBytes());
    // wrappedKey = base64(iv_raw ‖ ct_raw)
    final wrapped = base64Encode([
      ...base64Decode(w.ivBase64),
      ...base64Decode(w.ctBase64),
    ]);
    await _saveConfig({
      'salt': base64Encode(salt),
      'wrappedKey': wrapped,
      'version': 1,
    });
    _dataKey = dataKey;
  }

  /// 解锁：KEK 解包 dataKey（口令错 → GCM 认证失败抛异常）
  Future<void> unlock(String password) async {
    final cfg = await _loadConfig();
    if (cfg == null) throw StateError('尚未创建保险箱');
    final salt = base64Decode(cfg['salt'] as String);
    final wrapped = base64Decode(cfg['wrappedKey'] as String);
    final kek = await deriveVaultKey(password, salt);
    final dataKey = await decryptVaultBytes(
      EncryptedVaultBytes(
        ivBase64: base64Encode(Uint8List.sublistView(wrapped, 0, 12)),
        ctBase64: base64Encode(Uint8List.sublistView(wrapped, 12)),
      ),
      await kek.extractBytes(),
    );
    _dataKey = dataKey;
  }

  /// 锁定：清零内存
  void lock() => _dataKey = null;

  /// 导入文件：读字节 → dataKey 加密 → .jlv 落盘 → 写脱敏元数据
  Future<void> importFile(String sourcePath) async {
    final dk = _dataKey;
    if (dk == null) throw StateError('保险箱未解锁');
    final src = File(sourcePath);
    if (!src.existsSync()) throw StateError('源文件不存在');
    final name = p.basename(sourcePath);
    final ext = p.extension(sourcePath);
    final plain = await src.readAsBytes();

    final e = await encryptVaultBytes(plain, dk);
    final jlv = buildJlv(
      name: name,
      ext: ext,
      iv: base64Decode(e.ivBase64),
      ct: base64Decode(e.ctBase64),
    );
    final id = _uuid.v4();
    final dir = await _cipherDir();
    final cipherPath = p.join(dir, '$id.jlv');
    File(cipherPath).writeAsBytesSync(jlv);

    // 原名加密入库（方案 A）
    final eName = await encryptVaultBytes(utf8.encode(name), dk);
    final nameB64 = base64Encode([
      ...base64Decode(eName.ivBase64),
      ...base64Decode(eName.ctBase64),
    ]);

    await _db
        .into(_db.fileVaultFiles)
        .insert(
          FileVaultFilesCompanion.insert(
            id: id,
            name: Value(nameB64),
            mime: Value(''),
            ext: Value(ext),
            size: Value('${plain.length}'),
            ciphertextPath: Value(cipherPath),
            createdAt: Value(DateTime.now().toIso8601String()),
          ),
        );
  }

  /// 列表（解锁后解密文件名）
  Future<List<({FileVaultFile meta, String name})>> listFiles() async {
    final dk = _dataKey;
    if (dk == null) throw StateError('保险箱未解锁');
    final rows = await _db.select(_db.fileVaultFiles).get();
    final result = <({FileVaultFile meta, String name})>[];
    for (final row in rows) {
      result.add((
        meta: row,
        name: await decryptVaultName(row.name, dk) ?? '（未知文件）',
      ));
    }
    return result;
  }

  /// 解密文件内容为字节
  Future<Uint8List> decryptFile(FileVaultFile meta) async {
    final dk = _dataKey;
    if (dk == null) throw StateError('保险箱未解锁');
    final buf = await File(meta.ciphertextPath ?? '').readAsBytes();
    final parsed = parseJlv(buf);
    return decryptVaultBytes(
      EncryptedVaultBytes(
        ivBase64: base64Encode(parsed.iv),
        ctBase64: base64Encode(parsed.ct),
      ),
      dk,
    );
  }

  /// 删除（密文 + 元数据）
  Future<void> deleteFile(FileVaultFile meta) async {
    final path = meta.ciphertextPath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
    await (_db.delete(
      _db.fileVaultFiles,
    )..where((t) => t.id.equals(meta.id))).go();
  }
}

/// 服务 provider（App 生命周期单例；锁定态保存在实例字段）
final Provider<FileVaultService> fileVaultServiceProvider =
    Provider<FileVaultService>(
      (ref) => FileVaultService(ref.watch(appDatabaseProvider)),
    );
