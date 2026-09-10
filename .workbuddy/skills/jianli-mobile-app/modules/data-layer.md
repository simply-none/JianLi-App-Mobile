# 模块：数据层（drift）与 vault 加密

## 数据层（drift，对齐桌面端 db.sqlite）
- 移动端自有库文件：**`<filesDir>/databases/db.sqlite`**（`getApplicationSupportDirectory()`，path_provider 2.1.6 无 `getDatabasesPath()`，drift `LazyDatabase` 后台 isolate 打开；该路径对应 Auto Backup 的 `file` 域）。当前 `schemaVersion = 2`（v1 首批 25 张表 + v2 新增 `file_transfer`）。**扩表/加列必须 schemaVersion+1 并写 onUpgrade 迁移**（见下方「持久化与迁移铁律」）。
- 25 张表（22 张首批对齐桌面端 + countdown / qr_history / qr_template 三张工具表，工具表与桌面端同构）：habit_def、habit_checkin、todo_list、todo_tags、reminders、note_book、basic_info、pomodoro_status、pomodoro_mini_config、conversation×3、file_vault×2、ebook×7、screenshots、countdown、qr_history、qr_template。
  ⚠️ 库文件位置在 **2026-09-07 从 `app_flutter/db.sqlite`（getApplicationDocumentsDirectory() 返回的 `flutter` 目录）迁移到 `filesDir/databases/db.sqlite`（getApplicationSupportDirectory() 返回的 filesDir）**，原因见「持久化与迁移铁律」。老用户首次启动会单向拷贝旧文件，无需手动迁移。
- **三大铁律**：
  1. drift 默认把驼峰 getter 转下划线列名，而桌面端业务列多为驼峰 → 列名**必须用 `.named('桌面原名')` 显式锁定**（`@Named` 注解在 drift 2.34 不存在）。
  2. getter **不能叫 `text` / `dateTime`**（与 drift `Table.text()` / `Table.dateTime()` 构造方法冲突，导致整库解析失败、生成空壳 .g.dart）→ 改名 + `.named()` 锁定（现有先例：`annotatedText`、`recordedAt`）。
  3. **行类名会被单数化**：`TodoTags`→`TodoTag`、`Reminders`→`Reminder`、`Screenshots`→`Screenshot`，其余为 `XxxData`。
- 改表流程：改 `lib/core/db/tables/*.dart` → 在 `app_database.dart` 的 `@DriftDatabase` 注册 → 跑 build_runner（见下）→ 老用户需写迁移（增量、非破坏性）。
- 电子书表以桌面绝对路径 `file_path` 做关联键，移动端用 `content_hash` 做稳定映射，勿依赖 file_path。

### ⚠️ 数据库持久化与迁移铁律（2026-09-07 实测，防「更新版本/重装后数据被擦除」）
**现象**：用户反馈「更新版本重新安装后，主题对话等表的数据没了」。根因不是迁移逻辑，而是**沙盒被清**。

**根因（已对照 drift 2.34.4 源码核实）**：
1. `onUpgrade` 用 `m.createAll()`，而 drift 的 `createAll()` 生成的是 **`CREATE TABLE IF NOT EXISTS`**（`drift/src/runtime/migration.dart` 的 `_writeCreateTable`）。对「已存在」的表是空操作——**不重建、不清空任何行**。所以「原地升级」（Play 商店更新 / `flutter run` / `adb install -r`，沙盒保留）**永远不丢数据**。
2. 真正丢数据的是**干净卸载 + 重装**：Android 会把整个应用沙盒 `/data/data/com.jianli/` 删除，库文件 `db.sqlite` 随之消失，重装后 `onCreate` 建出空库 → 所有本地表都空。旧库位置 `app_flutter/db.sqlite` 是 `Context.getDir('flutter')` 目录，是 `filesDir` 的**兄弟目录**，**不在 Android 默认 Auto Backup 覆盖域内**（`app_flutter` 不是 files/databases/shared_prefs/externalFiles 标准根），所以默认备份也救不回来。

**修复（已落地，`lib/core/db/app_database.dart` + `AndroidManifest.xml` + `res/xml/backup_rules.xml` + `res/xml/data_extraction_rules.xml`）**：
1. **迁移非破坏性（原地升级保数据）**：`onUpgrade` 保持 `createAll()`（IF NOT EXISTS），并立铁律——**绝不能用 `destructiveFallback`**（drop 全表再重建 = 清空用户数据）。未来加列必须用 `m.addColumn(t, col)`，`createAll` 的 IF NOT EXISTS 不会给「已存在表」补列。
2. **库文件迁入 `file` 备份域（filesDir/databases）**：`_openConnection` 改读 `getApplicationSupportDirectory()/databases/db.sqlite`（path_provider 2.1.6 无 `getDatabasesPath()`，用 filesDir 等价落位；filesDir 对应 Auto Backup 的 `file` 域，默认覆盖根）；首次启动若新位置无文件而旧 `app_flutter/db.sqlite` 存在，则单向拷贝过去（旧文件保留，拷贝失败也不破坏原数据），老用户升级零丢失。
3. **开启 Android 自动备份**：`AndroidManifest.xml` 的 `<application>` 加 `android:allowBackup="true"` + `android:fullBackupContent="@xml/backup_rules"` + `android:dataExtractionRules="@xml/data_extraction_rules"`；两份 XML 显式 include `database/sharedpref/file/external` 域。这样卸载重装后，云备份会在首次启动前把 `databases/db.sqlite` 恢复回来，**所有表数据都不被擦除**。
4. **开发期提醒（治本靠流程）**：Auto Backup 依赖设备已登录 Google 账号且近期有备份，**调试期 `flutter run` 重装默认保留沙盒（不丢）；但手动「卸载再装」一定丢**（此时无云备份可恢复）。调试新版本务必用 `flutter run` / `adb install -r`，勿在验证数据时手动卸载。需要可携带备份时，后续可加「设置→导出/导入 db.sqlite」到用户可见目录（P3）。

**验证命令（用户在本地终端跑，Agent 不代跑构建）**：
```bash
# 1) 静态检查改动
dart analyze lib/core/db/app_database.dart
# 2) 生成/核对漂移产物（改了表定义才需要；本次只改了打开位置与 onUpgrade 注释，可跳过）
# dart run build_runner build -d
# 3) 真机/模拟器验证：先在有数据的旧 build 上操作，升级安装（adb install -r）后数据在；
#    若验证「卸载重装不丢」，需确认设备已登录账号且开启云备份，重装后等待恢复。
```

## 加密（vault 复刻）
- 入口：`lib/core/crypto/vault_codec.dart` —— `deriveVaultKey`（PBKDF2-SHA256 200000 次）、`decryptVaultEnvelope` / `encryptVaultEnvelope`（JSON 信封）、`encryptVaultBytes` / `decryptVaultBytes`（二进制流）。
- 两种密钥来源（与桌面端一致，勿混淆）：**2FA / 应用锁 = 用户口令派生**；**密保 / 股票 Key = 设备绑定随机主密钥**（重装失效）。移动端口令库文件存沙盒 `Documents/password-vault.jlv`，路径记 `basic_info.mobilePasswordVaultPath`。
- `.jlv` 二进制格式：`JLV1` 魔数 + metaLen + JSON + iv + ct，解析在 `features/file_vault/services/jlv_format.dart`（新旧格式兼容，与 PC 完全互通）。
- TOTP：`features/twofactor/services/totp_service.dart`（RFC 6238 全算法，向量化测试护住）；otpauth URI 解析在 `services/otpauth_parser.dart`。
- 纯 Dart PBKDF2 200000 次解锁约数秒；提速可接 `cryptography_flutter` 走平台实现（P2）。

