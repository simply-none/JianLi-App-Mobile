// vault 统一加密常量与格式说明（移动端复刻桌面端实现）
//
// 桌面端实现：electron/main/module/vault/crypto.ts（已逐行核对，2026-09-04）
// ---------------------------------------------------------------------------
// 一、JSON 信封格式（2FA / 密码库 vault 文件，文件内容即该 JSON 的 pretty 序列化）：
// {
//   "v": 1,
//   "kdf": "pbkdf2-sha256",
//   "iter": 200000,
//   "salt": "<base64, 16 字节随机盐>",
//   "iv":   "<base64, 12 字节随机 IV>",
//   "ct":   "<base64, AES-256-GCM 密文 + 16 字节认证标签（tag 附在尾部）>"
// }
// 明文 = JSON 数组的 UTF-8 字节；口令错误/文件损坏时 GCM 认证失败抛错。
//
// 二、二进制文件加密原语（fileVault 任意文件）：
// { "iv": "<base64, 12B>", "ct": "<base64, 密文+16B tag>" }，密钥由调用方传入。
//
// 三、密钥来源（deviceKey.ts 权威说明，⚠️ 修正 flutter-port.md 旧记载）：
// - 2FA / 应用锁：**用户手动输入的口令** 经 PBKDF2-SHA256(200000) 派生密钥；
// - 密保 / 股票 API Key：设备绑定随机主密钥（electron-store，32 字节 hex）；
// - 加密原语、信封格式两者完全一致。
//
// PoC 验收标准（P1）：用正确口令解密桌面端 twoFactorVaultPath 指向的真实 vault 文件，
// 并用其中 otpSecret 生成一致 TOTP。⚠️ PoC 通过前不得开发依赖 vault 的其他功能。
library;

/// PBKDF2 迭代次数（与桌面端 crypto.ts 的 PBKDF2_ITERATIONS 对齐）
const int kVaultPbkdf2Iterations = 200000;

/// 随机盐字节数（SALT_BYTES）
const int kVaultSaltBytes = 16;

/// GCM IV 字节数（IV_BYTES）
const int kVaultIvBytes = 12;

/// AES 密钥字节数（KEY_BYTES = 32 → AES-256）
const int kVaultKeyBytes = 32;

/// GCM 认证标签字节数（GCM_TAG_BYTES）
const int kVaultGcmTagBytes = 16;

/// 信封版本
const int kVaultEnvelopeVersion = 1;

/// KDF 标识（与桌面端字符串一致）
const String kVaultKdf = 'pbkdf2-sha256';
