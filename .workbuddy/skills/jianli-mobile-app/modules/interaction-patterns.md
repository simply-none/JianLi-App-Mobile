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
| `md` | **50%** | 多选、日期时间、按天列表 —— 需要滚动（**不含输入框**） | `SheetSize.md` |
| `lg` | **80%** | 详情、新增/编辑表单、**一切含输入框的弹窗（2026-09-13 定案）** | `SheetSize.lg` |

- **禁止第四种**：新增弹窗必须挂到其中一档，**不要在调用点写裸比例**（历史债：曾出现 0.86 / 0.88 / 0.9 / 0.94 / 0.7 五种散落比例，同一模块的详情比编辑矮、键盘一弹就全乱）。
- 比例值 = `AppTokens.sheetHeightSm / Md / Lg`（`lib/app/theme/app_theme.dart`）。
- 唯一实现：`lib/app/ui/sheet_surface.dart` 的 `SheetSize` + `sheetMaxHeight()` + `sheetTitleStyle()`。

### 1.2 高度分档：lg = 全屏固定 80vh（键盘不收），sm/md = 可用高度（扣键盘）

- **lg 档（详情 / 新增 / 编辑，长表单；⚠️ 2026-09-13 定案：判定标准 = **内含输入框**，
  只要抽屉里有 TextField / FTextField / SheetInputBox / SheetMultilineBox 就必须 lg**）**：高度 = **屏幕高 × 0.8**，取自 `sheetMaxHeightFull(context, size)`，**不扣键盘**。
  键盘弹出时**覆盖在抽屉上方**，抽屉不重排、不折叠；输入框聚焦后中间滚动区把该框滚入可视区，底部按钮在键盘收起后可见。
  调用点必须配对（见 §1.7）：`mainAxisMaxRatio: AppTokens.sheetHeightLg` + `resizeToAvoidBottomInset: false`；
  内部承载件**必须定高**（`BoxConstraints.tightFor(height: maxH)` 或 `SizedBox(height:)`），**绝不能只用 `ConstrainedBox(maxHeight:)`**（那只是上界，内容少会 hug，抽屉缩到 ~30% 够不到 80%，实踩 Request 5）。
- **sm / md 档（确认 / 单选 / 多选 / 日期（**不含输入框**））**：高度 = **（屏幕高 − 键盘高）× 档位**，取自 `sheetMaxHeight(context, size)`，**必须扣键盘**。
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

- **字段组（label ↔ 输入框）绑定规则（2026-09-12 下午定；2026-09-13 澄清间距唯一来源，强制）**：每个字段 = `Column(mainAxisSize:min, crossAxisAlignment:stretch, children:[ SheetFieldLabel(14, mutedForeground), 输入框 ])`，label 在上、输入框在下。⚠️ **组内间距 6px 的唯一来源 = `SheetFieldLabel` 自带的 `bottom:6`——字段组 Column 禁止再写 `spacing:`**（写了就叠成 12px；若 label 是平铺在外层 spacing 列表里，则叠出 14~20px。2026-09-13 用户实指「label 和表单值间距过大」后全库收口）。倒计时/提醒/番茄钟表单是正确先例：label 与输入框相邻、组间 `SizedBox(height:16)`。
  - 标签与字段值**同大 14**；**不要**把标签和输入框直接当作外层 `Column(spacing:12/14)` 的同级 children —— 外层间距会把「上一组输入框 / 下一组标签」也撑出来，导致 label↔field 视觉间距被放大（两次实踩：2026-09-12「label 和字段隔得太远」、2026-09-13「label 和表单值间距过大」）。字段组必须嵌套 Column 隔离组内 6px 与组间 16px。
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
- 🔴 **【键盘弹起时底部条必须抬起，否则「按钮点了没反应」】（2026-09-18 习惯编辑页实踩）**：lg 抽屉按 §一 走 `sheetMaxHeightFull`（固定 80vh、**不扣键盘**）+ 调用点 `resizeToAvoidBottomInset: false` ⇒ 软键盘是从屏幕底部**覆盖**抽屉的。按钮死贴抽屉底部时会被键盘**完全遮住**，用户在输入框打完字直接点保存，实际点到的是键盘区域 —— 观感就是「保存按钮没效果、弹窗也不关」，且**只在键盘弹起时复现**（不动输入框就正常），极难自查。**修法：给 bottomBar 包一层 `Padding(bottom: MediaQuery.of(context).viewInsets.bottom)`**（只抬按钮，抽屉高度与滚动区不变，不违反「lg 不扣键盘」红线）。`_habitSheetPanel` 已内置，新增自绘面板照抄。
- 🔴 **【主操作按钮必须能表达「进行中」且防连点】**：保存/创建类动作一律 `await` + `try/catch` + `saving` 禁用态（`onTap: saving ? null : ...`，按钮文案切「保存中…」）。**禁止 fire-and-forget 后立刻 `Navigator.pop`** —— 写库失败时用户看到的是「弹窗关了但没更新」，异常还变成未处理的异步错误。
- 🔴 **【校验失败绝不能静默 return】**：`if (name.isEmpty) return;` 这种写法让用户点了毫无反馈，被当成「按钮没效果」。**必填项为空要 `showFToast` 明确提示**。

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
| **列表卡片的破坏性动作** | **卡片行尾不放删除按钮**（2026-09-13 用户定，习惯卡首发）：删除统一收进**只读详情底栏**（`_sheetButton(label:'删除习惯', bg: destructive)`）。理由：卡右侧只留「主动作」（打卡圈 / ⋯），避免误触删除；新增列表页照此办，勿再往卡里塞 trash 图标 | `habit_page.dart` `_HabitCard` / `_showDetailSheet` |
| **详情出口动作回传** | 用 `枚举 + 目标条目` 回传（`TodoDetailResult(action, item)`），抽屉自己不直接开表单；带 item 是为了支持父任务**层层下钻**后动作逐层上抛 | `TodoDetailResult` |
| **新增 / 编辑保存** | 底部固定操作条（`GradientButton`），不随内容滚动；编辑态头部不放重复保存入口 | `note_editor_page.dart` |
| **同一动作不在页面上出现两个入口** | **元信息 / 摘要类 chip 行只做「展示」，入口统一收在一处**（2026-09-18 用户定，笔记编辑页首发）：顶行原本既有已选分类/标签、又塞「＋分类」「＋标签」入口，与底部条「分类 n」「标签 n」功能重复 → 顶行**只显示已选项**（点击已选 chip 仍可开抽屉增删），添加入口收敛到底部条。⚠️ **配套要求：纯展示行在「一个都没选」时必须整行 + 上下间距一起不渲染**（用 `if (hasX) ...[...]` 连 `SizedBox` 一起包），否则新建态会留下几十像素死区、还压掉内容高度 | `note_editor_page.dart` 的 `_metaRow(selectedTags)` + `hasMeta` |
| **页面底部固定条（机制）** | 一律用 **`FScaffold.footer:`**，**不要**自己拼 `Column + Expanded + 底部条`——forui 会自动把它排在 body 之下（body 高度自动扣减，内容不会滚到条下面）并按 `viewInsets` 避让键盘，且自带 `footerDecoration`（**默认仅一条顶部描边、无背景**，透明底透出页面背板，与 App「渐变背板」架构一致）。⚠️ **footer 内容必须自带 `SafeArea(top: false)`**：footer **不被 `childPad` 包裹**，forui 也**不会**自动避让系统导航栏（只避让键盘）。⚠️ **`child:` 必须写在构造参数最后**，否则报 info `sort_child_properties_last`（本项目 analyze 要求零 issue） | `main_shell.dart`（悬浮胶囊底栏）、`book_notes_page.dart`（导出条） |
| **表单输入框** | ① 抽屉内原生 `TextField` 必须有 `Material` 祖先 —— 统一由 `SheetSurface` 提供；`FScaffold` 与 forui Sheet **都不提供**（**非抽屉的整页自绘输入区**没有 `SheetSurface`，必须自己逐个补 `Material(type: MaterialType.transparency)`：笔记编辑页共 3 处 —— 标题/正文 `TextField`、`QuillEditor` 的选区菜单、`QuillSimpleToolbar` 的 `IconButton`，详见 SKILL 红线 #23 ⑦）；② **常态必须可见描边、聚焦高亮主题色**（不写 `border:` 即继承主题 `inputDecorationTheme`，**严禁 `InputBorder.none` 抹掉描边**）；③ **点空白 / 滚动失焦收键盘**（根 `Actions` 覆盖 `EditableTextTapOutsideIntent` + `SheetSurface` 的 `ScrollNotification` 兜底，无需各自写 `onTapOutside`）；④ 多行 `maxLines: null` 随内容增长 | `sheet_surface.dart` 注释 / `app.dart` / `interaction-patterns.md` §五 |
| **controller 生命周期** | controller 归**持有它的 State**，**绝不**在 `await 抽屉 Future` 之后 dispose（会断言 `_dependents.isEmpty` 整屏红） | `architecture.md` 雷区 #14 + `_ControllerHost` |
| **列表滚动吸顶** | 锚点 = **搜索行**（搜索框常驻视口顶部），**不是** Tab 栏；条件 chip / Tab 栏都随滚动移出 | `todo_page.dart` 的 `_PinnedHeader`；本模块 §3.5 / §3.17 |
| **反馈（toast）** | 统一 `showFToast`（`FToaster` 已在根组件挂全局） | `showRecordProgressSheet` |
| **库内英文码值展示** | 文案里**禁止直出 DB 码值**（`daily`/`weekly`…）。中文名放**模型 getter** 作单一来源（未知值原样返回，别吞信息），卡片与详情共用同一处（2026-09-13 习惯 `freqType` 先踩：卡片直出 `daily`、详情自带一份 switch → 两处重复） | `HabitItem.freqLabel`（`models/habit.dart`） |

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
Tab 栏（h34 分段）：进行中（默认）/ 未开始 / 已完成 / 已取消 / 全部 ← 随滚动移出（是状态范围，不是筛选；口径见 §3.7）
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

- 元素：`PageBanner(icon: check, title:'待办', subtitle:'专注当下，一件一件来', gradient: AppTokens.accentGradient(专属色), cornerRadius:22, textureAsset: CardTextures.texture11, ringDecor:true, shadow:false, margin: EdgeInsets(16,0,16,0), stats:[全部/进行中/已完成/已取消])`。
- 样式：**专属强调色渐变背景** + 纹理叠加 + 同心环装饰（`ringDecor`）。
- ⚠️ **功能色跟随功能域专属 accent（2026-09-13 用户定案，反转 09-12 的「统一主题色」）**：
  待办=accent(1)蓝 / 习惯=accent(2)绿 / 番茄钟=accent(6)红 / 倒计时=accent(0)紫 / 提醒=accent(3)琥珀——
  与 Hub 入口卡图标色一一对应，切换外观主题时**功能色不变**（外观只影响中性层与 CTA）。
  页面级强调元素（空态圆盘/勾选框/进度环/状态强调/条件 chip 默认色/弹层内选中态与开关轨）同步用专属色；
  GradientButton 与 `_sheetButton` 等 CTA 仍走主题主色（与内容/工具页一致）。先例：todo_page `_accent`、
  pomodoro 进度环颜色=阶段语义色（专注红 6 / 休息绿 2）。
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

- padding `16/4/4`，底 `muted`，`r11`，总高 34，内部 padding 3，spacing 3，`crossAxisAlignment.stretch`（选中白底要填满内轨 —— `fill_container` 不会自动发生，见 §3.17）。段宽由 `Expanded` 均分：**5 段在 320px 窄屏仍放得下**（每段 ~44px，3 字标签 13px ≈ 36px）；6 段会挤爆「重新开始」这种 4 字标签 → **上限 5 段**。
- Tabs = 进行中（默认）/ 未开始 / 已完成 / 已取消 / 全部（`kTodoScopeTabs`，顺序即画布顺序）。
- **6 状态 → 5 格是「完整划分」（不重不漏）**，口径表写在 `todo_filter.dart` 的 `applyTodoScope` 文档注释里，**改前先看那张表**：
  - 进行中 = `in_progress` · `blocked` · `restart`（**已开工未收尾**）
  - 未开始 = `not_started` ／ 已完成 = `completed` ／ 已取消 = `cancelled` ／ 全部 = 以上四种之和
- ⚠️ **2026-09-14 修正（用户实指）**：旧实现把 `active` 写成「未完成且未取消」→「进行中」页签里混进了未开始的任务。**不要再按「未完成」这个宽口径写 scope。**
- 「进行中」与 PC `useTodo.inProgressCount`（严格 `=== 'in_progress'`）**有意不同**：移动端 Tab 只有 5 格、塞不下 6 个状态各自一格；卡片自身的状态 chip 仍标精确状态（阻塞 / 重新开始分得清），信息不丢。
- ⚠️ **横幅统计行未同步**：`todo_page._banner` 仍是 全部 / 进行中 / 已完成 / 已取消 四格 → 现在**不再相加等于全部**（未开始没单列）。补一格即 5 格，320px 窄屏偏紧，**待用户定**。
- 这是**状态范围**，不是筛选；高级搜索抽屉不重复提供状态。随滚动移出（**不吸顶** —— 用户明确纠正旧实现「Tab 吸顶」）。
- 设计记录板：Ardot `725728418922780`（5 格真宽渲染 + 口径划分表）。

### 3.8 列表项（TodoListTile）

> ⚠️ 已并入**列表卡片族「三行式」**，**规格以 §3.19 为准**（2026-09-14 从旧「左侧 3.5px 轴线式」迁入）。
> 旧结构（3.5px 状态色轴 / 20 勾选环 / 状态圆点+彩色小字 / ⋯ 在标题行）**全部作废，勿照抄**。

- `AppCard(margin: EdgeInsets.zero, padding: 14, elevation: 1)`；R1 = 状态色渐变图标盘(40·r13) + 标题(15/w600·≤2 行) + 勾选(22)；R2 = 状态 chip + 标签 chip(≤3+「+N」) ┈┈ 子任务 `n/m`；R3 = `⏱时间 · ⟳重复` ┈┈ `⚑优先级` + `⋯`(16)。
- `indent` → `cornerDownRight` size14 放在 **R1 最前**（图标盘随之整体右移）。
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

### 3.18 待办骨架的共享原子与新消费方（2026-09-12 扩展）

> 待办骨架（图1：主色横幅统计 + 吸顶搜索行 + 分段 Tab + 列表）已抽出为 `lib/app/ui/`
> 共享原子，待办页与两个新消费方（提醒 / 倒计时）共同使用；行为页（习惯打卡）也已按此骨架加吸顶搜索行。
> ⚠️ 番茄钟记录已由独立列表页改为 80vh 抽屉（2026-09-13），**不再消费** `PinnedSearchRow`/`ScopeTabBar`。
> **新增列表页照此组装，禁止再各写一套搜索行 / Tab 栏 / 软底 chip。**

| 原子 | 路径 | 要点 |
|---|---|---|
| 吸顶搜索行 | `lib/app/ui/pinned_search_row.dart` | `PinnedSearchRow`（h40/r10/卡底描边 + 28×28 筛选钮，`onFilter:null` 隐藏）+ `PinnedSearchHeader`（`shrinkOffset>0` 才铺 `pinnedCover`，见 §3.5 雷区）+ `kSearchRowExtent`=60（吸顶高度与行内常量同源推导） |
| 分段 Tab 栏 | `lib/app/ui/scope_tab_bar.dart` | `ScopeTabBar<T>`（h34 muted 轨 r11、选中白卡 r8、13px、`CrossAxisAlignment.stretch`）；**不吸顶**，随滚动移出 |
| 软底 chip | `lib/app/ui/soft_chip.dart` | `SoftChip`（色底 alpha · r10 · 11/w600，可选 `leading`/`onRemove` ×；2026-09-13 增选择形态 `onTap`——无 ×、TapScale 包装，供分类/标签选择行使用，与 `onRemove` 互斥）；待办 `TodoStatusChip`(15%)/`TodoTagChip`(14%)/条件 chip(12%) 均为其包装 |
| 中性灰徽标 | `lib/app/ui/ui_atoms.dart` | `FlatBadge(label:)`（`colors.muted` 底 + `colors.mutedForeground` 字 · r10 · 11/w600 · h8/v3）。**中性提示（「+N」溢出计数、「子主题」）不能用 `SoftChip`**——`SoftChip` 的底色与文字同为传入色，给不出「浅灰底 + 灰字」这套配色。2026-09-14 落地，笔记卡首次消费；`conversation_page` 的私有 `_FlatBadge` 待迁移 |
| 弹窗表单原子 | `lib/app/ui/sheet_form.dart` | `SheetScaffold`（lg 定高骨架：居中把手 + 17/Bold 标题 + 裸 X + 中间滚动体 + 底部条）+ `SheetHandle`/`SheetChoiceChip`/`SheetFieldLabel`/`SheetInputBox`（数字类短输入可 `textAlign: center`；**与按钮并排等高对齐的唯一选择，见 §4.6**）/`SheetMultilineBox`/`SheetSwitchRow`/`sheetBottomActions`（`destructive: true` 出红色主按钮）+ **`showSheetActionMenu`（长按操作菜单，**默认 sm 档**；可传 `size:` 按三档制升档——**电子书书架长按书籍卡片用 `md`(50vh)**，2026-09-13 用户定）** + **`showSheetConfirm`（危险确认，sm 档，恒返回 bool）**；**新增弹窗优先用这组**（调用点必须配 `mainAxisMaxRatio: AppTokens.sheetHeightLg + resizeToAvoidBottomInset: false`，见 §一）；待办 `todo_sheets.dart` 私有 `_sheetScaffold` 为同构先例，待后续统一迁移 |
| 日期/时间选择 | `lib/app/ui/datetime_pickers.dart` | **录入日期时间一律走共享原子，禁止再手写文本框收日期**（interaction-patterns 同源思路），三选一：① `showTimePickerSheet`（**纯时刻「时/分」两列独立滚轮 → forui 公开原语 `FPicker`+`FPickerWheel` 自拼，中文单位 `时`/`分`，sm=30vh；滚轮高度按 `sheetMaxHeight(sm)−144` 自适应避免溢出**，2026-09-13 改 30vh）；② `showDateTimePickerSheet`（日期+时+分 → forui 原生 `FDateTimePicker` 轮式，md，分隔符 `:` 写死、无秒）；③ `showDateTimeWheelSheet`（**年/月/日/时/分/秒 六列独立滚轮 → `FPicker`+`FPickerWheel` 自拼，中文单位，md**，跨年/跨月场景好选，默认年列 `今年-10~今年+30`、`withSeconds` 默认 true）。⚠️ **forui 原生 picker 的分隔符写死、改不了**（`FTimePicker` 用 `:`、`FDateTimePicker` 时刻格式写死 `.Hm`），故要求中文单位（`08时00分` / `2026年 09月 13日 06时 10分 12秒`）的场景都走自拼 ① / ③（2026-09-13 用户定），`FDateTimePicker` 仅剩免拆列的简单场景（如二维码参数日期时间）。均三档制底部抽屉、24 小时制、取消返回 null。**嵌套抽屉安全写法**（从其他抽屉内打开）：`showFSheet` 走默认参数、**不传 `mainAxisMaxRatio`**（传了会让 ShiftedSheet 重入布局断言崩）；待办「新增/编辑-到期时间」消费 ③、习惯「提醒时刻」与提醒管理「时刻」均消费 ①。**间距优化**（forui `FPicker` 把每列包成 `Flexible` 均分整行 → 数字与中文单位被拉开；已用 `LayoutBuilder`+两端固定占位 `_textWidth` 量宽回压，见 changelog XLIII）|

| 消费方 | 骨架构成（横幅统计 / Tab / 备注） |
|---|---|
| `todo_page.dart` | 进行中/未开始/已完成/已取消/全部 · Tab=状态范围（口径见 §3.7） · 横幅纹理「卡11」+ 条件 chip 行（原子迁移，零视觉变化） |
| `reminder_list_page.dart` | 全部/定点/周期/启用中 · Tab=全部/定点/周期/多状态 · **提醒守护卡（常驻「N/4 项已就绪」→ 点开 `ReminderGuardSheet` lg 抽屉：四项系统开关一键修复 + 后台保活开关 + **前置显示（悬浮通知/锁屏显示）逐厂商引导** + 厂商后台限制路径引导 + 打开应用设置；2026-09-18 起抽屉抽出 `reminder_guard_card.dart`/`reminder_guard_sheet.dart` 共享组件，首页也复用，且**从系统设置页返回会强制重排一次提醒计划**，绕开回前台 5 分钟节流）** + 搜索按标题/内容 + 编辑弹层走 `SheetScaffold`（选「闹钟」且未授权时显示降级提示行）+ **长按卡片 → `showSheetActionMenu`【编辑/停用·启用/删除】**（stateful 只读不响应），删除走 `showSheetConfirm` |
| `countdown_page.dart` | 全部/进行中/已暂停/已结束 · Tab=同四段 · 大计时器白卡主色环（横幅与搜索行之间，随滚动移出）+ 新建/编辑共用 `_CountdownFormSheet`（**设定方式对齐 PC（2026-09-12）**：指定时刻=复用待办 `showTodoDateTimeSheet` 月历选择器；指定时长=年/月/日/时/分/秒六小输入框（年=365 天、月=30 天折算），默认 1 小时；编辑未改时间设定保留原 timing，改了回到 running 并重排通知）+ **长按卡片 → `showSheetActionMenu`【编辑/删除】**，删除走 `showSheetConfirm` |
| `pomodoro_page.dart` | **2026-09-13 重构：页面内本地计时（计时只在本页、离开/切后台即停并复位；原 startTime 持久状态机与原生阶段通知已删）**。头部统一 `‹ 番茄钟 [记录][设置]`（已删 ⟳ 横竖屏循环与 `pomodoro.orientation`）；底部统一 `[开始专注/暂停/继续] [重新开始]`。**三种展示效果**（basic_info 键 `pomodoro_display`，设置弹层 choiceChip 切换；展示效果即方向，离开页面恢复跟随系统）：`normal`=横幅 + 白卡进度环（**竖屏计时卡用 `Expanded` 撑满剩余高度、内容居中**；横屏=左横幅 + 右大环）／`clean`=仅进度环内容卡（无说明文字，锁竖屏）／`landscape`=**大字倒计时 HH:mm:ss**（`FittedBox(scaleDown)` 兜底，锁横屏）。阶段完成写 `pomodoro_status` 流水 + `NotificationService.showNow` 提示音 + `haptic(success)`；长按整页 → 编辑配置弹层（lg：专注/休息分钟 + 展示效果 + **周期规则**）。**周期规则**（basic_info 键 `pomodoro_cycle_rule`）：`未完成重新开始`（默认，丢弃进度）/ `未完成继续上一轮`（专注剩余写 `pomodoro_progress`，重进页面或切后台回前台还原为「已暂停」，点「继续」才走）；仅作用于专注阶段 |
| `pomodoro_records_sheet.dart` | **2026-09-13 由独立页改为 80vh 抽屉**（`showPomodoroRecordsSheet`，lg 定高）：把手 + 「番茄钟记录」+ 统计行（专注 N ｜ 休息 N ｜ 共 M）+ 可滚周期列表（类型 SoftChip：专注红(6)/休息绿(2)）+ **底部固定【导出】**（→ `Download/渐离App导出/番茄钟记录_*.md`，`exportTextToDownloadDir`）。原 `pomodoro_records_page.dart` 与 `/pomodoro/records` 路由**已删除** |

> 到点通知 / 权限 / 保活的横切约定（`POST_NOTIFICATIONS`、`SCHEDULE_EXACT_ALARM` 引导、
> `AlarmBootstrap` 启动重排、`stableId` 通知 id）见 `modules/features.md` 功能域清单
> 「新增功能域落地清单」第 4 条与 `modules/changelog.md`（2026-09-12 XIV）。

### 3.19 列表卡片族「三行式」（2026-09-14 收口）

> 提醒 / 主题对话 / 可归类笔记 / 待办 / 倒计时 五类列表卡统一为**三行式**，卡壳规格完全同源。
> **新增列表卡照此组装，勿各写一套。**（待办卡 2026-09-14 从旧「左侧 3.5px 轴线式」迁入本族；
> 倒计时卡 2026-09-14 从「三态各长各的」收进本族 —— 定稿：**不套进度环**。）

**卡壳规格（五者完全一致）**：`AppCard(margin: EdgeInsets.zero, padding: EdgeInsets.all(14))`
—— white 底 + r16 + 1px `colors.border` + `elevation:1`；行间 `SizedBox(height: 8)`；
列表项间距由外层 `Padding(bottom: 10)` 提供（**卡内 `margin` 必须清零**，
否则与 `AppCard` 默认 `vertical:6` 叠成 22px 大间隙，2026-09-13 用户实指）。
`AppCard.radius` 默认即 `AppTokens.radiusMd = 16` → **别再显式传 `radiusLg`(24)**。

**图标盘（R1 左）**：`Container(40×40, BoxDecoration(gradient: AppTokens.accentGradient(域色), borderRadius: circular(13)))`
+ 20px 白图标。**普通圆角矩形，不是 `SquircleBox`**（弧度基准 = 首页快捷入口）。
⚠️ **不存在 `AppTokens.iconRadius()`**（多次误记）：弧度就是这个写死的 `circular(13)`，
尺寸不同的盘按 40→13 的比例自行推导并写注释（**48 → 16**）。
📌 本配方**已外溢到非卡片列表与功能页**（2026-09-14 用户口径：「工具 tab 下所有用到图标的地方，
除了功能图标之外（增删改查等），都改成和提醒列表卡片左侧图标类似的弧度和渐变」）：
- 电子书列表行左图标（`bookshelf_page.dart` 的 `_BookRow`）`SquircleBox(48, r14)`
  → `Container(48×48, accentGradient, circular(16))` + 20px 白图标；
- **工具 tab 6 个功能页共 13 处**：`two_factor_page` / `password_vault_page` / `file_vault_page` /
  `qr_page` / `sync_page` / `file_transfer_page` ——
  ① 门禁页大图标 76（`SquircleBox r26`）→ `Container(76×76, circular(25))`，3 处；
  ② 列表行 / 设备行图标 44（r14）与 36（`SquircleBox r10`）→ `Container(44, circular(14))`、`Container(36, circular(12))`，6 处；
  ③ 空态图标 76 圆形淡底（`_accent.withValues(alpha:0.12)` + `BoxShape.circle` + 彩色 32px 图标）
  → **渐变瓷片** `Container(76×76, accentGradient(_accent), circular(25))` + 34px 白图标，4 处。
  六个文件的 `import '../../../app/ui/squircle_box.dart'` 已随之删除（无其它用途）。

**`SquircleBox` 不再用于图标瓷片场景** —— 超椭圆的弧度观感与卡片族不一致，
用户实指「参考提醒卡片左侧图标」「主要是弧度和渐变」。
⚠️ **空态图标按最新用户口径也用渐变瓷片**（2026-09-14 明确选择，不再保留「淡色圆底」的柔和层次）。
⚠️ `EmptyState`（`ui_atoms.dart` 的 soft `SquircleBox` 76·r26 + `accentSoft`）**尚未改** ——
它被非工具页（笔记 / 待办等）共用，改动会外溢到其它 tab，需单独确认。
（`squircle_box.dart` 本身保留，头像等场景仍可用。）

**工具 tab 里无需改动的图标（本来就已是本配方）**：`EntryCard`（Hub 入口卡 46·r15）、
`AccountCodeTile`（2FA 列表行 40·r13）、`password_vault` 列表行字母徽标（38·r11 `primaryGradient`）。
**应保留为「功能图标」不动**（别套渐变瓷片）：表单字段内嵌小图标（日历 / `chevronDown`）、
chip 内嵌图标（TOTP 胶囊里的 `keyRound`）、扫码页关闭圆钮、色板 swatch 圆点、
页面返回箭头、`FButton.prefix` / `GradientButton.icon` 等按钮图标。

⚠️ **列表卡的图标盘一律不套进度环**（2026-09-14 用户定；倒计时卡实指「环影响观感」）：
3px 细弧在 40px 尺寸下几乎等同装饰、读不出剩余比例，又和图标盘抢视觉 ——
**剩余 / 进度信息一律走文字**（倒计时走 R2 主行大字），不要回到环形。
（留档：倒计时曾试「环套图标盘」，画布里环外径 39 < 盘 40 且画在盘下层 → 环被整块盖住；
改 46/3 + 盘收 36 能露出，但最终仍被否。真要套环时记住
`RingProgress.radius = (size - strokeWidth)/2`，`child` 画在环**之上**
——`ring_progress.dart` 是 `Stack[CustomPaint, Center(child)]`；**别照抄画布 `Ellipse` 的数值**。）

| 卡 | R1 | R2 | R3 |
|---|---|---|---|
| 提醒 `_ReminderTile` | 图标盘 + 标题 + 模式 `SoftChip` + `FSwitch` | 规则摘要（含免打扰，2 行） | 下次触发 / 前台驱动 / 已停用 |
| 主题对话 `_ThemeCard` | 首字头像(44·r14) + 标题 + `chevronRight` | 标签 `Wrap`（≤4 + 「+N」） | `{N} 条 · 更新于 {X}` + 备注 |
| 可归类笔记 `_NoteCard` | 图标盘 + 标题 + **时间** + `chevronRight` | 摘要正文（2 行） | 分类 chip + 标签徽标 + 「+N」 |
| 待办 `_TodoListTile` | 图标盘(状态色) + 标题(≤2 行) + **勾选框(22)** | 状态 `SoftChip` + 标签 chips(≤3 + 「+N」) ┈┈ 子任务 n/m | ⏱时间 · ⟳重复 ┈┈ ⚑优先级 + **⋯** |
| 倒计时 `_CountdownCard` | 图标盘(状态色) + 标题(1 行) + 状态 `SoftChip` | 主行 20/Bold（剩余 / 结束时刻）+ 副行 12（目标 / 说明） | 设定方式 `FlatBadge` + 提醒 chip ┈┈ 圆钮组 |

- **「+N」溢出规则四张卡共用**：`FlatBadge`（最多展示 4 个；笔记卡的分类上限 2、待办卡的标签上限 3），
  超出合并为 **1 个**计数徽标（笔记卡把分类与标签的隐藏数**合并计数**）。
- **「时间」三种落位都已被采用，别互相改**：主题卡放 R3（行内文本）、笔记卡放 R1 行尾
  （2026-09-14 用户选定变体 B，标签行独占整宽）、待办卡放 R3 行首（要和时间行的
  ⟳重复 / 行尾 ⚑优先级 做分组）。
- **第二动作位的落位约定**：卡片最右侧的「开关 / 勾选 / 进入箭头」一律在 **R1 行尾**
  （提醒=`FSwitch`、待办=`_TodoCheck`、笔记=`chevronRight`）；「⋯ 更多」这类**次级**动作
  放 **末行行尾**，与主操作位分开（待办卡 2026-09-14 定）。
- **笔记卡的分类 ≠ 标签**：`categories` → `SoftChip(alpha:0.10, leading: Icon(FLucideIcons.folder, size:11))`
  （琥珀 + 前置文件夹图标）；`tags` → `SoftChip(alpha:0.14, leading: 6×6 色点)`
  （跟随 `NoteTag.colorValue`）。**只靠底色区分不够**，必须靠「folder 图标 / 色点」区分。
- **待办卡的状态 ≠ 标签**：同一条 R2 上两个 chip 都是 `SoftChip`，靠
  **命令 `TodoStatusChip`（alpha 0.15 · 无点）/ `TodoTagChip(dot:true)`（alpha 0.14 · 6px 色点）** 区分。
  `TodoTagChip.dot` 是 2026-09-14 新增的可选参数（默认 false → `todo_card_view` 不受影响）。
- **待办卡的状态色只在两处出现**：R1 图标盘（`accentGradient(statusColor)`）与 R2 状态 chip；
  旧的「左侧 3.5px 色轴」已删除。状态色取 `statusMetaOf(context, status)`（进行中 = `colors.primary`）。
- **倒计时卡三态只在三处随状态变**（`running` / `paused` / `finished`，槽位与排布完全一致）：
  ① 状态色（进行中 = `colors.primary` / 已暂停 = `accent(3)` 琥珀 / 已结束 = `accent(2)` 绿）
  ② 主副行文案 ③ 按钮组。「指定时刻」（`mode == 'datetime'`）不出重置/暂停，只留删除
  —— **按钮组按 `mode` 收敛，槽位不变**。状态色落到 R1 图标盘 + 状态 chip + 提醒 chip 三处。
  （曾做过「剩余占比进度环」，2026-09-14 用户否决删除，见上方 ⚠️。）
- **倒计时主行文案**（`_countdownLine`）：≥1 天 = `9天04:44:27`，否则固定三段 `04:44:27`
  （补两位 + `FontFeature.tabularFigures()`；外面套
  `FittedBox(scaleDown, alignment: centerLeft)` 防窄屏溢出）。
  副行 = `目标 X` / `已暂停 · 目标 X` / `已结束 · 时长 X`
  （`_durationLabel` 最多取两个最大档，不足 1 分钟兜底）；
  `finished` 的主行**降级为 `mutedForeground`** —— 已完成的事不抢眼。
  ⚠️ **紧凑口径（2026-09-14 用户两次实指，别再加空格）**：
  冒号两侧不加空格（`00 : 59 : 54` → `00:59:54`）、**「天」与两侧数字也不加空格**
  （`9 天 04:44:27` → `9天04:44:27`；CJK 全角字形自带侧边距，贴紧仍有呼吸）。
  注意这与 `_durationLabel` 的副行 prose 写法（`时长 30 分钟`，带空格）**有意不同**。
  `_hmsParts` 只返回三段补两位字符串（`List<String>`）。
- ⚠️ **卡片里别写「恒真」的静态文案**：倒计时卡的提醒 chip 原来恒渲染「提醒 · 声音」，
  压根没读 `row.notify`。2026-09-14 修为 `'1'` → 状态色软底「提醒 · 声音」、
  `'0'` → `FlatBadge('不提醒')`。**中性 / 否定态一律走 `FlatBadge`**（`SoftChip` 的底色与文字
  同为传入色，给不出「浅灰底 + 灰字」）。同卡的 `row.color`（表单自定义色）至今**未被消费**，待定。
- ⚠️ **chip 内边距尚未全族统一**：本族新口径为 **h8/v3**（画布）。已按新口径的 =
  待办卡（`TodoStatusChip` / `TodoTagChip` 传 `padding`）、倒计时卡（`_kChipPadH/_kChipPadV`）；
  仍用 `SoftChip` 默认 `all(4)` 的 = `_ReminderTile` / 笔记卡 / 主题卡。统一时**一起改**，勿只改一张。
- **笔记卡摘要要去重**：仓库写入格式 `excerpt = "{title}\n{正文首行}"`
  （`note_repository._excerptOf`），首行即标题 → 卡片须剔除首行再渲染，
  否则 R1 标题与 R2 摘要重复（`_NoteCard._excerptBody`）。

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
- ⚠️ **唯一例外：flutter_quill（`QuillEditor` / `QuillSimpleToolbar`）不走 `EditableText`** —— 它自带 `TextInputClient` 实现，**上面两处兜底全都管不到它**，必须自己在 `QuillEditorConfig.onTapOutside` 里实现（含「工具条豁免」，详见 §4.7）。凡是看到「第三方编辑器控件」就该想到这条例外。

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

### 4.6 与输入框并排的按钮（添加/发送等）等高对齐 —— 两侧全自绘，禁套 forui 控件（2026-09-13 定案）

- **根因（两轮实拍截图验证，勿再踩）**：
  - **forui `FTextField` 的可见边框按内容固有高度绘制，外层紧高度约束不拉伸它**——`SizedBox(height:44)` 套住后盒子是 44，可见边框仍只有 sm 档固有 ~36，其余透明（「一边虚高」）；
  - **forui `FButton` 同理**：在固定高度盒内仍按自身 padding 画框排内容（「一边实高」）。
  - 于是「虚高 + 实高」怎么调数字都对不齐：第一轮锁 44 输入框 vs FButton 不齐；第二轮输入框套 44 + 自绘按钮真 44，反而按钮比输入框还高。**结论：与输入框并排时，两侧必须都是自绘容器，禁用 forui 字段/按钮硬套高度。**
- **正确写法**（先例：`sync_page` / `file_transfer_page` 的「手动填 IP + 添加」行）：
  ```dart
  Row(
    children: [
      Expanded(
        child: SheetInputBox(                      // 共享原子（sheet_form.dart）：
          controller: _manualIp,                   //   边框由自绘 Container 画
          hintText: '手动填 IP…',                  //   高度真实可控 h40
          keyboardType: TextInputType.number,
        ),
      ),
      const SizedBox(width: 8),
      TapScale(                                    // 自绘按钮：与输入框同高同圆角
        onTap: ...,
        child: Container(
          height: 40,                              // = SheetInputBox 高（40），结构性等高
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppTokens.primaryGradient(context),   // 主操作 = 主色渐变
            borderRadius: BorderRadius.circular(10),        // = 输入盒圆角 10
          ),
          child: Text('添加', style: ...14/w600/白),
        ),
      ),
    ],
  )
  ```
- **2026-09-15 收口为共享原子**：上例的自绘按钮已抽成 `SheetActionButton`（`lib/app/ui/sheet_form.dart`）——h40 · r10 · 左右 padding 14 · 14/w600；`primary: true` = 主色渐变底 + 白字，否则 `muted` 底 + 前景字；`icon` 可选（14px）；`onTap: null` = 禁用态（如「扫描中…」）。**凡「输入框 + 按钮」同一行，一律 `SheetInputBox` + `SheetActionButton`（间距 6），不要再内联自绘第二份，更不要 `FButton`。**
- ⚠️ **实例（用户实拍指出）**：电子书「分类管理」弹窗的「新建分类」行曾直接并排 `FTextField(label:)/FButton` → 输入框与按钮高度、基线均不对齐。已改为 `SheetFieldLabel('新建分类') + SizedBox(6) + Row(SheetInputBox + SheetActionButton(primary))`；同批把电子书「传书」抽屉内的私有 `sheetAction` 闭包迁到该原子，删除本地副本（唯一实现）。
- **要点**：① 两侧同为自绘容器 → 结构性必然等高，键盘弹起不漂移，与字号缩放无关；② 圆角与输入盒统一 10；③ 次要按钮（如「扫描」独立行）可继续用 FButton——本规则只约束「与输入框并排」的场景；④ 需要固定高度/并排对齐的输入框**一律 SheetInputBox，不要 SizedBox 套 FTextField**（forui 字段适合自适应高度场景）。
- ⚠️ 禁止再写「SizedBox(height:X) 套 FTextField/FButton 求对齐」——2026-09-13 两轮截图实指后由自绘方案收口。
- **消费方（2026-09-13 起）**：文件互传「手动填 IP + 添加」、同步页、以及**主题对话「对话记录」页底部输入条**（`SheetInputBox` + 40×40 主色渐变**方形**发送钮，圆角 10；该页原先用 `FTextField + FButton.icon` 必然不等高）。`SheetInputBox` 已加可选 **`onSubmitted`** —— 聊天式输入条（回车/软键盘「完成」即发送）传它，别再为了回车发送而退回 `FTextField`。

### 4.7 第三方富文本编辑器（flutter_quill）的键盘 / 焦点契约（2026-09-18 血案定案）

> 适用：`QuillEditor` + `QuillSimpleToolbar`（笔记编辑页方案 B）。这三条任一违反，症状都是「**点开富文本后键盘弹一下就消失、正文区像没有可输入的地方**」。

- **① `FocusNode` / `ScrollController` 必须由 State 持久持有，禁用 `QuillEditor.basic`**。`.basic` 每次 `build` 都现造 `FocusNode()` + `ScrollController()`，而**键盘 inset 变化本身就会触发重建** ⇒ 节点被换掉 ⇒ 旧节点失焦 ⇒ `openOrCloseConnection()` 关掉输入连接 ⇒ 引擎收起键盘（自我循环）。正确写法：

  ```dart
  // State 字段
  final _richFocus = FocusNode(debugLabel: 'noteEditorRich');
  final _richScroll = ScrollController();
  // dispose() 里一并释放

  QuillEditor(                                    // 完整构造器，不用 .basic
    controller: _quill!,
    focusNode: _richFocus,
    scrollController: _richScroll,
    config: QuillEditorConfig(
      expands: true,                              // 默认 false ⇒ 可视输入区只有内容高度，空文档≈一行
      autoFocus: false,                           // 红线 #14⑤：打开不自动聚焦
      onTapOutside: (event, node) { /* 见 ③ */ },
    ),
  )
  ```

  进入富文本后要在 `WidgetsBinding.instance.addPostFrameCallback` 里 `requestFocus()`（同一帧编辑器尚未挂载，直接调等于打空）；退回纯文本前先 `unfocus()` 主动收键盘。

- **② 绝不能把 `QuillSimpleToolbar` 套进横向 `SingleChildScrollView`**。它内部是 `QuillToolbarArrowIndicatedButtonList` = `Row[箭头, Expanded(CustomScrollView), 箭头]`，**自带横滑、要求父级给出有界宽度**；外套横向滚动 ⇒ 宽度无界 ⇒ 内部 `CustomScrollView` 永远拿不到有效滚动尺寸 ⇒ `_handleScroll` 读 `position.minScrollExtent` 抛 `Null check operator used on a null value`。**致命之处是连锁**：该回调由 `WidgetsBinding.instance.addObserver(this)` 注册，而 Flutter 的 `handleMetricsChanged()` 观察者循环**没有 try/catch**，异常打断整条 metrics observer 链 —— **软键盘 insets 变化正是走这条链**，于是「键盘谈不开」。单行横滑交给 quill 自带箭头滚动，高度由它内部 `tightFor(height: _toolbarSize)` 兜住。

- **③ 自写 `onTapOutside` 必须豁免工具条**（§4.2 的例外）。quill 默认 `_defaultOnTapOutside` 只在「鼠标/触控笔且非移动端」失焦，移动端 touch 什么都不做，所以要自己实现；但**工具条位于编辑器的 `TapRegion` 之外**，不豁免就是「点一次加粗，键盘和光标一起没了」。做法：给工具条外层挂 `GlobalKey`，回调里 `box.globalToLocal(event.position)` 落在 `Offset.zero & box.size` 内则 `return`，否则 `node.unfocus()`。

  ```dart
  final _toolbarKey = GlobalKey();
  // ...
  onTapOutside: (event, node) {
    final box = _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final local = box.globalToLocal(event.position);
      if ((Offset.zero & box.size).contains(local)) return;   // 点在工具条上 → 不收键盘
    }
    node.unfocus();
  },
  ```

- **④ 排查口诀**：`adb logcat | grep -E "ImeTracker|Null check"`。出现 `onRequestShow → onShown → onRequestHide at ORIGIN_CLIENT_HIDE_SOFT_INPUT` = **客户端自己收的键盘**（查 ①）；出现 `Null check operator used on a null value` + `minScrollExtent` = 查 ②。

- **⑤ Material 祖先要补两处**（本项目 `FScaffold` 不提供）：`QuillEditor`（长按选区菜单走 Material `AdaptiveTextSelectionToolbar`）与 `QuillSimpleToolbar`（内部按钮是 Material `IconButton`），各自包一层 `Material(type: MaterialType.transparency)`。

- 关联：红线 `SKILL.md` #23（参数名清单）/ #24（本条三坑）；变更史 `changelog.md` 2026-09-18 续·六。

### 4.8 富文本编辑入口的形态：**独立沉浸页**，禁止用底部抽屉（2026-09-18 定案）

> 适用：任何需要「编辑区 + 格式工具条 + 软键盘」三方同时在屏的输入场景（笔记方案 B、主题对话富文本页）。

- **结论：走独立页 `push`，不走底部抽屉。** 反证过程：底部抽屉按 §1.2 的 **`lg` 档必须 `resizeToAvoidBottomInset: false` 且不扣键盘** —— 键盘弹起后会**直接盖住抽屉下半屏**；为了躲键盘只能把工具条挪到抽屉顶部，可见编辑区被压到约 **35vh**，实际不可用。独立页则随键盘自然收缩（`SafeArea` + `Expanded` 正文），**工具条常驻键盘上方**，符合用户对「打字时工具条在手边」的预期。
- **配套实现契约**（`conversation_compose_page.dart` 与笔记编辑页同构）：
  - 结构 = `FScaffold(childPad:false)` + `FHeader.nested`(标题左对齐) + `SafeArea` + `Column`[上下文行(可选) → `Expanded(QuillEditor)` → `QuillSimpleToolbar` → 底栏]。
  - 键盘/焦点三条铁律**照抄 §4.7**（State 持 `_richFocus`/`_richScroll`、完整构造器 + `expands:true`、禁套横向 `SingleChildScrollView`、`onTapOutside` 豁免工具条）；Material 祖先同样要补（编辑区 + 工具条各一处）。
  - **草稿状态单一持有者**：入口页（快速输入栏 / 列表页）持有标签与引用草稿并经路由参数带入，独立页只做「可点掉」的展示，**不在两处各放一套选择器**（否则草稿状态分裂）。编辑已有条目时该页**只改内容**，其余属性仍回入口页的既有入口改。
  - 返回用 `context.pop<bool>(...)`，新建成功回 `true`（入口页据此清空草稿并高亮），编辑成功回 `null`（无需清空）。
- **能力边界（跨端对齐时的铁律）**：工具条**只开对端渲染层真正支持的能力**。主题对话工具条只给「加粗/斜体/下划线/删除线/引用/代码块/有序·无序列表/链接/标题 1-3」（+ 移动端补撤销重做，手机没有 Ctrl+Z），**颜色 / 背景色 / 高亮 / 缩进 / 对齐 / 上下标 / 待办清单 / 搜索一律显式关** —— PC 气泡 `:deep` CSS 不覆盖这些标签，开了会在 PC 上渲染成「无样式的裸标签」。详见红线 `SKILL.md` #25。
- 关联：§1.2（lg 档不扣键盘）/ §1.9（打开不自动聚焦）/ §4.7（quill 键盘契约）；变更史 `changelog.md` 2026-09-18 续·七。

