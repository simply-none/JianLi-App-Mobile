// 2FA 账户模型 —— 与桌面端 electron/main/module/twoFactor/types.ts 的 TwoFactorAccount 对齐
//
// secret 明文仅存在于解密后的内存中，绝不落库（只回写加密 vault 文件）。
class TwoFactorAccount {
  const TwoFactorAccount({
    required this.key,
    required this.issuer,
    required this.account,
    required this.secret,
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
    this.group,
    this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 vault 明文 JSON 构造（字段缺失时按桌面端默认值兜底）
  factory TwoFactorAccount.fromJson(Map<String, dynamic> json) {
    return TwoFactorAccount(
      key: json['key'] as String? ?? '',
      issuer: json['issuer'] as String? ?? '',
      account: json['account'] as String? ?? '',
      secret: json['secret'] as String? ?? '',
      algorithm: json['algorithm'] as String? ?? 'SHA1',
      digits: (json['digits'] as num?)?.toInt() ?? 6,
      period: (json['period'] as num?)?.toInt() ?? 30,
      group: json['group'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  final String key;
  final String issuer;
  final String account;

  /// base32 明文密钥（仅内存态）
  final String secret;

  /// SHA1 / SHA256 / SHA512
  final String algorithm;
  final int digits;
  final int period;
  final String? group;
  final int? sortOrder;
  final String createdAt;
  final String updatedAt;

  /// 展示用标题（issuer + account）
  String get displayName => issuer.isEmpty ? account : '$issuer · $account';

  Map<String, dynamic> toJson() => {
    'key': key,
    'issuer': issuer,
    'account': account,
    'secret': secret,
    'algorithm': algorithm,
    'digits': digits,
    'period': period,
    if (group != null) 'group': group,
    if (sortOrder != null) 'sortOrder': sortOrder,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
