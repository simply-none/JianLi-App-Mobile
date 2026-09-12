# 交互模式规范（全 App 共有交互）

> **定位**：把「同类操作在全 App 有同一心智」写成**可执行规格**。本模块管**交互骨架**
> （弹窗规格 / 入口 / 结果回传 / 反馈 / 生命周期）；`architecture.md` 的「页面操作规范」
> 管页面级细则（筛选抽屉内容、保存条位置等），`ui-modernization.md` 管动效。
>
> **规矩**：新增或修改共有交互 → **先改本模块**，再实现；改先例时同步本节。
> 先例文件是**唯一的实现基准**，别另起一套。
>
> **待办模块**：本工程把上述规范落地得最完整的功能域，其详细 UI 交互设计（列表页规范、
> 统计卡片、弹窗交互等）**全部收敛到本文件 §三**，改待办以 §三 为准；`architecture.md`
> 仅保留跨模块通用的雷区与约定。

---

## 一、弹窗（底部抽屉）规格 —— 三档制（2026-09-12 定，强制）

### 1.1 高度只有三档

| 档位 | 高度 | 用在哪 | 枚举值 |
|---|---|---|---|
| `sm` | **30%** | 确认、操作菜单、单选 —— 内容少、一眼看完 | `SheetSize.sm` |
| `md` | **50%** | 多选、日期时间、输入、按天列表 —— 需要滚动 | `SheetSize.md` |
| `lg` | **80%** | 详情、新增/编辑表单 —— 长表单 | `SheetSize.lg` |

- **禁止第四种**：新增弹窗必须挂到其中一档，**不要在调用点写裸比例**（历史债：曾出现 0.86 / 0.88 / 0.9 / 0.94 / 0.7 五种散落比例，同一模块的详情比编辑矮、键盘一弹就全乱）。
- 比例值 = `AppTokens.sheetHeightSm / Md / Lg`（`lib/app/theme/app_theme.dart`）。
- 唯一实现：`lib/app/ui/sheet_surface.dart` 的 `SheetSize` + `sheetMaxHeight()` + `sheetTitleStyle()`。

### 1.2 高度分档：lg = 全屏固定 80vh（键盘不收），sm/md = 可用高度（扣键盘）

- **lg 档（详情 / 新增 / 编辑，长表单）**：高度 = **屏幕高 × 0.8**，取自 `sheetMaxHeightFull(context, size)`，**不扣键盘**。
  键盘弹出时**覆盖在抽屉上方**，抽屉不重排、不折叠；输入框聚焦后中间滚动区把该框滚入可视区，底部按钮在键盘收起后可见。
  调用点必须配对（见 §1.7）：`mainAxisMaxRatio: AppTokens.sheetHeightLg` + `resizeToAvoidBottomInset: false`；
  内部承载件**必须定高**（`BoxConstraints.tightFor(height: maxH)` 或 `SizedBox(height:)`），**绝不能只用 `ConstrainedBox(maxHeight:)`**（那只是上界，内容少会 hug，抽屉缩到 ~30% 够不到 80%，实踩 Request 5）。
- **sm / md 档（确认 / 单选 / 多选 / 日期 / 输入）**：高度 = **（屏幕高 − 键盘高）× 档位**，取自 `sheetMaxHeight(context, size)`，**必须扣键盘**。
  **为什么必须减键盘高**（2026-09-12 实测，改前必读）：forui 的 `ShiftedSheet` 用
  `dy = max(0, H − 抽屉高 − 键盘高)` 摆放抽屉。抽屉高一旦超过「H − 键盘高」，`dy` 就被夹到 0
  **停止上移** —— 抽屉**不会**抬到键盘上方，而是被键盘从底下盖住，底部「保存 / 查询」按钮
  点不到。按可用高度算 → 抽屉永远完整落在键盘上方，且**永远到不了 100vh**。
- ⚠️ 旧结论「键盘弹起时整张抽屉抬到键盘上方」**是错的**（`mainAxisMaxRatio: null` 时期的注释），
  已在本轮修正：lg = 覆盖不重排、sm/md = 按可用高度收缩。

### 1.3 内容超出 → 中间滚动，绝不撑高

- 抽屉是**定高容器**：内容超出由中间滚动区承担（`_sheetScaffold` 用 `Expanded(SingleChildScrollView)`，
  `_sheetPanel` 用 `SingleChildScrollView` + `Column(min)`）。
- 键盘展开**不改档**：档位不变，只是按可用高度收缩，多出来的内容交给滚动。

### 1.4 弹窗标题字号规则（**其他字段禁止比标题还大**）

- 弹窗标题一律 `sheetTitleStyle(context)` = **17 / Bold**（画布 09/10 规格，绝对像素）。
- **规则：弹窗内任何字段的字号都不得大于 17**；`待办详情` 只读态的「条目标题」用 **15 / Bold**（比弹窗标题小 2 号）。**编辑态的标题/名称输入框不再用 15/Bold**，改为与「待办列表搜索栏」同源的输入框盒子（高 40 + 卡面色底 + 1px 描边 + 圆角 10 + 14px，见 §4.5）——输入框以搜索栏为唯一样式参照，详情展示与编辑输入刻意区分。
- ⚠️ **不要用裸 `context.theme.typography.body.lg` 当标题**：主题把 forui 字型整体按
  `baseFontSizeNormal`（12）缩放过，`body.lg ≈ 13.7` —— 直接当标题会比正文还小。
  这正是「待办详情的弹窗标题比待办标题【xxx】小」的成因（2026-09-12 用户实指）。

弹窗内标准字号阶梯（待办口径，其他模块照此收敛）：

| 用途 | 字号 / 字重 | 备注 |
|---|---|---|
| 弹窗标题 | 17 / Bold | `sheetTitleStyle`，**上限** |
| 条目标题（详情只读展示） | **15 / Bold** | 比弹窗标题小 2 号；编辑态输入框改走搜索栏同款盒子（h40 + 14px，见 §4.5） |
| 字段值 / 正文 | 14 / Regular（强调 w600） | |
| 字段标签 | **14 / Regular · mutedForeground** | **与字段值同大**（2026-09-12 下午定：原 13 太小、层级不明；label 与 value 必须等大） |
| 右侧提示 / 辅助文字 | **12 / Regular · mutedForeground** | 比 label 小 2 号（如「留空不提醒」），与字段同一行右端 |
| 分组小标题 | 12 / Bold · mutedForeground | |
| chip（软底 / 状态 / 优先级 / 标签） | 11 / Semi Bold | |
| 底部按钮 | 15 / Semi Bold · 高 46 · r14 | |

- **字段组（label ↔ 输入框）绑定规则（2026-09-12 下午定，强制）**：每个字段 = `Column(mainAxisSize:min, crossAxisAlignment:stretch, spacing:6)[ 标签Text(14, mutedForeground), 输入框 ]`，label 在上、输入框在下、组内间距 6。
  - 标签与字段值**同大 14**；**不要**把标签和输入框直接当作外层 `Column(spacing:12)` 的同级 children —— 外层间距会把「上一组输入框 / 下一组标签」也撑出 12px，导致 label↔field 视觉间距被放大到约 30px（实踩：用户实指「label 和字段之间隔得太远」）。用嵌套字段组 Column 隔离组内 6px 与组间 12px。
  - **右侧提示**（如「留空不提醒」）= 12、与 label 同行右端：`Row(spaceBetween)[ label(14), hint(12) ]`，比 label 小 2 号，层级明显。

### 1.5 定高 vs 上限（三个承载件的分工）

| 承载件 | 高度语义 | 用在 |
|---|---|---|
| `_sheetScaffold(size:)` | **定高**（`SizedBox(height:)`）→ 同档弹窗**必然等高** | 待办全部表单/菜单/确认类弹窗（`todo_sheets.dart`） |
| `_habitSheetPanel(size:)` | **定高**（`BoxConstraints.tightFor(height:)`）→ 同档等高 | 习惯全部弹窗（新建/详情，`habit_page.dart`；2026-09-12 Request 6 重构加入 `bottomBar`） |
| `_sheetPanel(size:)` | **上限**（`ConstrainedBox(maxHeight:)` + hug） | 画布 09/10 两屏（画布明确标注 `hug_contents`） |

- 「详情与编辑等高」这条要求**靠定高满足**：两者都挂 `lg` → 高度必然一致，与内容多少无关。
- 画布 09/10 是唯一例外（画布写死 hug），档位只当上限用；**其余弹窗一律定高，lg 内部必须 `tightFor`/`SizedBox`，绝不能用 `maxHeight` 当唯一约束**（否则 hug 内容够不到 80%，Request 5 实踩）。
- 三个承载件**都输出固定高度的「把手 + 标题 + 滚动体 + （可选）底部条」四段式骨架**，新增模块优先复用而非自绘（底部条结构见 §1.8）。

### 1.6 待办各弹窗档位对照（改档必读）

| 弹窗 | 入口函数 | 档位 |
|---|---|---|
| 状态单选 | `showTodoStatusSheet` | `sm` |
| 操作菜单（编辑/记录进展/删除） | `showTodoActionSheet` | `sm` |
| 删除等危险确认 | `showTodoConfirmSheet` | `sm` |
| 标签多选 + 新建 | `showTodoTagSheet` | **`lg`**（2026-09-12 下午由 `md`→`lg`，与新增/编辑同 80%） |
| 父任务多选 | `showTodoParentSheet` | `md` |
| 日期与时间（自绘月历） | `showTodoDateTimeSheet` | `md` |
| 记录进展 | `showRecordProgressSheet` | `md` |
| 日历「按天待办」 | `showTodoDaySheet`（`todo_calendar_view.dart`） | `md` |
| **待办详情**（只读） | `showTodoDetailSheet` | **`lg`** |
| **新增 / 编辑表单** | `showTodoEditSheet` | **`lg`**（必须与详情同档） |
| 显示风格（画布 09） | `showTodoViewModeSheet` | `lg` 上限（hug） |
| 高级搜索（画布 10） | `showTodoFilterSheet` | `lg` 上限（hug） |
| 通用查询抽屉（跨模块） | `showFilterSheet`（`lib/app/ui/filter_sheet.dart`） | `md` 定高 |

### 1.7 弹窗左右内边距 = 全局 16，只应用一次

- 底部抽屉左右内边距统一引用 `AppTokens.pagePadding`（=16），**与页面正文同一个值**（2026-09-12 由 12 收口到 16）。
- **只应用一次**：左/右 padding 要么由 `SheetSurface` 提供、要么由抽屉骨架内部提供，**二者只取其一**，不要叠加。
  ⚠️ 历史坑：曾给 `SheetSurface` 传 `padding: fromLTRB(16,16,16,16)`，骨架内部又各写 16 → 左右实际 32，比正文多一倍（实踩 2026-09-12）。
- `FHeader` 标题、各页正文横向边距也已收口到同一 16；**新增页面/弹窗横向边距严禁硬编码数字**。

### 1.8 底部按钮固定贴底（不随内容滚动）

- 弹窗底部操作按钮（保存 / 创建 / 删除 / 查询 / 重置）一律放在**中间滚动体之外**的固定位置，永随内容滚走、永远贴抽屉底部可见。
- 两种已落地的先例结构（新增弹窗照抄其一）：
  - 待办 `_sheetScaffold(size:)`：`Column[ 标题行, Expanded(SingleChildScrollView(body)), if (bottomBar) Padding(Row(bottomBar)) ]`（`todo_sheets.dart`）。
  - 习惯 `_habitSheetPanel(size:)`：`Column[ Expanded(SingleChildScrollView(children)), const SizedBox(12), if (bottomBar) bottomBar ]`（`habit_page.dart`，2026-09-12 Request 6 重构加入 `bottomBar` 形参）。
- ⚠️ **不要**把按钮当成滚动体的最后一个 child（会随内容滚出屏幕找不到）；也**不要**用「`minHeight` 撑满」方案（内容少时按钮浮在中间，实踩）。
- 底部条按钮规范：高 46、`r14`、`15/SemiBold`；主操作用 `GradientButton` 或 `FButton.primary`、危险用 `FButton.destructive`、取消用 `FButton.outline`；两个并排建议都用 `Expanded`。

### 1.9 打开弹窗不要自动聚焦输入框

- 新增/编辑表单的**标题或首个输入框不要写 `autofocus: true`**——否则一打开弹窗就弹键盘、抢焦点（键盘覆盖抽屉、用户还没准备输入，交互突兀）。
- 交还控制权：用户**主动点**输入框才弹键盘（键盘的收起已由 `app.dart` 根 `Actions` + `SheetSurface` 的 `ScrollNotification` 两处兜底，见 §四）。
- 2026-09-12 Request 6 已把 habit 名称框、todo 标题框、todo 进展框的 `autofocus: true` 全部移除；grep 确认 `habit` + `todo` 目录已无残留。**新增弹窗默认不写 `autofocus`**。

---

## 二、共有交互模式目录

| 模式 | 规范要点 | 代码入口 / 先例 |
|---|---|---|
| **底部抽屉（承载）** | 一律 `showFSheet(side: FLayout.btt)` + `SheetSurface` 包底（forui 不画 surface，直接给 Padding 会露灰色 barrier）；居中弹窗全 App 禁止（见 SKILL.md 红线 #10） | `lib/app/ui/sheet_surface.dart` |
| **弹窗高度 / 标题** | 三档制 + 17/Bold 上限 | 本模块 §一 |
| **危险确认** | 也走底部抽屉（不是居中弹窗）；泛型 + `Navigator.pop(c, true/false)` 回传 | `showTodoConfirmSheet` |
| **查询 / 筛选** | 条件收进「查询抽屉」：标题「查询」+ 关裸图标；中部选项滚动；底部「重置 / 查询」**恒贴底**（定高 + `Expanded`，minHeight 方案会让按钮随内容浮起，实踩） | `lib/app/ui/filter_sheet.dart`（`md`）；待办另有 `showTodoFilterSheet`（画布 10） |
| **条目单击 = 查看详情** | 单击先出**只读详情**，要改再点详情的「编辑」；多入口**共用同一函数**，避免「某处点开是编辑」的漂移 | `openTodoDetail` + `showTodoDetailSheet` |
| **详情出口动作回传** | 用 `枚举 + 目标条目` 回传（`TodoDetailResult(action, item)`），抽屉自己不直接开表单；带 item 是为了支持父任务**层层下钻**后动作逐层上抛 | `TodoDetailResult` |
| **新增 / 编辑保存** | 底部固定操作条（`GradientButton`），不随内容滚动；编辑态头部不放重复保存入口 | `note_editor_page.dart` |
| **表单输入框** | ① 抽屉内原生 `TextField` 必须有 `Material` 祖先 —— 统一由 `SheetSurface` 提供；`FScaffold` 与 forui Sheet **都不提供**；② **常态必须可见描边、聚焦高亮主题色**（不写 `border:` 即继承主题 `inputDecorationTheme`，**严禁 `InputBorder.none` 抹掉描边**）；③ **点空白 / 滚动失焦收键盘**（根 `Actions` 覆盖 `EditableTextTapOutsideIntent` + `SheetSurface` 的 `ScrollNotification` 兜底，无需各自写 `onTapOutside`）；④ 多行 `maxLines: null` 随内容增长 | `sheet_surface.dart` 注释 / `app.dart` / `interaction-patterns.md` §五 |
| **controller 生命周期** | controller 归**持有它的 State**，**绝不**在 `await 抽屉 Future` 之后 dispose（会断言 `_dependents.isEmpty` 整屏红） | `architecture.md` 雷区 #14 + `_ControllerHost` |
| **列表滚动吸顶** | 锚点 = **搜索行**（搜索框常驻视口顶部），**不是** Tab 栏；条件 chip / Tab 栏都随滚动移出 | `todo_page.dart` 的 `_PinnedHeader`；本模块 §3.5 / §3.17 |
| **反馈（toast）** | 统一 `showFToast`（`FToaster` 已在根组件挂全局） | `showRecordProgressSheet` |

---

## 三、待办模块 UI 交互规范（详细设计参考 / 改造基线）

> 待办是「共有交互规范」落地得最完整的功能域，新增模块建议**照它抄骨架**。
> 以下列表页规范、统计卡片、弹窗交互均按画布 07/08/09/10 逐像素实现；
> 数据层契约（双端列名 / 同步白名单）见 `sync.md`。
> 弹窗三档制 / 标题字号 / 键盘扣减见 §一；输入框规范见 §五；本节点到为止是其**待办先例与落地细节**。

### 3.1 文件地图

| 文件 | 职责 |
|---|---|
| `lib/features/todo/components/todo_page.dart` | 列表/卡片/日历三视图页：头部、`PageBanner` 统计横幅、搜索行（吸顶）、生效条件 chip、Tab 栏、列表、空态、`_PinnedHeader` 吸顶 delegate |
| `lib/features/todo/components/todo_tile.dart` | `TodoListTile` 列表卡片 |
| `lib/features/todo/components/todo_sheets.dart` | 全部底部抽屉（新增/编辑/详情/状态/标签/父任务/日期/记录进展/显示风格/高级搜索/操作菜单/删除确认） |
| `lib/app/ui/page_banner.dart` | `PageBanner` 渐变横幅原子（待办统计横幅用它） |
| `lib/app/theme/card_textures.dart` | 纹理资源 + 合成不透明度（`CardTextures.texture11`） |

入口函数：`openTodoDetail`（列表卡片 / 卡片视图 / 日历当天抽屉三处**共用**，保证单击行为一致）。

### 3.2 列表页总览（画布 07/08）

```
头部（‹ 返回 / 「待办」/ ⚙ 设置 / + 新增）      ← FHeader，固定不参与滚动
统计横幅（PageBanner + 4 个统计数）             ← 随滚动移出
搜索行（页内搜索框 h40 + 筛选按钮）              ← ★ 吸顶锚点，常驻视口顶部
生效条件 chip（可点掉的摘要，如「条件-搜索」）    ← 随滚动移出
Tab 栏（h34 分段）：进行中（默认）/ 已完成 / 已取消 / 全部 ← 随滚动移出（是状态范围，不是筛选）
列表区（按「今天 / 明天 / 更晚」分组标题 + 卡片）  ← 从搜索行下方滚过
```

- **搜索留在页内**（实时过滤），**筛选条件收进高级搜索抽屉**（画布 10）——两者职责不要混。
- 状态范围由 Tab 承担，**高级搜索抽屉里不再重复提供状态**。
- 三种视图：列表 = `CustomScrollView`（搜索吸顶）；卡片 / 日历 = `Column` 固定头（已知不一致，见 §3.17）。
- **列表边距（防双重 padding，实踩 Request J/1）**：列表 `ListView`/`CustomScrollView` 的 padding 用 `EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pageBottomGapOf)`——**top 必须 0**（让统计横幅贴着 header 下方），底部用 `pageBottomGapOf`（防最后一条贴底白边），左右 `pagePadding`。配套 `PageBanner` 的 `margin` 必须用 `EdgeInsets.zero`：横幅自带 16 + 列表又套 16 → **双重 16 把横幅挤窄、与正文不对齐**。统一只在列表层给左右/底部 padding，横幅 margin 归零。

### 3.3 头部（Header）

- 用 `FHeader`（不是 AppBar）。标题「待办」`18/Bold`；`prefixes` = ‹`chevronLeft` 22（返回）；`suffixes` = ⚙`settings` 18（设置）+ ＋`plus` 22（新增）。
- 选择模式替代：✕（关闭选择）+「已选 N 项」+ `trash` 图标。
- 头部固定，不参与滚动（在 `CustomScrollView` 之外）。
- 头部 padding `fromLTRB(16,12,16,12)`，元素间距 10。

### 3.4 统计卡片（PageBanner 渐变横幅 + 统计数）

- 元素：`PageBanner(icon: check, title:'待办', subtitle:'专注当下，一件一件来', gradient: AppTokens.primaryGradient, cornerRadius:22, textureAsset: CardTextures.texture11, ringDecor:true, shadow:false, margin: EdgeInsets(16,0,16,0), stats:[全部/进行中/已完成/已取消])`。
- 样式：主色渐变背景 + 纹理叠加 + 同心环装饰（`ringDecor`）。
- **背景纹理**：`CardTextures.texture11 = 'assets/images/textures/lemoonboots-texture-2351354_1920.jpg'`；合成不透明度 `composedOpacity = 0.196`（= `fillOpacity 0.56 × nodeOpacity 0.35`）。纹理以 600×600 贴在 `(-100,-100)`，节点 opacity `0.35`，再叠整层 `0.56`。
- 统计数（`AnimatedStat`）：数值 `20/Bold` 白色，标签白色 `0.75`。
- 图标盘 `SquircleBox` 44/14 白 `0.22` + 白 icon 22；标题 `body.lg` 白 w800；副标题白 `0.78`；内边距全 18。
- 4 个统计：全部 / 进行中 / 已完成 / 已取消（字面量与 PC 对齐）。横幅随滚动移出（不是吸顶元素）。

### 3.5 搜索行（吸顶锚点）

- 高度常量：`_kSearchBoxHeight=40`、`_kSearchRowTopGap=12`、`_kSearchRowBottomGap=8`、`_kSearchRowExtent` = 三者之和（吸顶锚点高度，**与子节点同源推导**，勿两处各写一套数值）。
- 外观：白 `card` 底，描边（`border`），`r10`，高 40。内部 `Material(transparency)` + `TextField`（`InputBorder.none`，fontSize 14，实时过滤）+ 右侧 28×28 `listFilter` 按钮（`muted` 底，r8，激活时主题强调色软底 + 生效条件数角标）。
- **吸顶行为**：整行 `SliverPersistentHeader(pinned:true)` 包 `_PinnedHeader` delegate。吸顶后底色用 `AppTokens.pinnedCover(context, extent)`（背板同源渐变），**仅当 `shrinkOffset > 0` 才铺**，静止时完全透明透出页面渐变背板。
  - ⚠️ 判断吸顶覆盖**不能**用 delegate 的 `overlapsContent`（pinned 头恒 false，且 `SliverPersistentHeader` widget 无此命名参数，传了编译报错 `undefined_named_parameter`）。正确信号 `shrinkOffset > 0`。详见 §3.17 踩坑表。
- 搜索框必须常驻：滚动中随时改关键词。

### 3.6 生效条件 chip（已生效筛选摘要）

- 在搜索框下方，可点掉的摘要 chip，如「条件-搜索」「条件-优先级」。
- 布局 `Wrap` spacing 6，padding `16/0/16/8`；chip `r10`，padding 6，`11/SemiBold`，底色 = 色 `12%` + 删除 ×。
- 包含：搜索 / 优先级 / 标签 / 到期 / 仅未完成 / 含模板 +「清除全部」（destructive 红）。随滚动移出（不是吸顶）。

### 3.7 Tab 栏（状态范围）

- padding `16/4/4`，底 `muted`，`r11`，总高 34，内部 padding 3，spacing 3，`crossAxisAlignment.stretch`（选中白底要填满内轨 —— `fill_container` 不会自动发生，见 §3.17）。
- Tabs = 进行中（默认）/ 已完成 / 已取消 / 全部（`kTodoScopeTabs`）。
- 这是**状态范围**，不是筛选；高级搜索抽屉不重复提供状态。随滚动移出（**不吸顶** —— 用户明确纠正旧实现「Tab 吸顶」）。

### 3.8 列表项（TodoListTile）

- 卡片：底 `card`，边框，圆角 `radiusMd`=16，padding 14。`Row`：checkbox 20×20 `r6`（完成→主色填充 + 白 check size13；未完成→透明 + border 1.5）· 内容 · ⋯ `ellipsis` size16。
- 内容 3 行：
  1. 标题 `15/SemiBold` maxLines2，完成划线；+ `_StatusChip`（色底 15% `r10` pad4 `11/SemiBold`）+ 优先级文字 `11/SemiBold`（`priorityColor`）。
  2. tag `Wrap`（`_TagChip` 色底 14% `r10` pad4 `11/SemiBold`）若有标签。
  3. dueText `11/muted` ⇄「子任务 d/t」`11/muted` 若任一有。
- `indent` → `cornerDownRight` size14 在标题前（子任务层级标识）。
- 点击 → `openTodoDetail`（只读详情）；⋯ → `showTodoActionSheet`。
- 列表分组标题 `12/Bold` mutedForeground（若 `groupBy != none`）；卡片 gap 10；`ListView` padding `fromLTRB(pagePadding, 0, pagePadding, pageBottomGapOf)`（`top=0` 让横幅贴 header；底部 `pageBottomGapOf`；左右 `pagePadding`，**禁止再给横幅叠 16**）。

### 3.9 分组标题与空态

- 分组标题（按 `groupBy`）：`12/Bold` mutedForeground。
- 空态 `_emptyState`：76Ø `primary.12` 圆盘 + `list` icon 32，标题 `16/Bold`，副标题 `13/muted`。

### 3.10 页面背景与装饰

- 页面背景 = 主题 `background`（已叠冷调，跟随亮暗 / 主题样式）。
- 主视觉装饰来自统计横幅（渐变 + 纹理 + 同心环）；吸顶后 `pinnedCover` 也是背板同源渐变（与背景协调，不是纯色挡板）。
- ⚠️ 别刷纯色 `colors.background` 做吸顶底（静止时灰白挡板切断背景）；别用 `pageTint`（透明，透出内容）。

### 3.11 三种视图（显示风格，切换即生效）

| 视图 | 说明 | 持久化 |
|---|---|---|
| 列表（默认） | 紧凑三行，信息密度最高；`CustomScrollView`（搜索吸顶） | `todo.viewMode`（本地） |
| 卡片 | 卡片网格，视觉优先；`Column` 固定头 | 同上 |
| 日历 | 按月历看到期分布；点日期开「按天待办」抽屉 | 同上 |

- 显示风格切换弹窗 `showTodoViewModeSheet`（画布 09，`lg` 上限 hug）：三选项（列表/卡片/日历）。
  选中 = 主色 12% 底 + 35% 描边 + 16% 图标盘 + 主色图标/状态符；未选中 = `#F6F7F9` 底 + `#E5E7EB` 图标盘 + `#6B7280` 图标。
  - ⚠️ 标题文字两态都是 `#1C1C1E`（不染主色）；未选中图标盘用 `_stepUp` 压深一档（比行底 `#F6F7F9` 深一档才看得见）。
  - 点击立即返回并关闭（「切换后立即生效」）。

### 3.12 弹窗交互总览（档位 + 承载件）

- 三档制与待办各弹窗档位对照见 §一 §1.6。
- 两个承载件：
  - `_sheetScaffold(size:)` —— **定高**（`SizedBox(height:)` → 同档弹窗必然等高）。待办全部表单 / 菜单 / 确认类弹窗。
  - `_sheetPanel(size:)` —— **上限**（`ConstrainedBox(maxHeight:)` + hug）。画布 09/10（标注 `hug_contents`）。
- 标题 `sheetTitleStyle` = **17/Bold**；**字段禁止 > 17**；条目标题 **15/Bold**（详情与编辑必须一致）。
  - 公共件：`_sheetHandle`（把手 36×4 `#D9DDE4` r2 **居中**，走 `_stepUp`）· `_groupLabel`（12/Bold muted）· `_pill`（h30 r999 左右12 13，用 `Row(mainAxisSize:min)` 勿 `Container(alignment)`）· `_sheetButton`（h46 r14 15/SemiBold）· `_choiceChip`（pad 14/8，选中色 14% + 描边 + check14）· `_softChip`（色底 alpha `r10` 11/SemiBold）· `_detailRow`（图标 + 62 宽标签 + 值）· `_CanvasSwitch`（44×26 r13 自绘开关，不用 forui `FSwitch`）· `_stepUp`（抬升面再压一档灰，解决同色陷阱）。
  - **顶部把手必须居中**（2026-09-12 下午定，强制）：`_sheetHandle` 内 `Align(alignment: Alignment.center)`，**不要** `centerLeft`。所有弹窗（待办 `_sheetScaffold` / 习惯 `_habitSheetPanel` / 画布 09/10）共用同一个居中把手 —— 三处 `_sheetHandle` 实现必须一致。
  - **右上角关闭按钮不要背景色块**（2026-09-12 下午定，强制）：裸 `SizedBox(32,32, child: Icon(FLucideIcons.x, size:18, color: mutedForeground))`，**不要** `Container(装饰背景 + 圆角)` 包图标。与「居中把手 + 左标题」组成「把手 / 标题 / 关闭」三段式头部。

### 3.13 新增 / 编辑表单弹窗（showTodoEditSheet / _TodoEditSheet，`lg` 定高）

- 标题：`createTime == null ? '新增待办' : '编辑待办'`。
- 字段组（每个字段 = label(14, mutedForeground) 在上 + 输入框在下、组内间距 6，详见 §1.4 / §4.5）：标题输入（原生 `TextField`，**不写 `autofocus`**（打开不抢焦点，见 §1.9）；走 §4.5 的 search-bar 风格盒子——外层 `Container(h40·r10·1px描边·卡色底)` + 内层 `TextField(InputBorder.none, 14px)`，不再用 15/Bold）· 描述（`FTextField` `minLines:2, maxLines:null` 随内容增长；同样 search-bar 盒子、多行去定高）· 优先级（choiceChip 横排）· 状态（choiceChip 横排）· 到期时间（行 → 触发 `showTodoDateTimeSheet`）· 截止提醒（`FSwitch` + 提示）· 重复（`FSwitch` + daily/weekly + 间隔 + 周几 + 结束日期，仅非周期实例可编辑 `allowRecurrence`）· 父任务（行 → `showTodoParentSheet`，chip 展示）· 标签（行 → `showTodoTagSheet`，`lg`）。
- 底部固定条：`GradientButton`「保存」(`check`)，不随内容滚动（定高 + 中间滚动区）。
- 保存校验：标题非空，否则 `showFToast` destructive「标题不能为空」。返回 `TodoItem`（取消 null）。
- controller 全部由 `_TodoEditSheetState.dispose()` 释放（**绝不在 await 抽屉 Future 后 dispose**）。

### 3.14 查看详情弹窗（showTodoDetailSheet，`lg` 定高）+ 下钻

- 只读，标题「待办详情」。
- 字段（对齐 PC 只读态）：标题（15/Bold，完成划线 + 灰）· 状态 / 优先级 / 重复标记 chip · `描述` · 分隔线 · 到期时间 / 截止提醒 / 重复 / 关联父任务（可点进父任务详情 chip）/ 标签 / 子任务进度 / 创建时间 / 完成时间（每行 `_detailRow`：图标 + 62 标签 + 值，值可文本可 chip 组）。
- 底部两条：`记录进展`（muted 底）+ `编辑`（`GradientButton`，`pencil`）。
- 出口 `TodoDetailResult(action, item)`：`edit` → `openTodoDetail` 内调 `showTodoEditSheet` → upsert；`record` → `showRecordProgressSheet`。
- **下钻**：详情点父任务 chip → `_parentChip` 再开一层 `showTodoDetailSheet`，里层动作逐层上抛（带 item 是为了编辑里层那条）。三入口共用 `openTodoDetail`，避免「某处点开是查看、某处是编辑」的漂移。

### 3.15 各类选择 / 操作弹窗

| 弹窗 | 入口函数 | 档位 | 要点 |
|---|---|---|---|
| 状态单选 | `showTodoStatusSheet` | `sm` | `kTodoStatusOptions` Wrap chip，点即 pop |
| 标签多选 + 新建 | `showTodoTagSheet` | **`lg`** | 新建输入框 = search-bar 风格 `Container(h40·r10·1px描边·卡色底)` + 原生 `TextField`(14) + plus 图标（`FTappable`）；底部 `GradientButton`「完成」pop 草稿 |
| 父任务多选 | `showTodoParentSheet` | `md` | 排除自身 + `_descendantKeys`，按 sortOrder 排 |
| 日期与时间 | `showTodoDateTimeSheet` | `md` | 自绘月历 `GridView.count(7)` + 上/下月 + 星期标签 + 时/分 stepper（`FTextFieldControl.managed` 模式）；`dateOnly` 隐藏时间；`清除` 置 null |
| 记录进展 | `showRecordProgressSheet` | `md` | 主题标题 + 说明 + `FTextField`(minLines3 maxLines6 autofocus)；保存到主题对话（`findOrCreateThemeByTitle` + `addMessage`）；空内容 toast 报错 |
| 显示风格 | `showTodoViewModeSheet` | `lg` 上限 hug | 画布 09，见 §3.11 |
| 高级搜索 | `showTodoFilterSheet` | `lg` 上限 hug | 画布 10：分组 优先级/标签/到期时间/其他(含已完成/重复模板)/分组方式 + 关键词框；状态不重复；`_ControllerHost` 持有 controller；重置/查看结果贴底 |
| 操作菜单 | `showTodoActionSheet` | `sm` | 编辑 / 记录进展 / 删除（`_actionRow`，删除 destructive 红）；删除 → `showTodoConfirmSheet` |
| 删除确认 | `showTodoConfirmSheet` | `sm` | 标题 + 消息 + 取消(`FButton.outline`)/删除(`FButton.destructive`)，返回 bool |
| 按天待办 | `showTodoDaySheet` | `md` | `todo_calendar_view.dart`，日历点日期开 |

### 3.16 与 PC 的**有意差异**（别「对齐 PC」改回去）

| 项 | PC 桌面端 | 移动端 | 原因 |
|---|---|---|---|
| 列表单击 | **直接进编辑表单**（`TodoDetailDialog` 的 readOnly 只用于看父任务） | **先看只读详情** | 避免移动端误触即改（2026-09-12 用户定） |

详情字段口径仍以 PC 只读态为准（见 §3.14）。

### 3.17 改造待办必看的雷区（合并自 `architecture.md` + 本轮）

| 雷区 | 现象 / 正确做法 |
|---|---|
| **吸顶锚点选搜索框** | `overlapsContent` 是陷阱（pinned 头恒 false，且 widget 无此命名参数，传了编译报错 `undefined_named_parameter`）；正确信号 `shrinkOffset > 0`。静止不铺、滚动才铺 `pinnedCover`。详见 §3.5 |
| **Material 祖先**（`architecture.md` #10） | 页面主体包 `Material(transparency)`；抽屉走 `SheetSurface`（已提供）。自绘容器里的原生 `TextField`/`Chip`/`Switch` 必须显式补 Material，否则 `debugCheckHasMaterial` 崩 |
| **`fill_container` 不会自动发生**（#11） | `Row`/`Column` 默认 `crossAxisAlignment:center`，子项只 hug。Tab 药丸选中白底要显式 `CrossAxisAlignment.stretch` |
| **`Container(alignment)` 撑满毁 hug**（#12） | chip/pill 用 `Row(mainAxisSize:min)` 当 child；只给一种约束 + `alignment` 会被 `Align` 在有界松约束下撑满整行（高级搜索弹层 chip 全竖排即此因） |
| **同色陷阱**（#13） | `muted`==`border`==`surfaceElevated` → 描边/把手/图标盘要用 `_stepUp` 压深一档，别硬编码画布 hex |
| **controller 生命周期**（#14） | controller 生死只跟「持有它的 State」绑定，绝不在 `await` 抽屉 Future 后 `dispose`（`_ControllerHost` 先例；错误写法点「取消」整屏红 `'_dependents.isEmpty'`） |
| **输入框**（#15） | 常态描边（不写 `border:`）+ 点空白/滚动失焦收键盘（`app.dart` + `sheet_surface` 两处兜底）+ 多行 `maxLines:null minLines:N` 随内容增长 |
| **已知不一致** | 卡片/日历视图是 `Column` 固定头（搜索/条件/Tab 全固定），与列表页「只有搜索行吸顶」不同形；彻底统一需改 sliver，改动面大，**未拍板前保持现状** |

---

## 四、输入框交互规范（2026-09-12 定，全 App 适用）

> 覆盖用户四连需求之二/三：输入框必须显示边框、聚焦高亮主题色、点空白/滚动失焦收键盘、描述随内容增长。

### 4.1 常态可见描边 + 聚焦高亮主题色

- 描边来源：`FThemeData.toApproximateMaterialTheme()` 会用 `textFieldStyles`（`fieldColors` 已把 `border` 调亮为 `AppTokens.inputBorderColor`）生成 Material 的 `InputDecorationTheme`，**自带「常态描边 + focused 主题色描边」两套变体**。
- **结论：原生 `TextField` 只要「不写 `border:`」就自动拿到全 App 一致的描边与聚焦高亮**——不要画蛇添足写 `decoration: InputDecoration(border: InputBorder.none)`，**那会把主题描边整个抹掉**（实踩：新增待办标题框「看不到边框」即此因）。forui `FTextField` 同理继承主题描边。
- 唯一例外：搜索框嵌在**已经带描边的容器**里（如 `todo_sheets.dart` 标签搜索：外层 `Container(border: Border.all(...))` 已提供视觉边框），内层 `TextField` 才允许 `InputBorder.none`——此时边框是容器给的，不是输入框自己。

### 4.2 点空白 / 滚动 → 失焦收键盘（移动端必须显式处理）

- **根因（关键坑）**：Flutter 默认的 `_EditableTextTapOutsideAction`（`editable_text.dart` ~L6876）**只在 desktop 平台解焦**；`switch (defaultTargetPlatform)` 里 `android/iOS/fuchsia` 的 `touch` 事件**不解焦**（除非 `kIsWeb`）。所以「点输入框外收键盘」在移动端默认**不生效**，必须自己兜底。
- **`EditableTextTapOutsideIntent` 是官方扩展点**：它被 `Actions.overridable` 注册（`editable_text.dart` ~L5811），祖先 `Actions` 可覆盖默认行为。本工程**单一收口**：
  1. `lib/app/app.dart` 根组件用 `Actions` 覆盖 `EditableTextTapOutsideIntent`（`CallbackAction` 直接 `intent.focusNode.unfocus()`）——覆盖全 App 所有输入框（原生 `TextField` 与 forui `FTextField` 都走 `EditableText` → 该 intent），点任意输入框外即收键盘。
  2. `lib/app/ui/sheet_surface.dart` 另加 `NotificationListener<ScrollNotification>`：抽屉内任意滚动开始（`ScrollStartNotification`）即 `FocusManager.instance.primaryFocus?.unfocus()`——兜底**惯性滚动**（没有 pointer-down，走不到 tap-outside 那条路径）。
- ⚠️ **新增输入框无需各自写 `onTapOutside`**，统一由上述两处兜底；若某输入框需不同行为再单独覆盖。别回到「每个输入框手写 onTapOutside」的散落写法。

### 4.3 多行输入容器随内容增长

- forui `FTextField`：`maxLines` 只限制**同时可见**行数、不限制可输入行数。**给 `maxLines: null` + `minLines: N`** → 初始高 N 行，每多一行容器就长高一行，超出抽屉档位由 `_sheetScaffold` 中间滚动区（`Expanded(SingleChildScrollView)`）承担，不会把抽屉撑破。
- 新增「描述 / 备注 / 详情」类多行输入照此写，**不要写死固定行高**。先例：`todo_sheets.dart` 新增/编辑待办的描述框 `FTextField(maxLines: null, minLines: 2)`。
- 原生 `TextField` 等价写法：`maxLines: null`（同时 `minLines` 控制初始高）。

### 4.4 关联

- 弹窗边距（= 全局 16）：本模块 §1.7。
- 抽屉高度/标题/键盘扣减：本模块 §一。
- 红线汇总：`SKILL.md` #14；实战坑：`architecture.md` 坑位 #15。

### 4.5 新增/编辑表单输入框样式 = 待办列表搜索栏（高度/样式一致，2026-09-12 续）

- **盒子的唯一正确写法**（三处先例同源：`todo_page._searchRow` / `todo_sheets._TodoEditSheet` 标题+描述 / `habit_page._showCreateSheet` 名称）：
  ```dart
  Container(
    height: 40,                                // 单行固定高；多行（如描述）去掉 height + 改 padding: symmetric(h:12, v:12)
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: t.colors.card,                    // 卡面色底（比页面 background 亮一档）
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: t.colors.border),
    ),
    // 单行：Row 默认 crossAxisAlignment=center（与搜索栏 _searchRow 同款），Expanded 撑宽；
    // 固定高 40 下约 20px 高的 TextField 被居中，文字自然垂直居中。
    // ⚠️ 不要写 crossAxisAlignment: stretch —— 单行无必要，多行会直接崩溃（见下）。
    child: Row(
      children: [
        Expanded(
          child: Material(                     // 原生 TextField 需要 Material 祖先
            type: MaterialType.transparency,
            child: TextField(
              controller: ...,
              style: t.typography.body.sm.copyWith(fontSize: 14, color: t.colors.foreground),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,      // 边框由外层 Container 提供，内部必须 none 否则双重描边
                hintText: ...,
                hintStyle: t.typography.body.sm.copyWith(fontSize: 14, color: t.colors.mutedForeground),
              ),
            ),
          ),
        ),
      ],
    ),
  )
  ```
- **规则**：① 高度 40（单行）/ 随内容增长（多行）；② 卡面色 + 1px `border` + 圆角 10 + 左右 12；③ 内部原生 `TextField` 用 `InputBorder.none`，**绝不再用主题 `inputDecorationTheme` 自带的描边**（否则和盒子描边双重、且来源与搜索栏不一致）；④ 字号 14（与搜索栏一致）。编辑标题/名称输入框不再用 15/Bold（旧 §1.4 的「编辑标题输入框 15/Bold」让位于本规则——输入框以搜索栏为唯一参照）。
- ⚠️ **单行输入框文字垂直居中（关键，照搬搜索栏）**：固定高 `Container` 直接放 `Material(TextField)` 会让 TextField 按自身内容高、文字**贴顶**不对齐（Container child 默认 top-start）。修法是包一层 `Row`（`Expanded` 撑宽、默认 `center` 对齐）——和待办列表搜索栏 `_searchRow` 完全一致的写法，三处先例（`_searchRow` / `_TodoEditSheet` 标题 / `_showCreateSheet` 名称）已统一。**不要**用 `crossAxisAlignment: CrossAxisAlignment.stretch`：单行虽不崩但无必要，多行会崩。
- ⚠️ **多行输入框（描述/备注）绝对禁止套 Row/Expanded**：必须直接 `Container(padding: symmetric(h:12, v:12)) → Material(TextField(maxLines:null, minLines:2))`。一旦套 `Row(stretch)+Expanded` 且外层 `Container` **无定高**，会形成「Row 高度取决于子项、子项又被 stretch 撑到 Row 高度」的约束死循环 → `RenderBox was not laid out` / `Cannot hit test a render box with no size`（2026-09-12 实踩崩溃，已回退）。
- ⚠️ **不要**为了「输入框」去用 forui `FTextField` 再包 Container（双重盒子）；也不要裸写 `TextField(decoration: InputBorder.none)` 不加外层 Container（那会没边框、和搜索栏不一致）。先例：单行用「Container + Row(默认center) + Expanded + Material + 原生 TextField」，多行用「Container + Material + 原生 TextField」。
