# 文件互传（fileTransfer）移动端方案 · 决策记录

> 状态：**已实施完成（2026-09-06）**。本文件由方案草案转为决策记录，保留协议设计与实施决策；实现细节见桌面端技能 `references/modules/file-transfer.md`（契约基准）。
> 桌面端姊妹文档：`C:\cod\jianli\jianli-app\.workbuddy\skills\jianli-app\references\file-transfer-plan.md`（同协议、同历史表）。
> **2026-09-06 追加完成后续（第一批）**：sha256 完整性校验（双端）/ 历史 `error` 失败原因列（双端）/ 发送端 `peer_name` 经 offer `me` 回填 / 移动端历史「打开 / 分享」（`open_filex`+`share_plus`，**新增两个依赖**）/ 桌面端历史「打开文件 / 打开所在文件夹」/ 批次总进度·速率·ETA。改 `tables/file_transfer.dart` 后**须重跑 `dart run build_runner build -d`**。
> **2026-09-06 追加完成后续（第二批 · M12 · 全部剩余增强已落地）**：#9 重名覆盖策略（rename/overwrite，读 `TransferSettings.renameStrategy`）/ #11 最近设备记忆（`models/recent_peers.dart` + shared_preferences 持久化，离线可见）/ #13 断点续传（offer 响应回 `accepted:[{fid,resumeFrom}]` + data `?from=N` 追加写 + hash 播种）/ #14 会话加密（AES-256-CTR，默认关；offer 协商 `enc:{key,iv}` base64、data 密文流）/ #15 接收询问模式（关自动接收时经 `askStream` 弹窗等 UI 答复，不再直接拒）/ #16 磁盘预估（接收端软预估总大小）/ #17 并发守卫（`_activeReceiveTid`/`_activeSendTid`，同刻仅一收发批次，429 busy）/ #19 后台保活（`wakelock_plus` 发送全程持锁，新增依赖 + `WAKE_LOCK` 权限）/ #20 历史分页（`list({limit,offset})`）+ 超 1000 自动清理（`trim(1000)`）。**协议保持向后兼容**：加密/续传/询问均默认关或协商，未开启时完全退化为既有明文行为。

> **2026-09-06 追加（第三批）**：**接收目录改为系统 `Download/渐离App文件互传/`**——公共 Download 在 Android 10+ 受分区存储保护，新增依赖 `permission_handler`(^13.0.2)；`AndroidManifest.xml` 加 `MANAGE_EXTERNAL_STORAGE` + `WRITE_EXTERNAL_STORAGE(maxSdkVersion=32)` + `requestLegacyExternalStorage="true"`；入页 `_ensurePublicDownloadsPermission()` 申请（API 30+ 自动跳「所有文件访问」设置页，拒绝仅记日志），`receiveDir()` 按权限判定：通过 → 公共 Download，未授权/创建失败 → 回退沙盒 `Documents/渐离App文件互传/`（iOS 恒走回退）。续传追加写/改名/去重/删除是真实路径 dart:io 逻辑，零改动；open_filex FileProvider 覆盖 external-path，「打开/分享」不受影响。
> **2026-09-06 追加（第四批）**：**UI 记录区只显示当次批次**——页面 `_batchTid` 由发送首条进度 / `TransferServer.batchTidStream`（offer 登记时推 tid）切换，记录按 `r.tid == _batchTid` 过滤 `watchAll` 流；移除「加载更多」分页（#20 的 DB `list/trim` 照旧）。PC 端同语义（`loadHistory()` 只留最新 tid、`onProgress` 新 tid 清旧展示、启动不拉历史）。
> **2026-09-06 追加（第五批小改）**：**「传输记录」标题下方新增存储位置提示行**——`_receiveHint` 在 `_ensurePublicDownloadsPermission()` 末尾按授权结果刷新（Android 授权 → `系统 Download/渐离App文件互传/`；未授权 → 「未开启存储权限，接收的文件暂存应用沙盒；请点击记录中的『分享』，通过其他应用保存」；iOS → `应用 Documents/渐离App文件互传/`），渲染在 SectionHeader 与 AppCard 之间（mutedForeground xs），文案用 `kTransferDirName` 拼接不硬编码目录名。

## 一、需求（已落地）
- 移动端新增【文件互传】页面（工具组入口）：与 PC（Electron）局域网互发文件。
- **批量**互传：一次选多文件、逐文件串行、逐文件进度与成败结果。
- **双端对称**：都能发、都能收，复用既有类 LocalSend 设施（UDP 47123 发现 + HTTP 47124 数据面）。

## 二、协议 v1（文件互传，复用 47124，已落地）

两端对称实现「发送客户端 + 接收服务端」。批量 = 一次 offer + 逐文件串行 data/end。

| 端点 | 方向 | 说明 |
|---|---|---|
| `POST /file/offer` | 发→收 | JSON `{tid, from:{name,id,platform}, files:[{fid,name,size,mime?}]}`；收端回 `{ok:true, accepted:[fid...]}`；「自动接收」关闭时回 `{ok:false, reason:'rejected'}` |
| `POST /file/data?tid=&fid=` | 发→收 | **原始文件字节流**（带 Content-Length，全程流式、`req.addStream`）；收端先写 `<fid>.part`，回 `{ok:true, received:累计字节}` |
| `POST /file/end?tid=&fid=` | 发→收 | 单文件收尾：`.part` 改名去重终名、写 file_transfer 历史、发接收通知，回 `{ok:true, error?}`；**请求体 JSON 携带本文件 sha256 `{hash}`，接收端比对** |

- `tid`=uuid 批次号；`fid`=批次内序号（"1"、"2"…）。
- 文件名安全：收端仅取 basename、过滤非法字符、重名追加 ` (n)`；只允许落 `Download/渐离App文件互传/`（未授权回退沙盒 `Documents/渐离App文件互传/`，2026-09-06 第三批）。
- 进度：发送端 `addStream` 前包一层字节计数流（节流 ~100ms）；接收端在请求流上累计。
- 安全边界：与同步一致（明文、仅限受信局域网）；v1 默认自动接收，页面可关。
- 校验：**size 比对 + sha256 完整性校验双保险（2026-09-06 已实施）**。发送端 data 阶段经 `crypto.sha256.bind(file.openRead())` 算 sha256，随 `/file/end` 的 `{hash}` 带出；接收端 `/file/data` 边收边算 sha256 暂存（`_receiveHashing`），`/file/end` 比对，不符则删坏文件、历史记 `failed`(error=`hash mismatch`)。

**双端同构历史表 `file_transfer`（TEXT key 主键，设备本地记录，不入同步白名单）**：
`key`(uuid,每文件一条) / `tid` / `fid` / `direction`('send'|'receive') / `peer_name` / `peer_ip` / `file_name` / `size`(INTEGER) / `mime`(可空) / `path`(本地路径) / `status`('done'|'failed'|'canceled') / `error`(失败原因，可空) / `created_at`(ISO 文本)

> drift 三大铁律照旧：列名 `.named()` 锁定 snake_case；getter 不叫 text/dateTime；行类名 `FileTransfer`（单数化）。

## 二之一、协议增强（M12，向后兼容）

在原 v1 三端点之上叠加下列字段/行为；**未开启时完全退化为既有明文行为**，老版本双端仍可互通。

- **#9 重名策略**：接收端 `TransferSettings.renameStrategy`——`rename`（默认，追加 ` (n)`）或 `overwrite`（先删同名再改名）。页面「重名时覆盖」开关写入并持久化。
- **#11 最近设备**：扫描/发送过的对端写入 shared_preferences（键 `transfer_recent_peers`，最多 20 条，含 `lastSeen`）；页面「最近设备」区离线也展示，点「发到此处」重发、「忘记」剔除。与 PC 端 `store._transfer_recent` 同构。
- **#13 断点续传**：offer 响应 `accepted` 每项带 `resumeFrom`（收端按 `recvPartName(name,size)` 稳定名查已有 `.part` 字节数）；发送端 data 请求带 `?from=resumeFrom` 并从该偏移读流（进度起点同步 `countingStream(initial:)`），接收端 append + 用已有字节给 hash 播种。⚠️ **加密批次不做续传**（CTR keystream 无法任意字节对齐，`encSession != null` 时 `resumeFrom` 强制 0、发送端 `from=0`）。
- **#14 会话加密（默认关）**：发送端开启且密钥就绪时，offer 带 `enc:{key,iv}`（各 32/16 字节 base64，密钥用 `cryptography` 随机源 `newSecretKey()`/`newNonce()` 生成）；对端确认后 `offer` 响应 `enc:true`，发送端 data 经 `AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty).encryptStream(...)` 发密文流，接收端 `decryptStream(req, secretKey, nonce, mac: Mac.empty)` 边解密边落盘+算 hash（scheme 见 `models/transfer_utils.dart` encode/decodeEncSession）。**需收发双端均开启**；互操作失败时整批失败、可重发。
- **#15 接收询问模式**：`autoAccept=false` 时，offer 不再直接拒（`403 rejected`），改为经 `askStream`（`StreamController<IncomingAsk>.broadcast`）推事件给页面，弹 `showFDialog` 等用户「接收/拒绝」；`answerAsk(tid, bool)` 唤醒 `_handleOffer` 中的等待；60s 超时默认拒绝（避免 UI 未回应挂起）。
- **#16 磁盘预估**：接收端 offer 阶段累计 `total`，仅软预估（移动端无可靠 free-space API，做预估不硬拒）；PC 端用 `fs.statfsSync` 取剩余空间，不足回 `507`。
- **#17 并发守卫**：同刻仅一个接收批次（`_activeReceiveTid`）与一个发送批次（`_activeSendTid`）；冲突回 `429 busy`。
- **#19 后台保活**：发送全程 `WakelockPlus.enable()/disable()`（try/catch 容错），避免手机息屏中断。新增依赖 `wakelock_plus` + `AndroidManifest` 加 `WAKE_LOCK`。
- **#20 历史分页 + 自动清理**：`TransferRepository.list({limit,offset})` 供分页；`trim(1000)` 在 `/file/end` 后执行，超出删最旧。**2026-09-06 四批：UI 记录区改为只显示当次批次**（页面按 `_batchTid` 过滤 `watchAll` 流，批次 tid 来自发送首条进度 / `TransferServer.batchTidStream`；移除「加载更多」；DB 写入照旧）。

## 三、实施决策与偏差（相对原草案）
- **可插拔路由**：`SyncService` 新增模块级 `registerRouteHandler(matcher, handler)`，server 监听循环先查 `_extraRoutes` 再回退原 if 分支；`TransferServer` 在创建时注册 `/file/*` 三端点。
- **新增依赖（2026-09-06 后续批次）**：为历史「打开 / 分享」引入 `open_filex`(^5.8.0) + `share_plus`(^11.0.0)；其余仍纯 dart:io `HttpClient` + 既有 file_picker/crypto(^3.0.7)/path_provider/uuid。HttpClient 发流用 `req.addStream(file.openRead())`。
- **drift 首个迁移**：`schemaVersion 1→2` + `MigrationStrategy(onUpgrade: (m, from, to) async => await m.createAll())`（drift 只建缺失表）；改表后**必须 `dart run build_runner build -d`**。
- **页面**：`FileTransferPage`（ConsumerStatefulWidget）—— FScaffold + FHeader.nested + PageBanner 粉(4) + 设备扫描/手动 IP(`10.0.2.2`) + 选文件(file_picker 多选) + FDeterminateProgress 逐文件进度 + FSwitch 自动接收 + 收发记录列表；入页 `_init()` 调 `ref.read(transferServerProvider)`、`startServer`、`startResponder`（均幂等）。
- **工具组入口**：`hub_pages.dart` 加 `(FLucideIcons.arrowLeftRight, '文件互传', '双端批量收发文件', '/file-transfer', 4)`（`arrowLeftRight` 已 grep forui_lucide 验证）。
- **AndroidManifest**：补 `<uses-permission android:name="android.permission.INTERNET"/>` + `<application android:usesCleartextTraffic="true">`（release 必需，否则局域网明文 HTTP 被拦）。

## 四、移动端任务完成状态（M1–M10）
- [x] M1 `services/transfer_client.dart`：发送客户端——offer → 逐文件流式 data（字节计数节流）→ end；`cancel()`/`reset()`；历史写库
- [x] M2 `services/transfer_server.dart`：接收端三端点，注册进 SyncService 路由钩子；目录 `Documents/渐离App文件互传/`；`.part` 收尾改名去重 + 写历史
- [x] M3 `models/transfer_models.dart` + `repositories/transfer_repository.dart` + `providers/file_transfer_providers.dart`（**顶层** `transferHistoryProvider`）
- [x] M4 `components/file_transfer_page.dart`：PageBanner 粉(4) + 设备卡 + 发送卡 + 记录列表；入页 `_init()` 拉起 server/responder
- [x] M5 `sync_service.dart`：加 `registerRouteHandler` 可插拔路由
- [x] M6 drift：`tables/file_transfer.dart` + `app_database.dart` 注册 + schemaVersion 1→2 + onUpgrade
- [x] M7 `app_router.dart` `/file-transfer` + `hub_pages.dart` 入口（accent 4）
- [x] M8 `AndroidManifest.xml` INTERNET + cleartext
- [x] M9 依赖：不新增（HttpClient/file_picker/crypto/path_provider/uuid 已有）
- [x] M10 文档：SKILL.md 功能域清单 + 局域网同步章节 + 维护说明；本文档转决策记录
- [x] **M11（2026-09-06 第一批）**：`tables/file_transfer.dart` 加 `error` 列（须 `build_runner` 重生）→ `transfer_repository.dart` `add(error:)`；`transfer_server.dart` 边收边算 sha256 + `/file/end` 双重校验 + offer 回传 `me` + 收完回收 `_offers`；`transfer_client.dart` 算 sha256 随 `/file/end` 发送 + 取 offer `me` 填 `peer_name` + 失败写 `error`；`file_transfer_page.dart` 历史成功记录加「打开」(`OpenFilex.open`) /「分享」(`SharePlus`) + 失败显示 `error`
- [x] **M12（2026-09-06 第二批 · 全部剩余增强已落地）**：
  - `models/transfer_models.dart`：`TransferSettings` 加 `renameStrategy`/`enc` + `load()/persist()`（shared_preferences）；`countingStream` 加 `initial` 参数（续传进度起点）。
  - `models/transfer_utils.dart`（新建）：纯函数 `sanitizeFileName`/`recvPartName`/`encodeEncSession`/`decodeEncSession`（双端一致，单测兜底）。
  - `models/recent_peers.dart`（新建）：`RecentPeer` + `RecentPeers`（shared_preferences 持久化，#11）。
  - `services/transfer_server.dart`：#9 重名策略 / #13 续传（`resumeFrom` + 追加写 + hash 播种）/ #14 加密（`decodeEncSession` + `decryptStream`）/ #15 询问（`askStream` + `answerAsk` + 60s 超时）/ #17 并发守卫（`_activeReceiveTid`）/ #20 `trim(1000)`；`IncomingAsk` 事件类。
  - `services/transfer_client.dart`：#13 续传（读 `resumeFrom` + `from=` + `countingStream(initial)`）/ #14 加密（`newSecretKey`/`newNonce` 生成密钥 + `encryptStream`）/ #17 并发守卫（`_activeSendTid`）/ #19 后台保活（`WakelockPlus`）。
  - `repositories/transfer_repository.dart`：加 `list({limit,offset})` / `count()` / `trim(maxRows)`（#20）。
  - `components/file_transfer_page.dart`：最近设备区（#11）/ 重名策略开关（#9）/ 加密开关（#14）/ 接收询问弹窗（订阅 `askStream`，#15）/ 历史分页「加载更多」（#20）。
  - `pubspec.yaml` 加 `wakelock_plus: ^1.8.0`（#19）；`android/app/src/main/AndroidManifest.xml` 加 `WAKE_LOCK`（#19）。
  - `test/features/file_transfer/transfer_utils_test.dart`（新建，#28）：sanitize/recvPartName/密钥 base64 往返。
  - ⚠️ 本批未改 `tables/`（沿用既有 `error` 列），**无需迁移**；仅 `pubspec.yaml` 加依赖须 `flutter pub get`。

## 五、验证清单（命令由用户本地执行——分工铁律）
1. `flutter pub get → dart run build_runner build -d → flutter analyze（基线 0）→ flutter test（基线 5/5）→ flutter run -d emulator-5554`。
2. PC 发手机：批量 ≥3 文件（含大文件），逐文件进度 + 结果；手机 `Download/渐离App文件互传/` 收到（未授权则沙盒 `Documents/渐离App文件互传/`）。
3. 手机发 PC：批量发送；PC `fileNotify` 蓝色路径通知 + 历史正确。
4. 手动 IP：模拟器填 `10.0.2.2` 直传。
5. 边界：重名去重 ` (n)`、非法文件名、接收方关自动接收→发送端被拒、取消批次→剩余 canceled。
6. 热点场景：手机开热点给 PC，从手机侧扫描发起（PC 侧扫描受限，见可选项 A）。
7. sha256 校验：正常收发两端历史均 `done`；失败记录 `error` 非空（size mismatch / hash mismatch / peer rejected），且不弹通知。
8. 历史可操作：成功记录点「打开」用系统关联程序打开、「分享」调系统分享面板。

## 六、v1 裁剪与后续（P2/P3）
- [x] **可选项 A（桌面侧已完成，2026-09-06）**：`scanPeers()` 定向广播 + 网关单播，解决热点场景 PC 扫不到手机。
- [x] **sha256 完整校验（已完成，2026-09-06）**：双端流式算 sha256，发送端经 `/file/end` 的 `{hash}` 带出，接收端比对；不一致删坏文件、历史记 `failed`(error=`hash mismatch`)。
- [x] **接收文件「打开/分享」（已完成，2026-09-06）**：新增 `open_filex`+`share_plus`，历史成功记录可「打开」「分享」。
- [x] **P2 断点续传（已完成，2026-09-06 第二批）**：offer 响应带 `resumeFrom`、data 带 `?from=N` 追加写 + hash 播种；加密批次整文件重发（见 §二之一 #13）。
- [x] **P3 会话加密（已完成，2026-09-06 第二批）**：AES-256-CTR，offer 协商 `enc` 字段、data 密文流；默认关、向后兼容（见 §二之一 #14）。
- [x] **#9 重名覆盖策略 / #11 最近设备 / #15 接收询问 / #16 磁盘预估 / #17 并发守卫 / #19 后台保活 / #20 历史分页+自动清理**（均已完成，2026-09-06 第二批，见 §二之一）。
- 不做：传输历史跨设备同步（设备本地）；云端中转（纯局域网直连）。
