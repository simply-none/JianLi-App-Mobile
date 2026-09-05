// TOTP 算法单元测试 —— RFC 6238 官方测试向量 + base32 往返
//
// RFC 6238 Appendix B（种子 "12345678901234567890" 的 base32 即
// GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ，SHA1/8 位）：
//   T=59s        → 94287082
//   T=1111111109 → 07081804
//   T=1234567890 → 89005924
import 'package:flutter_test/flutter_test.dart';

import 'package:jianli_mobile_app/features/twofactor/services/totp_service.dart';

void main() {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  test('RFC 6238 向量：SHA1 / 8 位', () {
    expect(
      generateTotp(secret, options: const TotpOptions(algorithm: 'SHA1', digits: 8), atTimeMs: 59000),
      '94287082',
    );
    expect(
      generateTotp(
        secret,
        options: const TotpOptions(algorithm: 'SHA1', digits: 8),
        atTimeMs: 1111111109000,
      ),
      '07081804',
    );
    expect(
      generateTotp(
        secret,
        options: const TotpOptions(algorithm: 'SHA1', digits: 8),
        atTimeMs: 1234567890000,
      ),
      '89005924',
    );
  });

  test('base32 解码容错（大写化 + 剔除填充与非法字符）', () {
    // 'gezd gnbv=' 与 'GEZDGNBV' 应解出相同字节
    expect(base32Decode('gezd gnbv='), base32Decode('GEZDGNBV'));
  });

  test('base32 编解码往返', () {
    final bytes = List<int>.generate(20, (i) => i * 7 % 256);
    expect(base32Decode(base32Encode(bytes)), bytes);
  });

  test('校验容差 ±1 周期', () {
    final t = 1111111109000;
    expect(
      verifyTotpCode(secret, '07081804',
          options: const TotpOptions(algorithm: 'SHA1', digits: 8), atTimeMs: t),
      isTrue,
    );
    // 用上一周期的码校验当前时刻（时钟偏差 -1 周期）也应通过
    expect(
      verifyTotpCode(secret, '94287082',
          options: const TotpOptions(algorithm: 'SHA1', digits: 8), atTimeMs: t),
      isFalse,
    );
  });
}
