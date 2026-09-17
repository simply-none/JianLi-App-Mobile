# 模块：数据层（drift）与 vault 加密

## 数据层（drift，对齐桌面端 db.sqlite）
- 移动端自有库文件：默认落在系统 **`Download/渐离App/db.sqlite`**（公共 Download，需「所有文件访问」MANAGE_EXTERNAL_STORAGE，API30+ 才有此要求；该目录不在应用沙盒内，**卸载/重装不会被清**，文件管理器可直接浏览）。未授权「所有文件访问」或 非 Android → 回退沙盒 `<filesDir>/databases/db.sqlite`（`getApplicationSupportDirectory()`，path_provider 2.1.6 无 `getDatabasesPath()`，drift `LazyDatabase` 后台 isolate 打开）。落位与「首启从最新候选源单向拷贝」的迁移逻辑收口在 `lib/core/db/db_location.dart`。当前 `schemaVersion = 3`（v1 首批 25 张表 + v2 新增 `file_transfer` + v3 给 `reminders` 加 `delivery` 列）。**扩表/加列必须 schemaVersion+1 并写 onUpgrade 迁移**（见下方「持久化与迁移铁律」）。
- 25 张表（22 张首批对齐桌面端 + countdown / qr_history / qr_template 三张工具表，工具表与桌面端同构）：habit_def、habit_checkin、todo_list、todo_tags、reminders、note_book、basic_info、pomodoro_status、pomodoro_mini_config、conversation×3、file_vault×2、ebook×7、screenshots、countdown、qr_history、qr_template。
  ⚠️ 库文件位置在 **2026-09-07 从 `app_flutter/db.sqlite`（getApplicationDocumentsDirectory() 返回的 `flutter` 目录）迁移到 `filesDir/databases/db.sqlite`（getApplicationSupportDirectory() 返回的 filesDir）**，原因见「持久化与迁移铁律」。老用户首次启动会单向拷贝旧文件，无需手动迁移。
  ⚠️ **库文件默认位置 2026-09-17 再从 `filesDir/databases` 迁到公共 `Download/渐离App`（需求：重装/卸载不丢数据）**：详见下方「持久化与迁移铁律」第 5 点。落位与首启迁移在 `lib/core/db/db_location.dart`；外部数据库导入（按主键合并）在 `lib/core/db/db_import.dart`，入口在「数据管理」页（`features/data_management`）。
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
5. **库默认落位公共 Download/渐离App（2026-09-17 新增，根治「重装丢数据」）**：`_openConnection` 改调 `lib/core/db/db_location.dart` 的 `resolveDefaultDatabaseFile()`，优先返回 `Download/渐离App/db.sqlite`（需 `MANAGE_EXTERNAL_STORAGE`，复用 `public_downloads.dart` 的 `hasPublicDownloadsAccess` 判定）；未授权则回退沙盒 `filesDir/databases/db.sqlite`。**首启若目标文件不存在，从候选源里挑「修改时间最新」的一个单向拷贝**（候选 = 沙盒当前位置 / 更旧 `documents/app_flutter` / 可读时的公共 Download），避免权限来回开关时沙盒旧副本覆盖 Download 新数据导致静默丢数据。**首启（仅 API30+ 未授权且未询问过）经 `requestDbStoragePermissionOnce` 申请一次「所有文件访问」，让库默认落在 Download**；标记 `basic_info.dbFirstRunPermAsked` 去重，不在回前台路径反复弹（红线 #16）。用户也可在「数据管理」页点「迁移到公共存储」手动迁（迁后须重启 App 才切到 Download 上的库）。⚠️ 与 `public_downloads` 的区别：db.sqlite 是活动数据库，**不要对其做 MediaStore 扫描**（非媒体），也不要当导出物处理。

### ⚠️ 外部数据库导入（2026-09-17 新增，需求#2）
- 入口：「数据管理」页（`features/data_management/data_management_page.dart`）→「导入数据库」→ `file_picker` 选 `.sqlite/.db/.sqlite3` → 底部抽屉确认 → `importDatabaseFile(db, path)`（`lib/core/db/db_import.dart`）。
- 语义：**非破坏式按主键合并（upsert）**。只读打开源库（`AppDatabase.forFile(readOnly:true)`），逐「数据表」`SELECT *` → `INSERT OR REPLACE`（与局域网同步 upsert 语义一致）：源有本地也有 → 被源覆盖；源无本地有 → 保留。**排除 `basic_info` 配置表**（不动本地 2FA 保险库路径等设置）。
- 容错：源库必须含 `basic_info` 表才认作本 App 数据库，否则拒绝；逐表按本表实际列（`PRAGMA table_info`）过滤源行字段，兼容双端 schema 差异；整段包事务，失败整体回滚；写完后手动 `notifyUpdates` 触发 watch 流刷新（drift 的 `customStatement` 不自动通知，见 sync_service 同款坑）。

### ⚠️ 数据库导出（2026-09-17 新增，需求#1/#2 配套备份）
- 入口：「数据管理」页（`features/data_management/data_management_page.dart`）→「导出数据库」→ `exportDatabaseFile(db, context:)`（`lib/core/db/db_export.dart`）。
- 语义：**一致性独立快照**。活动库是 drift 热连接（常开 WAL），直接 `File.copy` 活文件会拷到半截 WAL 数据、在别的端打开报损坏 → 故用同连接内 `VACUUM INTO '目标路径'` 生成「仅含已提交数据」的独立 `.sqlite`（不依赖 -wal/-shm，可被本 App 或桌面端直接打开/导入）；保留 `PRAGMA wal_checkpoint(TRUNCATE)` + 直接拷贝的兜底分支。
- 落盘/权限/反馈**复用 `app/ui/file_export.dart` 约定**：`ensurePublicDownloadsPermission` 申请「所有文件访问」→ `moduleDownloadDir('渐离App导出')` 落到系统 `Download/渐离App导出/`（未授权回退沙盒 `Documents/渐离App导出/`），写后 `scanFileInMediaStore` 触发文件管理器可见，成功/失败均顶部 toast 提示真实路径（与主题对话/笔记/习惯/电子书导出完全一致）。文件名 `db_导出_<YYYYMMDD_HHmmss>.sqlite`。

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

