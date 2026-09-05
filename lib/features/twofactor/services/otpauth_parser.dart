// otpauth:// URI 解析 —— 对齐桌面端 src/views/twoFactor/utils/otpauth.ts
//
// 格式：otpauth://totp/[Issuer:]account?secret=BASE32&issuer=Issuer&algorithm=SHA1&digits=6&period=30
// 用于「从其他验证器粘贴导入」，与桌面端互通。
import '../models/two_factor_account.dart';

/// 解析结果（secret 非法时返回 null）
({TwoFactorAccount account, String label})? parseOtpauthUri(String uri) {
  if (!uri.startsWith('otpauth://totp/')) return null;
  final rest = uri.substring('otpauth://totp/'.length);
  final qIndex = rest.indexOf('?');
  if (qIndex < 0) return null;
  final labelPart = Uri.decodeComponent(rest.substring(0, qIndex));
  final params = Uri.splitQueryString(rest.substring(qIndex + 1));

  final secret = params['secret']?.toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '');
  if (secret == null || secret.isEmpty) return null;

  // label 形如 "Issuer:account" 或 "account"
  String issuer = params['issuer'] ?? '';
  String account = labelPart;
  final sep = labelPart.indexOf(':');
  if (sep > 0) {
    if (issuer.isEmpty) issuer = labelPart.substring(0, sep).trim();
    account = labelPart.substring(sep + 1).trim();
  }

  final now = DateTime.now().toIso8601String();
  final account0 = TwoFactorAccount(
    key: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
    issuer: issuer,
    account: account,
    secret: secret,
    algorithm: (params['algorithm'] ?? 'SHA1').toUpperCase(),
    digits: int.tryParse(params['digits'] ?? '') ?? 6,
    period: int.tryParse(params['period'] ?? '') ?? 30,
    createdAt: now,
    updatedAt: now,
  );
  return (account: account0, label: labelPart);
}

/// 拼回 otpauth:// URI（导出用，与桌面端 buildOtpauthUri 一致）
String buildOtpauthUri(TwoFactorAccount a) {
  final label = a.issuer.isEmpty
      ? Uri.encodeComponent(a.account)
      : '${Uri.encodeComponent(a.issuer)}:${Uri.encodeComponent(a.account)}';
  final params = <String>[
    'secret=${Uri.encodeComponent(a.secret)}',
    if (a.issuer.isNotEmpty) 'issuer=${Uri.encodeComponent(a.issuer)}',
    if (a.algorithm != 'SHA1') 'algorithm=${a.algorithm}',
    if (a.digits != 6) 'digits=${a.digits}',
    if (a.period != 30) 'period=${a.period}',
  ].join('&');
  return 'otpauth://totp/$label?$params';
}
