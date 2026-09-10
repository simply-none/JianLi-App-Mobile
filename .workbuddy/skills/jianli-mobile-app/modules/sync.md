# 模块：局域网同步与双端契约

## 局域网同步（类 LocalSend，协议 v1，双端已全通）
- 发现：UDP 广播端口 **47123**，请求包 `JIANLI_SYNC_DISCOVER_V1`，应答 `JIANLI_SYNC_INFO_V1|{json:{name,id,platform}}`（`core/sync/sync_discovery.dart`；PC 端 `syncModule.ts` 同协议应答）。
- **⚠️ 热点场景发现雷区（2026-09-05 修复）**：扫描**不能只发 255.255.255.255**——手机开热点给 PC 时，热点接口不是手机的默认路由，受限广播从默认网络口出去、到不了热点网段（PC 收不到请求 → 不应答），表现为「PC 能搜到手机、手机搜不到 PC」的不对称。修复：`scan()` 走 `broadcastCandidates()` **逐 IPv4 网卡发 `/24` 定向广播（x.y.z.255）+ 全网广播兜底**，OS 按直连路由选对网卡，应答按 ip 去重。若修复后仍搜不到 PC，优先查 Windows 防火墙对 Electron 入站 UDP 47123 的放行（手动 IP 兜底仍可用）。
- 数据面：HTTP 端口 **47124** —— `GET /ping` 设备信息、`POST /sync`（body `{table, rows}`）、`GET /export?table=`（对端拉取）。
- **文件互传（类 LocalSend 扩展，协议 v1，双端对称）**：复用同一 47124 数据面，新增 `POST /file/offer` / `POST /file/data?tid=&fid=&from=`(原始字节流，`from=` 为续传偏移) / `POST /file/end?tid=&fid=` 三端点（注册进 SyncService 可插拔路由 `registerRouteHandler`）；批量=一次 offer + 逐文件串行 data/end；收端写 `<fid>.part` → 改名去重 → 写 `file_transfer` 历史（`key` TEXT 主键，设备本地、不入同步白名单）；v1 默认自动接收（页面可关，关后进入**询问模式**弹窗等 UI 答复，不再直接拒）；校验 size 比对 + sha256 双保险（发送端随 `/file/end` 带 `{hash}`，接收端比对）；接收目录 `Download/渐离App文件互传/`（Android 需存储权限「所有文件访问」，入页申请；未授权/创建失败回退沙盒 `Documents/渐离App文件互传/`，iOS 恒走沙盒回退）。**增强（2026-09-06 二批，均向后兼容）**：#9 重名覆盖策略（rename/overwrite，读 `TransferSettings`）/ #11 最近设备持久化（shared_preferences，`RecentPeers`，离线可见）/ #13 断点续传（offer 回 `resumeFrom` + data `from=` 追加写 + hash 播种）/ #14 会话加密（AES-256-CTR，默认关，offer 协商 `enc` 字段、data 密文流）/ #15 接收询问（`askStream` + `showFDialog`）/ #17 并发守卫（429 busy）/ #19 后台保活（`wakelock_plus`）/ #20 历史分页 + 超 1000 自动清理（DB 侧；**UI 记录区只显示当次批次**，页面按 `_batchTid` 过滤 `watchAll` 流，批次 tid 来自发送首条进度 / `TransferServer.batchTidStream`）。与桌面端同协议、同历史表结构。
- 白名单 12 张表（2026-09-05 加入主题对话三表）：habit_def / habit_checkin / todo_list / todo_tags / note_book / basic_info / countdown / qr_history / qr_template（TEXT 主键 key）+ conversation_theme / conversation / conversation_tag（**INTEGER 自增 id 主键**，行内携带 id 值，`INSERT OR REPLACE` 按 id 幂等；桌面端 `tablePk()` 同步适配）。行全列 toString 后按主键幂等写；写入前按 `PRAGMA table_info` 过滤实际存在的列，双端 schema 差异（桌面端旧 SQL 层遗留列）免疫。
- **模拟器雷区**：NAT 广播不通扫不到宿主 → 同步页支持手动填 IP，Android 模拟器固定填 `10.0.2.2`；真机走正常广播。PC 端同步入口：系统与资源 → 局域网同步（扫描 / 手动 IP(ip:port) / 推送 / 拉取）。
- vault 类数据跨设备：密钥为设备绑定/口令派生，**不能直传设备密钥**，需用户口令重新封装（会话加密 P3）。

### ⚠️ 同步写入必须手动通知 watch 流（2026-09-07 定位：「拉取成功但界面空白」）
**现象**：同步日志显示「已拉取 conversation：5 行」等成功记录（说明数据确实拉到了、也写进库了），
但移动端**所有**列表页（主题对话 / 待办 / 笔记 / 习惯…）**全都显示不出**刚同步来的数据。

**根因（已对照 drift 2.34.4 源码核实，非迁移逻辑、非列不匹配）**：
1. 写入本身是成功的——`_upsertRow` 用 `customStatement` 执行 `INSERT OR REPLACE`，SQLite 层面行已落库，
   日志 `written` 计数也为真（此前还额外确认：`appDatabaseProvider` 是普通 `Provider` 单例，
   sync 与 UI 共用同一 `AppDatabase`、同一库文件，不存在「写到别的库」）。
2. 真正的坑：drift 的 **`customStatement` 不会自动通知（invalidate）`.watch()` 查询流**。
   drift 源码 `lib/src/runtime/api/connection_user.dart` 第 429–432 行明确写着：
   > "This method does **not** update stream queries on this drift database. To run custom statements
   > that update data, please use customInsert or customUpdate instead. You can also call
   > **markTablesUpdated** manually after awaiting customStatement."
3. 后果：列表页的 `StreamProvider`（`watchThemes()` / `watchMessages()` / 笔记流…）在拉取后**不重跑查询**，
   一直返回拉取前的旧快照（通常是空列表）→ 「记录说拉到了、界面啥也没有」。
   **与下方「笔记标签」小节那条「勿用 customUpdate，后者不会使 query 流失效」是同一类坑**，
   只是同步这条路径一直没人给 `customStatement` 补通知。

**修复（已落地 `lib/core/sync/sync_service.dart`）**：
1. `_upsertRow` 改为 `Future<bool>`（返回是否真的写入了至少一列）；`cols.isEmpty`（列名全部对不上）时不写——
   让上层 `written` 反映**真实写入**而非尝试次数，日志不再虚报。
2. **拉取（`fetchTable`）与推送（`POST /sync`）两个分支，各自在整表写入循环结束后**调用一次
   `_db.notifyUpdates({TableUpdate(table)})` 手动触发刷新（放在循环**外**，避免逐行刷新）。
   走 `notifyUpdates` 而非 `markTablesUpdated`，是因为 `TableUpdate(表名字符串)` 直接吃表名，
   无需建「表名 → drift Table 对象」映射，类型更安全。
3. 本文件补 `import 'package:drift/drift.dart';`——**`app_database.dart` 的 import 不会向下传递**，
   不补则 `TableUpdate` 不可见（编译错误）。

**铁律（改同步/新增写库逻辑时必须遵守）**：
- 凡走 `customStatement` / `customUpdate` / `customInsert` 等**原始 SQL 写库，写后必须手动通知**
  （`notifyUpdates({TableUpdate(表名)})` 或 `markTablesUpdated([Table对象])`），否则该表 `.watch()` 永不刷新。
- 能用 drift **typed API**（`into().insertOnConflictUpdate(...)` / `update()` / `delete()`）就优先用——
  它们会自动通知 watch 流（笔记标签回写即走 typed，见下节）。
- 本工程原始 SQL 写库目前**只有 `_upsertRow` 一处**，改它时两个 `notifyUpdates` 别漏；新增同类逻辑照抄此模式。

### ✅ 两端共享同步日志（2026-09-07 落地：被动端自记 + 中性统一格式）
**现象**：只有**主动操作**的那端看得到同步日志——手机拉取/推送只有手机记，PC 推送/拉取只有 PC 记；被动端（被推 / 被拉）UI 完全静默。

**根因**：两端日志都只记录「自己主动发起」的动作。
- 手机：日志原先是 `_SyncPageState._logs`（**页面级内存**），只有 `_send`/`_fetch` 追加；服务层够不着，被动事件无处记录。
- PC：日志是 Pinia `useSync.logs`，只有 `push`/`pull`/`scan` 追加；被动事件只在主进程 `console.log`（`/export`、`/sync` 分支），UI 拿不到。

**设计（关键：让两端产出字面相同的条目）**：
- 文案只写「**动作 + 表 + 行数**」，**不写「谁→谁」**——各端视角不同（我→对端 / 对端→我），
  且被动端无从得知对端平台，写了必然不一致。
- 动作判定两端都能**独立得出，无需任何协议字段**：
  - **推送** = 我调用 `sendTable/pushTables`（主动推），**或** 我处理了 `POST /sync`（被动收）
  - **拉取** = 我调用 `fetchTable/pullTables`（主动拉），**或** 我处理了 `GET /export`（被动供）
- 行数统一取「本次传输行数」（接收端写入数 / 发送端导出数，正常相等）。
- 于是同一次事件两端是同一行，例如 `16:30:12  推送 todo_list：5 行`。
- 注：扫描 / 手动添加设备是**本机发现行为**，天然只有本机有，两端不会相同（可接受）。

**改动**：
- 新增 `lib/core/sync/sync_log.dart`：`SyncLogLevel` / `SyncLogEntry` / `SyncLogController` / `syncLogProvider`
  （`NotifierProvider`，新→旧，上限 **50** 与 PC 对齐，**仅内存态**，重启清空）。
  放 `core/sync/` 是为了让 `SyncService` 与页面都能用，**避免 core→feature 反向依赖**。
- `SyncService` 构造加第二参 `SyncLogController`；`syncServiceProvider` 用
  `ref.read(syncLogProvider.notifier)` 注入。四个分支各记一条：
  `fetchTable`(拉) / `sendTable`(推) / `POST /sync` 处理(被推→记「推送」) / `GET /export` 处理(被拉→记「拉取」)；失败记 `error`。
- `sync_page.dart`：删掉页面级 `_logs`/`_log`，改 `ref.watch(syncLogProvider)`；
  **`_send`/`_fetch` 不再自己记日志**（否则与服务端重复）；扫描 / 手动添加仍走 provider。
- PC `syncModule.ts`：`import { win } from "../mainWindow.ts"` + `win?.webContents.send("sync:log", {msg, level})`，
  在 `/export`、`/sync` 两分支（含失败）上报——复用 `countdown.ts` / `browserDownload.ts` 的既有主→渲染推送模式。
- PC `useSync.ts`：`window.ipcRenderer.on("sync:log", ...)` 并入 `logs`。
  ⚠️ **勿用 `removeAllListeners`**（会误杀其它模块常驻监听，见 `useCountdown` 顶部注释）。

⚠️ **Dart 作用域雷区（本次实踩）**：`try {}` 块内声明的局部变量，在 `catch {}` 子句里**不可见**
（两者是独立作用域）。`/sync` 分支要在 catch 里记带表名的日志，必须把 `String? table;` 提前声明到 `try` 外；
（对比：`/export` 分支的 `table` 本来就声明在 `try` 之前，所以同样写法没报错。
`fetchTable`/`sendTable` 的 `table` 是方法参数，天然可见，不受影响。）

### ✅ 移动端同步日志支持滚动（2026-09-07）
**现象**：日志是页面 `ListView` 里的裸 `Column` 且硬编码 `.take(10)`，条目一多只能整页拖动、超出可视区难回溯。
**修复**：新增组件 `lib/features/sync/components/sync_log_list.dart`——
`ConstrainedBox(maxHeight: 260)` + 内层 `ListView.separated(shrinkWrap: true)`
（等价 CSS `max-height + overflow:auto`，与 PC `SyncLog.vue` 的 260px 对齐）；
条数上限交给 `SyncLogController`（50），**UI 层不再截断**。
级别着色复用已确认 token：ok → `t.colors.primary`、error → `t.colors.destructive`、info → `t.colors.foreground`。

⚠️ **顺带发现（未改，P3，需你确认后再动）**：PC `pullTables` 里 `upsert` 硬编码 `primaryKey: "key"`，
而 `/sync` 分支用的是 `tablePk(table)`——**PC 主动拉取主题对话三表（INTEGER `id` 主键）会因找不到 `key` 列而报错**。
属既有 bug，本次未动。

## 笔记标签双端契约（note_tags，2026-09-05 打通）
**同步问题结论（需求变更记录）**：用户反馈「PC 同步数据到移动端后看不到笔记标签」。分析结论：**数据其实早已同步，是移动端从未读取/展示**——
- 标签定义存 `basic_info` 表 `key='note_tags'` 行：桌面端 `src/utils/common.ts` 的 `getStore/setStore` → `electron/main/module/store.ts` 的 `get-store/set-store` IPC，**读写的就是 basic_info 表**，value 为 JSON 数组 `[{key: uuid, name, color:'#RRGGBB', createTime, updateTime, deleted?}]`；
- 每条笔记 `note_book.tags` 存标签 **key 的 JSON 数组**（非名称）；
- 两表都在同步白名单、移动端 drift 表也早有 `tags` 列（note_tables.dart），链路本身是通的。

移动端补齐（桌面端零改动、无表结构变更、无需迁移/build_runner）：
- 模型 `features/notes/models/note_tag.dart`：`NoteTag`（key/name/color/deleted + `colorValue`）+ `parseNoteTagDefs` + `kNoteTagPalette`（PC TagSelector 同款 10 色随机色板）。
- 仓储 `note_repository.dart`：`watchTagDefs/loadTagDefs`（watch basic_info 单行，PC 推送后自动重发）、`createTagDef`（同名去重 + 随机取色）、`deleteTagDef`（**软删** deleted:true，笔记上已挂 key 保留，与 PC 一致）；`createNote/updateNote` 加 `tagKeys` 参数写回 `note_book.tags`。回写用 typed `insertOnConflictUpdate`（整行覆盖语义同桌面端 set-store，且能正确通知 watch 流——勿用 customUpdate，后者不会使 query 流失效）。
- providers：`noteTagsProvider`（StreamProvider）。`NoteItem` 新增 `content/mdText` 字段与 `searchText` getter（excerpt/content/mdText/html 小写合并，等价 PC 四列 LIKE 范围）。
- 列表页：搜索框（FTextField，`prefixBuilder` 放大镜）+ 标签彩色筛选 chips（**多选，任一命中即保留**，同 PC some 语义）+ **内容/标签双搜索**（关键词命中 searchText 或任意已挂标签名）；`_NoteCard` 加彩色标签徽标（最多 3 个 + 「+N」，key 无定义的不显示）。
- 详情页：分类 chip 旁 Wrap 展示彩色标签徽标。
- 编辑页 2026 重设计：标题/正文无 label 输入 + 「分类与标签」AppCard（分类 chips 单选[已有分类+新建抽屉]、标签 chips 多选[新建抽屉创建后自动选中]）+ 底部 `GradientButton` 渐变保存（顶栏对勾保留）。
- 共用组件 `features/notes/components/note_tag_chip.dart`：`NoteTagChip`（可点，选中=标签色 16% 软底+对勾）/ `NoteTagBadge`（只读徽标，色点+名称）。

## 主题对话（移动端对齐 PC，2026-09-05 打通同步 + 功能对齐）
**无数据根因与同步打通**：桌面端主题对话三表（`conversation_theme` / `conversation` / `conversation_tag`）用 **INTEGER 自增 id 主键**（newSql 默认），不满足旧「TEXT 主键」同步规则而长期未入白名单 → 移动端永远拉不到数据。2026-09-05 双端加入白名单并做 **pk 按表适配**：桌面端 `syncModule.ts` 新增 `tablePk()`（conversation* → `id`，其余 → `key`），upsert 走 `ON CONFLICT(id)`；PC UI 的 `src/store/useSync.ts` `SYNC_TABLES` 同步加表；移动端 `kSyncableTables` 直接加表（通用 INSERT OR REPLACE 天然兼容 id）。**改桌面端同步必须重启 Electron。**

**桌面端表结构速查**（来源 `src/views/themeConversation/{db,types}.ts`，全部 snake_case、自增 id）：
- `conversation_theme`：title / tags(JSON 标签 id 数组) / create_time / update_time / remark / parent_id(子主题，TEXT 存父 id)
- `conversation`：theme_id / content / is_rich('1'=HTML) / ref_ids(引用 JSON) / cross_refs(跨主题引用 JSON) / tags / create_time / annotate_time / pinned('1'置顶) / is_deleted('1'软删)
- `conversation_tag`：name / color('#RRGGBB') / scope(theme|conversation) / create_time

**移动端已对齐**（`conversation_repository.dart` + `conversation_page.dart`）：主题列表（update_time 倒序 + 消息数角标 + 主题标签彩色徽标）；新建/编辑主题（标题+备注，底部抽屉 + 底部固定保存条——页面保存规范）；删除主题（子主题禁止 + 级联删消息，showFDialog 确认）；消息流（置顶 pinned 排前 + 图标、is_rich='1' 走 HtmlWidget 渲染 PC vue-quill 富文本、发送追加纯文本消息并刷新主题 update_time）；**引用关系**（2026-09-05）——① 气泡上显示四类关系 tag：`引用 N`（ref_ids）/`跨主题 N`（cross_refs）/`被引用 N`（同主题 ref_ids 反扫）/`被跨主题引用 N`（cross_refs 反扫，对齐 PC 气泡 footer），点击 tag 打开对应关系抽屉；② 长按气泡出操作菜单（对齐 PC 右键菜单子集：正向链接/反向链接/跨主题引用查看/置顶切换/删除）；③ 关系抽屉为**右侧抽屉**（`side: FLayout.rtl` + SheetSurface 左圆角），**点击条目跳转定位**：同主题 `Scrollable.ensureVisible` + 气泡高亮 1.8s（GlobalKey per message + AnimatedContainer），跨主题 `push('/conversation/<themeId>?highlight=<convId>')`（路由透传 highlight，进页后定位一次）。引用解析 `loadRefLinks`（全表 Dart 扫描，ref_ids/cross_refs JSON 解析）；气泡计数经 `allConversationsProvider` 全量流一次扫描建 `sameBack/crossBack` 两张 Map；**主题标签（创建/编辑可挂标签，2026-09-08）**：主题编辑抽屉加「主题标签」入口（scope='theme'，复用 `showFilterSheet` 选择/新建，配色对齐桌面 TAG_COLORS 按序取色，创建后自动选中），保存写 `conversation_theme.tags` JSON，`_ThemeCard` 彩色徽标照常读取展示；**导出 Markdown（2026-09-08）**：单主题经长按菜单「导出 Markdown」、批量经列表页头 `download` 入口多选抽屉（全选/反选）合并导出，均走 `export_markdown.dart` 生成 .md（`htmlToMarkdown` + 标签名解析，对齐 PC `exportMarkdown.ts`）后经 `share_plus` 分享落盘（无需文件权限）。
**移动端裁剪未做**（桌面端有）：标注 annotate_time、多选、标签改名/改色/删除（新建已完成）、富文本编辑、子主题发起——需要时按桌面端 `useThemeConversation.ts` 语义补齐。
**引用发起（2026-09-05）**：工具条「引用」按钮 + 长按菜单「引用此对话」→ 引用草稿（`_pendingRefIds`，工具条 chip 可点掉）→ 发送时按消息归属分类写入 ref_ids（同主题）/ cross_refs（跨主题，`addMessage(refIds:, crossRefs:)`）。引用选择抽屉 `showFilterSheet(title: 引用对话)`：模糊搜索（内容/主题标题 contains，小写化）+ 全主题消息列表（排除软删、按时间倒序、take 80 上限提示）、多选圆点勾选，完成回填草稿。
**消息标签（2026-09-05）**：输入框上方固定工具条（「标签」入口 + 发送草稿 chips 可点掉，对齐 PC 输入工具条）；标签选择走查询抽屉（`showFilterSheet` title=选择标签/完成/清空，草稿模式），抽屉内「＋新建标签」再叠一层输入抽屉（scope='conversation'，配色对齐桌面 TAG_COLORS 按序取色，创建后自动选中）；发送时 tags 写 JSON（`addMessage(tagIds:)`）；长按菜单「编辑标签」改已发消息（`updateMessageTags`）；气泡显示消息标签彩色徽标。**
**主题标签 + 导出 Markdown（2026-09-08）**：① 主题标签：`createThemeTag(name)`→scope='theme'（调色板对齐 `createConversationTag`），`createTheme`/`updateTheme` 加 `tagIds` 参数写 `tags` JSON；编辑抽屉 `_openThemeTagPicker`（`showFilterSheet`+`_buildThemeTagPickerBody`+`_createThemeTag`，复用消息标签 chip 规格 `_ConvTagOption`/`_ConvTagBadge`）。② 导出：`features/conversation/utils/export_markdown.dart` 提供 `buildThemeMarkdown`/`buildThemesMarkdown`（纯函数，HTML→MD 对齐 PC `utils/exportMarkdown.ts`）；入口 `_exportTheme`（长按菜单单主题）/ `_openExportPicker`（页头 `download` 多选合并），最终 `_shareMarkdown` 写临时目录经 `SharePlus.instance.share(ShareParams(files:[XFile]))` 分享，规避文件权限。
**排障**：主题列表角标 0 条 → 计数口径必须与 PC `loadThemeCounts` 一致（`GROUP BY theme_id` **不过滤 is_deleted**，NULL 免疫）；消息列表软删过滤需 NULL 安全（`isNull() | equals('0')`）；输入框与筛选按钮等高 → **双端写死同值**（forui 控件内部高度随字号缩放漂移；`FTappable` 不上报固有高度，IntrinsicHeight 会把按钮压小）。

## 待办（移动端对齐 PC，2026-09-07 打通）
**用户需求**：移动端【待办事项】页面的**全部功能**与 PC 端对齐；PC 端待办在 `C:\cod\jianli\jianli-app\src\views\todoList`（index.vue / store/useTodo.ts / TodoDetailDialog.vue / RecordProgressDialog.vue / TodoBatchDeleteDialog.vue + TodoBatchDeletePanel.vue / TagSelectPopover.vue / TodoParentSelectDialog.vue / TodoSubtaskProgress.vue / types.ts / statusConfig.ts / api/todoApi.ts）。**新增/编辑/展示/筛选/选择等所有弹层一律底部抽屉 `showFSheet`**（用户明确指示「弹窗一律使用底部抽屉，详情看技能」）。

**关键结论（无需迁移）**：drift `todo_tables.dart` 早已具备全量列（`priority`/`dueDate`/`completed`/`status`/`deadlineReminder`/`remindCount`/`remindInterval`/`remindIntervalUnit`/`createTime`/`updateTime`/`sortOrder`/`parentIds`/`recurrenceRule`/`recurrenceInterval`/`recurrenceWeekdays`/`recurrenceEnd`/`recurrenceId`/`isRecurrenceInstance`）——**表定义零改动、无需 build_runner、无 onUpgrade**；本次只改模型/仓储/UI 三层。

**PC 待办功能集速查（移动端逐项对齐）**：
- 视图三态：卡片 card / 列表 list / 日历 calendar（`JianliSegmented` 切换）。
- 搜索（关键词页内实时）+ 筛选（优先级/状态/标签多选/显示已完成/显示模板/分组方式 none·status·due·parent）。
- 统计横幅：**取全量计算**（总/进行中/已完成/已取消），不随过滤跳变（PageBanner 蓝(1)）。
- 分组：无 / 按状态 / 按到期（overdue 逾期·today·tomorrow·thisweek·later·nodate）/ 按父任务（子任务挂父级下、显示进度 `done/total`）。
- 字段全量：标题/描述/优先级(low/medium/high/urgent)/到期 dueDate/状态 6 态/截止提醒(deadlineReminder + 次数 remindCount + 间隔 remindInterval + 单位 remindIntervalUnit)/重复(rule daily|weekly + interval + weekdays + end)/父任务(parentIds 多选)/标签(tagKeys 多选)/完成时间。
- 子任务：父子结构（parentIds/isChild/isTemplate）、子任务勾选进度、父任务 chip、级联删除。
- 高级子功能（用户确认**全部实现**）：① 日历视图（按 dueDate 聚合的月历）；② 记录进展 → 写入「主题对话」（按标题 `findOrCreateThemeByTitle` 后 `addMessage`）；③ 截止提醒 → 本地通知（awesome_notifications `scheduleOnce`）；④ 重复实例自动生成（模板保存后由 `_ensureNextRecurrenceInstance` 生成下一实例）。

**移动端已实现（文件清单）**：
- `features/todo/models/todo.dart`（**全量重写**）：`TodoItem` 全字段 + `isChild/isTemplate` getter；`TodoTagView` 加 `name`；常量 `kTodoStatusOptions`(6 态)/`kTodoPriorityOptions`；helper `statusMeta`/`priorityColor`/`priorityLabel`/`effectiveStatus`/`isSubtask`/`childrenOf`/`subtaskProgress`/`parentItemsOf`/`formatRecurrence`/`TodoFilter`+`applyTodoFilter`（兼容旧调用）。状态色对齐 PC statusConfig：`not_started #6b7280`/`in_progress #3b82f6`/`blocked #ef4444`/`completed #22c55e`/`cancelled #9ca3af`/`restart #8b5cf6`。
- `features/todo/models/todo_filter.dart`（**新增**）：`TodoFilterState`（search/priority/status/tagKeys/showCompleted/showTemplates/groupBy）+ `TodoGroupBy` 枚举；`applyTodoFilters`（搜索+优先级+状态+标签+显示开关）/ `dueGroupOf`（overdue/today/tomorrow/thisweek/later/nodate）/ `groupTodos`（按状态·到期·父任务分组）/ `kGroupLabels`/`kStatusLabelByKey` 等标签常量。
- `features/todo/repositories/todo_repository.dart`（**全量重写**）：`kTodoTagPalette`(10 色对齐 PC)；`watchTodos`(updateTime 倒序)/`watchTags`；`addTodo`→`Future<String>`(返回新 key)；`toggleComplete`(只动 completed/completedTime/updateTime)；`upsertTodo`(**`InsertMode.replace`** 按 key 全字段写，tags/parentIds 走 JSON，parentId=首个父)；若 `isTemplate` 调 `_ensureNextRecurrenceInstance`，若 `deadlineReminder==1 && dueDate!=null` 调 `scheduleDeadlineReminder`；`addTag`(同名去重+随机取色)/`deleteTodo`(**级联** key===key | parentId===key | parentIds like %key%)；`_ensureNextRecurrenceInstance`/`_nextOccurrence`(daily/weekly，上限 366 次迭代)；`scheduleDeadlineReminder`/`cancelDeadlineReminder`→`NotificationService.scheduleOnce/cancel`。
- `features/todo/components/todo_sheets.dart`（**新增，全部 `showFSheet`+`SheetSurface`**）：`showTodoEditSheet`(标题/描述/优先级/到期/状态/截止提醒(次+间隔+单位)/重复(日|周+间隔+星期+结束)/父任务多选/标签多选+新建/记录进展入口)、`showTodoFilterSheet`(优先级/状态/标签/显示已完成/显示模板/分组)、`showTodoTagSheet`(标签多选+新建)、`showTodoParentSheet`(父任务多选)、`showTodoDateTimeSheet`(**自绘月历+时分步进器**，dateOnly 用于重复结束日)、`showRecordProgressSheet`(写主题对话)、`showTodoActionSheet`(编辑/记录进展/删除)、`showTodoConfirmSheet`(危险确认，取消 false/确认 true)。
- `features/todo/components/todo_tile.dart`（列表行）：AppCard + `FCheckbox` 勾选 + 状态 chip（色对齐）+ 父任务 chip + 子任务进度 `done/total` + 标签彩色徽标 + 到期相对文案 + 右侧「…」动作（非选择模式→动作抽屉；选择模式→点选）。
- `features/todo/components/todo_card_view.dart`（卡片网格）：2 列 `GridView`，每卡勾选/状态/标签/到期/父任务/子任务进度，点击→编辑、非选择模式「…」→动作抽屉。
- `features/todo/components/todo_calendar_view.dart`（月历）：按 `dueDate` 聚合的月视图，日期格显示当日待办数+点；点击日期 → 该日列表（下层 showFSheet）；今日高亮。
- `features/todo/components/todo_page.dart`（**全量重写主页**）：`JianliSegmented` 切 list/card/calendar + 搜索框 + 筛选按钮(激活软底+条件数) + 已生效条件可点掉 chip 行 + PageBanner 蓝(1) 全量统计 + 分组(无/状态/到期/父任务) + 批量删除选择模式(右上「选择」→勾选→底部「删除选中」危险确认) + 新增/编辑入口（均走底部抽屉）。

**跨模块依赖（本次新增，已并入对应模块）**：
- `core/notifications/notification_service.dart`：`scheduleOnce({id, channelKey, title, body, at: DateTime})` —— `NotificationCalendar.fromDate(at, repeats: false)`（单次定点，对齐 PC `update-todo-reminders`）。`cancel(id)` 已存在。
- `features/conversation/repositories/conversation_repository.dart`：`findOrCreateThemeByTitle(title)` → `int`（按标题查重，命中返回 id、否则 `createTheme` 建新主题并返回 id）；供「记录进展」写入主题对话（对齐 PC `RecordProgressDialog` 按标题建/查主题）。

**约定与雷区（待办专项）**：
1. **弹窗一律底部抽屉**：所有新增/编辑/筛选/标签/父任务/日期/记录进展/动作/确认均走 `showFSheet(side: FLayout.btt)`+`SheetSurface`；只有「删除/批量删除」这类破坏性二次确认可用 `showFDialog`（记录进展与编辑内部的副确认也走抽屉）。模板见「UI 体系」抽屉化约定。
2. **日期/时间选择器自绘**：forui 0.26 的 `FDateField.calendar`/`FTimeField.picker` 工厂构造不透明且本仓库**无任何现成用法**（照抄易编译翻车）→ 改用 `showTodoDateTimeSheet` 内**自绘月历网格 + 时分步进器**（`dateOnly` 参数支持只选日），避免依赖不透明的 forui date API。后续若 forui 用法明确可替换。
3. **重复实例生成边界**：`_nextOccurrence` 上限 366 次迭代防死循环；模板保存时只生成「下一个」实例（不预生成整年），对齐 PC `recurrence:sync` 按需生成语义。
4. **截止提醒单位**：`remindIntervalUnit` 取值 `'minute'|'hour'|'day'`，提醒时间 = `dueDate` 前推 `remindCount × 间隔`；通知标题取待办标题、body 取「将于 <相对> 到期」。
5. **级联删除语义**：`deleteTodo` 同时删自身 + 直接父引用(parentId===key) + parentIds 含 key 的子任务，对齐 PC 批量删除「含子任务」选项。
6. **颜色/文案常量统一**：状态色、优先级色、分组标签、重复文案均从 `todo.dart`/`todo_filter.dart` 取，页面/抽屉**严禁硬编码**（UI 红线 #6）；状态色严格对齐 PC `statusConfig.ts`。
7. 改动后静态检查：`flutter analyze lib/features/todo` **0 问题**（本次实测全绿；todo/notifications/conversation 三域干净，其余 30 条 lint 为 ferry/file_transfer/habit 既有无关项），`flutter test`/`flutter run` 交用户在本地执行（分工铁律）。

