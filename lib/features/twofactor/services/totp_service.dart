// TOTP 算法实现（RFC 6238）—— 逐行复刻桌面端 electron/main/module/twoFactor/otp.ts
//
// 动态码只在本地计算；secret 不持久化、不写日志。算法参数与桌面端完全一致，
// 保证同一密钥双端出码相同。RFC 6238 测试向量见 test/totp_test.dart。
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// base32 字母表（RFC 4648，无填充，与桌面端一致）
const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// base32 解码。容错与桌面端一致：自动转大写、剔除空格/'=' 填充及非字母表字符。
Uint8List base32Decode(String input) {
  final clean = input.toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '');
  final bytes = BytesBuilder();
  var bits = 0;
  var value = 0;
  for (final ch in clean.split('')) {
    final idx = _base32Alphabet.indexOf(ch);
    if (idx == -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.addByte((value >>> bits) & 0xff);
    }
  }
  return bytes.toBytes();
}

/// base32 编码（RFC 4648，无填充），用于生成随机 TOTP 密钥
String base32Encode(List<int> bytes) {
  var bits = 0;
  var value = 0;
  var out = '';
  for (final b in bytes) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out += _base32Alphabet[(value >>> bits) & 0x1f];
    }
  }
  if (bits > 0) {
    out += _base32Alphabet[(value << (5 - bits)) & 0x1f];
  }
  return out;
}

/// TOTP 参数（与桌面端 TotpOptions 对齐）
class TotpOptions {
  const TotpOptions({this.algorithm = 'SHA1', this.digits = 6, this.period = 30});

  /// SHA1 / SHA256 / SHA512
  final String algorithm;
  final int digits;
  final int period;
}

/// TOTP 结果 + 下一周期码 + 剩余秒数（供倒计时展示）
class TotpWithMeta {
  const TotpWithMeta({
    required this.code,
    required this.nextCode,
    required this.remainingSeconds,
    required this.period,
  });

  final String code;
  final String nextCode;
  final int remainingSeconds;
  final int period;
}

/// 生成指定时刻的 TOTP 码（动态截断算法，RFC 6238）
String generateTotp(String secretBase32, {TotpOptions? options, int? atTimeMs}) {
  final opts = options ?? const TotpOptions();
  final digits = opts.digits;
  final period = opts.period;
  final atTime = atTimeMs ?? DateTime.now().millisecondsSinceEpoch;
  final counter = atTime ~/ 1000 ~/ period;

  // 计数器 8 字节大端（对应桌面端 writeBigUInt64BE）
  final counterBuf = Uint8List(8);
  ByteData.view(counterBuf.buffer).setUint64(0, counter, Endian.big);

  final secret = base32Decode(secretBase32);
  final hmac = _hmac(opts.algorithm, secret, counterBuf);

  // 动态截断：取末尾字节低 4 位作偏移
  final offset = hmac[hmac.length - 1] & 0x0f;
  final binary = ((hmac[offset] & 0x7f) << 24) |
      ((hmac[offset + 1] & 0xff) << 16) |
      ((hmac[offset + 2] & 0xff) << 8) |
      (hmac[offset + 3] & 0xff);
  final otp = binary % _pow10(digits);
  return otp.toString().padLeft(digits, '0');
}

/// 生成当前码 + 下一周期码 + 剩余秒数
TotpWithMeta generateTotpWithMeta(String secretBase32, {TotpOptions? options, int? atTimeMs}) {
  final opts = options ?? const TotpOptions();
  final atTime = atTimeMs ?? DateTime.now().millisecondsSinceEpoch;
  final code = generateTotp(secretBase32, options: opts, atTimeMs: atTime);
  final nextCode =
      generateTotp(secretBase32, options: opts, atTimeMs: atTime + opts.period * 1000);
  final remainingSeconds = opts.period - ((atTime ~/ 1000) % opts.period);
  return TotpWithMeta(
    code: code,
    nextCode: nextCode,
    remainingSeconds: remainingSeconds,
    period: opts.period,
  );
}

/// 校验 TOTP 动态码：允许 ±1 个周期的时钟偏差容错
/// （桌面端额外做了 timingSafeEqual 常量时间比对；本端仅本地校验，保持等价容错）
bool verifyTotpCode(String secretBase32, String code, {TotpOptions? options, int? atTimeMs}) {
  final clean = (code).replaceAll(RegExp(r'\D'), '');
  if (clean.isEmpty) return false;
  final opts = options ?? const TotpOptions();
  final atTime = atTimeMs ?? DateTime.now().millisecondsSinceEpoch;
  for (var offset = -1; offset <= 1; offset++) {
    final candidate = generateTotp(
      secretBase32,
      options: opts,
      atTimeMs: atTime + offset * opts.period * 1000,
    );
    if (candidate == clean) return true;
  }
  return false;
}

/// 按算法选择 HMAC（SHA1 / SHA256 / SHA512，默认 SHA1，与桌面端一致）
List<int> _hmac(String algorithm, List<int> secret, List<int> message) {
  switch (algorithm.toUpperCase()) {
    case 'SHA256':
      return crypto.Hmac(crypto.sha256, secret).convert(message).bytes;
    case 'SHA512':
      return crypto.Hmac(crypto.sha512, secret).convert(message).bytes;
    case 'SHA1':
    default:
      return crypto.Hmac(crypto.sha1, secret).convert(message).bytes;
  }
}

/// 10 的 digits 次幂（避免引入 pow 的 double 精度问题）
int _pow10(int digits) {
  var result = 1;
  for (var i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}

/// 生成随机 base32 密钥（默认 20 字节 = 160 bit，与桌面端一致）
/// 使用 dart:math 的密码学安全随机源 Random.secure()。
String randomBase32Secret({int byteLength = 20}) {
  final secure = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => secure.nextInt(256));
  return base32Encode(bytes);
}
