---
name: jianli-mobile-app
description: 本技能用于开发、维护、扩展「渐离App」移动端 (jianli-mobile-app，包名 com.jianli) —— 桌面版渐离App (Electron+Vue3) 的 Flutter (Android/iOS) 移植工程。当任务涉及该工程任意功能域（习惯打卡、待办、番茄钟、提醒、倒计时、笔记、主题对话、电子书、2FA、密码库、文件保险箱、二维码、局域网同步、首页 Dashboard 等）、需要理解 drift 数据层与桌面端 db.sqlite 的对齐规则、vault 加密复刻、类 LocalSend 双端同步协议、国内镜像构建环境与已知雷区，或要新增功能域、排查构建/运行问题时，使用本技能。
agent_created: true
---

# 渐离App 移动端开发技能（jianli-mobile-app）

## 这是什么
封装「渐离App 移动端」的架构约定、数据层对齐规则、加密复刻、双端同步协议、构建环境与逐功能域知识，让 AGENTS 在本工程里按既定模式开发、维护、扩展功能，并避开已知雷区。它不是运行时功能，而是「开发该工程的知识库」。

与桌面端技能是**姊妹关系**：
- 桌面端契约（db.sqlite 表结构、vault 加密 `crypto.ts`、同步对端 `syncModule.ts`）以桌面技能为准：`C:\cod\jianli\jianli-app\.workbuddy\skills\jianli-app\SKILL.md`
- 移植的历史计划与决策记录在桌面技能的 `references/flutter-port.md`（本技能是它的「移动端落地版」，日常开发以本技能为准）

## 何时使用
- 任务涉及本工程任意功能域（首页 Dashboard / 习惯 / 待办 / 番茄钟 / 提醒 / 倒计时 / 笔记 / 主题对话 / 电子书 / 2FA / 密码库 / 文件保险箱 / 二维码 / 局域网同步）。
- 需要：新增 drift 表、对齐桌面端列名、复刻/扩展 vault 加密、接本地通知、加同步白名单表。
- 要：构建 APK、跑模拟器/真机、跑测试，或排查「构建失败 / sqlite3 崩溃 / 同步扫不到设备」等问题。

## 全局红线（先读，违反必踩雷）
1. 【环境雷区·中文用户名】跑任何 dart / flutter / gradle 命令前必须设置 ASCII 临时目录：`export TMP=C:\src\tmp TEMP=C:\src\tmp`（Windows 用户目录含中文 `C:\Users\风起`，Dart build_runner 自举编译会因 %TEMP% 含中文失败：`Unable to read program.dill`）。Gradle 再遇编码问题优先怀疑路径。
2. 【构建镜像】构建 shell 里的 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`、`PUB_HOSTED_URL=https://pub.flutter-io.cn` 必须是**当前有效值**——旧会话继承 cernet 旧镜像变量会导致 flutter_embedding_debug 等构件拉取失败。Gradle/Maven 已配阿里云镜像（`android/settings.gradle.kts`），勿删。
3. 【drift 三大铁律】写/改表定义前必读下方「数据层（drift）」，违反会导致整库解析失败、生成空壳 .g.dart 或列名与桌面端错位。
4. 【加密对齐】vault 信封格式必须与桌面端 `electron/main/module/vault/crypto.ts` 逐字节一致（AES-256-GCM + PBKDF2 iter=200000，JSON 信封 `{v,kdf,iter,salt,iv,ct}` 全 b64）。改加密相关代码前先读「加密（vault 复刻）」一节。
5. 【sqlite3 hooks】`pubspec.yaml` 里的 `hooks.user_defines.sqlite3`（Windows 用系统 `winsqlite3.dll`、Android 用裸名 `sqlite3` + jniLibs 手动分发 .so）是踩坑后固化的配置，**严禁删除或改回默认**（默认 hook 从 GitHub 下载 dll 国内超时；`name_android` 填 `libsqlite3.so` 会被再装饰成 `liblibsqlite3.so.so` 崩溃）。
6. 【UI 约定·forui】全 App UI 组件用 **forui（shadcn 风格）**，详见下方「UI 体系（forui）」。三条铁律：① Material 导入统一用 `package:material_ui/material_ui.dart`（**严禁与 `flutter/material.dart` 混用**——两套平行 Material 类，混用会断 Theme 继承链、ThemeData 类型不兼容）；② 严禁硬编码颜色，取色一律 `context.theme.colors.*`，字体一律 `context.theme.typography.body.*`；③ feature-first 原子拆分，单文件职责单一，每个功能/组件带中文注释。
7. 【同步白名单】新增可同步表**默认 TEXT 主键**（INTEGER 主键表需双端 pk 适配，先例见「主题对话」小节），且同时改两端白名单：移动端 `lib/core/sync/sync_service.dart` 的 `kSyncableTables` + 桌面端 `electron/main/module/sync/syncModule.ts` 的 `SYNCABLE_TABLES` 与 `tablePk()`（PC UI 另有 `src/store/useSync.ts` 的 `SYNC_TABLES`；改桌面端需重启 Electron）。幂等写只有 `INSERT OR REPLACE`（移动端）/ `ON CONFLICT(pk) DO UPDATE`（桌面端 newSql upsert），传输当前为明文 JSON（仅限受信局域网，会话加密是 P3 TODO）。
8. 【文档同步】每次大改动后同步更新**对应模块**（功能域状态改 `modules/features.md`、雷区/约定改对应主题模块），并在 `modules/changelog.md` 追加一条日期前缀记录；发现文档与代码不符，直接修正文档。
9. 【底部抽屉键盘兼容（2026-09-07 修过的坑，全局适用）】**任何含输入框的底部抽屉**（`showFSheet(side: FLayout.btt)`）都要防键盘压扁：forui `showFSheet` 默认 `mainAxisMaxRatio = 9/16`，键盘弹起时路由可用高度 =「屏幕高 − 键盘高」，抽屉最大高度被压成剩余高度的 56% → 内容被压成极矮一条、看不到。修复范式：统一走封装入口（如 `todo_sheets.dart` 的 `_showTodoSheet`），设 `mainAxisMaxRatio: null` + `resizeToAvoidBottomInset: true`，高度改由 sheet 承载组件（如 `_sheetScaffold`）的 `maxRatio(0.9)` 决定，键盘弹起时整张抽屉抬到键盘上方、内容在 `SingleChildScrollView` 内滚动。该承载组件的 `keyboard:` 参数**不可**再加 `viewInsets.bottom` 到外壳 padding（那会把内容高度再吃掉一截→重新压扁），表单类只需一点点固定底部呼吸距离即可。
10. 【**系统所有的弹出窗，都改为底层抽屉弹出**（强制条例，2026-09-10 用户拍板，全 App 适用）】**禁止**再新增任何居中弹窗（`showFDialog` / `FDialog` / `showDialog` / `AlertDialog` / `showCupertinoDialog`）；新增和改造**一律底部抽屉**：`showFSheet<T>(context: context, side: FLayout.btt, mainAxisMaxRatio: null, builder: (_) => SheetSurface(child: SafeArea(child: ...)))`。要点：① 内容必须用 `SheetSurface` 包底（forui 的 Sheet 链路不画 surface，直接给 Padding 会露出灰色 barrier「透明灰」实踩）；② 需要结果时用泛型 + `Navigator.pop(c, true)`，`await showFSheet<bool>(...)` 正常拿到返回值，`showFDialog<bool>` 可原样平移；③ 按钮行建议两个 `Expanded` 并排（取消 outline / 确定 primary 或 destructive），比右对齐更贴移动端；④ 含输入框时同时遵守红线 #9 的键盘兼容范式（`mainAxisMaxRatio: null` 必带）；⑤ 表单状态（`current` 等）要提到 `StatefulBuilder` 之外的外层作用域，避免 setSt 重建被重置。**已全量改造完毕（2026-09-10）：全 App `showFDialog` 归零**，共 5 处居中弹窗改为抽屉——电子书 `features/ebook` 2 处（`_confirmRemove` 删除确认、`_editBookCategories` 分类选择）、`conversation_page.dart` 2 处（`_deleteTheme` 删除主题、`_confirmSoftDelete` 软删消息）、`notes/note_detail_page.dart` 1 处（`_delete`）；`epub_reader_page` 5 处与 file_vault / password_vault / file_transfer / todo / reminder 等模块本就是 `showFSheet`，仅同步修正注释里过时的「showFDialog / AlertDialog」字样。**其余任何模块都不得再新增居中弹窗**。

11. 【**Android 11+(API 30+) 写共享 Download 必须「所有文件访问」**】写系统 `Download/` 共享目录（电子书传书 `Download/渐离App传书`、文件互传 `Download/渐离App文件互传` 等）在 API 30+ **只有 `MANAGE_EXTERNAL_STORAGE`（「所有文件访问」）才有权限**，旧的 `READ/WRITE_EXTERNAL_STORAGE`(`Permission.storage`) 在 API 30+ 已**不再**授予写共享存储的权限。任何「判定可写共享 Download」的代码（`hasPublicDownloadsAccess` 之类）**绝不能**把 `Permission.storage.isGranted` 当成可写——否则 `createSync` 抛 `Permission denied` → 被 `catch` 静默回退到应用沙盒 → 文件管理器永远看不到。正确写法：`manageExternalStorage.isGranted` 为真即通过；否则仅当 `Build.VERSION.SDK_INT <= 29`（配合 manifest 的 `requestLegacyExternalStorage`）才允许 `Permission.storage`。落盘后务必 `MediaScannerConnection.scanFile` 让 MediaStore 索引（共享辅助见 `lib/core/android/media_scan.dart` + `MainActivity.kt` 的 `jianli/file_actions` 通道 `getSdkVersion`/`scanFile`）。`ferry_page.dart` 的权限判定仍是旧写法，新增写共享存储的代码照此修正。
12. 【**电子书传书 `importBookBytes` 不得因 contentHash 命中已有记录而跳过落盘**】跨端传书以内容 sha256 做身份键（对齐 PC `content_hash`），但**绝不能**在「命中已有 contentHash 记录」时直接 `return existing` 而不写文件——否则会出现「传书成功（书架能看）但系统文件管理器看不到」的诡异现象（2026-09-10 IV 实踩：从 PC 同步来的记录 / 旧沙盒路径已失效的记录会命中 hash → 函数早退、文件根本没落到 `Download/渐离App传书`）。正确做法（见 `features/ebook/repositories/ebook_repository.dart` 的 `importBookBytes`）：先按公开 `booksDir` 算出 `localPath`，**仅当** `existing != null && existing.filePath == localPath && File(existing.filePath).existsSync()` 时才复用不写；否则一律 `writeAsBytes` 落盘到 `localPath` 并 `scanFileInMediaStore(localPath)`，命中旧记录时**按 `content_hash` 去重删插**：删除所有同 `content_hash` 行 + 任何占用 `localPath` 的行，再 `insert` 一条规范行（保留 `percent`/`addedAt`）。⚠️ **严禁用可空 `id` 做 UPDATE**——`id` 为 NULL（沙盒/同步来的异常行）时会生成 `WHERE id IS NULL` 匹配不到、且同内容重复行会撞 `UNIQUE(file_path)` 抛 `SqliteException(1555)`（2026-09-10 VI 实踩）；一律按 `content_hash` 去重删插。书签/批注按 `content_hash` 关联，删行不影响。文件互传无此去重门故始终可见；电子书传书必须与其行为对齐，**不要「为了去重而牺牲系统可见性」**。

## 📚 模块索引（按需读取，勿全量加载）

本技能拆分为「索引 hub（本文件）+ 主题模块」。技能加载时只有本文件进上下文；
涉及具体主题时，按下表用 Read 工具读取对应 `modules/*.md`（路径相对本文件）。

| 模块 | 路径 | 内容 | 何时读 |
|---|---|---|---|
| 架构 / UI | `modules/architecture.md` | 技术栈对应、工程结构(feature-first)、UI 体系(forui)、页面操作规范、Riverpod3 / forui API 雷区 | 写 UI/组件、改页面结构、用 forui / material_ui 时 |
| 数据层 | `modules/data-layer.md` | drift 表定义、数据库持久化与迁移铁律、vault 加密复刻(AES-256-GCM + PBKDF2) | 新增/改 drift 表、对齐桌面端列名、改加密时 |
| 同步 / 契约 | `modules/sync.md` | 局域网同步协议(v1)、同步日志、笔记标签 / 主题对话 / 待办 双端契约 | 加同步白名单表、改同步逻辑、对齐某功能域数据时 |
| 构建验证 | `modules/build.md` | 环境前置、日常循环、跑模拟器/真机、本机 Android 环境、生产打包、图标再生成、排障 | 构建 APK / 跑起来 / 排查构建失败 / 打包上架时 |
| 功能域 | `modules/features.md` | 功能域清单与状态、新增功能域落地清单、使用方式 | 盘点功能域状态、要新增功能域时 |
| UI 现代化 | `modules/ui-modernization.md` | UI 现代化与动效总体规划、原子组件、动效雷区 | 加动效 / 改视觉 / 用动画组件时 |
| 变更史 | `modules/changelog.md` | 维护说明（append-only，每完成一件事在此追加一条） | 查历史决策 / 雷区固化记录、要追加新变更时 |

> ⚠️ 日常维护：每完成一个功能域或踩出新雷区，**先改对应主题模块**，再在 `modules/changelog.md` 追加一条日期前缀记录；功能域状态有变改 `modules/features.md`。不要再往本 hub 堆内容。
> 决策类长文仍在 `references/`（file-transfer-plan.md / ui-modernization-plan.md / ferry-plan.md），与本知识模块区分。
