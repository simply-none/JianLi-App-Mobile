# 电子书阅读增强（划线 / 翻页 / 笔记入口）移动端方案 v2 · 含生态插件调研

> 制定日期：2026-09-10
> 范围：`C:\cod\jianli\jianli-mobile-app\lib\features\ebook`
> 需求来源（用户三条）：① EPUB/TXT 支持划线（高亮 / 横线 / 下划线）；② 翻页模式支持点击左右屏幕翻页（现只有滚动）；③ 书架长按封面，在「移除」右边加「查看笔记」，点击底部弹窗查看内容。
> 用户补充约束：**电子书对齐 PC 端数据库即可，阅读相关实现用移动端自己的方式**。

---

## 零、结论先行

**Flutter 生态确实有现成轮子，而且最优解一次性覆盖了本次三项需求里的两项核心。**

推荐 **方案 A：接入 `flutter_epub_viewer` ^2.0.0（epub.js 渲染内核 + WebView 桥）**，TXT 通过「合成最小 EPUB」并入同一条管线。

决定性理由（不是"轮子多一点"，是同源）：

| 依据 | 事实 |
|---|---|
| 桌面端 PC 用什么 | `jianli-app/package.json:93` → `"epubjs": "^0.3.93"`，PC 阅读器就是 **epub.js** |
| 该插件内核 | 内置 `lib/assets/webpage/dist/epub.js`（683KB）+ `epubView.js`，同样是 **epub.js** |
| 结果 | 移动端批注 anchor 可直接用 **epubjs cfiRange**，与 PC 端 `types.ts:69` 注释「定位锚点（epubjs 的 cfiRange 字符串，可用于 rendition.display 跳转）」**完全同源** → 双端同步后「PC 划的线，手机上能高亮显示并跳转」。这是任何纯 Dart 自研方案永远拿不到的能力 |
| 需求覆盖 | 划线（highlight / underline / 可扩展 mark 删除线）✓、分页翻页 + 触控回调查分左右屏 ✓、CFI 级进度 ✓、全文搜索 ✓、目录 ✓、主题字号实时调节 ✓ |

---

## 一、需求与目标

| 编号 | 需求 | 验收标准 |
|---|---|---|
| R1 | EPUB / TXT 划线 | 长按拖选正文 → 弹操作条 → 「高亮 / 横线 / 下划线 / 笔记 / 复制」；选中区域即刻上色；重开书自动还原；笔记可编辑删除 |
| R2 | 翻页模式 | 阅读设置新增「滚动 / 翻页」切换；翻页模式下点击屏幕左 1/3 = 上一页，右 1/3 = 下一页，中间 1/3 = 显隐上下工具栏；支持滑动翻页 |
| R3 | 查看笔记 | 书架长按封面 → 底部抽屉菜单「查看笔记」「移出书架」；查看笔记以底部抽屉展示本书全部划线/笔记，可点击跳转定位、可删除 |

**非目标 / 约束**：数据库表结构对齐 PC（本次**零改表**）；阅读渲染实现允许移动端自定；PDF 仍属 P2。

---

## 二、现状盘点（2026-09-10 实测）

| 文件 | 现状 | 对本需求的影响 |
|---|---|---|
| `features/ebook/components/epub_reader_page.dart`（819 行） | 用 `flutter_widget_from_html` 的 `HtmlWidget` 渲染整章 HTML | ⚠️ **取不到选区偏移量**：已核 `flutter_widget_from_html_core-0.17.3` 全包源码，`SelectableText` / `SelectionRegistrar` **零命中** → 现有渲染层无法做文字级划线 |
| 同上 | 仅 `SingleChildScrollView` 滚动，底部「上一章/下一章」 | 无分页概念，无法点击左右翻页 |
| 同上 | 批注 anchor 只能是 `chapter:<i>`，源码注释标注「CFI 级精确定位列 P2」 | 接方案 A 后该 P2 直接完成（升为真实 CFI） |
| 同上 | 搜索是全本 `for` + `indexOf` 正则 | 接方案 A 后可换成 `controller.search()`（epub.js 原生搜索） |
| `services/epub_service.dart` | 已有宽容 EPUB 解析（绕 epubx 的 TOC 异常）+ TXT 编码侦测（GBK 回退） | 保留，方案 A 下仍用于「取书名 / TXT 分章」 |
| `repositories/ebook_repository.dart` | `addAnnotation / watchAnnotations / removeAnnotation` 已具备（anchor 现为 `chapter:i`） | 只需升级 anchor 语义，**无需改表** |
| `components/book_cell.dart`（124 行） | `onLongPress: onRemove` 直接弹删除确认 | R3 需改为「动作菜单」再分流 |
| `core/db/app_database.dart` | `schemaVersion = 3` | 本次不触 → 规避红线 #3（不必跑 build_runner 重生成） |
| `android/app/build.gradle.kts` | `compileSdk = 37`，AGP 9.1.1 | 引入 `flutter_inappwebview` 的**最大兼容风险点**（见第七章） |

---

## 三、生态插件调研（2026-09-10 实拉包核实）

### 3.1 候选对比

| 包 | 版本 / 最后发布 | 渲染方式 | 划线 | 分页 | TXT | 关键依赖 | 结论 |
|---|---|---|---|---|---|---|---|
| **flutter_epub_viewer** | **2.0.0 / 2026-07-26** | epub.js in WebView | ✅ highlight / underline，JS 层另有 `mark`（删除线） | ✅ `EpubFlow.paginated` + `next()/prev()` + 归一化触控坐标 | ❌ 只吃 EPUB | `flutter_inappwebview ^6.1.5`、`http`、`json_annotation`、`web`；`sdk >=3.8.0 <4.0.0` | ✅ **主线方案 A** |
| epub_view | 停更边缘（实质最后更新 2024-11，且已切 `flutter_html 3.0.0-beta.2`） | 纯 Dart widget（epub + flutter_html） | ❌ 无 | 弱（整章一次性渲染） | ❌ | `flutter_html` beta | ❌ 排除：无划线能力，且 beta 依赖在我们 Flutter 3.47 上不稳 |
| flutter_readium / flureadium | 活跃但偏重 | Rust FFI / 原生 Readium | 需自己实现 | ✅ | ❌ | 原生工具链、体积大 | ❌ 排除：UI 不可控，与 forui 体系统一成本高 |
| vocsy_epub_viewer / epub_kitty / folioreader | 停更多年 | 原生壳 | 弱 | 部分 | ❌ | 老 Android 插件，AGP 9 必炸 | ❌ 排除 |
| **自研（SelectableText.rich + TextPainter 分页）** | — | 纯 Dart | ✅ 可控 | ✅ 自己算 | ✅ | 无新依赖 | 🅱️ **方案 B（兜底）** |

### 3.2 方案 A 关键 API 实测清单（已从 pub.dev 拉取 2.0.0 tarball 逐文件核实）

| 能力 | API / 文件 | 备注 |
|---|---|---|
| 高亮 | `EpubController.addHighlight({cfi, color = Colors.yellow, opacity = 0.3})` | → JS `addHighlight` → `rendition.annotations.highlight()` |
| 下划线 | `EpubController.addUnderline({cfi})` | → JS `addUnderLine` → `rendition.annotations.underline()` |
| **横线/删除线** | 插件**未提供 Dart 方法**，但底层 epub.js `Annotations` 支持三种 type：`"highlight" / "underline" / "mark"`，且 `add(type, cfiRange, data, cb, **className**, **styles**)` 支持自定义 CSS | → 我们自建 bridge： evaluation `rendition.annotations.mark(cfi, {}, cb, 'jl-strike')` + CSS 注入 |
| 自定义 CSS | `EpubTheme.custom(customCss: {...})` → `controller.updateTheme()` → JS `updateTheme(bg, fg, customCss)` | 三主题（日/夜/护眼）+ 自定义划线样式都能做 |
| 选中回调 | `onTextSelected(EpubTextSelection)`、`onSelection(rect)`、`onSelectionChanging()`、`onDeselection()`、`suppressNativeContextMenu: true` | 拿到 CFI + WebView 内坐标 → **我们弹自己的 forui 操作条**（红线 #10） |
| 点击已有划线 | `onAnnotationClicked(String cfiRange, Map? rect)` | JS 层已绑 `rendition.on('markClicked')` |
| 归一化触控 | `onTouchDown(double x, double y)` / `onTouchUp(...)`，0.0~1.0 | **R2 点击左右翻页就靠它**；JS 里还自带 `shouldBlockNavigation` / `blockGesturesWhenSelected` 帮我们屏蔽 WebView 自身点击行为 |
| 翻页/滚动 | `EpubDisplaySettings(flow: paginated/scrolled, spread, manager: continuous, snap, **useSnapAnimationAndroid: false**, fontSize: int, theme)` | `useSnapAnimationAndroid` 必须 false（官方已知：true 会打断 `onRelocated`） |
| 进度 | `initialCfi` / `initialXPath` / `getCurrentLocation()` → `EpubLocation(cfi/xpath/progress)` / `toProgressPercentage()` | 真实 CFI 进度，与 PC 同源 |
| 来源 | `EpubSource.fromFile(File)` / `fromData(Uint8List)` / `fromAsset` / `fromUrl` | 本地文件直读 ✓ |
| 搜索/文本 | `search(query)`、`extractText(startCfi,endCfi)`、`extractCurrentPageText()`、`getRectFromCfi()` | `extractText` 正好用来生成批注 `text` 摘录 |
| 扩展逃生口 | `EpubController.webViewController` 是 **public 字段** | 任何插件没暴露的 epub.js 能力都可自己 `callMethod` / `evaluateJavascript` |

### 3.3 方案 A 的代价（必须先看）

1. **依赖 `flutter_inappwebview ^6.1.5`，而它最后发布于 2024-10-08（近两年未更新）** —— 与本项目 `AGP 9.1.1 + compileSdk 37` 是否冲突未知，是 **Go/No-Go 门禁**。
2. 插件自带 JS 资产约 890KB（epub.js 683KB + jszip 102KB + epubView.js 105KB），APK 体积增加。
3. Android 需 `AndroidManifest` 加 `android:usesCleartextTraffic="true"`（插件走本地 HTTP server 加载 asset）。
4. 插件内部 `import 'package:flutter/material.dart'`，与我们 `material_ui` 并行 —— 隔离在阅读页内、不跨 Theme 边界即可（传色只用 `dart:ui Color`）。
5. 项目历史上有一次决策：**QRFerry 用 `webview_flutter` 替换 `flutter_inappwebview` 以规避模拟器渲染/loadStop 异常**（`pubspec.yaml:65` 注释）。同一份风险会在本模块重现 —— 也正因如此，必须保留方案 C（换引擎 fork）。

---

## 四、推荐方案 A 详细设计

### 4.1 模块拆分（feature-first，单文件职责单一）

```
lib/features/ebook/
├── services/
│   ├── txt_to_epub.dart            # TXT → 最小 EPUB（复用 archive ^3.6.1，已在依赖里）
│   └── reader_annotation_bridge.dart # CFI 划线 Dart↔JS 桥（含 mark 删除线 + CSS 注入）
├── providers/
│   ├── reader_settings.dart        # 已存在，扩：阅读模式 scroll/paging（附加 key）
│   └── reader_mode.dart            # 可选的独立 provider（或并入 reader_settings）
├── components/
│   ├── reader_page.dart            # 新：EpubViewer 宿主（替换 epub_reader_page 主链路）
│   ├── reader_selection_bar.dart   # 选中后的操作条（高亮/横线/下划线/笔记/复制）
│   ├── annotation_actions_sheet.dart # 点已有划线的动作抽屉（编辑笔记/改色/删除）
│   ├── book_notes_sheet.dart       # 本书笔记总览（R3，书架与阅读页共用）
│   ├── book_actions_sheet.dart     # 长按封面动作菜单（查看笔记 / 移出书架）
│   └── [保留] epub_reader_page.dart  # M6 前并行保留，验证通过后下线
└── repositories/ebook_repository.dart # 扩展：无米 CSS 注入无关，新增 anchor 语义解析
```

### 4.2 数据契约 —— **零改表，逐列对齐 PC**

沿用已存在的 `ebook_annotation`（`core/db/tables/ebook_tables.dart:78`），列语义与 PC `jianli-app/src/views/ebookReader/types.ts:66-83` 一致：

| 列 | 移动端写入 | PC 端语义（对齐源） |
|---|---|---|
| `anchor` | **epubjs cfiRange**（如 `epubcfi(/6/4[...]!/4/2/1612,/2/16)`） | 同锚点：epub 为 cfiRange |
| `text`（Dart 字段 `annotatedText`） | `controller.extractText()` 取原文摘录 | 选中原文摘录 |
| `note` | 笔记正文，空串 = 纯划线无笔记 | 同 |
| `color` | `'yellow'` / `'green'` / `'blue'` 色名 | 同 |
| `type` | `'highlight'` / `'underline'` / `'mark'`（删除线·横线）/ `'markStrong'`（双下划线）/ `'note'` | `types.ts:77`：完全同枚举 |
| `content_hash` / `file_path` / `format` / `created_at` / `updated_at` | 不变 | 同 |

**旧数据兼容**：现有行 anchor = `chapter:<i>` → 判定规则：以 `epubcfi(` 开头为 CFI，以 `chapter:` 开头为整章锚点（列表仍显示、跳转走章节 display，但不渲染划线）。

**进度升级**：`ebook_progress.cfi` 从 `'chapter:<i>'` 升级为真实 CFI；读取时先判 `startsWith('chapter:')` 走旧分支，`epubcfi(` 走 `initialCfi` 精确定位（与现有 `_load()` 的 66-76 行分支同构）。

> ✅ 因为完全不改列，**不需要动 `schemaVersion`、不需要跑 `build_runner`**，规避红线 #3。

### 4.3 R1 划线实现

```
长按/拖选 → epub.js `selected` → onTextSelected(EpubTextSelection{cfi, text, rects})
        + onSelection(WebView 内坐标)
        （suppressNativeContextMenu: true 屏蔽系统菜单）
      ↓
显示我们自己的操作条（forui，红线 #10：一律底部抽屉/条）
      ↓ 选择样式
  高亮  → controller.addHighlight(cfi, color, opacity)
  下划线 → controller.addUnderline(cfi)
  横线   → bridge: rendition.annotations.mark(cfi, {}, cb, 'jl-strike')
  笔记   → 同上 + 弹笔记输入抽屉（maxLines:3，键盘兼容按红线 #9）
  复制   → Clipboard.setData
      ↓
repo.addAnnotation(anchor: cfiRange, annotatedText: text, note, color, type)
      ↓
onRelocated / 换章后：按当前 section 过滤本书这批 cfi → 批量重放 highlight/underline/mark
```

- CSS 注入（一次性，随主题切换重放）：
  ```css
  .jl-strike        { text-decoration: line-through; text-decoration-thickness: 2px; }
  .jl-underline     { text-decoration: underline; }
  .jl-highlight     { mix-blend-mode: multiply; }
  ```
- 已有划线点击 → `onAnnotationClicked(cfiRange, rect)` → `annotation_actions_sheet.dart`（改笔记 / 改色 / 删除）。
- 注：`aniline disperse` ── 颜色必须经 `context.theme.colors.*` 取（红线 #6），传参只传 `dart:ui Color`。

### 4.4 R2 翻页模式实现

```dart
EpubDisplaySettings(
  flow: mode == ReaderMode.paging ? EpubFlow.paginated : EpubFlow.scrolled,
  spread: EpubSpread.none,
  manager: EpubManager.continuous,
  snap: true,
  useSnapAnimationAndroid: false,   // ⚠️ 必须为 false，否则 onRelocated 被破坏
  fontSize: settings.fontSize.round(),
  theme: EpubTheme.custom(foregroundColor: readerText(theme), customCss: css),
)
```

点击分区（利用公用 `onTouchDown/onTouchUp` 归一化 x）：

| 区域 | 行为 |
|---|---|
| `x < 0.30` | `controller.prev()` |
| `x > 0.70` | `controller.next()` |
| `0.30 ~ 0.70` | 切换顶栏 / 底部工具条显隐（同主流阅读器） |
| 当前存在有效选区 | **不翻页**（选中态优先，避免手一抖线没了） |

模式持久化沿用 `reader_settings.dart` 的 shared_preferences 风格，新增 key `ebook_reader_mode`；设置抽屉里加一组 `JianliSegmented(items: [(FLucideIcons.rows3,'滚动'),(FLucideIcons.bookOpen,'翻页')])`，切换时 `controller.setFlow(...)`。

> ⚠️ 与现有差异：插件 `fontSize` 是 `int`，现有 `ReaderSettings.fontSize` 是 `double` —— 桥接处 `.toInt()`，UI 仍按 double 步进。

### 4.5 TXT 支持（单管线的关键一招）

插件只吃 EPUB → **把 TXT 就地合成一个最小 EPUB**，从而让 EPUB / TXT 共用同一条渲染、划线、翻页、搜索管线：

```
splitTxtChapters()（已存在于 ebook_repository.dart:524）
      ↓
TxtToEpub.build(title, chapters) → Uint8List
  zip: mimetype / META-INF/container.xml / OEBPS/content.opf / OEBPS/nav.xhtml / OEBPS/chap_*.xhtml
      ↓ 缓存到 booksDir/.txtcache/<contentHash>.epub（避免每次重打包）
```

- 书架 `file_path` 仍指向原 `.txt`（与 PC 保持一致），读取时按 `contentHash` 定位缓存 epub。
- **已知差异（需在评审时确认是否接受）**：PC 端 TXT 批注 anchor 是 `'start-end'` 偏移量，移动端合成 EPUB 后是 CFI → **跨端 TXT 批注不互通**（只展示、不渲染划线）。EPUB 批注两端同源互通。

### 4.6 R3 查看笔记

```
BookCell.onLongPress → _showBookActionsSheet()          # 底部抽屉，红线 #10
  ├─ FTile "查看笔记"  → BookNotesSheet(contentHash)
  └─ FTile "移出书架"  → 现有 _confirmRemove（destructive）
```

`BookNotesSheet`：
- `ref.watch(annotationsStreamProvider(contentHash))`
- `JianliSegmented` 分两档：**划线**（type ≠ 'note'）/ **笔记**（type == 'note'）
- 条目：`FTile(title: annotatedText 摘录, subtitle: note, prefix: 色块 Container)`，`suffix` 放「跳转 + 删除」
- 跳转：`context.push('/ebook/reader?path=…&cfi=<encoded>')` → reader 启动时传 `initialCfi`
- **章节名显示取舍（待确认）**：不改表的话，需要从 CFI 解析 spine index 再映射章节名。建议一期先显示「—」或不显示，二期若确有必要再评估加列（加列需动 `schemaVersion` + build_runner，成本高，一期规避）。

---

## 五、实施里程碑

| 里程碑 | 内容 | 产出 / 门禁 |
|---|---|---|
| **M1 依赖与构建门禁（Go/No-Go）** | `flutter pub add flutter_epub_viewer`；`AndroidManifest` 加 `usesCleartextTraffic`；`flutter build apk --debug` 验证 AGP 9.1.1 / compileSdk 37 与 `flutter_inappwebview` 共存 | **不通过则直接切方案 C**（见第七章） |
| M2 引擎替换 + TXT 合成 | `reader_page.dart` 宿主；`txt_to_epub.dart` + 缓存；CFI 进度读写（兼容旧 `chapter:i`） | EPUB/TXT 都能开、能记住位置 |
| M3 划线三件套 | bridge + 自定义 mark CSS + 选中操作条 + 重开还原 + 点击已有划线动作 | R1 完成 |
| M4 翻页模式 | 设置加「滚动/翻页」；左右点击分区；中间区显隐工具栏；模式持久化 | R2 完成 |
| M5 书架笔记入口 | `book_actions_sheet.dart` + `book_notes_sheet.dart`；跳转定位；删除 | R3 完成 |
| M6 能力收尾 | 搜索/目录切到插件能力；旧 `epub_reader_page` 下线；删除估算量为全书 `.works` | 代码瘦身，功能集中 |
| M7 文档同步 | `modules/features.md`、`modules/changelog.md`（红线 #8） | 记录 Calculator + CFI 语义升级 |
| M8 可选 | 评估 `flutter_inappwebview` 与 `webview_flutter` 双引擎是否值得统一 | 不做强制 |

---

## 六、验证清单（命令交用户本地执行 —— 分工铁律 / 30 秒规则）

```bash
export TMP=C:/src/tmp TEMP=C:/src/tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_HOME=C:/apps/Android/AndroidSDK ANDROID_SDK_ROOT=C:/apps/Android/AndroidSDK
export GRADLE_USER_HOME=C:/src/gradle-home
export JAVA_HOME="/c/apps/Android/Android Studio/jbr"

cd C:/cod/jianli/jianli-mobile-app
flutter pub add flutter_epub_viewer                 # M1 门禁点 1
C:/src/flutter/bin/flutter build apk --debug        # M1 门禁点 2（<30s 无结果即停，转手动）
C:/src/flutter/bin/flutter run -d emulator-5554     # M2 起：渲染/划线/翻页手工验证
```

手工验证清单：① EPUB 打开正常、有无黑屏/白屏；② 长按选词能否弹出自定义菜单；③ 高亮/横线/下划线三种样式是否可见；④ 退出重进是否还原；⑤ 翻页 mode 下左右点击分区是否正确；⑥ TXT 打开是否正常（编码 + 合成 EPUB）；⑦ 书架长按 → 查看笔记 → 跳转定位。

---

## 七、风险与降级

| 风险 | 影响 | 对策 | 降级终点 |
|---|---|---|---|
| `flutter_inappwebview 6.1.5`（2024-10 停更）与 AGP 9.1.1 / compileSdk 37 冲突 | M1 门禁不过 | 先 debug 构建验证；冲突就锁 `dependency_overrides` 或换版本 | **方案 C**：fork 插件，把 WebView 层从 inappwebview 换成项目已在用的 `webview_flutter`（改动集中在 `platform/epub_web_view_io.dart` 与 JS 里 `callFlutterHandler` → `javaScriptChannels`） |
| 模拟器 WebView 渲染/loadStop 异常（项目历史坑） | 阅读页打不开/白屏 | 优先真机验证；必要时把 Dalvik WebView 升级/换实现 | **方案 D**：EPUB 走 A/C，TXT 保留现有 HtmlWidget 滚动（仅 EPUB 有划线）；极端 → **方案 B** 全自研 |
| APK 体积 +~9MB assets | 安装包变大 | `--split-per-abi` 打包；非阻塞 | 接受 |
| 插件内部引用 `flutter/material` 与 `material_ui` 并行 | Theme 继承链断裂 | 隔离在阅读页内部，不跨 Theme 边界；传色只用 `dart:ui Color` | 无 |
| 「横线」是否等同删除线 | 语义歧义 | 计划按 **横线 = 删除线 = PC 的 `mark`** 实现（与 PC `types.ts:77` 对齐） | 若用户本意是「双下划线」，改用 PC 的 `markStrong`，CSS 一行切换 |
| TXT 批注跨端不互通（CFI vs PC 的 start-end） | 双端 TXT 同步后只显示不高亮 | 计划中明示为已知差异 | 二期评估是否改 `start-end` 自研 TXT 管线 |

---

## 八、双端对齐总结

| 维度 | PC 端 | 移动端（方案 A 后） | 是否同源 |
|---|---|---|---|
| 阅读内核 | epub.js 0.3.93 | epub.js（插件内置） | ✅ 同源 |
| 批注 anchor（EPUB） | epubjs cfiRange | epubjs cfiRange | ✅ 互通 |
| 批注 anchor（TXT） | `start-end` 偏移 | CFI（合成 EPUB） | ❌ 已知差异 |
| 划线类型枚举 | highlight / underline / mark / markStrong | 同 | ✅ |
| 颜色标识 | yellow / green / blue | 同 | ✅ |
| 表名与列名 | `ebook_annotation` 十一列 | 完全一致（零改表） | ✅ |

---

## 九、开放待确认（开工前请拍板 5 条）

1. **是否接受 TXT 走「合成最小 EPUB」单管线**（换来 EPUB/TXT 体验一致，代价是 TXT 批注与 PC 的 `start-end` 不同源）。或选保守版：TXT 保留自研管线。
2. **「横线」= 删除线（`mark`）还是双下划线（`markStrong`）？** —— 计划默认按删除线（PC 语义对齐）。
3. **笔记列表是否需要显示章节名？** 不改表则只能降级显示（或不显示）；如需必保，则允许加列（要动 schemaVersion 跑 build_runner）。
4. **是否授权我先把 M1 的依赖装上跑一次构建门禁**（`flutter pub add` + `--debug` 构建），确认 inappwebview 与 AGP 9/SDK 37 能否共存 —— 这是唯一会让方案作废的关键未知项，其余都可离线推进。
5. 若 M1 不通过，默认按 **方案 C（fork 换 webview_flutter）** 继续，还是直接切 **方案 B（纯 Dart 自研）**？

---

## 附：方案 B（纯 Dart 自研）要点（若启用）

- 渲染：章节 HTML → 轻量 block 化（p/h/img/b/i）→ `SelectableText.rich`（已核实 `material_ui` 导出 `selectable_text.dart`，含 `SelectableText.rich` 与 `onSelectionChanged`）
- 划线：按 block 内 `start:end` 存 `TextSpan` 样式（`backgroundColor` / `TextDecoration.lineThrough` / `TextDecoration.underline`），anchor 编码 `chapter:<i>|b:<blockIdx>|s:<start>|e:<end>`
- 分页：`TextPainter.getPositionForOffset` + 断行测算 → `PageView`
- 代价：图片/复杂排版降级、CFI 无法与 PC 同源、工作量显著高于方案 A
