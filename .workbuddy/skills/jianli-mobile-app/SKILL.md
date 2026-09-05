---
name: jianli-mobile-app
description: 本技能用于开发、维护、扩展「渐离App」移动端 (jianli-mobile-app，包名 com.jianli) —— 桌面版渐离App (Electron+Vue3) 的 Flutter (Android/iOS) 移植工程。当任务涉及该工程任意功能域（习惯打卡、待办、番茄钟、提醒、倒计时、笔记、主题对话、电子书、2FA、密码库、文件保险箱、二维码、局域网同步、首页 Dashboard 等）、需要理解 drift 数据层与桌面端 db.sqlite 的对齐规则、vault 加密复刻、类 LocalSend 双端同步协议、国内镜像构建环境与已知雷区，或要新增功能域、排查构建/运行问题时，使用本技能。
agent_created: true
---

# 渐离App 移动端开发技能（jianli-mobile-app）

## 这是什么
封装「渐离App 移动端」的架构约定、数据层对齐规则、加密复刻、双端同步协议、构建环境与逐功能域知识，让 AGENTS 在本工程里按既定模式开发、维护、扩展功能，并避开已知雷区。它不是运行时功能，而是「开发该工程的知识库」。

与桌面端技能是**姊妹关系**：
- 桌面端契约（db.sqlite 表结构、vault 加密 `crypto.ts`、同步对端 `syncModule.ts`）以桌面技能为准：`C:\cod\jianli\jianli-app\.zcode\skills\jianli-app\SKILL.md`
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
7. 【同步白名单】新增可同步表必须是 **TEXT 主键**，且同时改两端白名单：移动端 `lib/core/sync/sync_service.dart` 的 `kSyncableTables` + 桌面端 `electron/main/module/sync/syncModule.ts` 的白名单（改桌面端需重启 Electron）。幂等写只有 `INSERT OR REPLACE`，传输当前为明文 JSON（仅限受信局域网，会话加密是 P3 TODO）。
8. 【文档同步】每次大改动后同步更新本 SKILL.md（功能域状态、新雷区、新约定）；发现文档与代码不符，直接修正文档。

## 技术栈与桌面端对应
| 移动端 | 桌面端 | 说明 |
|---|---|---|
| Flutter 3.47.2 stable（`C:\src\flutter`，Dart 3.13.2） | Electron + Vue3 + TS + Vite | SDK 在 `C:\src\flutter\bin`，PATH 已配 |
| **forui 0.26.x + material_ui 1.1.x**（UI 组件库，2026-09-05 换装） | Element Plus / 自研视觉 | shadcn 风格；material_ui 是 Flutter Material 独立发行版 |
| flutter_riverpod **3.x** | Pinia | ⚠️ 实装是 Riverpod 3.x，API 与 2.x 有差异，以 3.x 文档为准 |
| go_router | vue-router | `lib/app/router/app_router.dart` |
| drift + sqlite3 | newSql（better-sqlite3） | 表定义逐列对齐桌面端 db.sqlite |
| flutter_widget_from_html / flutter_quill | vue-quill | 渲染已通；flutter_quill 富文本编辑器 P2 |
| awesome_notifications | 提醒引擎（reminders 表） | reminders → 本地通知计划翻译 |
| workmanager | — | 待办每日实例等后台任务（iOS 受限） |
| epubx + file_picker | electron 侧文件访问 | 沙盒限制，导入式 |

## 工程结构（feature-first）
```
lib/
  main.dart                # 入口：ProviderScope 包根组件（通知等初始化走各 feature 首次进入，暂不在 main 阻塞）
  app/
    app.dart               # 根组件：读 themeStyle/themeMode provider → MaterialApp.router + FTheme 注入
    theme/app_theme.dart   # 主题入口（forui）：5 套主题样式（ThemeStyle / AppTheme.styles）+ 中性底亮/暗；桌面 25 套 token 全量映射 P2
    providers/theme_providers.dart  # themeStyleProvider / themeModeProvider（SharedPreferences 持久化）
    ui/settings_panel.dart # 设置面板（左侧滑出 PageRouteBuilder）+ SettingsButton（首页/三个分组页右上角）
    ui/                    # AppCard / SectionHeader / EmptyState / StatBlock / RingProgress 自绘环 + Phase1 原子组件
    router/app_router.dart # StatefulShellRoute 四 Tab（/ /efficiency /content /tools）+ 全屏功能路由
    shell/main_shell.dart  # 底部导航壳（IndexedStack 保持各 Tab 状态）
    di/app_providers.dart  # 全局单例注册（appDatabaseProvider 等）
  core/
    db/                    # drift：app_database.dart（25 张表注册）+ tables/*.dart 分域表定义
    crypto/                # vault_codec.dart（信封/二进制编解码）+ vault_crypto.dart（常量与格式说明）
    sync/                  # sync_discovery.dart（UDP 发现）+ sync_service.dart（HTTP 数据面）
    notifications/         # notification_service.dart（渠道定义 + 计划翻译）
  features/<module>/       # api · models · repositories · components · services · providers（按需原子拆分）
    hubs/hub_pages.dart    # 三个分组页（效率/内容/工具）的功能入口清单——新功能在此加入口
test/
  totp_test.dart           # RFC 6238 官方向量 ×4 + 冒烟 ×1
```

## UI 体系（forui，2026-09-05 全量换装）
- 组件库：**forui ^0.26**（shadcn 风格，要求 Flutter 3.44+，自带 Inter 字体与 Lucide 图标）+ **material_ui ^1.1**（Flutter Material 库的独立发行版，forui 建于其上）。
- ⚠️ **两套平行 Material 类**：`material_ui` 与 `flutter/material` 的 ThemeData/Theme/Scaffold/MaterialApp 同名但互不兼容。所有 UI 文件导入 `package:material_ui/material_ui.dart`，**严禁混用**（否则 Theme 继承链断裂、类型报错）；第三方包内部用 flutter/material 不受影响（mobile_scanner / qr_flutter / flutter_widget_from_html 等）。
- 主题入口 `lib/app/theme/app_theme.dart`：官方模式 `FThemeData(touch: true, debugLabel: ..., colors: FTheme.neutral.light/dark.touch.colors.copyWith(primary: seedColor, primaryForeground: Colors.white))` —— 只传 touch+colors，typography/style/icons 自动从 colors 推导继承；`toApproximateMaterialTheme()` 供 MaterialApp.theme 让残留 Material 组件同色系。
- 根组件 `app.dart`：material_ui 的 `MaterialApp.router` → builder 注入 `FTheme`（跟随系统亮暗）+ `FToaster` + `FTooltipGroup`；本地化 `FLocalizations.localizationsDelegates`（已内置 Global Material/Cupertino/Widgets 三件套，支持 zh）。
- 页面骨架：`FScaffold(header: FHeader(title:...) / FHeader.nested(title:, prefixes: [FHeaderAction.back(onPress: () => context.pop())]), child: ...)`；**FBottomNavigationBar 只能放 FScaffold.footer**（Material Scaffold 的 bottomNavigationBar 不可用），选中态由 `index`/`onChange` 驱动，item 无 onPress；`childPad` 默认提供水平内边距（全屏页设 `childPad: false`），ListView 只写垂直 padding。
- 组件替换对照：AppBar→FHeader(.nested)；Card→AppCard 原子或 FCard；按钮→FButton（`variant:` primary/secondary/destructive/outline/ghost，无命名构造）；TextField→FTextField（**controller 放 `FTextFieldControl.managed(controller:)`，无 controller 参数**）；Switch/Checkbox→FSwitch/FCheckbox（value/onChange）；showDialog→`showFDialog`；SnackBar→`showFToast`；showModalBottomSheet→`showFSheet(side: FLayout.btt)`；ListTile→FTile/FTileGroup；CircularProgressIndicator→FCircularProgress；Linear→FDeterminateProgress(value: 0..1)。后三者（dialog/toast/sheet）是**顶层函数**，没有 context.toast 之类的扩展。
- **FTabs 必看雷区**：Tab 内容含 viewport 类组件（ListView / GridView / FSelect 下拉菜单等）时**必须 `expands: true`**。默认 false 时 Tab 内容不经 Expanded 直接内联（无界高度），会触发 "Vertical viewport was given unbounded height" 连锁 render 异常，**整页白屏且 logcat 无 E/flutter 输出**（render 断言被吞，极难排查）。定位手段：最小 headless widget test 二分复现（先 FTabs 空内容 → 加真实内容，几秒锁定）。已有先例：`qr_page.dart`。
- 排查技巧：`am start` 对已运行应用只是切前台（result code=3），要抓启动/导航日志必须 `adb shell am force-stop <pkg>` 后冷启动再复现；真机调试 Dart 异常优先 `flutter run` 控制台，logcat 只能看到 `I/flutter` 标签的系统级输出。
- **FCard 无 title/subtitle 参数**：用 `FCard(builder: (c, style, _) => Column(children: [Text('标题', style: style.titleTextStyle), ...]))`。
- ⚠️ **forui 的 `factory({...})` 是 Dart 新「声明式工厂构造」语法**：类内部写 `factory({...})` = 未命名工厂构造，**调用时用类名直呼**（`FSelect<String>(items:...)`、`FThemeData(touch:, colors:)`），写 `Xxx.factory(...)` 会报 undefined。forui 0.26 源码文档示例大量使用点简写（`.light`、`.new`），照抄前先确认 Dart 版本支持。
- FTile/FItem 的 title/subtitle/details **不要放 Expanded/TextField**（不渲染，需 .raw 版）；FSelect 必须显式写泛型 `FSelect<String>`。
- 图标：`FLucideIcons.*`（Lucide 命名，forui.dart 已导出；新图标名先到 forui_lucide 包 `lib/src/assets.g.dart` grep `static const <name> = IconData` 验证）。
- 原子组件 `lib/app/ui/`：AppCard / SectionHeader / EmptyState / StatBlock / RingProgress / **PageBanner**（功能页渐变横幅，见「UI 现代化与动效」Phase 3→4 小节）—— 与业务无关的视觉复用入口，新页面优先用它们拼装。
- 残留 Material 组件白名单（无 forui 等价物，material_ui 版已被近似主题着色）：RefreshIndicator、Dismissible（滑动删除）、ReorderableListView、Slider、mobile_scanner、qr_flutter。
- 桌面 25 套主题映射（P2）：在 `app_theme.dart` 的 `_build` 加方案表，每套主题 = 一份 `FColors.copyWith` 主色（+可选中性色）覆盖。

### 主题体系（5 套样式 + 三态模式，2026-09-05 新增）
- `AppTheme.styles` 定义 5 套 `ThemeStyle{id,name,lightPrimary,darkPrimary}`：渐离紫 `zi`、远峰蓝 `blue`、森野绿 `green`、落日橙 `orange`、樱粉 `pink`；`styleById(id)` 按 id 取（缺省回落首套）。`AppTheme.build(style:, brightness:)` 是唯一构建入口，`materialLight/materialDark` 供 MaterialApp。
- `lib/app/providers/theme_providers.dart`：`themeStyleProvider`（存样式 id，key `jianli.themeStyle`）+ `themeModeProvider`（存 `AppThemeMode.system/light/dark`，key `jianli.themeMode`），均 `AsyncNotifierProvider` + SharedPreferences 持久化；`toMaterialMode()` 把枚举转 Material 的 `ThemeMode`。
- `app.dart` 是 `ConsumerWidget`，读两个 provider 后把 `themeMode:` 与 `theme/darkTheme` 交给 MaterialApp，`builder` 里按 `Theme.brightnessOf(context)` 现算 `FTheme`（**这样切样式/模式即时全树重渲，不用重启**）。
- **设置面板**：`lib/app/ui/settings_panel.dart` 的 `SettingsButton`（齿轮 SquircleBox）放在首页右上角与三个分组页 `FHeader.suffixes`；点击 `showSettingsPanel(context)` 推一个 `PageRouteBuilder`（`opaque:false` + `barrierColor: Colors.black54` + 左侧 `SlideTransition(-1,0)→(0,0)`），面板内含 5 色环样式选择 + 三态模式 `JianliSegmented` + 同步/关于入口。**刻意不用 forui 弹层**，规避与 material_ui 平行 Material 类的冲突。

### ⚠️ Riverpod 3 / forui API 雷区（2026-09-05 实踩，写代码前必看）
1. **Riverpod 3 移除了 `AsyncValue.valueOrNull`** —— 取异步值用 `.value`（如 `ref.watch(themeStyleProvider).value ?? 'zi'`）。写 `.valueOrNull` 直接报 undefined。
2. **forui `FHeader` 没有 `actions` 参数** —— 尾部动作是 **`suffixes`**，左侧是 **`prefixes`**（`FHeaderAction.back(onPress:)`）。写 `actions:` 报「named parameter doesn't exist」。
3. **`material_ui` 的 `ThemeMode` 与 `flutter/material` 的不是同一类型** —— provider/工具函数里若返回 `ThemeMode`，该文件必须 `import 'package:material_ui/material_ui.dart';`，否则赋给 `MaterialApp.themeMode` 类型不兼容。
4. **`JianliSegmented` 的 `items` 类型是 `List<(IconData?, String)>`** —— 传 `Icon(FLucideIcons.sun)` 会类型不符，要传 **`FLucideIcons.sun`**（IconData 本体）。
5. **drift 行类名不是猜的**：二维码历史是 `QrHistoryData`（不是 `QrHistoryRow`）；新增组件引用行类型前先 grep 确认。


- 移动端自有库文件：沙盒 `Documents/db.sqlite`，`LazyDatabase` 后台 isolate 打开；当前 `schemaVersion = 1`，**扩表必须 schemaVersion+1 并写 onUpgrade 迁移**。
- 25 张表（22 张首批对齐桌面端 + countdown / qr_history / qr_template 三张工具表，工具表与桌面端同构）：habit_def、habit_checkin、todo_list、todo_tags、reminders、note_book、basic_info、pomodoro_status、pomodoro_mini_config、conversation×3、file_vault×2、ebook×7、screenshots、countdown、qr_history、qr_template。
- **三大铁律**：
  1. drift 默认把驼峰 getter 转下划线列名，而桌面端业务列多为驼峰 → 列名**必须用 `.named('桌面原名')` 显式锁定**（`@Named` 注解在 drift 2.34 不存在）。
  2. getter **不能叫 `text` / `dateTime`**（与 drift `Table.text()` / `Table.dateTime()` 构造方法冲突，导致整库解析失败、生成空壳 .g.dart）→ 改名 + `.named()` 锁定（现有先例：`annotatedText`、`recordedAt`）。
  3. **行类名会被单数化**：`TodoTags`→`TodoTag`、`Reminders`→`Reminder`、`Screenshots`→`Screenshot`，其余为 `XxxData`。
- 改表流程：改 `lib/core/db/tables/*.dart` → 在 `app_database.dart` 的 `@DriftDatabase` 注册 → 跑 build_runner（见下）→ 老用户需写迁移。
- 电子书表以桌面绝对路径 `file_path` 做关联键，移动端用 `content_hash` 做稳定映射，勿依赖 file_path。

## 加密（vault 复刻）
- 入口：`lib/core/crypto/vault_codec.dart` —— `deriveVaultKey`（PBKDF2-SHA256 200000 次）、`decryptVaultEnvelope` / `encryptVaultEnvelope`（JSON 信封）、`encryptVaultBytes` / `decryptVaultBytes`（二进制流）。
- 两种密钥来源（与桌面端一致，勿混淆）：**2FA / 应用锁 = 用户口令派生**；**密保 / 股票 Key = 设备绑定随机主密钥**（重装失效）。移动端口令库文件存沙盒 `Documents/password-vault.jlv`，路径记 `basic_info.mobilePasswordVaultPath`。
- `.jlv` 二进制格式：`JLV1` 魔数 + metaLen + JSON + iv + ct，解析在 `features/file_vault/services/jlv_format.dart`（新旧格式兼容，与 PC 完全互通）。
- TOTP：`features/twofactor/services/totp_service.dart`（RFC 6238 全算法，向量化测试护住）；otpauth URI 解析在 `services/otpauth_parser.dart`。
- 纯 Dart PBKDF2 200000 次解锁约数秒；提速可接 `cryptography_flutter` 走平台实现（P2）。

## 局域网同步（类 LocalSend，协议 v1，双端已全通）
- 发现：UDP 广播端口 **47123**，请求包 `JIANLI_SYNC_DISCOVER_V1`，应答 `JIANLI_SYNC_INFO_V1|{json:{name,id,platform}}`（`core/sync/sync_discovery.dart`；PC 端 `syncModule.ts` 同协议应答）。
- 数据面：HTTP 端口 **47124** —— `GET /ping` 设备信息、`POST /sync`（body `{table, rows}`）、`GET /export?table=`（对端拉取）。
- 白名单 9 张 TEXT 主键表：habit_def / habit_checkin / todo_list / todo_tags / note_book / basic_info / countdown / qr_history / qr_template；行全列 toString 后按主键 `INSERT OR REPLACE`；写入前按 `PRAGMA table_info` 过滤实际存在的列，双端 schema 差异（桌面端旧 SQL 层遗留列）免疫。
- **模拟器雷区**：NAT 广播不通扫不到宿主 → 同步页支持手动填 IP，Android 模拟器固定填 `10.0.2.2`；真机走正常广播。PC 端同步入口：系统与资源 → 局域网同步（扫描 / 手动 IP(ip:port) / 推送 / 拉取）。
- vault 类数据跨设备：密钥为设备绑定/口令派生，**不能直传设备密钥**，需用户口令重新封装（会话加密 P3）。

## 构建与验证
```bash
# 任何 dart/flutter 命令前（中文用户名雷区 + 国内镜像，缺一必踩）
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

dart run build_runner build -d   # drift 生成代码（改表后必跑）
flutter analyze                  # 当前基线：0 问题
flutter test                     # 当前基线：5/5（RFC 6238 向量 ×4 + 冒烟 ×1）
flutter devices                  # 先确认在线设备/模拟器 id
flutter run -d <deviceId>        # 编译并启动到指定设备（看效果最快）
flutter build apk                # 真机 APK（默认三 ABI，已构建成功）
flutter build apk --debug --target-platform android-x64   # 只出 x86_64 debug APK（给模拟器装，最快）
```

### 跑起来看效果（UI 验证标准流程，**所有命令由用户在本地终端执行**）
> ⛔ **分工铁律（2026-09-05 用户明确指示，最高优先级）**：**Agent 只负责写代码与改文档；一切 flutter/dart 命令（analyze / test / build / run / pub get / build_runner…）一律由用户在本地终端执行，Agent 不代跑**。此前「Agent 可跑 analyze/test」的口径作废。
> 二次实踩依据（2026-09-05）：① Agent 侧无图形界面，无法观感验证；② 后台构建过慢（3~4 分钟仍未完）；③ 经 Git Bash 调用 `dart.bat`/`flutter.bat` 包装脚本会因本机 PowerShell 会话损坏直接失败（`InitialSessionState` 乱码报错），`dart.exe` 直连虽能跑 `analyze`，但 flutter tool 拉 git 子进程报「目录名称无效」——**结论：与其绕环境，不如全部交用户**。
> Agent 的职责止于：改码 → 把下方命令清单原样交给用户 → 等用户回贴结果再继续修。
>
> 另注：本机 bash 偶发「输出被吞」（命令执行了但 stdout 全空、exit 1），校验结果要落盘就写项目目录再用 Read 读。

```bash
# 0) 前置（每个新 shell 都要，中文用户名雷区 + 镜像）
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
cd /c/cod/jianli/jianli-mobile-app

# 【可选】把 SDK 工具加进 PATH（本机 adb 默认不在 PATH，直接敲 adb 会 command not found / exit 127）
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"

# 1) 确认模拟器在跑（没跑就先启动，见下节）
flutter devices          # 正常会显示 sdk gphone64 x86 64 (android-x64) → emulator-5554，Android 14

# 2) 一步编译并启动（看动效/UI 效果最快，推荐）
flutter run -d emulator-5554

# 3) 或：只出 debug APK 再手动装到模拟器
flutter build apk --debug --target-platform android-x64
adb install build/app/outputs/flutter-apk/app-x64-debug.apk
adb shell monkey -p <applicationId> 1     # applicationId 以 android/app/build.gradle.kts 为准
adb shell am start -n <applicationId>/.MainActivity   # 等价的显式启动方式
```

### 本机 Android 环境（2026-09-05 实测固定值，别再去默认位置找）
| 项 | 路径 / 值 |
|---|---|
| **Android SDK** | **`C:\apps\Android\AndroidSDK`**（**非默认位置**；`ANDROID_HOME`/`ANDROID_SDK_ROOT` 默认未设置，别去 `AppData\Local\Android\Sdk` 找，不存在） |
| adb | `C:\apps\Android\AndroidSDK\platform-tools\adb.exe` |
| emulator | `C:\apps\Android\AndroidSDK\emulator\emulator.exe` |
| system image | `android-34`（Android 14） |
| **AVD 名称** | **`Pixel_8`**（`C:\Users\风起\.android\avd\Pixel_8.avd` + `Pixel_8.ini`） |
| 在线设备 id | `emulator-5554` |

**启动模拟器**（`flutter devices` 里没有设备时先做这步）：
```bash
# 方式 1：直接拉起 AVD（最稳，推荐）
/c/apps/Android/AndroidSDK/emulator/emulator.exe -avd Pixel_8 &

# 方式 2：交给 Flutter（本机 flutter emulators 列表时常输出为空，不可尽信）
flutter emulators --launch Pixel_8

# 方式 3：Android Studio → Device Manager → 启动 Pixel_8（GUI，最省事）
```
启动后 `flutter devices` 复查出现 `emulator-5554`，再 `flutter run -d emulator-5554`。

### 排障：常见报错
- **`No supported devices found with name or id matching 'emulator-5554'`** → 模拟器进程根本没在跑（**不是 id 写错**）。先 `tasklist | grep -iE "qemu|emulator"` 确认无进程，再按上面「启动模拟器」拉起来，然后 `flutter devices` 复查。
- **`adb: command not found`（exit 127）** → 本机 adb 不在 PATH。用全路径 `C:\apps\Android\AndroidSDK\platform-tools\adb.exe`，或按上面把 `platform-tools` 加进 PATH。
- **`flutter emulators` 无输出 / exit 1** → 本机该命令不可靠（列表可能为空）。**别据此判断「没有 AVD」**——AVD 一直在 `C:\Users\风起\.android\avd\Pixel_8.avd`。
- **冷启动抓日志**：`am start` 对已运行应用只是切前台（result code=3），必须先 `adb shell am force-stop <pkg>` 再冷启动（同「UI 体系」排查技巧）。
- 查包名：`adb shell cmd package list packages | grep jianli`。
- Gradle JVM 已加 `--enable-native-access=ALL-UNNAMED`（修 JDK restricted-method 警告，见 `android/gradle.properties`）。
- **已知无法修的警告**：KGP 弃用警告（mobile_scanner / workmanager_android 用旧 Kotlin Gradle Plugin）——两插件已是最新，需等上游支持 Flutter built-in Kotlin，仅警告不阻塞。
- Android sqlite3：jniLibs 三 ABI（arm64-v8a / armeabi-v7a / x86_64）手动分发 `libsqlite3.so`（源文件取自 sqlite3.dart 3.5.2 release）。
- iOS：需 Mac + Xcode，Windows 阶段保留 ios 目录不构建。

## 功能域清单与状态
| 功能域 | 路由 | 状态与要点 |
|---|---|---|
| home | `/` | Dashboard 聚合：习惯/待办/专注/提醒统计 + 最近倒计时 + 快捷入口；**Phase 3 视觉重设计**（渐变英雄卡 + 专属色磁贴 + StaggerList）；右上角**设置按钮** |
| habit | `/habit` | 今日打卡 + 幂等切换（key=`habitKey#date`）+ 近 7 天；**视觉焕新**：**PageBanner 绿(2)**（启用/今日完成统计）+ 条目专属色 `SquircleBox` 图标盘 + `AnimatedCheck` + StaggerList |
| todo | `/todo` | 列表/筛选/新增/勾选/滑动删除，uuid 主键，字段与桌面一致；**视觉焕新**：**PageBanner 蓝(1)**（进行中/已完成，取全量不随过滤跳变）+ `JianliSegmented` 滑块分段 + 专属色图标盘 |
| pomodoro | `/pomodoro`、`/pomodoro/records` | 状态机解析（reminders stateful）+ 只读倒计时 + 流水统计；**视觉焕新**：**PageBanner 红(6)**（当前阶段+剩余时间）+ 白卡进度环（红色弧）；记录页 **PageBanner 红(6)** 三统计 |
| reminder | `/reminders` | 三模式 time/interval/stateful，启停联动本地通知；过滤 `source==='todo'`；**视觉焕新**：**PageBanner 琥珀(3)**（全部/启用中统计）+ 专属色图标盘 + StaggerList |
| countdown | `/countdown` | 独立表（end_time 毫秒基准 + paused_remaining，与桌面同构抗休眠）+ 暂停/恢复/重置；**视觉焕新**：大计时器整卡 **PageBanner 同款紫(0) 渐变**（白色 RingProgress + `trackColor` 半透明白 + 装饰圆） |
| notes | `/notes` | 列表（分类 chips）/ 详情（flutter_widget_from_html 渲染）/ 编辑（轻量文本，html 段落化落库，桌面 vue-quill 可渲染；flutter_quill 富文本 P2）；**视觉焕新**：**PageBanner 琥珀(3)**（篇数/分类数统计）+ `_NoteCard`（琥珀图标盘）+ StaggerList；详情页分类改琥珀软底 chip |
| conversation | `/conversation` | 主题列表 + 消息流 + 新建（过滤 `is_deleted`）；LLM 后端未定；**视觉焕新**：**PageBanner 粉(4)**（主题数统计）+ `_ThemeCard`（粉首字头像盘）+ StaggerList；消息气泡改粉 `accentSoft` 软底 + 小头像盘 |
| ebook | `/ebook` | file_picker 导入 → sha256 content_hash 身份键 → epubx（PascalCase 字段）/ TXT 正则分章 → 章节渲染 + 按章进度；PDF、CFI 精确进度未做；**视觉焕新**：**PageBanner 青(5)**（藏书数）+ **CustomScrollView+SliverGrid** 封面网格（按标题 hashCode 渐变 + 进度条）；阅读器正文 pageTint 护眼底 |
| twofactor | `/twofactor` | TOTP 全算法 + vault 口令解锁 + 动态码卡片（复制/倒计时/锁定清内存）+ 添加；**视觉焕新**：**PageBanner 紫(0)**（账户数）+ 解锁表单 pageTint+紫渐变图标盘 + `AccountCodeTile` 紫图标盘 |
| password_vault | `/password-vault` | 移动端口令库（同信封格式 .jlv）；**视觉焕新**：**PageBanner 蓝(1)**（条目数）+ 门禁表单 pageTint+蓝渐变图标盘 + 条目首字母蓝 `accent(1)` 渐变 SquircleBox + StaggerList |
| file_vault | `/file-vault` | 与 PC 完全兼容：wrappedKey 解包 + JLV1 parse + 导入/预览/删除；**视觉焕新**：**PageBanner 绿(2)**（文件数）+ 门禁表单 pageTint+绿渐变图标盘 + 文件行绿 `accent(2)` 渐变 SquircleBox |
| qr | `/qr` | 生成（text/url/wifi/vCard/email）+ 识别（mobile_scanner）+ 历史；**视觉焕新**：顶部 **PageBanner 琥珀(3)**（FTabs 包进 Expanded，`expands:true` 雷区照旧）+ 历史页 `_QrHistoryTile`（琥珀图标盘）+ StaggerList |
| sync | `/sync` | 扫描/手动 IP/推送/拉取，四种组合全通；**视觉焕新**：**PageBanner 青(5)**（发现设备/可同步表统计）+ 设备行图标青 `accent(5)` SquircleBox |
| screenshots | — | 未开工；移动端无法系统级监听截图，重设计为相册导入/分享收纳 |
| 主题 | — | **5 套主题样式**（渐离紫 `zi` / 远峰蓝 `blue` / 森野绿 `green` / 落日橙 `orange` / 樱粉 `pink`，`AppTheme.styles`）+ 三态模式（跟随系统/浅色/深色），SharedPreferences 持久化；切换入口在首页与三个分组页右上角的**设置按钮 → 左侧设置面板**。桌面 25 套 token 映射 P2 |

## 新增功能域落地清单
1. 建 `lib/features/<module>/`（models / repositories / providers / components 按需原子拆分，带中文注释）。
2. 需要数据表：按「drift 三大铁律」加表定义并注册，跑 build_runner，老用户写 onUpgrade 迁移。
3. 页面 UI 按「UI 体系（forui）」章节的骨架与组件对照表编写；在 `lib/app/router/app_router.dart` 加路由，并在 `lib/features/hubs/hub_pages.dart` 对应分组页加入口（对应桌面端「侧边栏菜单 + 可见开关」的移动端做法）。
4. 涉及到点提醒：在 `core/notifications/notification_service.dart` 的 `NotificationChannels` 注册渠道，reminders → 通知计划翻译。
5. 需要双端同步：表必须 TEXT 主键，同时加移动端 `kSyncableTables` 与桌面端 `syncModule.ts` 白名单。
6. `flutter analyze` + `flutter test` 过基线，更新本 SKILL.md 的功能域清单。

## 使用方式
1. 接到任务先判断属于「数据 / 加密 / 同步 / UI / 构建」哪一类，读对应章节。
2. 涉及桌面端契约（表结构、加密信封、同步对端协议）时，读桌面技能 `C:\cod\jianli\jianli-app\.zcode\skills\jianli-app\` 下对应文档（`references/flutter-port.md`、`references/modules/sync.md` 等）。
3. 新增能力优先复用既有模式：Riverpod provider 拆分、幂等 upsert、NotificationChannels、sync 白名单，不要另起炉灶。
4. 所有文档用中文；发现与代码不符，直接更新对应文档，保持 skill 与代码同步。

## UI 现代化与动效（Phase 0/1 已落地）
完整规划见 `references/ui-modernization-plan.md`（6 阶段：Phase 0 地基 → Phase 5 收口）。

**Phase 0 地基（已完成）**
- `app_theme.dart` 新增 **`AppTokens`**（设计 token 唯一入口）：圆角档位 sm/md/lg/xl、柔和阴影 `elevation(ctx, level:0..3)`、主色渐变 `primaryGradient`、语义软底 `soft`、动效节律 `fast/base/slow` + `standard/emphasize`。组件取色/取圆角一律走它，**严禁页面写死**。
- `lib/app/anim/`：
  - `jianli_motion.dart` — `JianliMotion.enabled(context)`（读系统「减弱动态效果」）+ `duration(ctx, normal)` 自动降级。
  - `jianli_haptics.dart` — `haptic(type, [context])`，用内置 HapticFeedback（**无新依赖**）。
  - `jianli_transitions.dart` — 自建 `fadeSlidePage` / `fadePage`（**刻意不引 `animations` 包**：其 Material 耦合重，易与 material_ui 平行 Material 类冲突）。
- `app_router.dart`：全屏 push 路由改 `pageBuilder` 包 `fadeSlidePage`；**底部四分支保持 `builder`**（导航壳用 indexedStack 管状态，Tab 转场 Phase 2 再精细化，`fadePage` 已备好）。
- `app.dart`：主题切换加 `AnimatedContainer` 背景过渡。

**Phase 1 原子组件（已完成）**——均在 `lib/app/ui/`，全部 import material_ui、取色走 token：
`TapScale`(按压缩放) / `GlassCard`(磨砂) / `GradientButton`(渐变) / `ShimmerSkeleton`(骨架屏，自实现) / `AnimatedStat`(数字滚动) / `AnimatedCheck`(弹簧对勾) / `StaggerList`(列表逐条入场) / `JianliSegmented`(滑块分段) / `ConfettiOverlay`(彩带，自实现) / `PageHero`(Hero 包装) / `SquircleBox`(超椭圆)。
就地升级（向后兼容、旧调用方零改动）：`AppCard` 默认悬浮阴影 + 按压缩放、`RingProgress` 改 StatefulWidget 进度平滑过渡、`StatBlock` 加 `animate` 接 AnimatedStat、`EmptyState` 加 `illustration` 插画位。
Shimmer / Confetti **均自实现，未新增任何依赖**（比引 `shimmer`、`confetti` 包更可控）。

**⚠️ 动效组件开发雷区（Phase 1 实踩，写组件前必读）**
1. **`State.dispose` 必须 `super.dispose()`**（`@mustCallSuper`）——写成 `void dispose() => _ctrl.dispose();` 报 `must_call_super`；`initState` 同理。
2. **`context` 不能用在字段初始化器**——`late final _ctrl = AnimationController(duration: JianliMotion.duration(context, ...))` 非法。改为 `late AnimationController _ctrl;` 在 `initState` 赋值；或字段里给常量、initState 里再改 `_ctrl.duration`。
3. **record 字段 `.$1` 不能直接提升**——`items[i].$1` 是 getter，先 `final icon = items[i].$1; if (icon != null) Icon(icon, ...)`。
4. **builder 参数列表要写全**：`AnimatedBuilder` 是 `Widget Function(BuildContext, Animation<double>)`，`TweenAnimationBuilder` 是 `Widget Function(BuildContext, T, Widget?)`。别写 `(_, __)`（触发 `unnecessary_underscores`），用 `(_, animation)` / `(_, v, child)`。
5. **参数别命名为 `haptic`**——会遮蔽 `jianli_haptics.dart` 导入的顶层 `haptic()` 函数，导致 `haptic(haptic!, ctx)` 报「可空函数不可无条件调用」。`JianliSegmented` 里已改名 `hapticType`。
6. 动效组件一律经 `JianliMotion.enabled/duration` 降级，别在组件里另写一套减弱动效判断。
7. 列表动效用原生 `Animated*`/`Tween`；玻璃（BackdropFilter）只用于横幅/弹层，**列表区用 elevation 而非 blur**，防掉帧。
8. **⚠️ `initState` 里绝对不能读 `MediaQuery`（含 `JianliMotion.enabled`/`JianliMotion.duration`，它们内部 `MediaQuery.of(context)` 会 `dependOnInheritedWidget`）**——否则启动即崩：`The following assertion was thrown ... dependOnInheritedWidgetOfExactType(MedianKey<MediaQuery>) ... called from constructor/initState`。修复模板：把所有依赖 `context` 的动效初始化（时长、是否减弱、首帧 `forward()`）从 `initState` 移到 `didChangeDependencies()`，并用一次性守卫（`bool _started`）防重入。涉及组件已全量修复：`stagger_list.dart`、`animated_check.dart`、`ring_progress.dart`、`confetti_overlay.dart`。

**Phase 3 — 首页 / 分组页视觉重设计（已完成，2026-09-05）**
用户反馈原首页「白底 + 白卡 1px 描边 + 紫小图标」像 2015 年前的 UI、没有个性，故提前从「逐屏接线」升级为「视觉重设计」。新增视觉语言：

- **`AppTokens` 新增个性色板**：`accents`（紫/蓝/绿/琥珀/粉/青/红 7 色）+ `accent(i)` + `accentSoft`（入口磁贴软底，亮暗自适应）+ `accentGradient`（图标底盘渐变）+ **`pageTint`**（页面底色叠 4%~6% 主色冷调，**去掉「纯白苍白感」，这是观感变化最大的一处**）。
- **新组件 `lib/app/ui/entry_card.dart`（`EntryCard`）**：渐变超椭圆图标底盘 + 标题 + 描述 + 箭头，取代旧的「白卡描边 + 紫小图标」；按 `accentIndex` 取专属色，**每个功能域一个色、不撞色**。首页与三个 Hub 分组页共用。
- **`SquircleBox` 增强**：新增 `gradient` 与 `alignment` 参数（图标底盘传 `Alignment.center` 居中，否则图标会贴左上角）。
- **`dashboard_page.dart` 重设计**：自定义大标题问候（`渐离` 30px w800 + 日期 + 渐变徽章）→ 渐变英雄卡（28 圆角 + level-3 阴影 + 白色装饰圆 + 数字 `AnimatedStat` 滚动）→ 最近倒计时卡 → 4 个专属色快捷磁贴 → 彩色分组入口卡；整页 `StaggerList` 分节入场，页面套 `pageTint`。
- **`hub_pages.dart` 重设计**：抽出 `_HubList`（底色冷调 + stagger），入口元组加第 5 项 `accentIndex`；效率=绿/蓝/红/紫/琥珀，内容=琥珀/粉/青，工具=紫/蓝/绿/琥珀/青。

> 后续其他页面（习惯 / 待办 / 番茄 / 笔记 / 电子书 / 2FA 等）沿用同一语言：`pageTint` 打底 + `EntryCard`/`SquircleBox` 专属色 + `StaggerList` 入场 + `AnimatedCheck` 反馈。

**Phase 3→4 · 全页彩焕「PageBanner 渐变横幅」（已完成，2026-09-05）**
用户要求所有功能页达到首页同款「颜色丰富」观感（渐变英雄卡视觉下沉到每个功能页）。新增与接线：

- **新组件 `lib/app/ui/page_banner.dart`（`PageBanner`）**：页面专属强调色渐变横幅 —— `accentGradient(accent)` 渐变底 + 白色装饰圆（右上/右下两枚）+ 半透明白 `SquircleBox` 图标盘 + 白字标题/副标题 + 可选统计行（`List<(String, String)>` 传 `(数值, 标签)`，纯数值自动 `AnimatedStat` 数字滚动）+ level-3 阴影；`accentIndex` 与 Hub 分组页入口色一一对齐，**每个功能域一色不撞色**。默认 margin `(16, 12, 16, 4)`，直接塞进各页 ListView/Column 即可。
- **逐页接线**（横幅色 = Hub 入口色）：habit=2 绿（启用/今日完成双统计）、todo=1 蓝（统计基于全量计算，不随过滤切换跳变）、pomodoro=6 红（横幅显示当前阶段/剩余 + 白卡承托进度环，环改红色）、pomodoro_records=6（原 primaryGradient 统计横幅换成 PageBanner 三统计）、countdown=0 紫（**大计时器整卡渐变化**：白色 RingProgress + `trackColor` 半透明白 + 白字大时间 + 装饰圆，取消外层 AppCard）、reminder=3 琥珀（全部/启用中双统计）、notes=3 琥珀（列表横幅 + 详情页分类改琥珀软底 chip）、conversation=4 粉（列表横幅 + 消息气泡由 `colors.card` 改 `accentSoft(accent(4))` 粉软底）、bookshelf=5 青（GridView 改 **CustomScrollView + SliverGrid**，横幅随页面滚动）、2FA=0 紫（解锁表单套 pageTint + 渐变盘替代裸图标；码列表顶部横幅）、password_vault=1 蓝、file_vault=2 绿（两者门禁表单同 2FA 式样 + 列表横幅）、qr=3 琥珀（横幅置于 FTabs **之上**，FTabs 包进 `Expanded` —— `expands:true` 雷区照旧生效）、sync=5 青（发现设备/可同步表双统计）。
- **组件增强**：`RingProgress` 新增可选 `trackColor`（放彩色渐变底上传半透明白，缺省仍 muted）；`EmptyState` 空态图标从裸 `border` 色图标升级为**主色软底 `SquircleBox` 盘**（76×76 圆角 26，全 App 空态一并变彩）。
- **顺手清理**：删除 habit 页死代码 `_WeekStrip`；清掉 4 条存量 lint（unused_element ×1、curly_braces_in_flow_control_structures ×2、settings_panel 的 `use_build_context_synchronously`——`originContext` 补 `mounted` 守卫）。

## 维护说明
- 本 skill 是移动端「项目知识基线」，随代码演进而更新；每完成一个功能域或踩出新雷区，同步「功能域清单」与「全局红线」。
- 2026-09-05：UI 全量换装 forui（shadcn 风格）+ material_ui，全 App 页面已改造（骨架/组件对照见「UI 体系」章节）。
- 2026-09-05：**UI 现代化 + 操作动效总体规划**已落地为 `references/ui-modernization-plan.md`——诊断现状短板、定义设计 token（形状/阴影/渐变/语义软底/动效时长曲线）、新增原子组件（GlassCard/GradientButton/ShimmerSkeleton/AnimatedStat/AnimatedCheck/StaggerList/JianliSegmented/ConfettiOverlay/PageHero/SquircleBox）、自建页面转场（禁用 `animations` 包以避开 material_ui 冲突）、Haptics + 减弱动效降级，含 6 阶段实施路线（Phase 0 地基 → Phase 5 收口）。改造时严格守住 forui/material_ui 约束与 FTabs `expands` 雷区。
- 2026-09-05：UI 现代化 **Phase 0 地基已完成**——`app_theme.dart` 加 `AppTokens`（形状/阴影/渐变/语义软底/动效节律）；新增 `lib/app/anim/{jianli_motion,jianli_haptics,jianli_transitions}.dart`（减弱动效开关 + 触感 + 自建 `fadeSlidePage`/`fadeSlide` 转场，刻意不引 `animations` 包）；`app_router.dart` 全屏 push 路由接 `fadeSlidePage`；`app.dart` 主题切换加 `AnimatedContainer` 背景过渡。`flutter analyze` 0 问题、`flutter test` 5/5 基线通过。
- 2026-09-05：UI 现代化 **Phase 1 原子组件已完成**（详见「UI 现代化与动效」章节）——`lib/app/ui/` 新增 TapScale/GlassCard/GradientButton/ShimmerSkeleton/AnimatedStat/AnimatedCheck/StaggerList/JianliSegmented/ConfettiOverlay/PageHero/SquircleBox；AppCard/RingProgress/StatBlock/EmptyState 就地升级。lint/类型问题已全修（dispose 漏 super、context 在字段初始化器、record 空安全提升、builder 参数列表、haptic 参数名遮蔽），同章节已固化 7 条动效组件开发雷区。**构建与运行交用户本地执行**（Agent 侧无 GUI 且后台构建过慢），命令见「构建与验证」的「跑起来看效果」小节。
- 剩余规划（截至 2026-09-05）：真机全量验证、桌面 25 套主题映射到 forui、flutter_quill 富文本编辑、PDF / CFI 精确进度、interval 通知精细化、QR 样式、同步会话加密、conversation LLM 后端、**UI 现代化 Phase 2（壳与导航动效）→ Phase 3（逐屏动效接线）→ Phase 4（点睛与无障碍）→ Phase 5（收口）**。
- 2026-09-05：**启动崩溃修复**——`StaggerList`/`AnimatedCheck`/`RingProgress`/`ConfettiOverlay` 四个动效组件在 `initState` 内读 `JianliMotion.enabled/duration`（内部 `MediaQuery.of`），触发 `dependOnInheritedWidgetOfExactType ... called from initState` 启动崩溃。已全部改为 `didChangeDependencies` + 一次性守卫（`_started`/`_initialized`）。雷区 #8 已固化。修复后由用户本地 `flutter run -d emulator-5554` 验证（Agent 侧不跑 analyze，>30s 即交用户）。
- **2026-09-05：主题系统 + 设置面板 + 剩余页面 UI 全量焕新（Phase 3→4）**。① 主题：`app_theme.dart` 参数化为 5 套 `ThemeStyle`（紫/蓝/绿/橙/粉）+ 新增 `theme_providers.dart`（`themeStyleProvider`/`themeModeProvider`，SharedPreferences 持久化），`app.dart` 改 `ConsumerWidget` 读 provider，切样式/模式即时全树重渲。② 入口：首页与三个分组页右上角装饰块换成 **`SettingsButton`**，点开 **左侧滑出设置面板**（自定义 `PageRouteBuilder`，刻意不用 forui 弹层以避免与 material_ui 平行 Material 类冲突），内含 5 色环样式选择 + 三态模式 `JianliSegmented`。③ 页面焕新（沿用 Phase 3 视觉语言 `pageTint` + 专属色 `SquircleBox` + `StaggerList` + `AppCard`）：效率类（habit/todo/reminder/pomodoro/countdown/pomodoro_records）、内容类（note 列表·详情·编辑、conversation 列表·消息流、bookshelf·reader）、工具类（2FA/密码库/文件保险箱/二维码/同步）。子页强调色与 Hub 入口色对齐（notes=3、conversation=4、ebook=按标题 hash、2FA=0、密码库=1、保险箱=2、QR=3、sync=5）。④ 新雷区已固化到「Riverpod 3 / forui API 雷区」小节（**`valueOrNull` 已移除改 `.value`；`FHeader` 用 `suffixes` 不是 `actions`；`material_ui` 的 `ThemeMode`；`JianliSegmented` items 传 IconData**）。
- 2026-09-05：**全页彩焕「PageBanner 渐变横幅」落地（Phase 3→4 二次焕新）**——新原子组件 `lib/app/ui/page_banner.dart`（页面专属强调色渐变横幅：accentGradient + 白色装饰圆 + 半透明图标盘 + 白字统计行，纯数值自动 `AnimatedStat`；`accentIndex` 与 Hub 入口色对齐），13 个功能页全部接线：habit 绿(2) / todo 蓝(1) / pomodoro+records 红(6) / countdown 紫(0，大计时器整卡渐变 + 白色进度环) / reminder 琥珀(3) / notes 琥珀(3，详情分类改软底 chip) / conversation 粉(4，消息气泡改 accentSoft 软底) / bookshelf 青(5，GridView 改 CustomScrollView+SliverGrid) / 2FA 紫(0，解锁表单渐变盘) / 密码库 蓝(1) / 保险箱 绿(2) / QR 琥珀(3，横幅置于 FTabs 上方) / 同步 青(5)。组件增强：`RingProgress` 加可选 `trackColor`；`EmptyState` 图标升级主色软底盘。顺手清 4 条存量 lint + 删 `_WeekStrip` 死代码。静态检查 `dart analyze` **0 问题**（经 dart.exe 直连跑通）；`flutter test` 未代跑。**分工铁律更新：Agent 只写码改档，一切 flutter/dart 命令交用户执行**（「跑起来看效果」小节已改写，「30 秒规则」作废）。
- 剩余规划（截至 2026-09-05）：真机全量验证、桌面 25 套主题映射到 forui、flutter_quill 富文本编辑、PDF / CFI 精确进度、interval 通知精细化、QR 样式、同步会话加密、conversation LLM 后端、UI 现代化落地（按 `references/ui-modernization-plan.md` 分阶段）。
