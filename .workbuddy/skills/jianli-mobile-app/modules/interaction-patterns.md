# 交互模式规范（全 App 共有交互）

> **定位**：把「同类操作在全 App 有同一心智」写成**可执行规格**。本模块管**交互骨架**
> （弹窗规格 / 入口 / 结果回传 / 反馈 / 生命周期）；`architecture.md` 的「页面操作规范」
> 管页面级细则（筛选抽屉内容、保存条位置等），`ui-modernization.md` 管动效。
>
> **规矩**：新增或修改共有交互 → **先改本模块**，再实现；改先例时同步本节。
> 先例文件是**唯一的实现基准**，别另起一套。

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

### 1.2 高度按「可用高度」算，不是屏幕高 —— 键盘一定会踩

```dart
height = (屏幕高 − 键盘高) × 档位        // sheetMaxHeight(context, size)
```

**为什么必须减键盘高**（2026-09-12 实测，改前必读）：forui 的 `ShiftedSheet` 用
`dy = max(0, H − 抽屉高 − 键盘高)` 摆放抽屉。抽屉高一旦超过「H − 键盘高」，`dy` 就被夹到 0
**停止上移** —— 抽屉**不会**抬到键盘上方，而是被键盘从底下盖住，底部「保存 / 查询」按钮
点不到。按可用高度算 → 抽屉永远完整落在键盘上方，且**永远到不了 100vh**。

> ⚠️ 旧结论「键盘弹起时整张抽屉抬到键盘上方」**是错的**（`mainAxisMaxRatio: null` 时期的注释），
> 已在本轮修正。别再照旧注释写。

### 1.3 内容超出 → 中间滚动，绝不撑高

- 抽屉是**定高容器**：内容超出由中间滚动区承担（`_sheetScaffold` 用 `Expanded(SingleChildScrollView)`，
  `_sheetPanel` 用 `SingleChildScrollView` + `Column(min)`）。
- 键盘展开**不改档**：档位不变，只是按可用高度收缩，多出来的内容交给滚动。

### 1.4 弹窗标题字号规则（**其他字段禁止比标题还大**）

- 弹窗标题一律 `sheetTitleStyle(context)` = **17 / Bold**（画布 09/10 规格，绝对像素）。
- **规则：弹窗内任何字段的字号都不得大于 17**；`待办详情` 里的「条目标题」与 `编辑` 的标题输入框
  同用 **15 / Bold**（比弹窗标题小 2 号，**详情与编辑必须一致**）。
- ⚠️ **不要用裸 `context.theme.typography.body.lg` 当标题**：主题把 forui 字型整体按
  `baseFontSizeNormal`（12）缩放过，`body.lg ≈ 13.7` —— 直接当标题会比正文还小。
  这正是「待办详情的弹窗标题比待办标题【xxx】小」的成因（2026-09-12 用户实指）。

弹窗内标准字号阶梯（待办口径，其他模块照此收敛）：

| 用途 | 字号 / 字重 | 备注 |
|---|---|---|
| 弹窗标题 | 17 / Bold | `sheetTitleStyle`，**上限** |
| 条目标题（详情标题、编辑标题输入框） | **15 / Bold** | 比弹窗标题小 2 号，详情与编辑必须一致 |
| 字段值 / 正文 | 14 / Regular（强调 w600） | |
| 字段标签 | 13 / Regular · mutedForeground | |
| 分组小标题 | 12 / Bold · mutedForeground | |
| chip（软底 / 状态 / 优先级 / 标签） | 11 / Semi Bold | |
| 底部按钮 | 15 / Semi Bold · 高 46 · r14 | |

### 1.5 定高 vs 上限（两个承载件的分工）

| 承载件 | 高度语义 | 用在 |
|---|---|---|
| `_sheetScaffold(size:)` | **定高**（`SizedBox(height:)`）→ 同档弹窗**必然等高** | 待办全部表单/菜单/确认类弹窗 |
| `_sheetPanel(size:)` | **上限**（`ConstrainedBox(maxHeight:)` + hug） | 画布 09/10 两屏（画布明确标注 `hug_contents`） |

- 「详情与编辑等高」这条要求**靠定高满足**：两者都挂 `lg` → 高度必然一致，与内容多少无关。
- 画布 09/10 是唯一例外（画布写死 hug），档位只当上限用；**其余弹窗一律定高**。

### 1.6 待办各弹窗档位对照（改档必读）

| 弹窗 | 入口函数 | 档位 |
|---|---|---|
| 状态单选 | `showTodoStatusSheet` | `sm` |
| 操作菜单（编辑/记录进展/删除） | `showTodoActionSheet` | `sm` |
| 删除等危险确认 | `showTodoConfirmSheet` | `sm` |
| 标签多选 + 新建 | `showTodoTagSheet` | `md` |
| 父任务多选 | `showTodoParentSheet` | `md` |
| 日期与时间（自绘月历） | `showTodoDateTimeSheet` | `md` |
| 记录进展 | `showRecordProgressSheet` | `md` |
| 日历「按天待办」 | `showTodoDaySheet`（`todo_calendar_view.dart`） | `md` |
| **待办详情**（只读） | `showTodoDetailSheet` | **`lg`** |
| **新增 / 编辑表单** | `showTodoEditSheet` | **`lg`**（必须与详情同档） |
| 显示风格（画布 09） | `showTodoViewModeSheet` | `lg` 上限（hug） |
| 高级搜索（画布 10） | `showTodoFilterSheet` | `lg` 上限（hug） |
| 通用查询抽屉（跨模块） | `showFilterSheet`（`lib/app/ui/filter_sheet.dart`） | `md` 定高 |

---

## 二、共有交互模式目录

| 模式 | 规范要点 | 代码入口 / 先例 |
|---|---|---|
| **底部抽屉（承载）** | 一律 `showFSheet(side: FLayout.btt)` + `SheetSurface` 包底（forui 不画 surface，直接给 Padding 会露灰色 barrier）；居中弹窗全 App 禁止（见 SKILL.md 红线 #10） | `lib/app/ui/sheet_surface.dart` |
| **弹窗高度 / 标题** | 三档制 + 17/Bold 上限 | 本模块 §1 |
| **危险确认** | 也走底部抽屉（不是居中弹窗）；泛型 + `Navigator.pop(c, true/false)` 回传 | `showTodoConfirmSheet` |
| **查询 / 筛选** | 条件收进「查询抽屉」：标题「查询」+ 关裸图标；中部选项滚动；底部「重置 / 查询」**恒贴底**（定高 + `Expanded`，minHeight 方案会让按钮随内容浮起，实踩） | `lib/app/ui/filter_sheet.dart`（`md`）；待办另有 `showTodoFilterSheet`（画布 10） |
| **条目单击 = 查看详情** | 单击先出**只读详情**，要改再点详情的「编辑」；多入口**共用同一函数**，避免「某处点开是编辑」的漂移 | `openTodoDetail` + `showTodoDetailSheet` |
| **详情出口动作回传** | 用 `枚举 + 目标条目` 回传（`TodoDetailResult(action, item)`），抽屉自己不直接开表单；带 item 是为了支持父任务**层层下钻**后动作逐层上抛 | `TodoDetailResult` |
| **新增 / 编辑保存** | 底部固定操作条（`GradientButton`），不随内容滚动；编辑态头部不放重复保存入口 | `note_editor_page.dart` |
| **表单输入框** | ① 抽屉内原生 `TextField` 必须有 `Material` 祖先 —— 统一由 `SheetSurface` 提供；`FScaffold` 与 forui Sheet **都不提供**；② **常态必须可见描边、聚焦高亮主题色**（不写 `border:` 即继承主题 `inputDecorationTheme`，**严禁 `InputBorder.none` 抹掉描边**）；③ **点空白 / 滚动失焦收键盘**（根 `Actions` 覆盖 `EditableTextTapOutsideIntent` + `SheetSurface` 的 `ScrollNotification` 兜底，无需各自写 `onTapOutside`）；④ 多行 `maxLines: null` 随内容增长 | `sheet_surface.dart` 注释 / `app.dart` / `interaction-patterns.md` §5 |
| **controller 生命周期** | controller 归**持有它的 State**，**绝不**在 `await 抽屉 Future` 之后 dispose（会断言 `_dependents.isEmpty` 整屏红） | `architecture.md` 雷区 #14 + `_ControllerHost` |
| **列表滚动吸顶** | 锚点 = **搜索行**（搜索框常驻视口顶部），**不是** Tab 栏；条件 chip / Tab 栏都随滚动移出 | `todo_page.dart` 的 `_PinnedHeader`；本模块 §4 |
| **反馈（toast）** | 统一 `showFToast`（`FToaster` 已在根组件挂全局） | `showRecordProgressSheet` |

---

## 三、待办模块设计总结（交互模式的旗舰先例）

> 待办是本工程把上述规范落地得最完整的功能域，新增模块建议**照它抄骨架**。
> 数据层契约（双端列名 / 同步白名单）见 `sync.md`，本节点到为止。

### 3.1 列表页结构（画布 07/08）

```
头部（‹ 返回 / 「待办」/ ⚙ 设置 / + 新增）      ← 固定，不参与滚动
统计横幅（容器，画布 5:431）                    ← 随滚动移出
搜索行（页内搜索框 h40 + 筛选按钮）              ← ★ 吸顶锚点，常驻视口顶部
生效条件（可点掉的摘要 chip，如「条件-搜索」）    ← 随滚动移出
Tab 栏（h34 分段）：进行中（默认）/ 已完成 / 已取消 / 全部   ← 随滚动移出（不是筛选）
列表区（按「今天 / 明天 / 更晚」分组标题 + 卡片）  ← 从搜索行下方滚过
```

- **搜索留在页内**（实时过滤），**筛选条件收进高级搜索抽屉**（画布 10）——两者职责不要混。
- 状态范围由 Tab 承担，**高级搜索抽屉里不再重复提供状态**。

### 3.2 三种视图（画布 09 显示风格，切换后立即生效）

| 视图 | 说明 | 持久化 |
|---|---|---|
| 列表 | 紧凑三行，信息密度最高 | `todo.viewMode`（本地） |
| 卡片 | 卡片网格，视觉优先 | 同上 |
| 日历 | 按月历看到期分布，点日期开「按天待办」抽屉 | 同上 |

### 3.3 类型分级（选项字面量与 PC 对齐，改动同步两端）

| 维度 | 取值 |
|---|---|
| 优先级 | `high/medium/low` → 高/中/低（`kTodoPriorityOptions`） |
| 状态（六态） | `not_started / in_progress / blocked / completed / cancelled / restart`（`kTodoStatusOptions`） |
| 分组方式 | `none / status / due / parent`（`TodoGroupBy`） |
| 到期时间段 | `overdue / today / tomorrow / thisweek / later / nodate` |

### 3.4 交互语义

- **单击条目 = 只读详情**（→「编辑」/「记录进展」两个出口），三处入口（列表卡片 / 卡片视图 / 日历）**共用 `openTodoDetail`**。
- 「删除 / 记录进展」在卡片 ⋯ 菜单里（`showTodoActionSheet` = `sm`）。
- 详情里点**父任务 chip 会再开一层详情**下钻，里层点「编辑」时编辑的是**里层那一条**（靠 `TodoDetailResult` 逐层上抛实现）。

### 3.5 与 PC 的**有意差异**（别「对齐 PC」改回去）

| 项 | PC 桌面端 | 移动端 | 原因 |
|---|---|---|---|
| 列表单击 | **直接进编辑表单**（`TodoDetailDialog` 的 readOnly 只用于看父任务） | **先看只读详情** | 避免移动端误触即改（2026-09-12 用户定） |

详情字段口径仍以 PC 只读态为准：标题 / 描述 / 优先级 / 截止时间 / 截止提醒 / 重复 /
关联父任务 / 标签 / 状态 / 完成时间（移动端另补「子任务进度」「创建时间」）。

---

## 四、列表页滚动吸顶 —— 以「搜索框」为锚点（2026-09-12 定，强制）

### 4.1 规则

列表页只要有页内搜索框，**吸顶元素就是搜索行**（不是 Tab 栏、不是条件 chip）：

```
横幅            → 随滚动移出
【搜索行】       → ★ 吸顶：滚过横幅后常驻视口顶部
条件 chip        → 随滚动移出
Tab 栏          → 随滚动移出
列表内容         → 从搜索行（含其下方 8px 留白）下方滚过
```

- **搜索框必须常驻**：滚动中随时能改关键词，不必先滑回顶部。这是吸顶锚点的选择依据。
- **Tab 栏不吸顶**：不要为了「随时能切状态范围」把锚点改回 Tab 栏 —— 用户 2026-09-12 明确纠正
  （旧实现即「Tab 栏吸顶」，已改）。
- 吸顶行底色用 `AppTokens.pinnedCover(context, extent)`（背板同源渐变）—— **只在 `shrinkOffset > 0`（已滚动吸顶）时铺**，静止时完全透明透出页面渐变背板。
  ⚠️ 不要直接刷 `colors.background` 纯色（静止时是一块灰白挡板，把背景切断，2026-09-12 用户实指）；也不要用 `pageTint`（透明色，会透出内容）。

### 4.2 实现要点（踩坑表）

| 点 | 做法 | 为什么 |
|---|---|---|
| 吸顶件 | `SliverPersistentHeader(pinned: true)` + 自定义 delegate | 不要用 `SliverAppBar`（会带进与 forui 无关的 Material 视觉） |
| 高度 | `minExtent == maxExtent ==` 结构化常量 | 两者不等 → 吸顶 / 松开瞬间会跳一下 |
| 高度同源 | 吸顶高度由**子节点实际用的同一批常量**推导（`_kSearchRowExtent = 上留白 + 框高 + 下留白`） | 分别写两套数值 → 改边距时必然漂移 |
| 下留白 | 留白放进吸顶行**内部**，并把下一行的上留白置 0 | 内容从元素下方 8px 处开始消失，而不是贴着底边被切断 |
| 全 App 唯一 | 目前仅 `todo_page.dart` 使用 `SliverPersistentHeader` | 新增吸顶页**照抄它**（delegate 模板 `_PinnedHeader`），别各写一套 |
| ⚠️ `overlapsContent` 是陷阱 | 判断「吸顶后是否盖住内容」**不能**用 delegate `build()` 的 `overlapsContent` 参数，也**不能**给 `SliverPersistentHeader` 传 `overlapsContent:`（该 widget 根本没有这个命名参数，会编译报错） | 对 **pinned** 头，`overlapsContent = constraints.overlap > 0`，即「前方是否有 floating sliver 压着自己」——本布局前方是 banner，永远 false。直接用它会让吸顶后永远透明、滚动列表文字从缝里透出来（2026-09-12 用户实指） |
| ✅ 正确信号 `shrinkOffset` | 用 `shrinkOffset > 0` 判断「已滚动 / 头已吸顶 / 内容正从缝下经过」，此时才铺 `pinnedCover` | `shrinkOffset` = 已滚过的量，是 pinned 头检测「内容滚到下方」唯一可靠信号；`== 0`（静止、banner 在上方）则不铺，透出背板无额外色块 |

### 4.3 已知不一致（待用户拍板，别擅自改）

`todo_page.dart` 的**卡片视图 / 日历视图**是 `Column` 固定头 —— 搜索 / 条件 / Tab 三者都固定在
滚动区外、完全不参与滚动，与列表页「只有搜索行吸顶」不同形。彻底统一需把这两个视图也改成
sliver 结构（内部滚动件要换成 sliver 版本），改动面较大。**未拍板前保持现状。**

---

## 五、输入框交互规范（2026-09-12 定，全 App 适用）

> 覆盖用户四连需求之二/三：输入框必须显示边框、聚焦高亮主题色、点空白/滚动失焦收键盘、描述随内容增长。

### 5.1 常态可见描边 + 聚焦高亮主题色

- 描边来源：`FThemeData.toApproximateMaterialTheme()` 会用 `textFieldStyles`（`fieldColors` 已把 `border` 调亮为 `AppTokens.inputBorderColor`）生成 Material 的 `InputDecorationTheme`，**自带「常态描边 + focused 主题色描边」两套变体**。
- **结论：原生 `TextField` 只要「不写 `border:`」就自动拿到全 App 一致的描边与聚焦高亮**——不要画蛇添足写 `decoration: InputDecoration(border: InputBorder.none)`，**那会把主题描边整个抹掉**（实踩：新增待办标题框「看不到边框」即此因）。forui `FTextField` 同理继承主题描边。
- 唯一例外：搜索框嵌在**已经带描边的容器**里（如 `todo_sheets.dart` 标签搜索：外层 `Container(border: Border.all(...))` 已提供视觉边框），内层 `TextField` 才允许 `InputBorder.none`——此时边框是容器给的，不是输入框自己。

### 5.2 点空白 / 滚动 → 失焦收键盘（移动端必须显式处理）

- **根因（关键坑）**：Flutter 默认的 `_EditableTextTapOutsideAction`（`editable_text.dart` ~L6876）**只在 desktop 平台解焦**；`switch (defaultTargetPlatform)` 里 `android/iOS/fuchsia` 的 `touch` 事件**不解焦**（除非 `kIsWeb`）。所以「点输入框外收键盘」在移动端默认**不生效**，必须自己兜底。
- **`EditableTextTapOutsideIntent` 是官方扩展点**：它被 `Actions.overridable` 注册（`editable_text.dart` ~L5811），祖先 `Actions` 可覆盖默认行为。本工程**单一收口**：
  1. `lib/app/app.dart` 根组件用 `Actions` 覆盖 `EditableTextTapOutsideIntent`（`CallbackAction` 直接 `intent.focusNode.unfocus()`）——覆盖全 App 所有输入框（原生 `TextField` 与 forui `FTextField` 都走 `EditableText` → 该 intent），点任意输入框外即收键盘。
  2. `lib/app/ui/sheet_surface.dart` 另加 `NotificationListener<ScrollNotification>`：抽屉内任意滚动开始（`ScrollStartNotification`）即 `FocusManager.instance.primaryFocus?.unfocus()`——兜底**惯性滚动**（没有 pointer-down，走不到 tap-outside 那条路径）。
- ⚠️ **新增输入框无需各自写 `onTapOutside`**，统一由上述两处兜底；若某输入框需不同行为再单独覆盖。别回到「每个输入框手写 onTapOutside」的散落写法。

### 5.3 多行输入容器随内容增长

- forui `FTextField`：`maxLines` 只限制**同时可见**行数、不限制可输入行数。**给 `maxLines: null` + `minLines: N`** → 初始高 N 行，每多一行容器就长高一行，超出抽屉档位由 `_sheetScaffold` 中间滚动区（`Expanded(SingleChildScrollView)`）承担，不会把抽屉撑破。
- 新增「描述 / 备注 / 详情」类多行输入照此写，**不要写死固定行高**。先例：`todo_sheets.dart` 新增/编辑待办的描述框 `FTextField(maxLines: null, minLines: 2)`。
- 原生 `TextField` 等价写法：`maxLines: null`（同时 `minLines` 控制初始高）。

### 5.4 关联

- 弹窗边距（= 全局 16）：本模块 §1.7。
- 抽屉高度/标题/键盘扣减：本模块 §1。
- 红线汇总：`SKILL.md` #14；实战坑：`architecture.md` 坑位 #15。

