# 文件互传（fileTransfer）双端方案与任务清单

> 状态：**方案草案，待用户确认后动码**（2026-09-06 依据双端代码勘察产出）。
> 实施完成后：本文件精简为协议与决策记录，实现细节回写 SKILL.md「局域网同步/功能域清单」等章节。
> 桌面端对应方案：`C:\cod\jianli\jianli-app\.zcode\skills\jianli-app\references\file-transfer-plan.md`（以桌面技能为契约基准，姊妹文档）。

## 一、需求

- 双端各新增一个页面【文件互传】：桌面端（Electron）⇆ 移动端（Flutter）局域网互发文件。
- 支持**批量**互传：一次选多个文件、逐文件串行传输、逐文件进度与成功/失败结果。
- 双端**对称**：都能发送、都能接收，复用现有类 LocalSend 设施（UDP 47123 发现 + HTTP 47124 数据面）。

## 二、勘察结论（方案依据，2026-09-06 实测）

### 移动端（本工程）
- 数据面：`lib/core/sync/sync_service.dart` L42-98，裸 `dart:io HttpServer` 绑 `SyncProtocol.dataPort`=47124，if-else 分派（/ping L52、/export L61、/sync L75、404 L96），**server 不在 main 启动，而是同步页 `_init()` 调 `startServer`**（有幂等守卫）→ 文件互传页入页同样调用即可，谁先开谁拉起，全程常驻直到进程退出。
- 发现：`lib/core/sync/sync_discovery.dart` —— `SyncDiscovery.scan()` 返回 `Map<ip, PeerDevice>`（L128-166，已含热点定向广播 `broadcastCandidates()`）；`PeerDevice{ip,name,id,platform}`（L26-52）。
- HTTP 客户端统一 dart:io `HttpClient`（`sendTable` L153-179 为 POST 先例，`req.add(utf8.encode(...))`）；**发文件流用 `req.addStream(file.openRead())`，无 http/dio 依赖，也不新增**。
- file_picker 12.2.0 静态 API：`FilePicker.pickFiles(...)`，先例（file_vault_page L257、bookshelf_page L99）都拿 `f.path` 直接当真实路径读——**多选参数名实施时先 grep 插件签名**。
- `crypto` ^3.0.7 / `path_provider` ^2.1.6 / `uuid` ^4.6.0 已有；**share_plus、open_filex、http、dio 均无**（v1 不引）。
- 接收文件落盘先例：电子书把外来文件拷进 `Documents/books/<uuid><ext>`（ebook_repository L44-48）；保险箱目录 `Documents/渐离App保险箱/`（file_vault_repository L34-39）→ 互传目录定为 `Documents/渐离App文件互传/`。
- drift：`app_database.dart` `schemaVersion = 1`（L66），`MigrationStrategy(onCreate: m.createAll())`，**onUpgrade 尚无先例，本功能写第一个迁移**；最简表模板 `tool_tables.dart` L73-85（QrTemplate）；列名必须 `.named('snake_name')`。
- 页面骨架先例：`sync_page.dart` L105-130（FScaffold + FHeader.nested + PageBanner + SectionHeader + AppCard）；`FDeterminateProgress(value: 0..1)` 可做逐文件进度条；顶层 StreamProvider 先例 `habit_providers.dart` L15-18（**禁 build 内联，雷区 #9**）。
- 路由先例 `/sync`（app_router.dart L180-183，`fadeSlidePage` 包装）；工具组入口 `hub_pages.dart` L67-73，`_Entry = (IconData, String, String, String, int)`，工具组已用 accent 0/1/2/3/5 → **互传用 4（粉）**。
- ⚠️ Android：`android/app/src/main/AndroidManifest.xml` **无任何 uses-permission**（INTERNET 只在 debug/profile manifest）；release 包需补 INTERNET 权限 + `usesCleartextTraffic="true"`（否则局域网明文 HTTP 被系统拦）。
- 图标名铁律：`FLucideIcons.arrowLeftRight` 用前先到 forui_lucide `lib/src/assets.g.dart` grep 验证。

### 桌面端（契约对端，详见桌面方案文档）
- 同一 47124 数据面原生 http server；`/file/*` 端点由新 `transferModule.ts` 经可插拔注册接入；接收目录 `<fileCachePath>/文件互传/`；接收成功经 fileNotify 蓝色路径通知；改主进程需重启 Electron。

## 三、协议设计 v1（文件互传，复用 47124，不新开端口与发现协议）

两端对称实现「发送客户端 + 接收服务端」。批量 = 一次 offer + 逐文件串行 data/end。

| 端点 | 方向 | 说明 |
|---|---|---|
| `POST /file/offer` | 发→收 | JSON `{tid, from:{name,id,platform}, files:[{fid,name,size,mime?}]}`；接收端回 `{ok:true, accepted:[fid...]}`；「自动接收」关闭时回 `{ok:false, reason:'rejected'}` |
| `POST /file/data?tid=&fid=` | 发→收 | **原始文件字节流**（带 Content-Length，全程流式、不落内存不 base64）；接收端先写 `<fid>.part`，回 `{ok:true, received:累计字节}` |
| `POST /file/end?tid=&fid=` | 发→收 | 单文件收尾：`.part` 改名为去重终名、写 file_transfer 历史、发接收通知，回 `{ok:true}` |

- `tid` = uuid 批次号；`fid` = 批次内序号（"1"、"2"…）。
- 文件名安全：接收端仅取 basename、过滤非法字符、重名追加 ` (n)`；**只允许落到专用接收目录**。
- 进度：发送端 `addStream` 前包一层字节计数流（节流 ~100ms 刷新 UI）；接收端在请求流上累计。
- 安全边界：与现有同步一致（明文、仅限受信局域网）；v1 默认自动接收，页面可关。
- 校验：v1 做 size 比对，sha256 完整校验列 P2。

**双端同构历史表 `file_transfer`（TEXT key 主键，设备本地记录，不入同步白名单）**：
`key`(uuid,每文件一条) / `tid` / `fid` / `direction`('send'|'receive') / `peer_name` / `peer_ip` / `file_name` / `size`(INTEGER) / `mime`(可空) / `path`(本地路径) / `status`('done'|'failed'|'canceled') / `created_at`(ISO 文本)

> drift 三大铁律照旧：列名 `.named()` 锁定 snake_case；getter 不叫 text/dateTime；行类名 `FileTransfer`（FileTransfers→FileTransfer 单数化确认）。

## 四、移动端任务清单

**新建（`lib/features/file_transfer/`，feature-first 原子拆分 + 中文注释）**
- [ ] M1 `services/transfer_client.dart`：发送客户端——offer → 逐文件流式 data（字节计数节流回调）→ end；批次可取消（剩余置 canceled）；历史写库。
- [ ] M2 `services/transfer_server.dart`：接收端——offer/data/end 三端点处理，注册进 SyncService 路由钩子；接收目录 `Documents/渐离App文件互传/`（不存在则 createSync）；`.part` 收尾改名去重；接收成功 `showFToast`。
- [ ] M3 `models/transfer_models.dart` + `repositories/transfer_repository.dart`（drift 历史读写，回写用 typed insert 触发 watch 流）+ `providers/file_transfer_providers.dart`（**顶层声明**：`transferHistoryProvider` StreamProvider、服务 provider）。
- [ ] M4 `components/file_transfer_page.dart`：FScaffold + PageBanner（粉 accent 4，统计=发现设备/已传文件数）+ 设备卡（扫描按钮 + 手动 IP 输入，模拟器填 `10.0.2.2`）+ 发送卡（选文件按钮 + 已选清单 + 逐文件 FDeterminateProgress + 取消）+ 记录列表（收/发双色图标 + 大小 + 时间）；入页 `_init()`：`startServer + startResponder`（幂等，同 sync 页）。

**修改**
- [ ] M5 `lib/core/sync/sync_service.dart`：加可插拔路由注册 API（如 `registerRouteHandler(bool Function(HttpRequest) matcher, Future<void> Function(HttpRequest) handler)`），/ping、/sync、/export 行为不变。
- [ ] M6 drift 表：新建 `lib/core/db/tables/file_transfer.dart` + `app_database.dart` 注册 + **schemaVersion 1→2 + onUpgrade 迁移**（`onUpgrade: (m, from, to) async => await m.createAll()`，drift 只建缺失表）→ **改表必须跑 build_runner**。
- [ ] M7 `lib/app/router/app_router.dart` 加 `/file-transfer`（GoRoute + fadeSlidePage）；`lib/features/hubs/hub_pages.dart` 工具组加 `(FLucideIcons.arrowLeftRight, '文件互传', '双端批量收发文件', '/file-transfer', 4)`。
- [ ] M8 `android/app/src/main/AndroidManifest.xml`：`<uses-permission android:name="android.permission.INTERNET"/>` + `<application android:usesCleartextTraffic="true" ...>`（release 必需）。
- [ ] M9 依赖：**不新增**（HttpClient/file_picker/crypto/path_provider/uuid 已有）；file_picker 多选参数先 grep 插件 12.x 签名再写。

**文档（实施后）**
- [ ] M10 SKILL.md：功能域清单加 file-transfer 行、「局域网同步」章节补文件端点、全局红线不变、维护说明记一条；本文档转决策记录。

## 五、桌面端任务清单（对端，概要）

- 主进程新模块 `electron/main/module/transfer/transferModule.ts`（发送客户端 + /file/* 端点 + 历史 + IPC + 事件推送），`syncModule.ts` 数据面改可插拔路由注册，`electron/main/index.ts` 注册 `initTransfer()`；preload 补 `on` 透传（限 `file-transfer:` 前缀）。
- 渲染端 `src/views/fileTransfer/`（DeviceList / TransferPanel / TransferLog + Pinia store），菜单四件套（router RouteNames、iconMap `ArrowLeftRight`、layout groupDefs、routeSetting 可见开关），layout 全局监听接收事件 → fileNotify。
- 建表 `file_transfer`（ensureTableExists，key TEXT）；接收目录 `<fileCachePath>/文件互传/`。
- 详见桌面方案 `references/file-transfer-plan.md`。

## 六、验证清单（实施后，flutter/dart 命令一律用户本地执行——分工铁律）

1. 桌面端重启 Electron；移动端用户跑 `flutter pub get → dart run build_runner build -d → flutter analyze（基线 0）→ flutter test（基线 5/5）→ flutter run -d emulator-5554`。
2. PC 发手机：批量 ≥3 文件（含大文件），逐文件进度 + 结果；手机收到 `Documents/渐离App文件互传/`。
3. 手机发 PC：批量发送；PC fileNotify 蓝色路径通知 + 历史正确。
4. 手动 IP：模拟器填 `10.0.2.2` 直传。
5. 边界：重名去重 ` (n)`、非法文件名、接收方关自动接收 → 发送端被拒提示、取消批次 → 剩余 canceled。
6. 热点场景：手机开热点给 PC，从手机侧扫描发起（PC 侧扫描为已知受限，见可选项 A）。

## 七、v1 裁剪与可选项（需用户表态）

- **可选项 A（建议做）**：桌面 `scanPeers()` 移植本端已修的 `broadcastCandidates()` 定向广播，解决热点场景 PC 扫不到手机（动 syncModule.ts，需重启 Electron）。
- P2：sha256 完整校验；断点续传（data 分块 seq）；接收文件「打开/分享」（需引 share_plus）；移动端文件预览。
- P3：传输会话加密（与同步协议加密同一规划）。
- 不做：传输历史跨设备同步（设备本地）；云端中转（纯局域网直连）。
