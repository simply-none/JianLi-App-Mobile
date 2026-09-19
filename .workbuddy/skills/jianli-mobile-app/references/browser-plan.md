# 浏览器功能域 —— 方案与分期（design → code 映射）

> 制定：2026-09-19 ｜ 设计稿：<https://ardot.tencent.com/file/727382358962697>（7 屏，唯一真源）
> 落地知识（表结构 / 红线 / 验证命令）见 `modules/browser.md`，本文只讲**范围、屏↔文件映射、已定案的规则**。

## 一、范围（用户已定案）

**完整 Via 风浏览器 + 极简搜索首页 + 单 WebView 多标签。**

用户逐轮否掉并最终定案的交互：
- ❌ 首页输入框挪到底部 dock（用户明确否掉）
- ❌ 首页顶部固定地址栏（用户明确否掉）
- ✅ **首页 = 通用浏览器新标签页布局：【图标标题 + 搜索栏 + 固定标签（默认 8 个，2×4 九宫格）】**
- ✅ 第 1 屏不是独立首页，而是**浏览页顶部地址栏被点开输入时的效果**
- ✅ **广告拦截 = 三级规则**：内置静态规则集 + 支持可订阅规则 + 支持自定义拦截规则

## 二、屏 ↔ 落地文件映射

| 屏 | 设计稿内容 | 落地文件 | 期 |
|---|---|---|---|
| 极简首页 | 图标标题 + 搜索栏 + 2×4 固定标签 | `components/browser_new_tab_home.dart` + `browser_speed_dial.dart` | P1 ✅ |
| 1·地址栏输入态 | 顶部地址栏点开输入 | `components/browser_address_bar.dart`（两态）| P1 ✅ |
| 浏览页 | WebView + 顶部地址栏 + 底部工具栏 | `browser_page.dart` + `components/browser_toolbar.dart` | P1 ✅ |
| 多标签 | 标签列表抽屉 | `components/browser_tab_sheet.dart` | P1 ✅ |
| 菜单抽屉 | **19 项 5×2 图标网格 + 分页**（≤10 一页，>10 `PageView` 横滑 + 底部小圆点；关机键关闭**在内容第三行最右列**，与分页圆点居中同行）| `components/browser_menu_sheet.dart`（`_BrowserMenuGrid` 分页）+ `browser_ua_sheet.dart`（UA 选择）| P0 ✅ |

> ⚠️ 菜单弹窗高度用 **sm 档 `AppTokens.sheetHeightSm`（0.30 = 30vh）**，是「操作菜单」类弹窗；**严禁用 lg 档**（会撑大半屏，2026-09-19 实踩「撑大半屏 + 关闭键跑右上角」）。关机键（power）从顶部右上角移到了内容第三行页脚最右列，对齐图标网格第 5 列。
| 书签历史 + 长按操作单 | 文件夹树 / 历史列表；长按 → 加入固定标签页 | `pages/browser_bookmarks_page.dart` + `pages/browser_history_page.dart` + `components/browser_site_actions.dart` + `components/browser_site_tile.dart` | P2 ✅ |
| 设置 | 6 分组（常规/外观/隐私/广告拦截/固定标签页/关于）| `pages/browser_settings_page.dart` | P2 ✅ |
| （增设）固定标签页管理 | 说明 + 8 格管理网格 + 加入按钮 | `pages/browser_pinned_page.dart` | P2 ✅ |
| （增设）广告拦截三级 | 静态集 / 订阅 / 自定义 | `pages/browser_static_rules_page.dart` / `browser_subscriptions_page.dart` / `browser_custom_rules_page.dart` + `services/adblock_*.dart` | P2 ✅ |
| （增设）清除浏览数据 | 时间范围 + 勾选项 | `pages/browser_clear_data_page.dart` | P2 ✅ |

## 三、已定案的规则（不要再「优化」）

1. **固定标签页**：默认 8 个 / 2×4；**超 8 时新的替换 `added_at` 最早的**（FIFO）并**复用其槽位**；名单可编辑；添加入口 = 设置页「加入固定标签页」；**书签 / 历史里的文件夹与地址长按 → 加入固定标签页**。
2. **首页固定标签区是「可选」的**（设置项 `browser_home_pinned`，默认开）。
3. **默认站点名单**（用户已确认）：百度 / 淘宝 / 京东 / 微博 / 知乎 / 哔哩哔哩 / 豆瓣 / 小红书（各带品牌色）。落地换真 favicon 时格子规格不动。
4. **地址栏输入态视觉**：靠**底色**表达激活（淡紫底 + 浅紫描边 r22），不用 1.5px 亮紫粗边框（初版那样「边框抢戏、盒子显笨」已被用户否掉）。
5. **设置页 6 分组**：常规（搜索引擎 / 首页显示固定标签页 / 新标签页打开方式）· 外观（深色模式 / 网页字号）· 隐私与安全（无痕模式 / 不追踪请求 / 清除浏览数据）· 广告拦截（总开关 / 内置静态规则集 / 订阅规则 / 自定义拦截规则）· 固定标签页 · 关于（版本 / 开源许可）。
6. **搜索引擎可选项**：百度 / 必应 / Google / 搜狗 / 自定义（`kBrowserEngines`；自定义模板含 `%s`）。
7. **「清除浏览数据」** 单独出屏（时间范围 + 勾选项）——**已落地**，勾选项 = 历史 / Cookie / 缓存 / 本地存储，时间范围 = 全部 / 最近 1 小时 / 24 小时 / 7 天。
8. **底部工具栏中间位 = 首页（回新标签页）**，不是刷新（2026-09-19 用户定案）；刷新移到菜单抽屉。
9. **首页九宫格长按 = 进固定标签页管理页**（与书签/历史长按「加入固定标签页」互补：一个是管理、一个是新增）。

## 四、Ardot 画布协作备注（做设计稿时踩到的）

- 九宫格在画布上已改为**真组件**（主件「组件·固定标签页网格」），首页与设置页各放实例 → 改站点/格子两处同步。⚠️ **把节点设为组件会让它换 ID**，同一批 `batch_edit` 里用旧 ID 引用会失败（旧网格被删、新实例没插上）→ 设组件后必须用**新 ID** 补引用。
- flex 行里 `fill_container` 会吃满整行、把 hug 的兄弟节点挤出容器（第 1 屏「取消」一度整个不可见）→ 需要剩余宽度用固定值或 `layoutGrow`。
- 覆盖层用 `layoutPositioning:"ABSOLUTE"`；同构区块直接 `C()` 整段拷贝最省 op。

## 五、待确认 / 未决

- 首页九宫格与底部工具栏之间留白约 200px（Chrome 的「上重下轻」构图），是否下移居中 —— **用户未表态，暂保持 Chrome 做法**。
- 广告拦截的内置静态规则集**实际条数**（设计稿写 12,438 条）：真实 EasyList CN 体量大，P2 先落了一个**精选种子集**（常见广告/统计/追踪域，体积小、命中快），设置页文案如实标注为「种子集」，并在页内引导用户去「订阅规则」拿完整清单。**后续可把完整 EasyList CN 作为构建期资源打包**再替换。
- **菜单 P0 + P1 已落地**（2026-09-19 续轮）：菜单重构为 19 项分页图标网格；`BrowserSettings` 新增 `desktopMode`/`uaPreset`/`customUa`/`noImage`（键 `browser_desktop_mode`/`browser_ua_preset`/`browser_ua_custom`/`browser_no_image`，全进 `BrowserKeys.all` + 完整快照 `toMap`，规避稀疏存储旧值残留坑）；`browser_page.dart` 接 夜间模式快捷切（菜单内）/分享(`SharePlus.instance.share(ShareParams)`)/电脑模式(`userAgent` 套桌面 UA)/浏览器标识(UA 预设)/无图(`blockNetworkImage`)/页内查找(`findAllAsync`+上/下一处+清除，独立 `browser_find_bar.dart`)/源码(`evaluateJavascript` 抓 `outerHTML` → `/browser/view-source`，独立 `browser_view_source_page.dart`)/全屏(`SystemChrome.immersiveSticky`)。全部 `dart analyze` 通过（仅 `findAllAsync/clearMatches/findNext/onFindResultReceived` 的 `deprecated_member_use` info 级提示，6.1.5 仍可用）。
- **P2 未做（菜单里给「功能开发中」占位）**：下载（`onDownloadStartRequest` + `BrowserDownloads` 表 + 列表页）、资源嗅探（JS 枚举 `<img>/<video>/<a download>`）、离线页面（`BrowserOfflinePages` 整页缓存 + 列表）。这三项菜单项已就位、点击弹 toast 提示，待单独排期实现。
- 真机未验证（P0 + P1 + P2 都只过了静态检查）：需跑一次确认 WebView 渲染、无痕隔离、DNT 注入、广告拦截实际命中、清除数据、以及新增的桌面UA/无图/页内查找/全屏/源码/下载/嗅探/离线在真机表现。注：下载/嗅探/离线**需 `dart run build_runner build -d` 已跑过**（`app_database.g.dart` 含新表）才能运行。
