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
8. 【文档同步】每次大改动后同步更新本 SKILL.md（功能域状态、新雷区、新约定）；发现文档与代码不符，直接修正文档。
9. 【底部抽屉键盘兼容（2026-09-07 修过的坑，全局适用）】**任何含输入框的底部抽屉**（`showFSheet(side: FLayout.btt)`）都要防键盘压扁：forui `showFSheet` 默认 `mainAxisMaxRatio = 9/16`，键盘弹起时路由可用高度 =「屏幕高 − 键盘高」，抽屉最大高度被压成剩余高度的 56% → 内容被压成极矮一条、看不到。修复范式：统一走封装入口（如 `todo_sheets.dart` 的 `_showTodoSheet`），设 `mainAxisMaxRatio: null` + `resizeToAvoidBottomInset: true`，高度改由 sheet 承载组件（如 `_sheetScaffold`）的 `maxRatio(0.9)` 决定，键盘弹起时整张抽屉抬到键盘上方、内容在 `SingleChildScrollView` 内滚动。该承载组件的 `keyboard:` 参数**不可**再加 `viewInsets.bottom` 到外壳 padding（那会把内容高度再吃掉一截→重新压扁），表单类只需一点点固定底部呼吸距离即可。

## 技术栈与桌面端对应
| 移动端 | 桌面端 | 说明 |
|---|---|---|
| Flutter 3.47.2 stable（`C:\src\flutter`，Dart 3.13.2） | Electron + Vue3 + TS + Vite | SDK 在 `C:\src\flutter\bin`，PATH 已配 |
| **forui 0.26.x + material_ui 1.1.x**（UI 组件库，2026-09-05 换装） | Element Plus / 自研视觉 | shadcn 风格；material_ui 是 Flutter Material 独立发行版 |
| flutter_riverpod **3.x** | Pinia | ⚠️ 实装是 Riverpod 3.x，API 与 2.x 有差异，以 3.x 文档为准 |
| go_router | vue-router | `lib/app/router/app_router.dart` |
| drift + sqlite3 | newSql（better-sqlite3） | 表定义逐列对齐桌面端 db.sqlite |
| flutter_widget_from_html / flutter_quill | vue-quill | 渲染已通；flutter_quill 富文本编辑器 P2 |
| awesome_notifications | 提醒引擎（reminders 表） | reminders → 本地通知计划翻译；`delivery` 双模式（notification 系统通知 / alarm 闹钟：preciseAlarm+fullScreenIntent+alarm 渠道）；闹钟支持重复响铃（`extraRings`）与「稍后提醒」动作（`actionSnooze` + payload） |
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
- 页面骨架：`FScaffold(header: FHeader(title:...) / FHeader.nested(title:, prefixes: [FHeaderAction.back(onPress: () => context.pop())]), child: ...)`；**FBottomNavigationBar 只能放 FScaffold.footer**（Material Scaffold 的 bottomNavigationBar 不可用），选中态由 `index`/`onChange` 驱动，item 无 onPress；`childPad` 默认 `true`，会再给 `child` 套一层 `childPadding = pagePadding`（水平 12）。为避免与 ListView 自身水平 padding 叠加成 24，**全屏页一律 `childPad: false`，水平边距交给 ListView 的 `AppTokens.pagePadding` 统一控制**（改 `AppTokens.pagePadding` 一处即全 App 生效）；标题（FHeader）不受影响，仍由 `FThemeData.headerStyles` 的 `pagePadding` 控制。⚠️ 踩坑：若既不设 `childPad:false` 又在 ListView 写水平 `AppTokens.pagePadding`，内容体会比标题宽一倍的边距（24 vs 12）。
- 组件替换对照：AppBar→FHeader(.nested)；Card→AppCard 原子或 FCard；按钮→FButton（`variant:` primary/secondary/destructive/outline/ghost，无命名构造）；TextField→FTextField（**controller 放 `FTextFieldControl.managed(controller:)`，无 controller 参数**；**监听输入变化也写在 managed control 的 `onChange:` 里，FTextField 本体无此参数**）；Switch/Checkbox→FSwitch/FCheckbox（value/onChange）；SnackBar→`showFToast`；showDialog→**仅破坏性确认用 `showFDialog`**（新增/编辑/展示一律走下条抽屉化约定）；ListTile→FTile/FTileGroup；CircularProgressIndicator→FCircularProgress；Linear→FDeterminateProgress(value: 0..1)。后三者（dialog/toast/sheet）是**顶层函数**，没有 context.toast 之类的扩展。
- **小功能抽屉化约定（2026-09-05 用户定，全局强制）**：所有小功能的**新增/编辑/展示**弹层一律用底部抽屉 `showFSheet(side: FLayout.btt)`，**禁用居中 `showFDialog`**；`showFDialog` 仅保留给**破坏性操作二次确认**（删除等）。抽屉模板：① **builder 内容必须用 `SheetSurface`（`lib/app/ui/sheet_surface.dart`）包住**——forui 的 Sheet 链路（FModalSheetRoute→Sheet→ShiftedSheet）**不画任何背景**，直接给 Padding 会露出灰色 barrier（「透明灰」实踩）；SheetSurface = 主题 background（已叠冷调、跟随亮暗/主题样式）+ 顶部圆角，`padding` 参数与 `Padding` 同名直换；② 键盘避让 `padding: EdgeInsets.fromLTRB(16,16,16, MediaQuery.of(c).viewInsets.bottom + 24)`；③ 高表单（多字段）加 `mainAxisMaxRatio: null` + `SingleChildScrollView`（先例 2FA 添加账户、密码库条目）；④ 提交按钮统一 `GradientButton`（图标 `FLucideIcons.check`），标题 `body.lg + w700`、副标题 muted；⑤ 输入框 `autofocus + onSubmit` 回车提交与按钮双通道。已改造先例：待办新增、笔记编辑页新建分类/标签、密码库新增/编辑条目、保险箱文件预览、QR 识别结果、阅读器目录、习惯/提醒/倒计时/对话新建。
- **FTabs 必看雷区**：Tab 内容含 viewport 类组件（ListView / GridView / FSelect 下拉菜单等）时**必须 `expands: true`**。默认 false 时 Tab 内容不经 Expanded 直接内联（无界高度），会触发 "Vertical viewport was given unbounded height" 连锁 render 异常，**整页白屏且 logcat 无 E/flutter 输出**（render 断言被吞，极难排查）。定位手段：最小 headless widget test 二分复现（先 FTabs 空内容 → 加真实内容，几秒锁定）。已有先例：`qr_page.dart`。
- 排查技巧：`am start` 对已运行应用只是切前台（result code=3），要抓启动/导航日志必须 `adb shell am force-stop <pkg>` 后冷启动再复现；真机调试 Dart 异常优先 `flutter run` 控制台，logcat 只能看到 `I/flutter` 标签的系统级输出。
- **FCard 无 title/subtitle 参数**：用 `FCard(builder: (c, style, _) => Column(children: [Text('标题', style: style.titleTextStyle), ...]))`。
- ⚠️ **forui 的 `factory({...})` 是 Dart 新「声明式工厂构造」语法**：类内部写 `factory({...})` = 未命名工厂构造，**调用时用类名直呼**（`FSelect<String>(items:...)`、`FThemeData(touch:, colors:)`），写 `Xxx.factory(...)` 会报 undefined。forui 0.26 源码文档示例大量使用点简写（`.light`、`.new`），照抄前先确认 Dart 版本支持。
- FTile/FItem 的 title/subtitle/details **不要放 Expanded/TextField**（不渲染，需 .raw 版）；FSelect 必须显式写泛型 `FSelect<String>`。
- 图标：`FLucideIcons.*`（Lucide 命名，forui.dart 已导出；**新图标名必须先到 forui_lucide 包 `lib/src/assets.g.dart` grep `static const <name> = IconData` 验证再用**，写不存在的名字是编译期报错——2026-09-05 实踩：`alphabet` 不存在，字号类图标用 `type`/`aLargeSmall`/`caseUpper`/`letterText`）。
- 原子组件 `lib/app/ui/`：AppCard / SectionHeader / EmptyState / StatBlock / RingProgress / **PageBanner**（功能页渐变横幅，见「UI 现代化与动效」Phase 3→4 小节）—— 与业务无关的视觉复用入口，新页面优先用它们拼装。
- 残留 Material 组件白名单（无 forui 等价物，material_ui 版已被近似主题着色）：RefreshIndicator、Dismissible（滑动删除）、ReorderableListView、Slider、mobile_scanner、qr_flutter。
- 桌面 25 套主题映射（P2）：在 `app_theme.dart` 的 `_build` 加方案表，每套主题 = 一份 `FColors.copyWith` 主色（+可选中性色）覆盖。

### 主题体系（5 套样式 + 三态模式 + 阅览模式，2026-09-05 更新）
- `AppTheme.styles` 定义 5 套 `ThemeStyle{id,name,lightPrimary,darkPrimary}`：渐离紫 `zi`、远峰蓝 `blue`、森野绿 `green`、落日橙 `orange`、樱粉 `pink`；`styleById(id)` 按 id 取（缺省回落首套）。`AppTheme.build(style:, brightness:)` 是唯一构建入口，`materialLight/materialDark` 供 MaterialApp。
- `lib/app/providers/theme_providers.dart`：`themeStyleProvider`（存样式 id，key `jianli.themeStyle`）+ `themeModeProvider`（存 `AppThemeMode.system/light/dark`，key `jianli.themeMode`）+ **`readingModeProvider`**（`ReadingMode.normal/large` 阅览模式，key `jianli.readingMode`，`ReadingModeX.scale` 扩展给正文缩放系数），均 `AsyncNotifierProvider` + SharedPreferences 持久化；`toMaterialMode()` 把枚举转 Material 的 `ThemeMode`。
- `app.dart` 是 `ConsumerWidget`，读两个 provider 后把 `themeMode:` 与 `theme/darkTheme` 交给 MaterialApp，`builder` 里按 `Theme.brightnessOf(context)` 现算 `FTheme`（**这样切样式/模式即时全树重渲，不用重启**）。
- **基准字号体系（阅览模式）**：`AppTheme.build(style:, brightness:, baseFontSize:)` 构造 FThemeData 时传 `typography: base.typography.scale(sizeScalar: baseFontSize / forui默认md像素)`——普通文本（md）精确对齐基准像素，其余字型（xs/sm/lg/xl…）按 forui 默认比例**等比缩放**；运行时取默认 md 值做分母（不硬编码版本号）。**必须构造期传入**——`copyWith(typography:)` 不会让 forui 组件内部样式重推导（官方文档同款姿势：改 colors/typography 要新建 FThemeData）。基准值在 `AppTokens.baseFontSizeNormal=12` / `baseFontSizeLarge=18`，改这两个数全 App 字号体系生效。
- **设置面板**：`lib/app/ui/settings_panel.dart` 的 `SettingsButton`（齿轮 SquircleBox）放在首页右上角与三个分组页 `FHeader.suffixes`；点击 `showSettingsPanel(context)` 推一个 `PageRouteBuilder`（`opaque:false` + `barrierColor: Colors.black54` + 左侧 `SlideTransition(-1,0)→(0,0)`），面板内含 5 色环样式选择 + 三态模式 `JianliSegmented` + **阅览模式卡片选择（`_ReadingModeRow`，普通/大号字体）** + 同步/关于入口。**刻意不用 forui 弹层**，规避与 material_ui 平行 Material 类的冲突。

### ⚠️ Riverpod 3 / forui API 雷区（2026-09-05 实踩，写代码前必看）
1. **Riverpod 3 移除了 `AsyncValue.valueOrNull`** —— 取异步值用 `.value`（如 `ref.watch(themeStyleProvider).value ?? 'zi'`）。写 `.valueOrNull` 直接报 undefined。
2. **forui `FHeader` 没有 `actions` 参数** —— 尾部动作是 **`suffixes`**，左侧是 **`prefixes`**（`FHeaderAction.back(onPress:)`）。写 `actions:` 报「named parameter doesn't exist」。
3. **`material_ui` 的 `ThemeMode` 与 `flutter/material` 的不是同一类型** —— provider/工具函数里若返回 `ThemeMode`，该文件必须 `import 'package:material_ui/material_ui.dart';`，否则赋给 `MaterialApp.themeMode` 类型不兼容。
4. **`JianliSegmented` 的 `items` 类型是 `List<(IconData?, String)>`** —— 传 `Icon(FLucideIcons.sun)` 会类型不符，要传 **`FLucideIcons.sun`**（IconData 本体）。
5. **drift 行类名不是猜的**：二维码历史是 `QrHistoryData`（不是 `QrHistoryRow`）；新增组件引用行类型前先 grep 确认。
6. **`FTextField` 没有 `onChange` 命名参数**（2026-09-05 实踩，编译期报错）：监听输入变化必须写在 `FTextFieldControl.managed(controller:, onChange:)` 里，回调收 `TextEditingValue`（取文本用 `controller.text` 或 `_.text`）。直接写在 FTextField 上报「No named parameter with the name 'onChange'」。先例：`qr_page.dart`、`note_list_page.dart`。
7. **FThemeData 构造期定制样式：先实例 copyWith 再传实例**（2026-09-05 实踩，两连报）：构造器的 `scaffoldStyle:`（等 style 参数）收 **`FScaffoldStyle` 实例**，传 `(s) => ...` 回调报 Function→FScaffoldStyle 类型错；正确姿势 = `base.scaffoldStyle.copyWith(...)` 先造出新实例再传入。而**样式实例自身 copyWith 的 delta 参数**（如 `childPadding: EdgeInsetsGeometryDelta?`）是 **Delta 类**（官方工厂 `EdgeInsetsGeometryDelta.add/.scale/.value`，`scale(k)` 即全边等比缩放），**不是 lambda**——传函数同样类型错。变量名先定义再用（`isDark ? 0.06 : 0.04` 写在只有 `isLight` 的作用域直接 Undefined name）。
8. **forui typography 是两级结构**（2026-09-05 实踩）：`typography.body.{xs,sm,md,lg,xl}` / `typography.display.*`，**不存在 `typography.xs` 这类直取**——写错报「The getter 'xs' isn't defined for the type 'FTypography'」。
9. **provider 必须顶层声明，严禁 build 内联**（2026-09-05 实踩，电子书页空白转圈）：在 build 里 `ref.watch(StreamProvider(...))` 内联构造，每次重建都是**全新 provider**（初始态 loading）→「订阅→重建→再新建」死循环，页面永远加载。修复：抽到 `features/<module>/providers/` 顶层变量。

## 页面操作规范（共有交互，2026-09-05 起：新功能必须遵循，旧功能逐步对齐）
> 目的：让同类操作在全 App 有同一心智。每新增一种共有交互先在此登记模式与组件，再实现；改先例时同步本节。

1. **查询/筛选规范**：类型、标签、状态等**筛选条件一律收进底部「查询抽屉」**，用通用骨架 `showFilterSheet`（`lib/app/ui/filter_sheet.dart`）：
   - 抽屉结构固定：顶部 = 左侧「查询」标题 + 右侧**关闭裸图标（无背景色）**（关闭 = 不应用更改）；中部 = 选项区可滚动；底部 = **「重置 / 查询」两按钮恒贴抽屉底部**（选项区吸收剩余空间，Column 填充分配不用 min；`FButton.outline` 重置 + `GradientButton` 查询，等宽各半）。
   - **抽屉固定高度 50vh**（`SizedBox(height: 屏高×0.5)`，两改后定案：minHeight/松约束下按钮会随内容浮起，定高 + 选项区 `Expanded` 才能绝对贴底；选项多时中部滚动。调抽屉高度改 filter_sheet.dart 的 0.5）。
   - **同抽屉内所有选项 chip 统一规格**（padding h14/v7 + body.sm 文字；标签 chip = 色点 + 名称 + 选中对勾），禁止大小混排。
   - 交互语义：打开时**草稿从已生效条件初始化**；「重置」= 清空草稿（`refresh()` 刷新，不关闭）；「查询」= 应用草稿并关闭（草稿经 pop 值返回，record 传递）。
   - 列表页形态：关键词搜索保留页内输入框（实时过滤，不走抽屉）；筛选入口 = 搜索框右侧的筛选按钮（激活时主题强调色软底 + 生效条件数角标），**高度写死 40 对齐 forui sm 输入框 touch 规格高度**（`FTappable` 不上报固有高度，IntrinsicHeight 方案会把按钮压小——实踩勿回退）；已生效条件在搜索框下方以**可点掉的摘要 chip** 呈现。先例：`note_list_page.dart`（分类单选 + 标签多选）。
2. **新增/编辑保存规范**：保存/提交按钮**统一固定底部**——页面结构 = `Column[ Expanded(内容滚动区), 底部固定操作条(SafeArea + GradientButton，页面水平边距) ]`，按钮不随内容滚动、头部不放重复的保存入口（编辑态头部仅保留返回/删除等非保存动作）。先例：`note_editor_page.dart`（底部「保存笔记」渐变条，保存中变字+禁用）。
3. 既有相关约定（见「UI 体系」）：小功能新增/编辑/展示一律底部抽屉 `SheetSurface` + `GradientButton`；破坏性确认才用 `showFDialog`。


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

## 构建与验证

> 📘 **从零开始（clone → 配环境 → 运行 → 打包）的完整逐步操作见仓库 `README.md`**，
> 本文档只写「已知就够用」的命令速查与雷区。README 有更新时，两边的环境值（镜像地址、SDK 路径、AGP/compileSdk 版本）
> 需保持一致。

### 环境前置（每个新 shell 必设，缺一必踩）
```bash
# 中文用户名雷区（%TEMP% 含中文 → build_runner 自举编译报 Unable to read program.dill）+ 国内镜像
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"
cd /c/cod/jianli/jianli-mobile-app
```

### 日常开发循环（改码后按序执行）
```bash
flutter pub get                    # 改了 pubspec.yaml（依赖/版本）后必跑
dart run build_runner build -d     # 改了 drift 表定义（lib/core/db/tables/*.dart）后必跑，重新生成 app_database.g.dart
flutter analyze                    # 静态检查；基线 0 问题（2026-09-06 复核），出现新 error 必须修掉再交验
flutter test                       # 单测；基线全绿（totp RFC 向量 / transfer_utils / widget 冒烟，数量变化后更新此行）
flutter run -d emulator-5554       # 编译并启动到设备，看效果最快（r=热重载 / R=热重启 / q=退出）
```
布局排障开关见下文「代码级 paint 调试」。

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
| applicationId（包名） | `com.jianli.jianli_mobile_app`（`android/app/build.gradle.kts`，namespace 同） |
| minSdk / targetSdk | 24（`flutter.minSdkVersion`，Flutter 3.47 默认）/ 随 Flutter 插件默认 |
| 版本号 | `pubspec.yaml` 的 `version: 26.9.6+1`（`+`前=versionName，`+`后=versionCode；发版先改这里） |
| 签名现状（2026-09-06） | release 仍用 **debug key**（Flutter 模板 TODO，无 keystore）——自测可装可跑，**正式发布前必须按「生产打包」配正式签名** |
| 应用名 / 图标 | 渐离App（AndroidManifest `android:label` + iOS Info.plist）；图标/启动屏由 `tool/make_icons.py` 生成，源图 `appLogo.png` |

**代码级 paint 调试（布局排障利器，2026-09-05 新增）**：`lib/main.dart` 顶部有三个默认关闭的开关，排查布局时置 `true` 后热重载（r），用完关回：
```dart
const bool kDebugPaintSize = false;      // 所有组件画青色边框 + padding 可视化（≈ CSS outline）
const bool kDebugPaintBaselines = false; // 文字基线
const bool kDebugRepaintRainbow = false; // 重绘彩虹（颜色变了=发生了重绘，查多余重绘）
```
仅 debug/profile 生效（release 剥离 assert）；开关经 `flutter/rendering.dart show 限定导入`（避免与 material_ui 符号冲突）；配合 DevTools 的 Widget Inspector / Layout Explorer 使用效果最佳（`flutter run` 控制台按 `v` 打开）。

**启动 SDK 虚拟机——完整可复制序列（2026-09-05 固化）**：
```bash
# ① 环境变量（每个新 shell 必设：中文用户名雷区 + 镜像 + SDK 工具入 PATH）
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"
cd /c/cod/jianli/jianli-mobile-app

# ② 拉起虚拟机（后台运行，等它开机到锁屏/桌面）
/c/apps/Android/AndroidSDK/emulator/emulator.exe -avd Pixel_8 &

# ③ 确认在线（应出现 sdk gphone64 x86 64 (android-x64) → emulator-5554）
flutter devices

# ④ 编译并启动（首次构建数分钟属正常；运行会话内 r=热重载 / R=热重启 / q=退出）
flutter run -d emulator-5554
```
备选启动方式（`flutter devices` 里没有设备时先做这步）：
```bash
# 方式 1：直接拉起 AVD（最稳，推荐）
/c/apps/Android/AndroidSDK/emulator/emulator.exe -avd Pixel_8 &

# 方式 2：交给 Flutter（本机 flutter emulators 列表时常输出为空，不可尽信）
flutter emulators --launch Pixel_8

# 方式 3：Android Studio → Device Manager → 启动 Pixel_8（GUI，最省事）
```
启动后 `flutter devices` 复查出现 `emulator-5554`，再 `flutter run -d emulator-5554`。**真机调试**：手机开 USB 调试连电脑 → `adb devices` 授权 → `flutter devices` 拿真机 id → `flutter run -d <真机id>`（arm64 的 libsqlite3.so 已在 jniLibs 就位，无需特殊处理）。

### 生产打包（release APK / AAB，2026-09-06 全面拆解）

#### ① 版本号
- 唯一出处：`pubspec.yaml` 的 `version: 26.9.6+1`。`+` 前 = versionName（显示名），`+` 后 = versionCode（整数，**必须严格递增**才能覆盖安装）。发版第一步改这里。
- split APK 会自动在 versionCode 上加 `1000 × ABI 序号`（arm32=1/arm64=2/x64=3）；要强制用 pubspec 原值加 `-P force-version-code-ignoring-abi=true`。

#### ② 签名（当前 release 签 debug key，正式发布前必做，一次性配置）
1. 生成正式 keystore（本机一次生成、永久保管，**丢了无法再以同签名发版**；文件与口令勿外传/勿提交）：
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 36500 -alias upload
   # keytool 不在 PATH 时用 Android Studio 自带 JBR（本机 Android Studio 装在 C:\apps\Android，注意不是默认位置）：
   # "C:\apps\Android\Android Studio\jbr\bin\keytool.exe" <同上参数>
   # 该 JBR 实测为 JDK 25.0.2，同时也是 Gradle 构建实际使用的 JDK（PATH 上的 java 可能仍是 1.8，以 Gradle 用的为准）
   ```
2. 新建 `android/key.properties`（口令明文，勿提交）：
   ```properties
   storePassword=<keystore 口令>
   keyPassword=<key 口令>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
   `storeFile` 相对 **android/app/** 目录解析；keystore 放哪就写相对谁的路径，拿不准就写绝对路径。
3. 改 `android/app/build.gradle.kts`：文件顶部加两行 import 与加载逻辑，release buildType 换正式签名：
   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = keystoreProperties["storeFile"]?.let { file(it) }
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")   // 替换原来的 getByName("debug")
           }
       }
   }
   ```

#### ③ 打包命令矩阵（产物都在 `build/app/outputs/`）
| 命令 | 产物 | 用途 |
|---|---|---|
| `flutter build apk --release` | `flutter-apk/app-release.apk`（三 ABI 合一 fat 包） | **直接发用户装**，最省事 |
| `flutter build apk --release --split-per-abi` | `flutter-apk/app-{armeabi-v7a,arm64-v8a,x86_64}-release.apk` | 瘦包（体积约减半），真机一般发 arm64 |
| `flutter build appbundle --release` | `bundle/release/app-release.aab` | Google Play 上架 |
| `flutter build apk --debug --target-platform android-x64` | `flutter-apk/app-x64-debug.apk` | 模拟器快装调试，**非生产** |

#### ④ 安装与发布前验证
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk    # -r 覆盖升级保留数据；降级 versionCode 会拒装
adb shell am force-stop com.jianli.jianli_mobile_app            # 冷启动抓启动问题（am start 对热进程只是切前台）
adb shell am start -n com.jianli.jianli_mobile_app/.MainActivity
adb shell dumpsys package com.jianli.jianli_mobile_app | grep -E "versionName|versionCode"   # 核对版本
# 签名校验（上架/分发前）：
C:/apps/Android/AndroidSDK/build-tools/<版本号>/apksigner.bat verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```
- 未配正式签名时 `--release` 也能出包（debug key 签名），可装可跑，但**不能上架**，且与将来正式签名包互相覆盖会因签名不一致拒装（见排障）。
- release 专属问题复现：`flutter run --release -d <id>`。

### 图标 / 启动屏再生成（换 logo 或改尺寸策略时）
1. 覆盖根目录 `appLogo.png`（1024×1024 白底）。
2. `py tool/make_icons.py`（依赖 Pillow：`py -m pip install pillow`）——自动重出 Android 五密度 `ic_launcher` / 自适应前景（62% 安全区）/ `drawable-nodpi/splash_logo` / iOS AppIcon 15 尺寸（去 alpha）/ LaunchImage 三倍图。
3. 配套资源声明（一般不动）：`mipmap-anydpi-v26/ic_launcher.xml`、`values/colors.xml`、`values-v31` 与 `values-night-v31` 的 `styles.xml`（A12+ 系统启动屏白底；night 优先级高于 v31，故两处都要）。
4. 应用名（渐离App）：Android `AndroidManifest.xml` 的 `android:label` + iOS `Info.plist` 的 `CFBundleDisplayName/CFBundleName`。

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
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`（覆盖安装报签名不一致）** → debug 包 ↔ 正式签名包之间切换必现：`adb uninstall com.jianli.jianli_mobile_app`（会清数据）后重装。
- **`key.properties` / keystore 相关报错**（打包期 `FileNotFoundException` / `Password verification failed`）→ `storeFile` 相对 `android/app/` 解析；逐项核对文件存在、口令、alias。
- **release 包闪退而 debug 正常** → 先 `flutter run --release -d <id>` 本机复现；再看 `adb logcat` 过滤 `FATAL`。Flutter 下 R8 混淆缺反射规则的场景罕见，优先怀疑插件初始化（通知/后台任务）与 release 剥离 assert 暴露的空安全问题。
- **`A problem occurred evaluating project ':flutter_inappwebview_android'`** → 报错 `getDefaultProguardFile('proguard-android.txt') is no longer supported`（AGP 9.x 已删除该默认文件）。根因：`flutter_inappwebview: ^6.1.5` 依赖 `flutter_inappwebview_android: ^1.1.3`，官方最新版（6.1.5，无 7.x 可用）的 `android/build.gradle` 仍引用它，assembleRelease 评估阶段即抛错。**已永久修复**：仓库内 `third_party/flutter_inappwebview_android/` 为已打补丁副本（其 `android/build.gradle` 改用 `proguard-android-optimize.txt`），app `pubspec.yaml` 用 `dependency_overrides` 指向该本地路径。⚠️ **该 override 与 `third_party/` 目录必须保留**——若被误删或 `flutter pub cache repair` 后未恢复，报错会复现。release 若因 R8 优化误删插件代码而崩，在 `third_party/flutter_inappwebview_android/android/proguard-rules.pro` 末尾加 `-dontoptimize` 兜底。

## 功能域清单与状态
| 功能域 | 路由 | 状态与要点 |
|---|---|---|
| home | `/` | Dashboard 聚合：习惯/待办/专注/提醒统计 + 最近倒计时 + 快捷入口；**Phase 3 视觉重设计**（渐变英雄卡 + 专属色磁贴 + StaggerList）；右上角**设置按钮** |
| habit | `/habit` | 今日打卡 + 幂等切换（key=`habitKey#date`）+ 近 7 天；**视觉焕新**：**PageBanner 绿(2)**（启用/今日完成统计）+ 条目专属色 `SquircleBox` 图标盘 + `AnimatedCheck` + StaggerList |
| todo | `/todo` | **已对齐 PC（2026-09-07，全量重写，详见「待办」专节）**：三视图 list/card/calendar（`JianliSegmented`）；搜索 + 筛选抽屉（优先级/状态/标签/显示已完成·模板/分组 none·status·due·parent）；全量统计 PageBanner 蓝(1)；分组（状态/到期 overdue·today·tomorrow·thisweek·later·nodate/父任务带子任务进度）；全字段（优先级/到期/状态 6 态/截止提醒→本地通知/重复 daily·weekly 自动生成实例/父任务多选/标签多选/子任务级联）；记录进展→主题对话；动作/确认/编辑/筛选/日期/标签/父任务**全部底部抽屉**。表定义零改动、无需迁移 |
| pomodoro | `/pomodoro`、`/pomodoro/records` | 状态机解析（reminders stateful）+ 只读倒计时 + 流水统计；**视觉焕新**：**PageBanner 红(6)**（当前阶段+剩余时间）+ 白卡进度环（红色弧）；记录页 **PageBanner 红(6)** 三统计 |
| reminder | `/reminders` | **已对齐 PC newTips（2026-09-09 全量重写）**：三模式 time/interval/stateful；**送达双模式** `delivery`（'notification' 系统通知 / 'alarm' 闹钟：preciseAlarm+fullScreenIntent+高重要'alarm'渠道，锁屏弹全屏，App 被杀仍响）；time 模式支持 每天/每周/一次性(date)/每小时/每月/每年，weekDays 用 PC 约定 0=周日…6=周六（awesome 1=周日…7=周六→+1）；interval 模式每 N 分/时/天（NotificationInterval）；免打扰 idleTime 段内顺延（一次性最佳，周期逐次精确跳过需后台 worker，标记近似）；过滤 `source==='todo'`；stateful 只读展示（番茄钟拥有）；进入页面 `rescheduleAll()` 重排程防 awesome 原生计划被清；**视觉焕新**：**PageBanner 琥珀(3)** + 专属色图标盘（闹钟红(6)/通知琥珀(3)）+ 新建/编辑底部抽屉 `SheetSurface`（JianliSegmented 选模式·送达·重复 + 星期 FButton + 免打扰开关）。**创建 UI 已开放全 6 种重复**（每天/每周/一次性/每月/每小时/每年，`_repeatIndex` 0-5 → `'daily'/'weekly'/'once'/'monthly'/'hourly'/'yearly'`；每月写 `dayOfMonth`、每年写 `month`+`dayOfMonth`，`date` 三者都留以便回显编辑）；列表副标题用 `ReminderItem.repeatLabel`。**闹钟增强（2026-09-09）**：① 重复响铃 —— `scheduleCalendar(extraRings: alarm?2:0)` 额外排 2 次顺延 1 分钟的响铃（id `+1000*k`，可单独取消；hourly 场景 hour 为 null 只回绕分钟）；② 稍后提醒 —— 闹钟（fullScreen=true）自动带 `actionSnooze`「稍后提醒」按钮 + payload，点击后 5 分钟再响且可连续贪睡（`init()` 注册 `setListeners(onActionReceived:)` → `_onActionReceived`，重排 id 用 `base+50000` 段避开主响铃与 ring 段） |
| countdown | `/countdown` | 独立表（end_time 毫秒基准 + paused_remaining，与桌面同构抗休眠）+ 暂停/恢复/重置；**视觉焕新**：大计时器整卡 **PageBanner 同款紫(0) 渐变**（白色 RingProgress + `trackColor` 半透明白 + 装饰圆） |
| notes | `/notes` | 列表（**关键词页内实时搜索 + 「查询抽屉」筛选**：分类单选/标签多选，已生效条件可点掉）/ 详情（flutter_widget_from_html 渲染 + 彩色标签徽标）/ 编辑（轻量文本 + 分类/标签 chips + **底部固定保存条**，html 段落化落库，桌面 vue-quill 可渲染；flutter_quill 富文本 P2）；**标签能力已全量对齐 PC**（内容+标签双搜索、多选筛选、新建/软删，见「笔记标签双端契约」小节）；**视觉焕新**：PageBanner 琥珀(3)（结果数/标签数统计）+ 卡片彩色标签徽标 + StaggerList |
| conversation | `/conversation` | **已对齐 PC（2026-09-05，同步已打通——见「主题对话」专节）**：主题列表（update_time 倒序 + 消息数角标 + 主题标签彩色徽标）/ 新建·编辑主题（底部抽屉+固定保存条）/ 删除主题（子主题禁止+级联删消息）/ 消息流（置顶排前 + is_rich 走 HtmlWidget 渲染 PC 富文本 + 长按软删）/ 发送追加记录；LLM 后端未定；**视觉焕新**：PageBanner 粉(4) + StaggerList + 粉软底气泡 |
| ebook | `/ebook` | **打开空白/一直转圈已修（2026-09-05）**——根因：书架页 build 内联 StreamProvider（雷区 #9），改顶层 `bookshelfStreamProvider`；TXT 编码对齐 PC（BOM/UTF-8 严格/GBK 回退，`fast_gbk` 纯 Dart 包）；移出书架走 showFDialog 确认；组件化拆分 `book_cell.dart`。file_picker 导入 → sha256 content_hash 身份键 → epubx / TXT 正则分章 → 章节渲染 + 按章进度；**裁剪未做**（PC 有）：标注划线 / 书签 / 分类 / PDF 渲染 / 章节搜索 / 扫描文件夹；**视觉焕新**：PageBanner 青(5) + CustomScrollView+SliverGrid 封面网格；阅读器正文 pageTint 护眼底 |
| twofactor | `/twofactor` | TOTP 全算法 + vault 口令解锁 + 动态码卡片（复制/倒计时/锁定清内存）+ 添加；**视觉焕新**：**PageBanner 紫(0)**（账户数）+ 解锁表单 pageTint+紫渐变图标盘 + `AccountCodeTile` 紫图标盘 |
| password_vault | `/password-vault` | 移动端口令库（同信封格式 .jlv）；**视觉焕新**：**PageBanner 蓝(1)**（条目数）+ 门禁表单 pageTint+蓝渐变图标盘 + 条目首字母蓝 `accent(1)` 渐变 SquircleBox + StaggerList |
| file_vault | `/file-vault` | 与 PC 完全兼容：wrappedKey 解包 + JLV1 parse + 导入/预览/删除；**视觉焕新**：**PageBanner 绿(2)**（文件数）+ 门禁表单 pageTint+绿渐变图标盘 + 文件行绿 `accent(2)` 渐变 SquircleBox |
| qr | `/qr` | 生成（text/url/wifi/vCard/email）+ 识别（mobile_scanner）+ 历史；**视觉焕新**：顶部 **PageBanner 琥珀(3)**（FTabs 包进 Expanded，`expands:true` 雷区照旧）+ 历史页 `_QrHistoryTile`（琥珀图标盘）+ StaggerList |
| sync | `/sync` | 扫描/手动 IP/推送/拉取，四种组合全通；**视觉焕新**：**PageBanner 青(5)**（发现设备/可同步表统计）+ 设备行图标青 `accent(5)` SquircleBox；**#昵称**：发现设备区上方「我的设备」卡片展示本机随机昵称（`localNickname`，同 file_transfer 行机制）|
| file_transfer | `/file-transfer` | 双端批量互传（PC⇆手机），与 sync 同协议同历史表 `file_transfer`（含 `error` 失败原因列）；接收目录 `Download/渐离App文件互传/`（Android 需存储权限「所有文件访问」，入页申请；未授权/创建失败回退沙盒 `Documents/渐离App文件互传/`，iOS 恒走沙盒回退）；sha256 双端校验；历史成功记录可「打开」（**底部弹层 `showFSheet`+`SheetSurface`**：打开所在文件夹 / 用应用打开，原生化 —— `MethodChannel('jianli/file_actions')`（`MainActivity.kt` 实现 `queryOpenableApps` 系统解析可打开应用+图标base64 / `openFolder` 打开所在文件夹 / `openWithApp` 用指定应用打开）+ 自持 `FileProvider` `${applicationId}.fileprovider`（`res/xml/file_paths.xml` 覆盖整外部存储）+ manifest `<queries>` 声明 `VIEW */*` 包可见性；Dart 封装 `services/file_actions.dart` 的 `FileActions`；**按钮文字仍是「打开」、图标 `folderOpen` 不变**）/「分享」(`share_plus`)；记录区只显示当次批次（`_batchTid` 过滤，其他历史暂不展示）；记录标题下方有存储位置提示行（授权→`Download/渐离App文件互传/`，未授权→提示点「分享」经其他应用保存，iOS→沙盒 Documents，`_receiveHint` 随入页授权流程刷新）；**增强（2026-09-06 二批）**：重名覆盖策略(rename/overwrite)、最近设备记忆(离线可见)、断点续传、会话加密(AES-256-CTR，默认关)、接收询问弹窗(关自动接收时，已改底部抽屉 `showFSheet`+`SheetSurface`+`GradientButton`「接收」主按钮，非破坏性按 UI 规范不用 `showFDialog`；`_AskReceiveSheet` 组件)、并发守卫(429)、后台保活(wakelock)、历史分页+自动清理；**视觉焕新**：**PageBanner 粉(4)**（收发统计）+ FDeterminateProgress 逐文件进度 + 设备扫描/手动 IP（模拟器 `10.0.2.2`）；**#昵称（随机设备名，2026-09-06 新增，三次细化）**：本机随机昵称便于识别收发双方。**基座格式** `【形容词1】【形容词2】的【名词】`（如「软萌俏皮的樱桃」）；词库三组（`lib/core/sync/device_nickname.dart` 的 `_nickAdj1/_nickAdj2/_nickNoun`，与 PC `transferModule.ts` 同源 `随即词库.md`）+ `ensureNickname()` 持久化（shared_preferences 键 `device_nickname`/`device_nickname_ts`，**首次生成后永久留存、不再轮换**（2026-09-08 改，原 3 天轮换已移除）；**迁移**：旧格式（带 `的渐离App`/`的App`/`的PC`/` (App)`/` (PC)` 任一后缀）一律立即重生为新基座格式）。`main()` 启动 `await ensureNickname()` 预载。**平台后缀规则**：本机展示（首页顶部「渐离」、同步页/文件互传页「我的设备」卡片）只用 `localNickname`（基座、**不带任何后缀**）；广播给对端的场景（`startServer`/`startResponder`/offer `me`/发送 `from` 应答，即 `sync_service`/`sync_discovery`/`transfer_server`/`transfer_client`）改取 `localBroadcastName` = `${localNickname}的App`，因此发现设备/历史设备列表里的对端名带 `的App` 后缀以便区分平台。|
| ferry | `/ferry` | 隔空互传：屏幕二维码 → 摄像头直传（QRFerry 本地 WebView，≤10MB；与 PC 同机制共享资源） |
| screenshots | — | 未开工；移动端无法系统级监听截图，重设计为相册导入/分享收纳 |
| 主题 | — | **9 套主题样式**（渐离紫 `zi` / 远峰蓝 `blue` / 森野绿 `green` / 落日橙 `orange` / 樱粉 `pink` + 莫兰迪灰调四套：丹枫红 `red` / 秋香黄 `yellow` / 远山青 `cyan` / 霜月白 `white`，`AppTheme.styles`）+ 三态模式（跟随系统/浅色/深色）+ **阅览模式**（普通/大号正文字体，卡片 tag 切换），均 SharedPreferences 持久化；切换入口在首页与三个分组页右上角的**设置按钮 → 左侧设置面板**。桌面 25 套 token 映射 P2 |

## 新增功能域落地清单
1. 建 `lib/features/<module>/`（models / repositories / providers / components 按需原子拆分，带中文注释）。
2. 需要数据表：按「drift 三大铁律」加表定义并注册，跑 build_runner，老用户写 onUpgrade 迁移。
3. 页面 UI 按「UI 体系（forui）」章节的骨架与组件对照表编写；在 `lib/app/router/app_router.dart` 加路由，并在 `lib/features/hubs/hub_pages.dart` 对应分组页加入口（对应桌面端「侧边栏菜单 + 可见开关」的移动端做法）。
4. 涉及到点提醒：在 `core/notifications/notification_service.dart` 的 `NotificationChannels` 注册渠道（`habit`/`todo`/`pomodoro`/`alarm`），`reminders` → 通知计划翻译（`ReminderRepository.scheduleNotification` 按 `mode`+`delivery` 路由：`scheduleCalendar`/`scheduleInterval`/`scheduleOnce`；`alarm` 走 preciseAlarm+fullScreenIntent+alarm 渠道；`notification` 走普通渠道+allowWhileIdle）。⚠️ 闹钟的 preciseAlarm 需 Android 12+ `SCHEDULE_EXACT_ALARM`（已在 AndroidManifest 声明）；iOS 无等价 AlarmManager，闹钟退化为高优通知。改动 `reminders` 表（如加 `delivery` 列）须 `schemaVersion+1` + `onUpgrade` `addColumn`，并 `dart run build_runner build -d` 重新生成 `app_database.g.dart`。⚠️ **awesome_notifications 0.12.1 API 三坑（2026-09-09 实测踩过）**：① `actionButtons` 是 `createNotification` 的参数，**不是** `NotificationContent` 的（写进 content 直接「No named parameter」）；② `setListeners` 的回调参数名是 **`onActionReceivedMethod`**（没有 `onActionReceived`），且**必须传静态/顶层函数引用**、绝不能传闭包——插件内部用 `PluginUtilities.getCallbackHandle` 取句柄，闭包取不到会静默不触发回调；③ `ReceivedAction.id` 类型是 `int?`，参与算术前要 `?? 0`。⚠️ `ReminderItem` 新增字段须同步改 **4 处**：构造器 `required this.x` / `fromRow` / `copyWith`（参数 **+** body）/ `ReminderRepository._toCompanion`，漏任何一处都编译不过（2026-09-09 加 `month`/`dayOfMonth` 时踩过；注意 `month`/`dayOfMonth` 是表已有列，故无需再跑 build_runner）。⚠️ 反之，**给 `reminders` 表新加列（如 `delivery`）必须 `dart run build_runner build -d`** —— 没重生成的 g.dart 会同时炸三处：`addColumn` 报「`Column<String>` 不能赋给 `GeneratedColumn`」（因为列 getter 回落成 Table 类的声明）、`row.xxx` 报 getter 未定义、`RemindersCompanion` 报「No named parameter」。这三处报错**不是代码写错，是 g.dart 过期**，先跑 build_runner 再排查。
5. 需要双端同步：默认 TEXT 主键（INTEGER 主键表参考「主题对话」的 pk 按表适配先例），同时加移动端 `kSyncableTables` 与桌面端 `syncModule.ts` 白名单（PC UI `useSync.ts` 的 `SYNC_TABLES` 别漏）。
6. `flutter analyze` + `flutter test` 过基线，更新本 SKILL.md 的功能域清单。

## 使用方式
1. 接到任务先判断属于「数据 / 加密 / 同步 / UI / 构建」哪一类，读对应章节。
2. 涉及桌面端契约（表结构、加密信封、同步对端协议）时，读桌面技能 `C:\cod\jianli\jianli-app\.workbuddy\skills\jianli-app\` 下对应文档（`references/flutter-port.md`、`references/modules/sync.md`、`references/modules/file-transfer.md` 等）。
3. 新增能力优先复用既有模式：Riverpod provider 拆分、幂等 upsert、NotificationChannels、sync 白名单，不要另起炉灶。
4. 所有文档用中文；发现与代码不符，直接更新对应文档，保持 skill 与代码同步。

## UI 现代化与动效（Phase 0/1 已落地）
完整规划见 `references/ui-modernization-plan.md`（6 阶段：Phase 0 地基 → Phase 5 收口）。

**Phase 0 地基（已完成）**
- `app_theme.dart` 新增 **`AppTokens`**（设计 token 唯一入口）：圆角档位 sm/md/lg/xl、柔和阴影 `elevation(ctx, level:0..3)`、主色渐变 `primaryGradient`、语义软底 `soft`、动效节律 `fast/base/slow` + `standard/emphasize`。组件取色/取圆角一律走它，**严禁页面写死**。
- `lib/app/anim/`：
  - `jianli_motion.dart` — `JianliMotion.enabled(context)`（读系统「减弱动态效果」）+ `duration(ctx, normal)` 自动降级。
  - `jianli_haptics.dart` — `haptic(type, [context])`，用内置 HapticFeedback（**无新依赖**）。
  - `jianli_transitions.dart` — 自建 **`slidePage`**（唯一 push 转场，纯 6% 横向滑入，**刻意不引 `animations` 包**：其 Material 耦合重，易与 material_ui 平行 Material 类冲突）。
- `app_router.dart`：全屏 push 路由（20 条）统一 `pageBuilder` 包 `slidePage`；**底部四分支保持 `builder`**（导航壳用 indexedStack 管状态）。
- ⚠️ **禁止给全屏页转场加淡入淡出**（重影根因）：原 `fadeSlidePage` / `fadePage` 已于 2026-09-08 删除——只给新页淡入、旧页不处理会导致两页叠加重影；若要淡入必须同时给旧页 `secondaryAnimation` 反向淡出。**2026-09-09 更新**：用户要求彻底去除所有页面转场动画，`slidePage` 已改为零时长 + `transitionsBuilder` 直接返回 `child`（页面瞬间切换、无任何位移/淡入）；页面内微动效（StaggerList/AnimatedCheck 等）保留。设置面板 `PageRouteBuilder` 左侧滑入属覆盖层动画、非页面转场，按用户要求保留。
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

- **页面底色与白边（2026-09-05，三修：全局渐变背板）**：背景绘制权收归 app.dart 根容器——`builder` 里 `AnimatedContainer(gradient: 顶部强冷调→background)` + `CustomPaint(_BackdropPainter: 右上大圆/左中圆/右下圆环，primary 极低透明度)`；`FScaffoldStyle.backgroundColor` 透明、`FHeaderStyle.decoration`（forui 默认即透明）不画底色，`AppTokens.pageTint(context)` 返回**透明色**（保留兼容旧调用）。**任何页面/组件禁止再自绘不透明整页底色**，透出背板即可——头部/外框/边缘/内容同源，无色差无白边。抽屉 `SheetSurface` 保持不透明（弹层需与背板分离）。
- **间距随字号联动（仅垂直缝隙）**：页面**左右边距固定 `AppTokens.pagePadding = 12`，不随字号缩放**，全 App 统一引用该静态常量；`FScaffold` 全屏页设 `childPad: false`，水平边距交给 ListView 的 `AppTokens.pagePadding` 提供（避免与默认 `childPadding` 叠加成 24）。垂直缝隙 `listTopGap`/`pageBottomGap` 仍走 `*Of(context)` 随字号缩放。

**全局排版/布局配置 + 阅览模式（2026-09-05，二次修订为基准字号体系）**
- **统一调参入口在 `AppTokens`**（app_theme.dart 顶部「全局排版与布局配置」区，改一处全 App 生效）：
  - **基准字号体系**：`baseFontSizeNormal = 12` / `baseFontSizeLarge = 18`（普通文本 md 的目标像素）。阅览模式切换基准档，其他字型等比缩放；接线链路 = `app.dart` watch `readingModeProvider` → 算出 baseFontSize → 传给 `materialLight/materialDark`（MaterialApp.theme）与 `AppTheme.build`（builder 内 FTheme）→ 全树重渲必然生效。
  - **边距 token（横向边距固定 12，不随字号缩放）**：`pagePadding = 12`（**静态常量 `AppTokens.pagePadding`，直接引用；`pagePaddingOf` 已删除，严禁再调用**）；左右边距全 App 统一引用 `AppTokens.pagePadding`——`FScaffold` 全屏页设 `childPad: false`，水平边距由 ListView 的 `AppTokens.pagePadding` 提供，避免与默认 `childPadding` 叠加成 24。垂直缝隙 `listTopGap = 4` / `pageBottomGap = 24` 仍走随字号缩放的 `AppTokens.listTopGapOf(context)` / `AppTokens.pageBottomGapOf(context)`。**新增页面横向边距严禁硬编码数字，一律用 `AppTokens.pagePadding`**。含 viewInsets 的抽屉 padding 例外（键盘避让值不缩放）。根页（dashboard/editor）底部 32 为滚动尾部特例。
- **阅览模式**（需求演进：v1 页内 1.15 缩放视觉无感＝「切换无效」→ v2 基准字号体系全局驱动）：
  - `ReadingMode{normal,large}` + `readingModeProvider`（key `jianli.readingMode`，默认 normal），见「主题体系」；**不要在页面内做阅览模式缩放**——主题已全局缩放，页面只需直接用 `context.theme.typography`。
  - 生效面 = 全 App（forui 组件内部样式 + 页面排版）；笔记详情 `NoteHtmlView` / 阅读器正文额外给了 `height: 1.7/1.8` 阅读行高，fontSize 直接取 `md.fontSize`（已被主题缩放）。
  - 设置面板 UI：`_ReadingModeRow` 两张 `_ModeCard`（图标 + 名称 + 「基准 Npx」副标题，选中主色软底 + 主色描边 + `AnimatedContainer` 过渡）。

**Phase 3→4 · 全页彩焕「PageBanner 渐变横幅」（已完成，2026-09-05）**
用户要求所有功能页达到首页同款「颜色丰富」观感（渐变英雄卡视觉下沉到每个功能页）。新增与接线：

- **新组件 `lib/app/ui/page_banner.dart`（`PageBanner`）**：页面专属强调色渐变横幅 —— `accentGradient(accent)` 渐变底 + 白色装饰圆（右上/右下两枚）+ 半透明白 `SquircleBox` 图标盘 + 白字标题/副标题 + 可选统计行（`List<(String, String)>` 传 `(数值, 标签)`，纯数值自动 `AnimatedStat` 数字滚动）+ level-3 阴影；`accentIndex` 与 Hub 分组页入口色一一对齐，**每个功能域一色不撞色**。默认 margin `(16, 12, 16, 4)`，直接塞进各页 ListView/Column 即可。
- **逐页接线**（横幅色 = Hub 入口色）：habit=2 绿（启用/今日完成双统计）、todo=1 蓝（统计基于全量计算，不随过滤切换跳变）、pomodoro=6 红（横幅显示当前阶段/剩余 + 白卡承托进度环，环改红色）、pomodoro_records=6（原 primaryGradient 统计横幅换成 PageBanner 三统计）、countdown=0 紫（**大计时器整卡渐变化**：白色 RingProgress + `trackColor` 半透明白 + 白字大时间 + 装饰圆，取消外层 AppCard）、reminder=3 琥珀（全部/启用中双统计）、notes=3 琥珀（列表横幅 + 详情页分类改琥珀软底 chip）、conversation=4 粉（列表横幅 + 消息气泡由 `colors.card` 改 `accentSoft(accent(4))` 粉软底）、bookshelf=5 青（GridView 改 **CustomScrollView + SliverGrid**，横幅随页面滚动）、2FA=0 紫（解锁表单套 pageTint + 渐变盘替代裸图标；码列表顶部横幅）、password_vault=1 蓝、file_vault=2 绿（两者门禁表单同 2FA 式样 + 列表横幅）、qr=3 琥珀（横幅置于 FTabs **之上**，FTabs 包进 `Expanded` —— `expands:true` 雷区照旧生效）、sync=5 青（发现设备/可同步表双统计）。
- **组件增强**：`RingProgress` 新增可选 `trackColor`（放彩色渐变底上传半透明白，缺省仍 muted）；`EmptyState` 空态图标从裸 `border` 色图标升级为**主色软底 `SquircleBox` 盘**（76×76 圆角 26，全 App 空态一并变彩）。
- **顺手清理**：删除 habit 页死代码 `_WeekStrip`；清掉 4 条存量 lint（unused_element ×1、curly_braces_in_flow_control_structures ×2、settings_panel 的 `use_build_context_synchronously`——`originContext` 补 `mounted` 守卫）。

## 维护说明
- 本 skill 是移动端「项目知识基线」，随代码演进而更新；每完成一个功能域或踩出新雷区，同步「功能域清单」与「全局红线」。
- 2026-09-06：**移动端 release 打包报错修复（flutter_inappwebview_android proguard）**——`assembleRelease` 卡在 `evaluating project ':flutter_inappwebview_android'`，报 `getDefaultProguardFile('proguard-android.txt')` 不再支持（AGP 9.x 已删除该文件；根因：`flutter_inappwebview: ^6.1.5` 依赖的 `flutter_inappwebview_android: ^1.1.3` 是官方最新版，未修）。**永久修复**：把插件复制到 `jianli-mobile-app/third_party/flutter_inappwebview_android/`（其 `android/build.gradle` 已改用 `proguard-android-optimize.txt`），app `pubspec.yaml` 加 `dependency_overrides: flutter_inappwebview_android -> path: third_party/flutter_inappwebview_android`。**切勿** `flutter pub cache repair` 后又动它、或删除 `third_party/` 目录（会复现报错）；升 `flutter_inappwebview` 前先在本地副本验证新版本是否修了 AGP 9 proguard 问题。详见「排障」对应条目。
- 2026-09-06：**双端「文件互传」已实施完成**（批量收发、双端对称）。移动端 `lib/features/file_transfer/` 新功能域落地：M1 发送客户端（`TransferClient.sendBatch` 流式 + 字节回调 + 取消）、M2 接收服务端（三端点注册进 `SyncService` 可插拔路由 `registerRouteHandler`，接收目录 `Download/渐离App文件互传/`（Android 需存储权限「所有文件访问」，入页申请；未授权/创建失败回退沙盒 `Documents/渐离App文件互传/`，iOS 恒走沙盒回退））、M3 models/repositories/providers（顶层 `transferHistoryProvider`）、M4 页面（`FileTransferPage`，PageBanner 粉(4) + 设备扫描/手动 IP `10.0.2.2` + FDeterminateProgress 逐文件进度 + 收发记录）；M5 SyncService 加 `registerRouteHandler`、M6 drift 首个 onUpgrade 迁移（`schemaVersion 1→2` + `file_transfer` 表 .named() 列）、M7 路由 `/file-transfer` + 工具组入口（FLucideIcons.arrowLeftRight，accent 4）、M8 AndroidManifest 补 INTERNET/cleartext。桌面端同协议同历史表。决策记录：`references/file-transfer-plan.md`。改码后 `flutter pub get → dart run build_runner build -d → flutter analyze(0) → flutter test(5/5) → flutter run` 交用户在本地执行。
- 2026-09-06（文件互传后续分批，M11）：补齐 sha256 双端校验（发送端 `crypto.sha256.bind` 算 hash 随 `/file/end` 带出，接收端 `_receiveHashing` 边收边算比对，不符删坏文件记 `failed`/`hash mismatch`）、历史 `error` 列（`tables/file_transfer.dart` 加 `error` → 须重跑 `build_runner`）、发送端 `peer_name` 经 offer 响应 `me` 回填、offer 响应 `me` 回传本机设备信息、接收端收完回收 `_offers`、`file_transfer_page.dart` 历史成功记录加「打开」(`OpenFilex.open`) /「分享」(`SharePlus.instance.share`) 并显示 `error`。**新增依赖 `open_filex`(^5.8.0) + `share_plus`(^11.0.0)**（pubspec.yaml），改 `pubspec.yaml` 后须 `flutter pub get`。
- 2026-09-06：**应用品牌化（图标/名称/启动屏）落地 + 「构建与验证」生产打包拆解**。① 名称：AndroidManifest `android:label` 与 iOS `CFBundleDisplayName/CFBundleName` → **渐离App**。② 图标/启动屏：用户提供 1024 白底源图（根目录 `appLogo.png`），`tool/make_icons.py`（Pillow；本机 py 3.8.5 + Pillow 10.4）全量生成——Android 五密度 ic_launcher、自适应前景（源图 logo 占 85%，**必须缩进 62% 安全区**否则圆遮罩裁边）、drawable-nodpi 启动屏、iOS AppIcon 15 尺寸（去 alpha）、LaunchImage 三倍图；配套新增 `mipmap-anydpi-v26/ic_launcher.xml`、`values/colors.xml`、`values-v31` 与 `values-night-v31` 的 `styles.xml`（A12+ 系统启动屏白底；**night 限定优先级高于 v31**，两处都要写）。③ **flutter_launcher_icons / flutter_native_splash 依赖 image ^4，与 epubx（锁 image ^3）版本死冲突 → 手工 Pillow 生成为定案**，勿再引入。④ 构建与验证章节全面重构：环境前置/日常循环/生产打包（版本号、keytool 签名三步、命令矩阵、安装验证）——**release 目前仍 debug 签名，正式发布前需配 keystore（步骤在「生产打包②」）**。
- 2026-09-06：**文件互传两处关键修复**——① 移动端发送 hash 计算错误：`crypto.sha256.bind()` 返回 `Stream<Digest>` 非 Future，直接 `await` 拿到流对象、`toString()` 后当 hash 发出 → 手机→PC **恒报 hash mismatch**；修复为 `.first` 消费流（`transfer_client.dart`），Node 复刻实验双端 hash 对齐验证。② Dart SDK 3.13 已从 `dart:convert` 移除 `ChunkedConversionSinkBase` 公开导出：`transfer_server.dart` 的 `_DigestSink` 改为 `implements Sink<crypto.Digest>`。修复后 `flutter build apk --debug` 通过。
- 2026-09-06（文件互传后续二批，M12 · 全部剩余增强已落地）：`models/transfer_models.dart`（TransferSettings 加 `renameStrategy`/`enc` + `load/persist`；`countingStream` 加 `initial`）、`models/transfer_utils.dart`（新建：sanitize/recvPartName/enc base64 编解码）、`models/recent_peers.dart`（新建：#11 最近设备 shared_preferences 持久化）、`services/transfer_server.dart`（#9 重名策略 / #13 续传 resumeFrom+追加写+hash 播种 / #14 加密 decryptStream / #15 询问 askStream+answerAsk+60s 超时 / #17 并发守卫 `_activeReceiveTid` / #20 trim(1000)）、`services/transfer_client.dart`（#13 续传 from= / #14 加密 encryptStream / #17 `_activeSendTid` / #19 WakelockPlus 后台保活）、`repositories/transfer_repository.dart`（加 `list/count/trim`）、`components/file_transfer_page.dart`（最近设备区 / 重名策略+加密+自动接收三开关 / 接收询问弹窗 / 历史分页「加载更多」）、`test/features/file_transfer/transfer_utils_test.dart`（#28 单测）。**新增依赖 `wakelock_plus: ^1.8.0`**（pubspec.yaml）+ `AndroidManifest.xml` 加 `WAKE_LOCK`。协议保持向后兼容（加密/续传/询问均默认关或协商，未开启退化为既有明文）。决策记录：`references/file-transfer-plan.md`（§二之一 / 四 M12 / 六）。
- 2026-09-06（文件互传第三批）：**接收目录改为系统 `Download/渐离App文件互传/`**——公共 Download 在 Android 10+ 受分区存储保护，`receiveDir()` 改为「权限通过 → 公共 Download；未授权/创建失败 → 回退沙盒 `Documents/渐离App文件互传/`（iOS 恒走回退）」。**新增依赖 `permission_handler: ^13.0.2`**（pubspec.yaml 须 `flutter pub get`）+ `AndroidManifest.xml` 加 `MANAGE_EXTERNAL_STORAGE`、`WRITE_EXTERNAL_STORAGE(maxSdkVersion=32)`、`<application android:requestLegacyExternalStorage="true">`（API ≤10 传统写）；入页 `_ensurePublicDownloadsPermission()` 申请（API 30+ 自动跳「所有文件访问」设置页，拒绝仅记日志不阻塞），`hasPublicDownloadsAccess()` 供 `receiveDir()` 判定。续传追加写/改名去重/删除均为真实路径 dart:io 逻辑，零改动；`open_filex` FileProvider 含 `external-path .`，Download 下文件「打开/分享」正常。系统文件管理器现可直接浏览接收文件。
- 2026-09-06（文件互传第五批小改）：**「传输记录」标题下方新增存储位置提示行**——`_receiveHint` 由 `_ensurePublicDownloadsPermission()` 末尾按授权结果刷新（Android 授权→`系统 Download/渐离App文件互传/`；未授权→「未开启存储权限，接收的文件暂存应用沙盒；请点击记录中的『分享』，通过其他应用保存」；iOS→`应用 Documents/渐离App文件互传/`），提示行插在 SectionHeader 与 AppCard 之间（mutedForeground xs）。文案用常量 `kTransferDirName` 拼接，不硬编码目录名。
- 2026-09-06（文件互传第四批）：**双端「传输记录」只显示当次批次**——移动端 `TransferServer` 加 `batchTidStream`（offer 登记时推 tid，broadcast 流，dispose 关闭），页面 `_batchTid` 由发送首条进度事件 / 该流切换，记录区按 `r.tid == _batchTid` 过滤 `watchAll` 流，移除 `_historyLimit`/「加载更多」（#20 的 DB 分页/trim 照旧），PageBanner 统计改「当次文件」；PC 端 `useFileTransfer.loadHistory()` 只保留 created_at 最新记录所属 tid 的行、`onProgress` 新 tid 先清旧展示、`index.vue` 启动不再拉历史（事件驱动 + 「刷新」按钮）。DB 仍全量写入，仅 UI 不展示其他记录。
- 2026-09-05：UI 全量换装 forui（shadcn 风格）+ material_ui，全 App 页面已改造（骨架/组件对照见「UI 体系」章节）。
- 2026-09-05：**UI 现代化 + 操作动效总体规划**已落地为 `references/ui-modernization-plan.md`——诊断现状短板、定义设计 token（形状/阴影/渐变/语义软底/动效时长曲线）、新增原子组件（GlassCard/GradientButton/ShimmerSkeleton/AnimatedStat/AnimatedCheck/StaggerList/JianliSegmented/ConfettiOverlay/PageHero/SquircleBox）、自建页面转场（禁用 `animations` 包以避开 material_ui 冲突）、Haptics + 减弱动效降级，含 6 阶段实施路线（Phase 0 地基 → Phase 5 收口）。改造时严格守住 forui/material_ui 约束与 FTabs `expands` 雷区。
- 2026-09-05：UI 现代化 **Phase 0 地基已完成**——`app_theme.dart` 加 `AppTokens`（形状/阴影/渐变/语义软底/动效节律）；新增 `lib/app/anim/{jianli_motion,jianli_haptics,jianli_transitions}.dart`（减弱动效开关 + 触感 + 自建 `fadeSlidePage`/`fadeSlide` 转场，刻意不引 `animations` 包）；`app_router.dart` 全屏 push 路由接 `fadeSlidePage`；`app.dart` 主题切换加 `AnimatedContainer` 背景过渡。`flutter analyze` 0 问题、`flutter test` 5/5 基线通过。
- 2026-09-05：UI 现代化 **Phase 1 原子组件已完成**（详见「UI 现代化与动效」章节）——`lib/app/ui/` 新增 TapScale/GlassCard/GradientButton/ShimmerSkeleton/AnimatedStat/AnimatedCheck/StaggerList/JianliSegmented/ConfettiOverlay/PageHero/SquircleBox；AppCard/RingProgress/StatBlock/EmptyState 就地升级。lint/类型问题已全修（dispose 漏 super、context 在字段初始化器、record 空安全提升、builder 参数列表、haptic 参数名遮蔽），同章节已固化 7 条动效组件开发雷区。**构建与运行交用户本地执行**（Agent 侧无 GUI 且后台构建过慢），命令见「构建与验证」的「跑起来看效果」小节。
- 剩余规划（截至 2026-09-05）：真机全量验证、桌面 25 套主题映射到 forui、flutter_quill 富文本编辑、PDF / CFI 精确进度、interval 通知精细化、QR 样式、同步会话加密、conversation LLM 后端、**UI 现代化 Phase 2（壳与导航动效）→ Phase 3（逐屏动效接线）→ Phase 4（点睛与无障碍）→ Phase 5（收口）**。
- 2026-09-05：**启动崩溃修复**——`StaggerList`/`AnimatedCheck`/`RingProgress`/`ConfettiOverlay` 四个动效组件在 `initState` 内读 `JianliMotion.enabled/duration`（内部 `MediaQuery.of`），触发 `dependOnInheritedWidgetOfExactType ... called from initState` 启动崩溃。已全部改为 `didChangeDependencies` + 一次性守卫（`_started`/`_initialized`）。雷区 #8 已固化。修复后由用户本地 `flutter run -d emulator-5554` 验证（Agent 侧不跑 analyze，>30s 即交用户）。
- **2026-09-05：主题系统 + 设置面板 + 剩余页面 UI 全量焕新（Phase 3→4）**。① 主题：`app_theme.dart` 参数化为 5 套 `ThemeStyle`（紫/蓝/绿/橙/粉）+ 新增 `theme_providers.dart`（`themeStyleProvider`/`themeModeProvider`，SharedPreferences 持久化），`app.dart` 改 `ConsumerWidget` 读 provider，切样式/模式即时全树重渲。② 入口：首页与三个分组页右上角装饰块换成 **`SettingsButton`**，点开 **左侧滑出设置面板**（自定义 `PageRouteBuilder`，刻意不用 forui 弹层以避免与 material_ui 平行 Material 类冲突），内含 5 色环样式选择 + 三态模式 `JianliSegmented`。③ 页面焕新（沿用 Phase 3 视觉语言 `pageTint` + 专属色 `SquircleBox` + `StaggerList` + `AppCard`）：效率类（habit/todo/reminder/pomodoro/countdown/pomodoro_records）、内容类（note 列表·详情·编辑、conversation 列表·消息流、bookshelf·reader）、工具类（2FA/密码库/文件保险箱/二维码/同步）。子页强调色与 Hub 入口色对齐（notes=3、conversation=4、ebook=按标题 hash、2FA=0、密码库=1、保险箱=2、QR=3、sync=5）。④ 新雷区已固化到「Riverpod 3 / forui API 雷区」小节（**`valueOrNull` 已移除改 `.value`；`FHeader` 用 `suffixes` 不是 `actions`；`material_ui` 的 `ThemeMode`；`JianliSegmented` items 传 IconData**）。
- 2026-09-05：**全页彩焕「PageBanner 渐变横幅」落地（Phase 3→4 二次焕新）**——新原子组件 `lib/app/ui/page_banner.dart`（页面专属强调色渐变横幅：accentGradient + 白色装饰圆 + 半透明图标盘 + 白字统计行，纯数值自动 `AnimatedStat`；`accentIndex` 与 Hub 入口色对齐），13 个功能页全部接线：habit 绿(2) / todo 蓝(1) / pomodoro+records 红(6) / countdown 紫(0，大计时器整卡渐变 + 白色进度环) / reminder 琥珀(3) / notes 琥珀(3，详情分类改软底 chip) / conversation 粉(4，消息气泡改 accentSoft 软底) / bookshelf 青(5，GridView 改 CustomScrollView+SliverGrid) / 2FA 紫(0，解锁表单渐变盘) / 密码库 蓝(1) / 保险箱 绿(2) / QR 琥珀(3，横幅置于 FTabs 上方) / 同步 青(5)。组件增强：`RingProgress` 加可选 `trackColor`；`EmptyState` 图标升级主色软底盘。顺手清 4 条存量 lint + 删 `_WeekStrip` 死代码。静态检查 `dart analyze` **0 问题**（经 dart.exe 直连跑通）；`flutter test` 未代跑。**分工铁律更新：Agent 只写码改档，一切 flutter/dart 命令交用户执行**（「跑起来看效果」小节已改写，「30 秒规则」作废）。
- 2026-09-05：**笔记标签功能对齐 PC（需求变更）**——用户反馈「同步 PC 数据后看不到笔记标签」，定位结论：标签定义在 `basic_info.note_tags` 行、笔记 tags 为 key 数组，两表均在同步白名单，**数据早已同步、移动端此前未消费**。移动端补齐：`NoteTag` 模型 + 仓储标签读写（watch/创建同名去重/软删 + `createNote/updateNote` 写回 tags）+ `noteTagsProvider`；列表页加搜索框、彩色标签筛选条、**内容+标签双搜索**；笔记卡与详情页彩色标签徽标；**编辑页重设计**（分类/标签 chips 化 + 「分类与标签」卡 + 渐变保存按钮）。契约与实现细节见「笔记标签双端契约」小节；无表变更零迁移；`dart format` 语法自查通过，analyze/test/run 一律交用户（分工铁律）。
- 2026-09-05：**「小功能抽屉化」全局约定落地（需求变更）**——用户反馈新建标签的居中弹窗太丑，定为全局规则：**所有小功能的新增/编辑/展示弹层一律底部抽屉 `showFSheet(side: FLayout.btt)`，`showFDialog` 仅保留破坏性确认**（模板与先例见「UI 体系」抽屉化约定条目）。本轮改造 4 处：笔记编辑页新建分类/标签（抽 `_inputSheet` 共用 helper）、待办新增、密码库新增/编辑条目（高表单 `mainAxisMaxRatio: null` + 滚动）、保险箱文件预览。全 App 现仅剩笔记删除确认一处 `showFDialog`（合规）。`dart format` 自查通过，analyze/run 交用户。
- 2026-09-05：**热点场景设备发现修复**——手机开热点给 PC 时手机搜不到 PC（反向正常）。根因：`scan()` 只发 255.255.255.255 受限广播，而热点接口非手机默认路由，广播出不去热点网段。`sync_discovery.dart` 新增 `broadcastCandidates()`（逐 IPv4 网卡 x.y.z.255 定向广播 + 全网广播兜底），取代原「逐网卡发送 TODO(P3)」；雷区已固化到「局域网同步」章节。
- 2026-09-05：**阅览模式二次修订（基准字号体系）**——用户反馈 v1「切换无效 + 普通字体太大」（根因：页内 1.15 倍缩放视觉无感且只挂两个阅读页）。v2 改为**基准字号体系**：`AppTokens.baseFontSizeNormal=12 / baseFontSizeLarge=18`，`app.dart` 读阅览模式 → 传 `baseFontSize` 进 `AppTheme.build`（构造期 `typography.scale(sizeScalar: 基准/forui默认md)`）+ `materialLight/materialDark`，全 App（含组件内部样式）随档位等比缩放；笔记详情/阅读器移除页内缩放、正文字号直取 `md.fontSize`；设置面板卡片副标题显示「基准 Npx」。同步修正技能「主题体系/全局配置」小节。analyze/run 交用户。
- 2026-09-05：**三处视觉修正（真机反馈，二次）**——修复编译错误 2 个（`isDark` 未定义；`scaffoldStyle` 参数收 FScaffoldStyle 实例而非回调，delta 用官方 `EdgeInsetsGeometryDelta.scale(k)` 类工厂——雷区 #7）；随后按截图升级为**全局渐变背板架构**：app.dart 根容器画「顶部强冷调→background」渐变 + `_BackdropPainter` 图案（大圆×2/圆环×1），scaffold 透明、header 默认透明、`pageTint` 返回透明色，三处色差/白边一次性消灭；新增规则「页面禁止自绘不透明整页底色」。虚拟机启动完整命令序列已固化到「构建与验证」。`dart format` 全库通过，analyze/run 交用户。
- 2026-09-05：**页面操作规范落地（需求变更，先例=可归类笔记）**——① 新章节「页面操作规范（共有交互）」：查询/筛选统一走**通用查询抽屉**（新组件 `lib/app/ui/filter_sheet.dart`：顶部「查询」+关闭图标、中部选项滚动、底部固定「重置/查询」；草稿模式——打开时从已生效条件初始化，重置只清草稿，查询才应用并经 pop 值返回）；保存/提交按钮**统一固定底部**（`Column[Expanded(内容), SafeArea+GradientButton]`，头部不放重复保存入口）。② 可归类笔记先例改造：列表页分类/标签行内 chips 移入查询抽屉，搜索框右侧加筛选按钮（激活时琥珀软底+条件数角标），已生效条件以可点掉摘要 chip 呈现；编辑页保存条固定底部、头部对勾入口移除。后续新功能按该章节模式实现。
- 2026-09-05：**电子书空白转圈修复 + PC 对齐（需求变更）**——① 根因：书架页 build 内联 `StreamProvider`（Riverpod 每次重建都是新 provider → 永远 loading），新建 `providers/ebook_providers.dart` 顶层 `bookshelfStreamProvider` 修复，雷区 #9 固化「provider 严禁 build 内联」；② TXT 编码对齐 PC：`epub_service` 增 BOM 识别（UTF-8/UTF-16LE/BE）+ UTF-8 严格解码失败回退 GBK（新依赖 `fast_gbk` 纯 Dart，**需先 flutter pub get**），修复中文 GBK TXT 乱码；③ 组件化：`BookCell` 拆为 `components/book_cell.dart`；移出书架改 showFDialog 确认（破坏性规范）；④ 裁剪项（PC 有）：标注划线/书签/分类/PDF/章节搜索/扫描文件夹。`dart format` 通过，pub get + analyze + run 交用户。
- 2026-09-05：**主题对话对齐 PC（需求变更）**——① 根因：桌面端主题对话三表（conversation_theme/conversation/conversation_tag）为 INTEGER 自增 id 主键，不满足旧 TEXT 主键同步规则而未入白名单 → 移动端无数据；② 双端白名单加三表并做 pk 按表适配（桌面端 `tablePk()` + `ON CONFLICT(id)`；PC `useSync.ts` 表清单同步；改桌面端需重启 Electron）；③ 移动端功能对齐：主题消息数角标/主题标签彩色徽标/编辑主题（抽屉+固定保存条）/删除主题（子主题禁止+级联）/消息置顶排序/is_rich 富文本 HtmlWidget 渲染/长按软删消息/发送后刷新主题 update_time；裁剪项（引用/标注/多选/搜索/导出 md/标签管理）记入「主题对话」专节待办。全局红线 7 与落地清单第 5 条的「TEXT 主键」规则已改为「按表 pk 适配」。桌面端改动见 jianli-app 技能 sync.md。
- **2026-09-08：页面转场重影修复**——用户反馈「页面切换有两个页面的重影」。根因：`fadeSlidePage` 只给新页淡入、旧页不处理 → 转场期间两页叠加。处理：`jianli_transitions.dart` 删除 `fadeSlidePage` 与未接线的 `fadePage`，只留 **`slidePage`（纯 6% 横向滑入）**；`app_router.dart` 全部 20 条全屏路由改用 `slidePage`（含 `/ferry`）。`StaggerList` 的列表逐条淡入按用户要求保留。雷区 #9 已固化。
- **2026-09-08：三项体验/安全优化**。① **首页状态栏重叠**：`dashboard_page.dart` 无 `FHeader`（其它页用 forui FHeader 自带顶部安全区），`ListView` 从 y=0 起致状态栏透出滚动内容 → 用 `SafeArea(top:true, bottom:false)` 包 `RefreshIndicator`/`ListView`。**约定：无 FHeader 的自定义页必须用 SafeArea 包滚动区，否则滚动内容钻状态栏**。② **设置面板未铺满**：`settings_panel.dart` 外层 `SafeArea` 缩进导致顶部（状态栏）/底部（tab/Home 条）留空突兀 → 去掉外层 `SafeArea`，面板 `Container` 铺满全高，仅 `FHeader` 单独加 `MediaQuery.padding.top`、列表底部补 `padding.bottom`。③ **隐私页不锁（2FA/密码库/文件保险箱）**：原解锁态在 Riverpod 单例 / 服务单例 / 局部 State，路由切走与应用切后台都不清 → 新增三个 `Notifier<bool>`（`twoFactorUnlockedProvider`/`passwordVaultUnlockedProvider`/`fileVaultUnlockedProvider`，页面 `watch`；各自暴露 `unlock()`/`lock()` 方法置态，呼应 Riverpod 3 原生而非 legacy 的 `StateProvider`）+ `lib/app/security/vault_auto_lock.dart` 的 `lockAllVaults(WidgetRef)`（清内存明文 + 置反开关）；`JianliApp` 改 `ConsumerStatefulWidget` + `WidgetsBindingObserver`，`AppLifecycleState.paused/hidden/detached` 时锁全部；三页 `dispose` 各自锁自己。`dart analyze` 0 问题。
- **隐私保险箱自动锁约定（2026-09-08 实踩，勿回退）**：2FA/密码库/文件保险箱的「解锁态」必须能响应「应用隐藏」与「路由切走」。两件套：① 每个域一个 `Notifier<bool>` 的 `unlocked` 开关（`build()=>false`，暴露 `unlock()`/`lock()` 方法置态），页面 `watch` 它（不能用单例字段 `_unlocked`/`_dataKey`/`isUnlocked` 当 UI 真相，因为它们不可响应 `lockAllVaults`；也不可用 Riverpod 3 已移入 legacy.dart 的 `StateProvider`，且其 `notifier.state` 受保护不可外部赋值）；② 解锁成功调 `unlock()`、锁按钮/`dispose`/`lockAllVaults` 调 `lock()`。新增第四个隐私域时照抄此模式 + 在 `lockAllVaults` 补一行。
- **2026-09-09：彻底去除页面转场动画 + 设置面板优化**。① **转场动画全移除**：用户要求「彻底去除所有页面的转场动画」，`lib/app/anim/jianli_transitions.dart` 的 `slidePage` 改为 `transitionDuration`/`reverseTransitionDuration = Duration.zero` 且 `transitionsBuilder` 直接返回 `child`（页面瞬间切换、无滑入）；`app_router.dart` 全部 20 条 `pageBuilder: slidePage(...)` 调用方零改动，同时删除不再使用的 `AppTokens` 导入。**页面内微动效（StaggerList / AnimatedCheck / AnimatedStat 等）保留**——它们不是路由转场。设置面板 `PageRouteBuilder` 左侧滑入属覆盖层动画、非页面转场，按用户要求保留。② **设置面板顶部空隙修复**：根因 `FHeader.nested` 自身已含 `SafeArea(top)`（状态栏安全区），而面板又在外层套 `Padding(top: topPad)` → 状态栏高度叠加两次 + FHeader 内部 8px 顶部内边距 = 空隙过大；修法：去掉外层 `Padding(top: topPad)`（并删 `topPad` 变量），给 `FHeader.nested` 加 `style: FHeaderStyleDelta.delta(padding: EdgeInsetsGeometryDelta.value(EdgeInsets.only(left:12,right:12,bottom:10)))` 把顶部 8px 归零 → 标题正好落在状态栏高度处。③ **去多余容器嵌套**：设置面板「数据同步」「关于」两区块原为 `AppCard(FTile(...))` 多包一层，改为代码库通用写法 `FTileGroup(divider: FItemDivider.none, children:[FTile(...)])`（与 conversation/ebook 页一致），并移除不再使用的 `import 'ui_atoms.dart';`。`flutter analyze` 0 问题基线由用户本地验证。
- **2026-09-09：四个 Tab 内容体 / 首页标题边距统一为 12px（修复 FScaffold 双重内边距）**。用户实测：三个 Hub 标题边距正确、内容体比标题大；首页所有边距与 Hub 内容体一致。根因：forui `FScaffold` 默认 `childPad:true`，会给 `child` 再套一层 `childPadding = pagePadding`（水平 12），而 Hub 的 `_HubList` ListView 与 `dashboard_page` 的 ListView 又各自写了水平 `AppTokens.pagePadding`（12）→ 内容体被叠加成 24；标题走 `FHeader` 的 `header:` 参数不吃 childPadding，只有 12。另厘清：`FHeader` 标题水平 padding 来自 `FHeaderStyle.padding`（`FHeaderStyles.inherit` 用 `style.pagePadding.copyWith(bottom:10)` 算，非 `FStyle.pagePadding`），上一轮 Task D 的 `headerStyles` 已把它锁到 `AppTokens.pagePadding`。修复：3 个 Hub 页与 dashboard 的 `FScaffold` 加 `childPad: false`，让 ListView 的 `AppTokens.pagePadding` 成唯一水平边距（仍由全局变量驱动）。附带修正技能文档第 74/594/599 行过时/矛盾表述。analyze/run 交用户。
- 剩余规划（截至 2026-09-05）：真机全量验证、桌面 25 套主题映射到 forui、flutter_quill 富文本编辑、PDF / CFI 精确进度、interval 通知精细化、QR 样式、同步会话加密、conversation LLM 后端、UI 现代化落地（按 `references/ui-modernization-plan.md` 分阶段）。
- 2026-09-07：**待办功能全量对齐 PC（需求变更）**——移动端 `features/todo/` 整体重写，对齐 `jianli-app/src/views/todoList`：① 模型 `todo.dart` 补齐 PC 全字段 + 状态/优先级/子任务/重复/分组 helper（状态色严格对齐 PC statusConfig）；② 新增 `todo_filter.dart`（TodoFilterState + applyTodoFilters/dueGroupOf/groupTodos）；③ 仓储 `todo_repository.dart` 重写：`upsertTodo`(InsertMode.replace 全字段)、`addTag` 同名去重、级联 `deleteTodo`、`_ensureNextRecurrenceInstance`/`_nextOccurrence`(daily/weekly 上限 366 次)、`scheduleDeadlineReminder`/`cancelDeadlineReminder`；④ 新增 `todo_sheets.dart`（**全部底部抽屉**：编辑/筛选/标签/父任务/自绘日期时间/记录进展/动作/确认）；⑤ 三视图 `todo_tile.dart`(列表)/`todo_card_view.dart`(卡片网格)/`todo_calendar_view.dart`(月历按 dueDate 聚合)；⑥ 主页 `todo_page.dart` 重写（三视图切换+搜索+筛选抽屉+已生效 chip+全量统计+分组+批量删除选择模式+新增编辑入口）。**跨模块新增**：`notification_service.scheduleOnce`(单次定点 NotificationCalendar.fromDate repeats:false，供截止提醒)、`conversation_repository.findOrCreateThemeByTitle`(供记录进展写主题对话)。**关键：drift `todo_tables.dart` 已含全量列，表定义零改动、无需 build_runner、无 onUpgrade**。约定：弹窗一律底部抽屉、日期选择器自绘（forui FDateField API 不透明）、状态色/文案常量集中不硬编码。`flutter analyze lib/features/todo` 0 问题，test/run 交用户。详情见「待办」专节。
- **2026-09-09：提醒全部不弹系统通知（根因：`NotificationService.init()` 从未被调用）**。现象：所有提醒（周期/定点、通知与闹钟两种送达）均不出现在系统通知栏（用户明确要「系统消息」而非应用内消息）。根因：`notification_service.dart` 的 `init()`（注册 habit/todo/pomodoro/alarm 四渠道 + 注册 `actionSnooze` 动作监听）**从未在任何地方被调用**——`main()` 与 reminder 页只调 `requestPermission()`、不调 `init()`，导致 `AwesomeNotifications().initialize(...)` 不执行、四渠道未注册，`createNotification` 因 `channelKey` 不存在而**静默丢弃**每条排程。修复：`main()` 在 `runApp` 前 `await NotificationService.init()`（initialize 不依赖 BuildContext，可在 main 直接 await）；并对 habit/todo/pomodoro 三普通渠道补 `channelShowBadge:true`+`playSound:true`（alarm 渠道本就有），保证系统通知可见且有声。`requestPermission()` 仍由 reminder 页 `initState` 调用（Android 13+ 运行时授权），`rescheduleAll()` 进页重排程逻辑不变。⚠️ **任何新增 `NotificationChannel` 必须走 `init()` 注册，否则对应提醒静默失效**——这是本次实踩的最高优先雷区。analyze/run 交用户 `flutter run -d emulator-5554` 验证。
- **2026-09-09：新增提醒弹窗顶部灰白带（根因：`FHeaderAction` 用在 `FHeader` 之外）**。现象：新增/编辑提醒底部抽屉顶部、「提醒标题」字段上方有一块灰白空区，无任何内容。根因：`_ReminderEditor` 的关闭按钮用了 `FHeaderAction`（close ×），但 `FHeaderAction.build` 依赖 `FHeaderData.of(context)`，`FHeaderAction` 被放在普通 `Row` 里、没有 `FHeader` 祖先 → 回落到 `FScaffold` 默认 `FHeaderData` 的 `actionStyle`，其 `tappableStyle` 带灰底，渲染出灰白块。修复：改用本仓库既定关闭按钮写法（`GestureDetector`+`Padding`+`Icon(FLucideIcons.x, color: t.colors.foreground)`，与 `todo_sheets.dart` 一致），透明无灰底；`FHeader` 内的 `FHeaderAction`（页头返回/新建）不受影响。⚠️ **`FHeaderAction` 必须包在 `FHeader` 里；抽屉/弹层内的关闭按钮一律用 `GestureDetector`+`Icon` 写法**（UI 红线，勿在 `Row` 里裸用 `FHeaderAction`）。analyze/run 交用户验证。
- **2026-09-09：首页「活跃提醒」取值口径修正**。首页统计栏 `dashboard_providers.dart` 的 `remindersEnabled` 原查询为 `reminders` 表全表 `enabled='1'` 计数，会错误计入 `id='pomodoro'` 的 stateful 行（番茄钟状态机由 App 前台驱动、不发系统通知、单行不代表「一条提醒」）。按用户拍板口径修正为：**所有 `enabled='1'` 的提醒都计入（含用户自建 `source` 空 / 习惯 `source='habit'` / 待办 `source='todo`），但排除 `mode='stateful'`**；`mode` 为 NULL 的行用 `mode.isNull() | mode.isNotValue('stateful')` 一并保留，避免漏算异常数据。⚠️ 红线：**「活跃提醒」统计必须排除 stateful（番茄钟），且必须含习惯/待办引擎行**；不要写回「只数 source 为空」或「全表无脑 count」的旧口径。analyze/run 交用户 `flutter run -d emulator-5554` 验证。
