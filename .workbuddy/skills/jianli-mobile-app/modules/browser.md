# 模块：浏览器（`features/browser`）

> 定位：**完整 Via 风浏览器** = 极简搜索首页（新标签页）+ 单 WebView 多标签 + 书签/历史 + 三级广告拦截。
> 设计稿（7 屏，唯一真源）：<https://ardot.tencent.com/file/727382358962697>
> 方案文档：`references/browser-plan.md`（屏 ↔ 文件映射、分期范围、已定案的交互规则）
>
> **移动端专有功能域**：桌面端（Electron）没有浏览器模块，故本域数据表**不入同步白名单**。

## 一、范围与分期

| 期 | 范围 | 状态 |
|---|---|---|
| **Phase 1** | 主壳（地址栏两态 / WebView / 底部工具栏）+ 极简首页 + 固定标签九宫格 + 多标签抽屉 + 菜单抽屉 + 数据层 4 表 + 设置持久化 | **已落地（2026-09-19）** |
| **Phase 2** | 书签页（文件夹树 + 长按操作单）、历史页（+ 长按操作单）、完整设置页（7 分组）、固定标签管理页、广告拦截引擎（内置静态集 / 订阅 / 自定义三级）、清除浏览数据页、**底部工具栏中间位 刷新 → 首页** | **已落地（2026-09-19）** |
| **Phase 3** | 真实 favicon（替换字母占位）、会话恢复语义打磨、下载管理 | 待做 |

菜单抽屉（`browser_menu_sheet.dart`）现在放的是**全部可用入口**（页面动作 4 项 + 数据 2 项 + 设置/无痕 2 项，共 8 行 → 用 lg 80% 档）。**新加动作必须同步实现目标页，不留死入口**。

## 二、文件结构（feature-first，单文件职责单一）

```
lib/features/browser/
├── browser_page.dart                    主壳：只做「状态编排 + WebView 生命周期」，不放 UI 细节
├── models/
│   ├── browser_models.dart              常量/默认站点/搜索引擎 + 纯函数（地址解析、host、哈希、占位字）
│   └── browser_settings.dart            BrowserSettings + BrowserKeys（basic_info 键）+ 序列化
├── data/
│   └── browser_repository.dart          drift 读写唯一入口（UI 不直接碰 AppDatabase）
├── services/
│   ├── adblock_rules.dart               规则解析（`||domain^` / 子串 / `@@` 例外）+ 内置静态种子集
│   ├── adblock_engine.dart              三级规则编译成索引 + `shouldBlock(url)` 单次判定
│   └── adblock_subscriptions.dart       订阅抓取（dart:io）+ 缓存（存 basic_info，**不进 BrowserKeys.all**）
├── providers/
│   └── browser_providers.dart           仓库 + 4 条数据流 + 设置 AsyncNotifier + 导航通道 + 引擎（**全部顶层声明**）
├── pages/                               6 个子页（统一走 `BrowserSubPage` 骨架）
│   ├── browser_bookmarks_page.dart      书签（文件夹树 + 面包屑 + 长按操作单）
│   ├── browser_history_page.dart        历史（按天分组 + 长按操作单）
│   ├── browser_settings_page.dart       设置（常规/外观/隐私/广告拦截/固定标签页/书签与历史/关于）
│   ├── browser_pinned_page.dart         固定标签页管理（九宫格 + 加入/替换/重命名/排序/移除）
│   ├── browser_static_rules_page.dart   内置静态规则集（开关 + 条目预览）
│   ├── browser_subscriptions_page.dart  订阅规则（增删 + 抓取刷新 + 缓存状态）
│   ├── browser_custom_rules_page.dart   自定义规则（逐条增删 + 语法提示）
│   └── browser_clear_data_page.dart     清除浏览数据（时间范围 + 勾选项）
└── components/
    ├── browser_address_bar.dart         顶部地址栏两态（常态 / 输入态）
    ├── browser_new_tab_home.dart        极简首页（品牌块 + 搜索入口 + 九宫格）
    ├── browser_speed_dial.dart          固定标签九宫格（**首页 / 管理页 / 设置页共用**）
    ├── browser_toolbar.dart             底部工具栏（返回/前进/**首页**/标签/菜单）
    ├── browser_tab_sheet.dart           多标签抽屉
    ├── browser_menu_sheet.dart          菜单抽屉（lg 80%，8 行）
    ├── browser_subpage.dart             子页骨架（返回 + 标题 + 右侧动作）+ `BrowserHeaderAction`
    ├── browser_site_tile.dart           站点条目卡（书签/历史共用）
    ├── browser_site_actions.dart        长按操作单 + 加入固定标签 + 复制链接 + **跨页导航通道**
    ├── browser_prompt.dart              单字段输入抽屉（新建文件夹/重命名/填订阅地址共用）
    └── settings_tiles.dart              设置行原子（分组/开关行/跳转行/提示行/章节标题）
```

分工原则：**页面只管编排与生命周期，组件只吃数据 + 回调**（九宫格因此能被首页与设置页复用，改一处两处同步）。

## 三、数据层（4 张表，v4）

表定义 `lib/core/db/tables/browser_tables.dart`，全部**移动端专有、不入同步白名单**（`sync_service.dart` 的 `kSyncableTables` 不动）。

| 表 | 主键 | 要点 |
|---|---|---|
| `browser_tabs` | `key`(uuid) | 标签会话，只存「地址 + 标题 + 顺序 + 最后活动时间」。切标签 = 换地址重新 `loadUrl` |
| `browser_pinned` | `key`(uuid) | 固定标签页。`position` = 槽位 0..7；**`added_at` 是 FIFO 替换的唯一判据，勿删** |
| `browser_bookmarks` | `key`(uuid) | 书签 + 文件夹（`is_folder='1'` 时 `url` 为空，`parent_key` 组树） |
| `browser_history` | `key`(hash) | 历史，`key = urlKeyOf(url)`（FNV-1a 32 → 同一地址只留一行），`visit_count` 累计 |

迁移：`schemaVersion 3 → 4`，`if (from < 4) await m.createAll();`——`createAll()` 生成 `CREATE TABLE IF NOT EXISTS`，对已有 28 张表是空操作，**存量数据原样保留**（遵守数据层三铁律，禁止 `destructiveFallback`）。

### 固定标签页规则（用户定案）
- 默认 **8 个**（`kPinnedMaxSlots`），2×4 九宫格，槽位 `position` 0..7。
- **加入第 9 个 → 替换 `added_at` 最早的那个**（FIFO），且**复用被替换者的槽位**（视觉上「就地替换」而非末尾插入）；`addPinned()` 返回被替换站点标题供 UI 提示。
- 名单可编辑（设置页九宫格 + 长按）；`ensureDefaultPinned()` **只在表为空时写入默认 8 站**，绝不覆盖用户编辑。

### 设置持久化（`basic_info`，不另开表）
- 键前缀统一 `browser_`，见 `BrowserKeys`；**新增键必须同时加进 `BrowserKeys.all`**（`readSettings()` 按它一次性捞）。
- ⚠️ **例外：订阅抓取缓存键（`BrowserKeys.adBlockSubsCache = 'browser_adblock_subs_cache'`）刻意不进 `BrowserKeys.all`** —— 它不是「设置」而是「缓存」，进 `all` 会污染 `BrowserSettings.toMap()` 的「完整快照 = 只有设置项」语义。这类键用 `readRawSetting` / `writeRawSetting` 直接读写。
- 布尔存 `'1'`/`'0'`，列表字段存 JSON 串，解析脏数据一律降级为默认值、不抛异常。
- ⚠️ **`toMap()` 必须返回完整快照（所有键都写）**，不能只写「与默认值不同」的项——否则把开关改回默认后旧值永久留在 DB，重启又变回来（例：无痕 开→关，重启仍为开）。

## 四、必须遵守的红线（本域特有）

1. **单 WebView 多标签**：全程只有一个 `InAppWebView`，切标签 = 重新 `loadUrl`，**不要做多 WebView 常驻**（内存）。空白标签用 `about:blank`（`kBrowserBlankUrl`）表示，首页是**盖在 WebView 之上的覆盖层**（WebView 不销毁，切回旧标签能继续用）。
2. **首页没有自己的输入框**：`_SearchEntry` 只是「点击区」→ 让顶部地址栏进入输入态。**统一由地址栏承担输入**，否则会出现「同一个输入在不同入口行为不同」。**⚠️ 进入输入态必须让页面 `setState(_editing=true)` 再挂载 `TextField` 抢焦点，绝不能只 `focusNode.requestFocus()`（非输入态 `TextField` 未挂载，requestFocus 作用于未挂载节点会失效，表现为「点不动」）—— 详见红线 #19。**
3. **导航唯一入口 `_load(url)`**；输入解析唯一入口 `resolveInput(raw, engine:, customTemplate:)`（`models/browser_models.dart`）。**不要在页面里另写一套 `looksLikeUrl` 判断**。
4. **路由必须纯横向滑入**（`slidePage`，禁淡入）——WebView 平台视图对透明度动画敏感，淡入期间易空白。先例：`/ferry`。
5. **抽屉内容自带 `Consumer`**（红线 #28）：`showFSheet` 的 builder 属于 Navigator overlay 子树，页面 `ref.watch` 不会让抽屉重建。已落地：`browser_tab_sheet.dart`、`browser_menu_sheet.dart`。
6. **无痕切换需重建 WebView**：`incognito` 写进 `InAppWebView` 的 `ValueKey`（模式隔离），不要期待改设置就能切干净。
7. **DNT 注入必须有去重护栏**：`_shouldOverrideUrlLoading` 里「请求已带 DNT / 本轮已注入过」必须直接 `ALLOW`，否则 `loadUrl` 会自我循环。
8. **原生 `TextField` 必须有 `Material` 祖先**：`_AddressInput` 外层包了 `Material(type: MaterialType.transparency)`。例外允许 `InputBorder.none`（外层药丸自带描边，再画会「双框」，见红线 #14 ①）。
9. **跨页「打开某个地址」走 `browserPendingUrlProvider` 通道，不要 `pop(url)` 回传**：子页可能被多层推入（浏览器 → 设置 → 固定标签管理），`pop` 只退一层、结果到不了主壳。子页写 `requestBrowserNavigation(ref, url)`，主壳 `ref.listen` 消费后**必须立刻 `consume()` 清空**（不清空会被下次 push 重复消费）。
10. **子页一律顶层路由**（`/browser/bookmarks`、`/browser/rules/static` …），**不做 `/browser` 的子路由**：`/browser/pinned` 既从设置进也从首页长按进，挂在父路由下会被父级栈绑定。子页无 WebView，**可以**用 `slidePage`（纯横向）。
11. **可热更的设置不许重建 WebView**：深色模式 / 网页字号 / 广告拦截开关都走 `controller.setSettings(_webSettings(s))`（原地生效，保住滚动位置与表单状态）；只有 `incognito` 因模式隔离必须走 `ValueKey` 重建。**`_webSettings()` 是唯一构造点**，首次创建与热更共用，禁在 `initialSettings` 里再抄一份。
12. **工具栏中间位是「首页」不是「刷新」**（2026-09-19 用户定案）：中间位放最高频动作，回首页比刷新常用；刷新已移到菜单抽屉。当前已是新标签页时 `onHome` 传 null 置灰。
13. **广告拦截只拦子资源，主文档绝不拦**：`_shouldInterceptRequest` 里 `request.isForMainFrame == true` 直接放行 —— 规则写错时最坏结果是「某个广告没拦住」，绝不能是「整页白屏」。且 `useShouldInterceptRequest` **只在总开关打开时开启**（它让所有请求都过平台通道，有实打实的开销）。

### 框架版本坑（踩过，别再犯）
14. **Riverpod 3 已移除 `StateProvider`**（要用得从 `flutter_riverpod/legacy.dart` 单独导入）→ 一次性状态一律用最小 `Notifier`（见 `BrowserPendingUrlNotifier`）。报错是 `Undefined class 'StateProvider'`。
15. **`ForceDark_` 是生成器内部类，未导出**：`ForceDark_.AUTO/OFF/ON` 会报 `Undefined name 'ForceDark_'`。公开名是 **`ForceDark`**（`src/types/main.dart` 里 `export 'force_dark.dart' show ForceDark, AndroidForceDark;`）。同规律适用于所有 `@ExchangeableEnum` 类型。
16. **`SheetSize` 定义在 `app/ui/sheet_surface.dart`，不在 `sheet_form.dart`** → 用 `SheetScaffold(size: SheetSize.md)` 的文件必须**两个都导**。`sheet_form.dart` 不会帮你 re-export。
17. **`WebResourceRequest.url` 在 6.x 是非空类型**（写 `?.toString() ?? ''` 会有 `invalid_null_aware_operator` 警告）。`WebResourceResponse` 的 `headers`/`statusCode`/`reasonPhrase` **要么都给要么都不给**，只给一个会被原生化抛异常。
18. **私有具名参数（Dart 3.6+）**：`required this._blockHosts` 是合法的，对外形参名仍是 `blockHosts`（下划线自动剥掉），调用点写法不变 —— 这就是 `prefer_initializing_formals` 想让你写的形态。
19. **地址栏 / 首页搜索「点不动」= 焦点回灌死锁（2026-09-19 实踩，真机表现就是「无法点击」）**：地址栏**非输入态渲染的是 `Text`、没有挂载 `TextField`** → 此时 `_addressFocus` 这个 `FocusNode` **没有挂到任何 widget**。若点药丸 / 点首页搜索只调 `focusNode.requestFocus()`，是对「未挂载的节点」请求焦点 → 什么都不做 → `hasFocus` 恒 false → `_onFocusChanged` 永远不把 `_editing` 翻成 `true` → 地址栏永远停在常态、首页搜索永远进不了输入态，两种表现都是「点不动」。**修法（已落地）**：进入输入态必须**直接 `setState(_editing = true)`**（页面侧 `_enterEditing()`），让 `_AddressInput` 挂载、`TextField` 用 `autofocus: true` 抢焦点；文本与选区提前写进 `controller`，挂载即呈现。`BrowserAddressBar` 新增 `onActivate` 回调（页面传 `_enterEditing`），非输入态点药丸走 `onActivate` 而非裸 `requestFocus`；首页 `onTapSearch` 也从 `requestFocus` 改为 `_enterEditing`。⚠️ 退出输入态仍靠 `_addressFocus.unfocus()` → `_onFocusChanged` 把 `_editing` 翻回 false（这条路径正常，因为 TextField 已挂载）。
20. **自定义 scheme（baiduboxapp:// / intent:// 等）绝不能放行给 WebView（2026-09-19 实踩）**：WebView 内核原生不认这些 scheme → 放行必报 `net::ERR_UNKNOWN_URL_SCHEME`；百度结果页「网页无法打开」和视频播放报错全是同一根因（百度 H5 注入「唤起自家 App」的跳转）。处理在 `_shouldOverrideUrlLoading` 前置：内部 scheme（about/data/blob/javascript/file）放行；**子框架里的自定义 scheme 一律 CANCEL**；主文档走 `_launchExternalScheme` = `launchUrl(mode: externalApplication)` + try/catch（**不要用 canLaunchUrl 预检**——Android 11+ 包可见性会误报 false），失败回退 intent URI 的 `S.browser_fallback_url`（`_intentFallbackUrl` 解析 `#Intent;` 后分号键值对），再不行 `showFToast` 提示。依赖 `url_launcher`（6.3.2，原本就在依赖树里，提升为直接依赖零新增下载）。配套：默认 UA 显式给 `kMobileUserAgent`（标准 Chrome Reduced UA，`browser_settings.dart`）——WebView 默认串带 `; wv` 标记会被百度识别成非正规浏览器并注入唤起跳转；语义约定 = `effectiveUserAgent == null` 仍表示「无用户覆盖」，UA 兜底只在 `_webSettings` 层做（`s.effectiveUserAgent ?? kMobileUserAgent`），菜单「浏览器标识」激活态判断不受影响。
21. **返回/前进必须走 `_historyStep(±1)`，不能裸 goBack/goForward（2026-09-19 实踩）**：DNT 注入的实现是「CANCEL 原始导航 + `loadUrl(同URL+DNT头)` 重放」（加请求头的唯一手段），而 `loadUrl` 只压栈不替换 → **每次点击链接都在历史里留两条同 URL 条目**（DNT 默认开）。裸返回落在同页旧条目上 = 「按返回却重定向回当前页」；有 JS 自动跳转的页面（百度）表现成反复重载退不回去。修法：`_historyStep(delta)` 用 `onUpdateVisitedHistory` 做「落点信号」（`_historySignal` Completer，1.5s 超时兜底），落点与出发页同 URL 就继续步进（上限 8 条），底栏返回/前进 + PopScope 系统返回三处都接它。配套防护（同在 `_launchExternalScheme`）：同 scheme URL 5 秒内反复出现（openApp 重试型站点）第 3 次起静默取消；`S.browser_fallback_url` 与当前页相同不重载（重载 = 再压一条同页历史 + 再触发 openApp，死循环）。
22. **地址栏键盘必须用普通文本键盘，绝不能 `TextInputType.url`（2026-09-21 修复）**：URL 专用键盘压掉中文 IME（只能英文/符号），而地址栏是「搜索或输入网址」的 omnibox，关键词搜索占大半场景 → `keyboardType: TextInputType.text` + `enableSuggestions: true` + `autocorrect: false`。**网址 vs 搜索的分流与键盘类型无关**，由 `resolveInput(looksLikeUrl)` 唯一承担（红线 #3，勿另写）。例外：设置里的自定义搜索模板 / 固定标签网址 / 订阅源 URL 三个**纯 URL 配置项**仍保留 `TextInputType.url`（内容恒为英文/符号）。

## 五、关键实现备注

- **地址栏两态规格**（对齐画布「1·地址栏输入态」）：常态 = 卡片底 + 发丝线 + r22/h44 + 锁图标 + 域名；输入态 = **淡紫底 + 浅紫描边（用底色表达激活，不用粗边框）** + 18px 淡紫放大镜 + 紫色光标 + 清空 ✕ + 行尾独立「取消」。加载进度是 2px 条，只在 `0 < progress < 1` 出现。
- **依赖**：`flutter_inappwebview ^6.1.5` 提为**直接依赖**（原本由 `flutter_epub_viewer` 传递引入，零新增下载）；与 `webview_flutter`（流光扫传用，原「隔空互传」）两套插件共存，互不影响。manifest 已有 `INTERNET` + `usesCleartextTraffic="true"`，联网无需改清单。
- **占位字**：设计稿的站点图标是字母占位（无 favicon 资源），落地换真 favicon 时**格子尺寸/间距不用动**；`parseHexColor` 非法值回落主题主色。
- **广告拦截三级规则（Phase 2 已落地）**：
  1. **内置静态规则集**（`adblock_rules.dart` 的 `kStaticBlockedHosts` / `kStaticBlockedPatterns`）= 中英文常见广告/统计/追踪域的**种子集**，体积小、命中快，硬编码进 Dart。设置页「内置静态规则集」页可单独开关。
  2. **订阅规则**（`adblock_subscriptions.dart`）= 用户填 URL → `dart:io` 抓回原始规则文本 → 存 `basic_info`（**缓存键刻意不进 `BrowserKeys.all`**，见下）→ 设置变更时重新编译。
  3. **自定义规则** = 用户逐条输入。
  三条路径在 `AdBlockEngine.compile()` 里合并；**例外规则（`@@`）优先级最高**：先查例外，命中即放行，不看拦截规则。
- **拦截实现**：`useShouldInterceptRequest: true` + `shouldInterceptRequest` 回调，**拦截 = 返回空的 `WebResourceResponse`**（`contentType:'text/plain', data: Uint8List(0)`）。⚠️ 该开关会让**所有**请求过平台通道 → 只在总开关打开时开；匹配侧先对 URL 分词、再用 token 反查候选规则、最后完整 `contains` 校验（O(长度)，不逐条扫）。iOS 无此 API（需 `ContentBlocker`），本域当前只针对 Android。
- **媒体嗅探双通道（2026-09-19 落地，Via 同构，红线 #13 的开销例外见下）**：① 网络层 = `shouldInterceptRequest` 观察子资源 URL 扩展名；② JS hook = `_sniffHookJs` UserScript（AT_DOCUMENT_START，脚本自带 `__jlSniffInstalled` 防重，DNT 重放重注入也安全）hook fetch/XHR/周期扫 video·audio·source，经 `callHandler('browserSniff')` 回传（handler 在 `onWebViewCreated` 注册）。**分类唯一真源在 Dart 侧 `BrowserSniffer.observe()`**（扩展名映射 `kSniffExtKinds`，无扩展名时才用 JS 的 video/audio hint 兜底），JS 只报 URL+标签。开关 `sniffEnabled`（默认开，设置页「媒体嗅探」）：`useShouldInterceptRequest = adBlockEnabled || sniffEnabled` —— 嗅探开着时平台通道开销是**有意接受的**（Via 同架构）。换页重置：主文档 `onLoadStart`（非 about:blank）调 `_sniffer.reset()`（SPA pushState 不触发 loadStart，同标签持续累计是预期行为）。`_openSniff` = 实时累计 + DOM 静态扫描按 URL 合并去重。**流媒体（m3u8/mpd）只是清单链接**：面板条目尾按钮 = 复制链接，交给外部 HLS 工具；内置清单解析+分片合成下载是独立工程，勿把 m3u8 直接塞进 DownloadService（只会下到文本）。
- **引擎记忆化**：`adBlockEngineProvider` 用「设置 + 订阅缓存摘要」拼签名，签名不变就复用上一次编译结果 —— 否则任一 provider 微动都会重编译上万条规则。
- **清除浏览数据**：历史走 drift；Cookie / 缓存 / 本地存储走 WebView 原生 API（`CookieManager.instance().deleteAllCookies()` / `InAppWebViewController.clearAllCache()` / `WebStorageManager.instance().deleteAllData()`），**每项独立 try/catch**，失败项收集后统一提示，不因一项失败中断其余。
- **深色模式映射**：`BrowserDarkMode.system/light/dark` → `ForceDark.AUTO/OFF/ON`；网页字号 → `textZoom: (fontScale * 100).round()`。

## 六、验证

```bash
cd /c/cod/jianli/jianli-mobile-app
export TMP=C:/src/tmp TEMP=C:/src/tmp
# 1) 新增/改表定义后必须先重新生成（否则满屏 undefined_class / undefined_getter）
dart run build_runner build --delete-conflicting-outputs
# 2) 静态检查
dart analyze lib/features/browser lib/core/db
# 3) 真机/模拟器（浏览器功能只针对 Android）
flutter run
```

⚠️ **本机不用 `flutter test`**（沙箱跑不了）；`flutter.bat` 在本机被沙箱拦（shim 转调 wsl.exe），**静态校验改直接调** `C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe analyze <相对路径>`（先 `cd` 到工程根）。
⚠️ 改完表定义**没跑 build_runner** 时的症状：`.g.dart` 里没有新表 → 报一堆 `Undefined class 'BrowserTab'` / `The getter 'browserPinned' isn't defined for the type 'AppDatabase'`。**看到这类错先去跑 codegen，不要改代码。**
