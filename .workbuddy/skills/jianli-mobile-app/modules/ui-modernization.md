# 模块：UI 现代化与动效

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

