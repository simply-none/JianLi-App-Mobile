# 模块：架构、技术栈与 UI 体系

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


