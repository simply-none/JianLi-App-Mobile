// vault 信封编解码实现（AES-256-GCM + PBKDF2-SHA256）
//
// 与桌面端 electron/main/module/vault/crypto.ts 逐字节对齐：
// - JSON 信封：salt/iv/ct 三个 base64 字段，ct = 密文 || 16B tag；
// - 二进制原语：{iv, ct} 同布局，供文件保险箱使用。
// 性能注意：cryptography 包为纯 Dart 实现，200000 次 PBKDF2 在移动端解锁约需数秒，
// P2 可接入 cryptography_flutter 走平台实现提速（接口不变）。
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'vault_crypto.dart';

/// AES-GCM 实例（256 位密钥）
final AesGcm _aesGcm = AesGcm.with256bits();

/// 安全随机源
final Random _secureRandom = Random.secure();

/// 生成 [length] 字节安全随机数
Uint8List randomVaultBytes(int length) => Uint8List.fromList(
  List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
);

/// 由口令派生 32 字节密钥（PBKDF2-SHA256，盐 + 迭代次数与桌面端一致）
Future<SecretKey> deriveVaultKey(
  String passphrase,
  List<int> salt, {
  int? iterations,
}) {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations ?? kVaultPbkdf2Iterations,
    bits: kVaultKeyBytes * 8,
  );
  return kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: salt,
  );
}

/// 解密 JSON 信封为明文 JSON 数组（口令错误/文件损坏时抛异常）
/// 返回 `List<dynamic>`，由调用方映射到具体模型（避免本层耦合 feature 模型）。
Future<List<dynamic>> decryptVaultEnvelope(
  String rawJson,
  String passphrase,
) async {
  final env = jsonDecode(rawJson);
  if (env is! Map<String, dynamic>) {
    throw const FormatException('vault 信封格式非法：顶层不是对象');
  }
  final iter = (env['iter'] as num?)?.toInt() ?? kVaultPbkdf2Iterations;
  final salt = base64Decode(env['salt'] as String);
  final iv = base64Decode(env['iv'] as String);
  final ct = base64Decode(env['ct'] as String);

  // 桌面端布局：ct = 密文 || tag，需拆分后交给 cryptography（SecretBox 分离 mac）
  if (ct.length <= kVaultGcmTagBytes) {
    throw const FormatException('vault ct 长度非法');
  }
  final cipherData = Uint8List.sublistView(
    ct,
    0,
    ct.length - kVaultGcmTagBytes,
  );
  final tag = Uint8List.sublistView(ct, ct.length - kVaultGcmTagBytes);

  final key = await deriveVaultKey(passphrase, salt, iterations: iter);
  final clearText = await _aesGcm.decrypt(
    SecretBox(cipherData, nonce: iv, mac: Mac(tag)),
    secretKey: key,
  );
  final decoded = jsonDecode(utf8.decode(clearText));
  if (decoded is! List<dynamic>) {
    throw const FormatException('vault 明文不是 JSON 数组');
  }
  return decoded;
}

/// 加密 JSON 数组为信封 JSON 字符串（与桌面端 encryptVault 等价）
Future<String> encryptVaultEnvelope(
  List<Object?> items,
  String passphrase,
) async {
  final salt = randomVaultBytes(kVaultSaltBytes);
  final iv = randomVaultBytes(kVaultIvBytes);
  final key = await deriveVaultKey(passphrase, salt);
  final box = await _aesGcm.encrypt(
    utf8.encode(jsonEncode(items)),
    secretKey: key,
    nonce: iv,
  );
  // 拼回桌面端布局：ct = cipher || tag
  final ct = <int>[...box.cipherText, ...box.mac.bytes];
  return jsonEncode({
    'v': kVaultEnvelopeVersion,
    'kdf': kVaultKdf,
    'iter': kVaultPbkdf2Iterations,
    'salt': base64Encode(salt),
    'iv': base64Encode(iv),
    'ct': base64Encode(ct),
  });
}

/// 二进制加密产物（对应桌面端 EncryptedBytes：iv/ct 两个 base64 字段）
class EncryptedVaultBytes {
  const EncryptedVaultBytes({required this.ivBase64, required this.ctBase64});

  factory EncryptedVaultBytes.fromJson(Map<String, dynamic> json) =>
      EncryptedVaultBytes(
        ivBase64: json['iv'] as String,
        ctBase64: json['ct'] as String,
      );

  final String ivBase64;
  final String ctBase64;

  Map<String, dynamic> toJson() => {'iv': ivBase64, 'ct': ctBase64};
}

/// 加密任意字节（密钥由调用方给，如保险箱还原出的主密钥）
Future<EncryptedVaultBytes> encryptVaultBytes(
  List<int> plain,
  List<int> key,
) async {
  final iv = randomVaultBytes(kVaultIvBytes);
  final box = await _aesGcm.encrypt(
    plain,
    secretKey: SecretKey(key),
    nonce: iv,
  );
  final ct = <int>[...box.cipherText, ...box.mac.bytes];
  return EncryptedVaultBytes(
    ivBase64: base64Encode(iv),
    ctBase64: base64Encode(ct),
  );
}

/// 解密任意字节（布局同桌面端：ct = 密文 || tag）
Future<Uint8List> decryptVaultBytes(
  EncryptedVaultBytes env,
  List<int> key,
) async {
  final iv = base64Decode(env.ivBase64);
  final ct = base64Decode(env.ctBase64);
  if (ct.length <= kVaultGcmTagBytes) {
    throw const FormatException('vault ct 长度非法');
  }
  final cipherData = Uint8List.sublistView(
    ct,
    0,
    ct.length - kVaultGcmTagBytes,
  );
  final tag = Uint8List.sublistView(ct, ct.length - kVaultGcmTagBytes);
  final clear = await _aesGcm.decrypt(
    SecretBox(cipherData, nonce: iv, mac: Mac(tag)),
    secretKey: SecretKey(key),
  );
  return Uint8List.fromList(clear);
}
