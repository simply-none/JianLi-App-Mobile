// 密码条目模型 —— 移动端账号密码管理的最小模型
//
// 与桌面端密码保险库的对齐说明：
// 桌面端 passwordVaultPath 的 vault 由「设备绑定主密钥」加密（deviceKey.ts），
// 设备密钥无法跨设备迁移；移动端采用**同套信封格式（AES-256-GCM + PBKDF2）但用
// 用户口令派生密钥**的本地 vault（存沙盒 Documents/password-vault.jlv）。
// 双端同步时需做「口令重包装」迁移（TODO(P3)，见 core/sync/README.md）。
class PasswordEntry {
  const PasswordEntry({
    required this.key,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.note,
    required this.updatedAt,
  });

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        key: json['key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        url: json['url'] as String? ?? '',
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  final String key;
  final String title;
  final String username;
  final String password;
  final String url;
  final String note;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'note': note,
        'updatedAt': updatedAt,
      };

  PasswordEntry copyWith({String? title, String? username, String? password, String? url, String? note}) =>
      PasswordEntry(
        key: key,
        title: title ?? this.title,
        username: username ?? this.username,
        password: password ?? this.password,
        url: url ?? this.url,
        note: note ?? this.note,
        updatedAt: updatedAt,
      );
}
