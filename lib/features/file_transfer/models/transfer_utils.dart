// 文件互传纯函数工具（无 IO 依赖，便于单测；server/client 复用保证双端一致）
import 'dart:convert';

import 'package:path/path.dart' as p;

/// 文件名安全化（仅取 basename、过滤非法字符），与 server 中同款
String sanitizeFileName(String raw) {
  final base = p.basename(raw);
  const illegal = r'<>:"/\|?*';
  var cleaned = base;
  for (final ch in illegal.split('')) {
    cleaned = cleaned.replaceAll(ch, '_');
  }
  return cleaned.isEmpty ? '未命名文件' : cleaned;
}

/// 接收端 .part 稳定名（#13 断点续传）：以「安全名 + 大小」命名，
/// 使同一文件跨批次重试用同一临时文件，续传时直接append。
String recvPartName(String rawName, int size) {
  return '.recv-${sanitizeFileName(rawName)}-$size.part';
}

/// 加密会话密钥 base64 编码（用于 offer 在局域网内协商，#14）
Map<String, String> encodeEncSession(List<int> key, List<int> iv) => {
      'key': base64Encode(key),
      'iv': base64Encode(iv),
    };

/// 加密会话密钥 base64 解码
Map<String, List<int>> decodeEncSession(String keyB64, String ivB64) => {
      'key': base64Decode(keyB64),
      'iv': base64Decode(ivB64),
    };
