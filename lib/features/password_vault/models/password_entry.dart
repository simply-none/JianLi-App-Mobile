// 密码条目模型 —— 字段对齐桌面端密码保险库 VaultEntry（types.ts）
//
// PC 端条目字段：key/title/username/password/url/note/category/otpSecret/createdAt/updatedAt。
// 桌面端 passwordVaultPath 的 vault 由「设备绑定主密钥」加密（deviceKey.ts），
// 设备密钥无法跨设备迁移；移动端采用**同套信封格式（AES-256-GCM + PBKDF2）但用
// 用户口令派生密钥**的本地 vault（存沙盒 Documents/password-vault.jlv）。
// 双端同步时需做「口令重包装」迁移（TODO(P3)，见 core/sync/README.md）。
//
// 向后兼容：category/otpSecret/createdAt 为后补字段，旧 vault JSON 缺失时取默认空值，
// 解码不报错；重新保存后字段即补齐。
class PasswordEntry {
  const PasswordEntry({
    required this.key,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.note,
    this.category,
    this.otpSecret,
    required this.updatedAt,
    this.createdAt,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
    key: json['key'] as String? ?? '',
    title: json['title'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    url: json['url'] as String? ?? '',
    note: json['note'] as String? ?? '',
    category: json['category'] as String?,
    otpSecret: json['otpSecret'] as String?,
    updatedAt: json['updatedAt'] as String? ?? '',
    createdAt: json['createdAt'] as String?,
  );

  final String key;
  final String title;
  final String username;
  final String password;
  final String url;
  final String note;

  /// 分类（对齐 PC；列表聚合去重做筛选 chips）
  final String? category;

  /// 可选 TOTP 密钥（base32，与 2FA 打通——对齐 PC otpSecret 实时出码）
  final String? otpSecret;

  final String updatedAt;
  final String? createdAt;

  /// 是否配置了 TOTP（展示徽标 + 详情实时出码）
  bool get hasOtp => (otpSecret ?? '').trim().isNotEmpty;

  /// 弱密码粗判：长度 < 8 视为弱（横幅「弱密码」统计口径）
  bool get isWeak => password.length < 8;

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'username': username,
    'password': password,
    'url': url,
    'note': note,
    if (category != null && category!.isNotEmpty) 'category': category,
    if (otpSecret != null && otpSecret!.isNotEmpty) 'otpSecret': otpSecret,
    if (createdAt != null) 'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  PasswordEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? url,
    String? note,
    String? category,
    String? otpSecret,
    String? updatedAt,
    bool clearCategory = false,
    bool clearOtpSecret = false,
  }) => PasswordEntry(
    key: key,
    title: title ?? this.title,
    username: username ?? this.username,
    password: password ?? this.password,
    url: url ?? this.url,
    note: note ?? this.note,
    category: clearCategory ? null : (category ?? this.category),
    otpSecret: clearOtpSecret ? null : (otpSecret ?? this.otpSecret),
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt,
  );
}
