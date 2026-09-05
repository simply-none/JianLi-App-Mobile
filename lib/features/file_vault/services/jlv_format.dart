// .jlv 密文格式编解码 —— 逐字节对齐桌面端 fileVault.ts
//
// 新格式（自描述）：`JLV1`(4B ASCII) + metaLen(uint32 BE) + JSON 元数据 {"name","ext"} + iv(12B 原始字节) + ct(密文+16B tag 原始字节)
// 旧格式：iv(12B 原始字节) + ct（无魔数；原名只存于 DB，此处 meta 返回 null）
// 另有「文件名加密存储」布局：base64(iv‖ct)，用 dataKey 解（对应 file_vault_files.name）。
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/vault_codec.dart';

/// JLV 魔数（与桌面端 JLV_MAGIC 一致）
const String kJlvMagic = 'JLV1';

const int _ivBytes = 12;

/// 解析结果
class JlvParsed {
  const JlvParsed({this.metaName, this.metaExt, required this.iv, required this.ct});

  /// 新格式内嵌原名；旧格式为 null
  final String? metaName;
  final String? metaExt;

  /// 12 字节 IV
  final Uint8List iv;

  /// 密文 + 16B tag
  final Uint8List ct;
}

/// 解析 .jlv 密文字节（按魔数自动区分新旧格式）
JlvParsed parseJlv(Uint8List buf) {
  if (buf.length >= 8) {
    final magic = String.fromCharCodes(buf.sublist(0, 4));
    if (magic == kJlvMagic) {
      final bd = ByteData.sublistView(buf, 4, 8);
      final metaLen = bd.getUint32(0);
      final metaJson = utf8.decode(buf.sublist(8, 8 + metaLen), allowMalformed: true);
      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      final iv = Uint8List.sublistView(buf, 8 + metaLen, 8 + metaLen + _ivBytes);
      final ct = Uint8List.sublistView(buf, 8 + metaLen + _ivBytes);
      return JlvParsed(
        metaName: meta['name'] as String?,
        metaExt: meta['ext'] as String?,
        iv: iv,
        ct: ct,
      );
    }
  }
  // 旧格式：iv(12) + ct
  return JlvParsed(
    iv: Uint8List.sublistView(buf, 0, _ivBytes),
    ct: Uint8List.sublistView(buf, _ivBytes),
  );
}

/// 构造 .jlv 密文（导入时使用；与桌面端 composeCipher 等价）
Uint8List buildJlv({required String name, required String ext, required Uint8List iv, required Uint8List ct}) {
  final meta = utf8.encode(jsonEncode({'name': name, 'ext': ext}));
  final out = BytesBuilder();
  out.add(ascii.encode(kJlvMagic));
  final len = ByteData(4)..setUint32(0, meta.length);
  out.add(len.buffer.asUint8List());
  out.add(meta);
  out.add(iv);
  out.add(ct);
  return out.toBytes();
}

/// 解密 DB 中加密存储的文件名（file_vault_files.name = base64(iv‖ct)，dataKey 加密）
Future<String?> decryptVaultName(String? nameB64, List<int> dataKey) async {
  if (nameB64 == null || nameB64.isEmpty) return null;
  try {
    final buf = base64Decode(nameB64);
    final iv = Uint8List.sublistView(buf, 0, _ivBytes);
    final ct = Uint8List.sublistView(buf, _ivBytes);
    final plain = await decryptVaultBytes(EncryptedVaultBytes(
      ivBase64: base64Encode(iv),
      ctBase64: base64Encode(ct),
    ), dataKey);
    return utf8.decode(plain);
  } catch (_) {
    return null;
  }
}
