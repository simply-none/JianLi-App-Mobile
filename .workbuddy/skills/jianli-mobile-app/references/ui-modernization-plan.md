# 渐离移动端 UI 现代化 + 操作动效方案（完整规划）

> 状态：规划文档（尚未落地）。本文件是「先做设计系统、再做动效、再逐屏落地」的总方案，
> 落地时按「实施路线」分阶段执行，并在 `SKILL.md` 的「功能域清单 / 维护说明」同步进度。
> 最后更新：2026-09-05。

## 0. 背景与现状诊断

换装 forui（shadcn 风格）后，App 视觉统一了，但整体偏「朴素/功能化」，缺乏现代效率类 App
（如 Things、TickTick、苹果提醒、Notion Calendar）该有的「质感」与「灵气」。具体短板：

| 维度 | 现状 | 问题 |
|---|---|---|
| 层次（depth） | `AppCard` 仅 1px border，无 elevation、无阴影 | 卡片「贴」在背景上，缺乏悬浮感 |
| 容器形态 | 统一 16px 圆角矩形 | 形态单一，无 squircle / 玻璃 / 渐变等现代语言 |
| 主色运用 | 仅边框色条、图标着色、首页横幅渐变 | 主色未形成「品牌氛围」，缺少渐变强调 |
| 暗色模式 | card vs background 两档 | 暗色缺「分层表面」（surface-1/2/3），层次扁平 |
| 列表入场 | 进入页面瞬间全量出现 | 无 stagger / fade，显「愣」 |
| 页面切换 | go_router 默认无转场 | Tab 与 push 都是硬切，割裂感强 |
| 点击反馈 | `FTappable` 有按压态但无缩放/ripple | 触感「钝」，不像可点 |
| 数字 | `StatBlock` 静态 | 统计无 count-up，缺乏「活」的感觉 |
| 加载态 | `FCircularProgress` 转圈 | 无骨架屏，列表区空白跳动 |
| 完成反馈 | 勾选仅改图标/删除线 | 无庆祝动效（spring check / confetti） |
| 底部导航 | `FBottomNavigationBar` 选中态无动效 | 无滑动指示条 / 图标弹跳 |
| 空态 | 单图标 + 文案 | 缺插画氛围，略「冷」 |
| 无障碍 | 未处理 | 未尊重系统「减弱动态效果」 |

技术约束（必须守住，详见 `SKILL.md` 全局红线）：
- forui 组件不可替换为裸 Material；所有 UI 文件继续 `import 'package:material_ui/material_ui.dart'`。
- 第三方动画库内部用 `flutter/material` 是被允许的（skill 已明确：mobile_scanner / qr_flutter 等先例），但**我们的页面文件**必须保持 material_ui 导入，避免断 Theme 继承链。
- `FScaffold.footer` 放底部导航、`FTabs` 含 viewport 必须 `expands: true`、`material_ui` 的独立 Material 类勿与 `flutter/material` 混用——这些雷区在动效改造时照旧有效。

---

## 1. 设计目标与原则

四大原则（写进代码评审清单）：
1. **克制但有灵气**：默认安静，关键操作（打卡 / 完成 / 切换 Tab / 入场）给「恰到好处」的动效，不做炫技。
2. **token 驱动**：所有新视觉走 `context.theme.*` 或新增的设计 token，严禁页面里写死颜色 / 阴影 / 圆角。
3. **性能优先**：单帧动画 ≤ 16ms；列表动效用原生 `Animated*` / `Tween`；避免大范围 `BackdropFilter` 堆叠。
4. **无障碍**：尊重 `MediaQuery.of(context).disableAnimations`，提供 reduced-motion 降级路径。

目标观感关键词：**柔和悬浮 + 主色渐变点缀 + 玻璃磨砂 + 顺滑入场 + 轻爽触感**。

---

## 2. 视觉系统升级（设计 token 与原子组件）

### 2.1 新增设计 token（`lib/app/theme/app_theme.dart`）

在 `_build` 之外新增一份「Motion + Surface」扩展 token，作为全局常量，避免散落硬编码：

```dart
// app_theme.dart 追加
class AppTokens {
  AppTokens._();

  // —— 形状 ——
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  // —— 阴影（轻量、柔和、低透明度，避免 iOS 重阴影观感） ——
  static List<BoxShadow> elevation(BuildContext context, {int level = 1}) {
    final t = context.theme;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final a = isDark ? 0.45 : 0.08;
    const off = [Offset(0, 1), Offset(0, 2), Offset(0, 6), Offset(0, 12)];
    const bl  = [2.0, 4.0, 12.0, 24.0];
    final i = level.clamp(0, 3);
    return [
      BoxShadow(
        color: (isDark ? Colors.black : t.colors.foreground).withValues(alpha: a * (i + 1) / 4),
        offset: off[i],
        blurRadius: bl[i],
      ),
    ];
  }

  // —— 主色渐变（品牌氛围用） ——
  static LinearGradient primaryGradient(BuildContext context) {
    final c = context.theme.colors.primary;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c, Color.lerp(c, Colors.black, 0.22)!],
    );
  }

  // —— 语义软底（success / warn / info，用于打卡/提醒/同步状态） ——
  static Color soft(BuildContext context, Color base) =>
      base.withValues(alpha: Theme.brightnessOf(context) == Brightness.dark ? 0.22 : 0.12);

  // —— 动效时长 / 曲线（统一节律） ——
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasize = Curves.easeOutBack;
}
```

暗色分层表面（在 `_build` 里把 `FTheme` 的中性色按需叠一层 surface 派生，供 `GlassCard` / 嵌套卡片取用）：
- light：background(由 neutral 给) → surface(#FFF) → surfaceMuted(#F4F4F5)
- dark：background(#0B0B0F) → surface(#16161C) → surfaceMuted(#1F1F27)

> 实现方式：不破坏 forui 的 `FColors`，在 `AppTokens` 里按 brightness 返回派生色，组件取色优先 `AppTokens`。

### 2.2 新增原子组件（`lib/app/ui/` 下新增文件）

| 组件 | 文件 | 说明 | 复用点 |
|---|---|---|---|
| `GlassCard` | `glass_card.dart` | 磨砂玻璃卡：`ClipRRect` + `BackdropFilter`(blur) + 半透明填充 + 1px 高光描边 | 首页横幅、弹层、置顶卡 |
| `GradientButton` | `gradient_button.dart` | 主色渐变按钮，封装 `FButton` 外观 + 按压缩放 | 关键 CTA（创建 / 开始专注） |
| `ShimmerSkeleton` | `shimmer_skeleton.dart` | 骨架屏：渐变扫光占位（自绘或 `shimmer` 包） | 列表 / 详情加载 |
| `AnimatedStat` | `animated_stat.dart` | 数字 count-up（`TweenAnimationBuilder<double>` + 千分位） | 首页统计、番茄流水 |
| `AnimatedCheck` | `animated_check.dart` | 弹簧对勾（`AnimatedContainer` + `CustomPainter` 描边动画） | 习惯打卡 / 待办完成 |
| `StaggerList` | `stagger_list.dart` | 列表入场 stagger 包装（对 children 注入延迟 fade+slide） | 各列表页 |
| `JianliSegmented` | `segmented.dart` | 带动滑块指示的 segmented 控件（替换 todo 过滤的裸 `FButton` 组） | 待办过滤、番茄模式 |
| `ConfettiOverlay` | `confetti_overlay.dart` | 完成庆祝彩带（`confetti` 包或自绘，自动消失） | 连续打卡达成 / 专注结束 |
| `PageHero` | `page_hero.dart` | 列表→详情共享元素（Hero tag） | 笔记 / 电子书封面 |
| `SquircleBox` | `squircle_box.dart` | 超椭圆容器（`ContinuousRectangleBorder` 近似 squircle） | 头像 / 图标底盘 |
| `PageBanner` | `page_banner.dart` | **功能页渐变横幅**（Phase 3→4 新增）：页面专属强调色 `accentGradient` + 白色装饰圆 + 半透明图标盘 + 白字标题/统计（纯数值自动 count-up） | 13 个功能页顶部（色与 Hub 入口对齐） |

> 规则：这些原子组件**只吃 `context.theme` / `AppTokens`**，保持无业务依赖，与现有 `AppCard` / `SectionHeader` / `EmptyState` / `StatBlock` / `RingProgress` 同目录共存，逐步替换而非一次性重写。

### 2.3 现有原子升级（就地改，向后兼容）

- `AppCard`：默认加 `AppTokens.elevation(context, level: 1)`（可由参数关掉），圆角提至 `radiusMd`；`onTap` 时包裹 `ScaleTransition` 轻微缩放（按压 0.97）。
- `RingProgress`：把 `progress` 改为带 `Animation<double>` 的 tween（外部用 `AnimatedBuilder`），倒计时 / 番茄 / 2FA 周期平滑过渡而非跳变；Phase 3→4 追加可选 `trackColor`（放彩色渐变底上传半透明白）。
- `EmptyState`：增加可选 `illustration` 参数（Lottie / SVG 插画），缺省仍是图标；Phase 3→4 缺省图标升级为**主色软底 `SquircleBox` 盘**（76×76）。
- `StatBlock`：内部可选委托给 `AnimatedStat`，旧调用方零改动。

---

## 3. 动效系统（Motion System）

### 3.1 转场系统（页面级）—— `lib/app/anim/jianli_transitions.dart`

自建 `CustomTransitionPage`（**不引 `animations` 包**，避免与 material_ui 的 Material 耦合），提供三类：

```dart
// 推送/详情：共享轴横向滑入 + 淡入
CustomTransitionPage fadeSlidePage(Widget child, GoRouterState s) =>
  CustomTransitionPage(
    key: s.pageKey,
    child: child,
    transitionDuration: AppTokens.base,
    transitionsBuilder: (c, anim, sec, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
            .chain(CurveTween(curve: AppTokens.standard)).animate(anim),
        child: child,
      ),
    ),
  );

// Tab 切换：纯淡入（StatefulShell 内分支）
// 弹层/对话框：forui 自带；如需自定义用 scale+blur 包装
```

在 `app_router.dart` 给全屏路由包 `fadeSlidePage`；底部四分支用淡入（避免导航壳闪）。

> 注意：`StatefulShellRoute.indexedStack` 内分支转场需谨慎，先只做淡入；若果壳抖动，回退到默认。

### 3.2 微交互（组件级）

| 交互 | 实现 | 落点 |
|---|---|---|
| 卡片按压 | `ScaleTransition`(0.97) + `HapticFeedback.lightImpact()` | `AppCard.onTap` |
| 列表入场 | `StaggerList`（每项延迟 40ms fade+slideY 8px） | 各列表页 ListView |
| 数字滚动 | `AnimatedStat` | 首页 / 番茄统计 |
| 勾选完成 | `AnimatedCheck` spring + 轻微 confetti（仅连续达成） | 习惯 / 待办 |
| 过滤切换 | `JianliSegmented` 滑块指示（emphasize 曲线） | 待办 / 番茄 |
| Tab 指示 | 底部导航选中项图标 `scale` 弹跳 + 渐变指示条 | `MainShell` |
| 下拉刷新 | 自定义 `RefreshIndicator` 颜色/弧度（或 liquid 指示） | 首页 / 列表 |
| 弹层/对话 | scale(0.96→1) + 淡入，spring 回弹 | `showFSheet` / `showFDialog` 包装 |
| 主题切换 | 背景色 `AnimatedContainer` 过渡 | `app.dart` 的 `FTheme` 包裹 |
| 共享元素 | `Hero` tag 列表→详情 | 笔记 / 电子书 |

### 3.3 触感反馈（Haptics）—— `lib/app/anim/jianli_haptics.dart`

```dart
void haptic(HapticType type) {
  if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations) return;            // 减弱动效时跳过
  switch (type) {
    case HapticType.light: HapticFeedback.lightImpact();
    case HapticType.medium: HapticFeedback.mediumImpact();
    case HapticType.success: HapticFeedback.mediumImpact(); // + 可选 confetti
  }
}
```

### 3.4 降级（Accessibility）

- 所有动效入口读取 `MediaQuery.of(context).disableAnimations`：
  - 为 true 时，转场退化为无时长淡入、`StaggerList` 退化直出、`AnimatedStat` 直接显示终值。
- 封装 `JianliMotion.enabled(context)` 统一判断，组件内调用。

---

## 4. 推荐依赖（写入 `pubspec.yaml`）

| 包 | 版本（建议，以 pub 实际为准） | 用途 | 约束说明 |
|---|---|---|---|
| `flutter_staggered_animations` | ^0.3.1 | 列表 stagger 入场 | 纯 widget，安全 |
| `shimmer` | ^3.0.0 | 骨架屏扫光 | 纯 widget，安全 |
| `confetti` | ^0.8.0 | 完成庆祝 | 纯 widget，安全；可自绘替代 |
| `flutter_animate` | ^4.5.0 | 微交互链（延迟/链式/then） | 第三方内部用 flutter/material，**允许**；我们文件仍 import material_ui |
| `lottie` | ^4.0.0 | 空态 / 引导插画（可选） | 需放 assets；非必须 |

> **不引入** `animations`（Material 耦合重，易与 material_ui 冲突）。页面转场一律自建 `CustomTransitionPage`。
> 安装前确认 Flutter 3.47 / Dart 3.13 兼容，跑 `flutter pub get` 后 `flutter analyze` 过基线。

---

## 5. 实施路线（分阶段，可独立验收）

### Phase 0 — 地基（无视觉破坏）✅ 2026-09-05 完成
- [x] `app_theme.dart` 加 `AppTokens`（形状/阴影/渐变/语义软底/动效时长曲线）。
- [x] 新增 `lib/app/anim/{jianli_transitions,jianli_haptics,jianli_motion}.dart`。
- [x] `app_router.dart` 接入 `fadeSlidePage`；`app.dart` 主题切换加 `AnimatedContainer`。
- [x] 验收：`flutter analyze` 0 问题 / `flutter test` 5/5 基线通过。

> 落地实况：额外新增 `TapScale`（按压缩放，AppCard 与 GradientButton/SquircleBox 共用）；`fadePage` 已写好但**暂未接入**底部四分支（导航壳 indexedStack，转场留 Phase 2）。

### Phase 1 — 原子升级 ✅ 2026-09-05 完成（构建待用户本地验证）
- [x] 新增 `TapScale` / `GlassCard` / `GradientButton` / `ShimmerSkeleton` / `AnimatedStat` / `AnimatedCheck` / `StaggerList` / `JianliSegmented` / `ConfettiOverlay` / `PageHero` / `SquircleBox`。
- [x] `AppCard` 加默认 elevation + 按压缩放；`RingProgress` 动画化；`StatBlock` 接 `AnimatedStat`；`EmptyState` 加插画位。
- [ ] 验收：**构建/真机手感待用户本地执行**（Agent 侧无 GUI 且后台构建过慢，已改为给命令由用户跑，见「构建与运行」）。

> 落地实况：`ShimmerSkeleton` 与 `ConfettiOverlay` **自实现、零新依赖**（优于引 `shimmer`/`confetti` 包）；
> lint/类型问题已全修，7 条动效组件开发雷区已固化到 `SKILL.md`「UI 现代化与动效」章节。

### Phase 2 — 壳与导航
- [ ] `MainShell` 底部导航选中态动效（图标弹跳 + 渐变指示条）。
- [ ] `JianliSegmented` 替换 todo 过滤裸 `FButton` 组；番茄模式同步。
- [ ] 下拉刷新自定义指示。
- [ ] 验收：四 Tab 切换顺滑、无果壳抖动。

### Phase 3 — 逐屏动效
- [ ] 首页 `DashboardPage`：`StaggerList` 入场 + `AnimatedStat` 统计 count-up + 横幅 `GlassCard`/`GradientButton`。
- [ ] 习惯 `HabitPage`：打卡 `AnimatedCheck` spring + 连续达成 `ConfettiOverlay` + 卡片按压 haptic。
- [ ] 待办 `TodoPage`：`JianliSegmented` 滑块 + 勾选动画 + 滑动删除保留并加 haptic。
- [ ] `hub_pages`：入口卡 stagger 入场 + 图标底盘 `SquircleBox`。
- [ ] 弹层/对话：`showFSheet`/`showFDialog` scale 入场包装。
- [ ] 验收：逐屏走查 + 真机录屏对比。

### Phase 3.5 — 全页彩焕「PageBanner 渐变横幅」✅ 2026-09-05 完成（静态检查过，观感待用户真机验证）
- [x] 新增 `lib/app/ui/page_banner.dart`：页面专属强调色渐变横幅（accentGradient + 装饰圆 + 半透明图标盘 + 白字统计行，`accentIndex` 与 Hub 入口色对齐）。
- [x] 13 个功能页接线：habit 绿(2) / todo 蓝(1) / pomodoro+records 红(6) / countdown 紫(0，大计时器整卡渐变 + 白色进度环) / reminder 琥珀(3) / notes 琥珀(3，详情分类软底 chip) / conversation 粉(4，消息气泡 accentSoft 软底) / bookshelf 青(5，CustomScrollView+SliverGrid) / 2FA 紫(0，解锁表单渐变盘) / 密码库 蓝(1) / 保险箱 绿(2) / QR 琥珀(3，横幅置于 FTabs 上方) / 同步 青(5)。
- [x] 组件增强：`RingProgress` 加可选 `trackColor`；`EmptyState` 缺省图标升级主色软底盘。
- [x] 顺手清理：删 habit `_WeekStrip` 死代码；清 4 条存量 lint（unused_element / curly_braces ×2 / settings_panel 补 mounted 守卫）。
- [ ] 验收：`flutter analyze` / `flutter test` / `flutter run -d emulator-5554` **由用户本地执行**（分工铁律，见 §6.5）。

### Phase 4 — 点睛与无障碍
- [ ] 空态插画（Lottie / SVG）。
- [ ] 完成庆祝（专注结束、连续打卡）。
- [ ] 全量 `JianliMotion.enabled` 降级路径接通。
- [ ] 暗色分层表面打磨。
- [ ] 验收：开启系统「减弱动态效果」后无不适动画。

### Phase 5 — 收口
- [ ] `flutter analyze` + `flutter test` 过基线；`flutter run` 真机验证；`flutter build apk` 通过。
- [ ] 同步 `SKILL.md`：功能域清单加「UI 现代化」状态；维护说明加新雷区（转场/动效与 material_ui 约束）。

---

## 6. 风险与对策

| 风险 | 对策 |
|---|---|
| 动效库与 material_ui 的 Material 类冲突，断 Theme | 页面文件坚持 import material_ui；禁用 `animations` 包；转场自建 |
| `FTabs` 内含动画 viewport 触发无界高度白屏 | 动画内容仍遵循 `expands: true` 雷区 |
| `BackdropFilter` 过多掉帧 | 玻璃仅用于首页横幅/弹层，列表用 elevation 而非 blur |
| 动效打断 `StatefulShellRoute` 状态保持 | Tab 转场只用淡入，不重建子树 |
| 减弱动态效果未生效 | 所有动效经 `JianliMotion.enabled` 统一开关 |
| 真机性能（中低端机） | 列表 stagger 上限 12 项批量；count-up 用 `Ticker` 限帧 |

---

## 6.5 构建与运行（**全部命令由用户本地执行**，Agent 不代跑任何 flutter/dart 命令）

> **分工铁律（2026-09-05 用户明确指示，取代旧「30 秒规则」与「Agent 可跑 analyze/test」口径）**：
> **Agent 只负责写代码与改文档；一切 flutter/dart 命令（analyze / test / build / run / pub get / build_runner…）一律由用户在本地终端执行。**
> 实踩依据：① Agent 侧无图形界面，无法观感验证；② 后台构建过慢（3~4 分钟仍未完）；③ 经 Git Bash 调用 `dart.bat`/`flutter.bat` 包装脚本因本机 PowerShell 会话损坏直接失败（`InitialSessionState` 乱码报错），`dart.exe` 直连能跑 `analyze` 但 flutter tool 拉 git 子进程报「目录名称无效」——与其绕环境，不如全部交用户。
> Agent 职责止于：改码 → 把下方命令清单原样交给用户 → 等用户回贴结果再继续修。

### 前置（每个新 shell 必设，缺一必踩）
```bash
export TMP=C:\src\tmp TEMP=C:\src\tmp                                            # 中文用户名雷区（C:\Users\风起 会让 Dart 自举失败）
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn   # 国内镜像，勿继承旧 cernet 变量
cd /c/cod/jianli/jianli-mobile-app

# 【可选】SDK 工具入 PATH（本机 adb 默认不在 PATH，直接敲 adb 会 command not found / exit 127）
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"
```

### 本机 Android 环境（2026-09-05 实测固定值）
| 项 | 路径 / 值 |
|---|---|
| **Android SDK** | **`C:\apps\Android\AndroidSDK`**（非默认位置，`ANDROID_HOME`/`ANDROID_SDK_ROOT` 默认未设置） |
| adb | `C:\apps\Android\AndroidSDK\platform-tools\adb.exe` |
| emulator | `C:\apps\Android\AndroidSDK\emulator\emulator.exe` |
| system image | `android-34`（Android 14） |
| **AVD 名称** | **`Pixel_8`**（`C:\Users\风起\.android\avd\Pixel_8.avd`） |
| 在线设备 id | `emulator-5554` |

**启动模拟器**（没有在线设备时先做这步）：
```bash
/c/apps/Android/AndroidSDK/emulator/emulator.exe -avd Pixel_8 &     # 方式 1：直接拉起 AVD（最稳）
flutter emulators --launch Pixel_8                                  # 方式 2：交给 Flutter（本机列表时常为空，不可尽信）
# 方式 3：Android Studio → Device Manager → 启动 Pixel_8（GUI，最省事）
```

### A. 一键编译并启动（看效果最快，推荐）
```bash
flutter devices                  # 确认设备 id（已验证：sdk gphone64 x86 64 → android-x64 → emulator-5554，Android 14）
flutter run -d emulator-5554     # 编译 + 安装 + 启动，可直接看 Phase 0/1 动效
```

### B. 只出 debug APK 再手动装（改一次装一次更快）
```bash
flutter build apk --debug --target-platform android-x64
adb install build/app/outputs/flutter-apk/app-x64-debug.apk
adb shell monkey -p <applicationId> 1                    # 启动；applicationId 以 android/app/build.gradle.kts 为准
adb shell am start -n <applicationId>/.MainActivity      # 等价显式启动
```

### 排障要点
- **`No supported devices found with name or id matching 'emulator-5554'`** → 模拟器进程根本没在跑（**不是 id 写错**）。先 `tasklist | grep -iE "qemu|emulator"` 确认无进程，再按上面「启动模拟器」拉起来，然后 `flutter devices` 复查。（2026-09-05 实踩：刚跑完 `flutter devices` 看到设备，随后进程退出就报这个错）
- **`adb: command not found`（exit 127）** → 本机 adb 不在 PATH。用全路径 `C:\apps\Android\AndroidSDK\platform-tools\adb.exe`，或按上面把 `platform-tools` 加进 PATH。
- **`flutter emulators` 无输出 / exit 1** → 本机该命令不可靠（列表可能为空）。**别据此判断「没有 AVD」**——AVD 一直在 `C:\Users\风起\.android\avd\Pixel_8.avd`。
- 查包名：`adb shell cmd package list packages | grep jianli`。
- **冷启动抓日志**：`am start` 对已运行应用只是切前台（result code=3），必须先 `adb shell am force-stop <pkg>` 再冷启动。
- build_runner 若报错 `Unable to read program.dill` → 就是 `%TEMP%` 含中文，确认上面 TMP/TEMP 已 export。
- 静态检查也交用户跑：`flutter analyze`（当前基线 0 问题，2026-09-05 全页彩焕后）、`flutter test`（基线 5/5）。Agent 侧不要代跑（见上分工铁律）；若未来确需诊断，`dart.bat`/`flutter.bat` 包装脚本会因 PowerShell 会话损坏失败，`dart.exe` 直连仅 `analyze` 可用、`test` 会在 flutter tool 拉 git 时报「目录名称无效」。

---

## 7. 验收标准（Done 定义）

1. `flutter analyze` 0 问题、`flutter test` 5/5 基线通过、`flutter build apk` 成功。
2. 首页 / 习惯 / 待办 / 分组页均有「入场 stagger + 主色点缀 + 按压反馈」。
3. 页面切换有统一转场；打卡 / 完成有庆祝反馈；加载有骨架屏。
4. 开启系统「减弱动态效果」后动画自动降级，功能不受影响。
5. 全程未破坏 forui Theme 继承链、未引入 material_ui / flutter/material 混用。
