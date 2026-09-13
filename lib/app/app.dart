// 应用根组件 —— MaterialApp.router + forui 主题装配
//
// 结构：material_ui 的 MaterialApp.router（forui 建立在 material_ui 之上，
//       勿改回 flutter/material——两套平行 Material 类，混用会断 Theme 继承链）
//       └─ builder 注入 FTheme（跟随 themeMode + 选中样式）+ FToaster（全局 toast）+ FTooltipGroup
// 本地化：FLocalizations.localizationsDelegates 已内置 Global Material/Cupertino/Widgets
//       三件套，且支持 zh（115 种语言），无需再单独引 flutter_localizations。
// 主题：样式与主色取自 themeStyleProvider，模式取自 themeModeProvider（均持久化）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/android/system_actions.dart';
import 'providers/theme_providers.dart';
import 'security/vault_auto_lock.dart';
import 'theme/app_theme.dart';
import 'theme/jianli_palette.dart';
import 'router/app_router.dart';
import 'di/app_providers.dart';
import 'alarm_bootstrap.dart';

/// 渐离App移动端根组件
class JianliApp extends ConsumerStatefulWidget {
  const JianliApp({super.key});

  @override
  ConsumerState<JianliApp> createState() => _JianliAppState();
}

/// 根组件状态：挂接 App 生命周期监听——应用隐藏（切后台/多任务/被杀）即锁全部隐私保险箱。
class _JianliAppState extends ConsumerState<JianliApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 到点提醒引导（首帧后跑一次）：通知权限 + 提醒重排 + 倒计时补账 + 番茄钟阶段通知。
    // initState 里不能同步 read provider（会断 Riverpod 生命期断言），放首帧回调。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      bootstrapAlarms(ref.read(appDatabaseProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用隐藏即锁掉全部隐私保险箱（2FA / 密码库 / 文件保险箱），
    // 避免切后台后被他人直接看到已解锁的明文。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      lockAllVaults(ref);
    }
    // 回到前台 → 到点提醒自愈重排（节流 5 分钟）：
    // 系统/ROM 在后台清理过原生 AlarmManager 计划后，用户随手打开一次 App 就自动恢复，
    // 否则「不再进提醒页就永远不恢复」——那是提醒失效的主因。
    if (state == AppLifecycleState.resumed) {
      _healAlarms();
    }
    super.didChangeAppLifecycleState(state);
  }

  /// 回前台自愈的节流间隔（避免频繁切前后台时反复查库 + 重排原生计划）
  static const Duration _healThrottle = Duration(minutes: 5);

  DateTime? _lastHealAt;
  bool _healing = false;

  /// 回到前台时自愈：重排全部启用提醒（防原生计划被清理）+ 确保保活服务在跑。
  ///
  /// ⚠️ 只做自愈、**不申请权限**（权限只在冷启动 bootstrapAlarms 里申请，回前台反复弹框会骚扰用户）。
  /// 独立 try/catch 包住，任何失败都不影响前后台切换本身。
  Future<void> _healAlarms() async {
    if (_healing) return;
    final now = DateTime.now();
    final last = _lastHealAt;
    if (last != null && now.difference(last) < _healThrottle) return;
    _healing = true;
    _lastHealAt = now;
    try {
      final db = ref.read(appDatabaseProvider);
      await healAlarmSchedules(db);
      await KeepAliveGuard(db).ensureRunning();
    } catch (_) {
      // 自愈失败不阻断：下次回前台/下次冷启动会再试
    } finally {
      _healing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.styleById(
      ref.watch(themeStyleProvider).value ?? 'zi',
    );
    final mode = ref.watch(themeModeProvider).value ?? AppThemeMode.system;
    // 阅览模式（基准字号体系）：普通 12px / 大号 18px，其他字型按比例缩放。
    // 在根组件读取并传进主题构建 → 切换时 MaterialApp.theme + FTheme 全树重渲，必然生效。
    final reading = ref.watch(readingModeProvider).value ?? ReadingMode.normal;
    final baseFontSize = reading == ReadingMode.large
        ? AppTokens.baseFontSizeLarge
        : AppTokens.baseFontSizeNormal;

    return MaterialApp.router(
      title: '渐离App',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      theme: AppTheme.materialLight(style, baseFontSize),
      darkTheme: AppTheme.materialDark(style, baseFontSize),
      themeMode: toMaterialMode(mode),
      routerConfig: appRouter,
      builder: (context, child) {
        final brightness = Theme.brightnessOf(context);
        final isDark = brightness == Brightness.dark;
        // 当前外观色系（每套主题一套，亮/暗各一）：背板渐变浓度 + 三枚光晕透明度同源。
        final isZi = style.id == 'zi';
        final pal = isDark
            ? JianliPalette.dark(style.darkPrimary, zi: isZi)
            : JianliPalette.light(style.lightPrimary, zi: isZi);
        final data = AppTheme.build(
          style: style,
          brightness: brightness,
          baseFontSize: baseFontSize,
        );
        // 全局渐变背板 + 简单图案（大圆/圆环）：所有页面透明（pageTint/FScaffold
        // 均不画底色），背板统一透出——头部/外框/内容无色差、无白边；
        // 主题切换经 AnimatedContainer 平滑过渡（Decoration 渐变可 lerp）。
        //
        // 渐变规格 = 画布「02 导航重设计」的 `背景装饰` 层（三段：顶浓 → 中淡 → 底透明），
        // 统一由 `AppTokens.pageGradientOf` 产出，**列表页吸顶条的覆盖色也从它派生**
        // —— 两处共用一份定义，吸顶条才不会把背板切断（2026-09-12 实踩）。
        return FTheme(
          data: data,
          child: AnimatedContainer(
            duration: AppTokens.base,
            decoration: BoxDecoration(
              gradient: AppTokens.pageGradientOf(data, brightness),
            ),
            child: CustomPaint(
              painter: _BackdropPainter(
                primary: data.colors.primary,
                isDark: isDark,
                pal: pal,
              ),
              // 全局输入行为（单一来源）：**移动端点输入框以外任何地方 → 立刻失焦、收键盘**。
              //
              // 为什么需要这一层：Flutter 自带的默认实现 `_EditableTextTapOutsideAction`
              // 只在桌面端失焦 —— 移动端（android/iOS）遇到 touch 事件**什么都不做**
              //（见 flutter/lib/src/widgets/editable_text.dart，官方注释：desktop platforms only）。
              // 而 EditableText 是用 `Action.overridable` 注册这个 intent 的（官方预留扩展点），
              // 所以只要在祖先挂一个同名 `Actions` 即可覆盖默认行为 —— 一处生效，
              // 覆盖全 App 的输入框（原生 TextField 与 forui FTextField 都走同一条链路）。
              // 「滑动收键盘」另见 `SheetSurface` 里的滚动监听（惯性滚动没有 pointer-down）。
              child: Actions(
                actions: <Type, Action<Intent>>{
                  EditableTextTapOutsideIntent:
                      CallbackAction<EditableTextTapOutsideIntent>(
                    onInvoke: (intent) {
                      intent.focusNode.unfocus();
                      return null;
                    },
                  ),
                },
                child: FToaster(child: FTooltipGroup(child: child!)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 全局背板的简单图案：右上探出大圆 + 左侧中圆 + 右下圆环（极低透明度，
/// 只做氛围不做视觉焦点）。painter 在 child 之下，随主题色/亮暗重绘。
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({
    required this.primary,
    required this.isDark,
    required this.pal,
  });

  final Color primary;
  final bool isDark;

  /// 当前外观色系（提供三枚光晕的透明度）
  final Scheme pal;

  @override
  void paint(Canvas canvas, Size size) {
    // 右上探出大圆
    canvas.drawCircle(
      Offset(size.width - 36, -48),
      150,
      Paint()..color = primary.withValues(alpha: pal.glowAlpha),
    );
    // 左侧中圆
    canvas.drawCircle(
      Offset(-40, size.height * 0.42),
      90,
      Paint()..color = primary.withValues(alpha: pal.glowLeftAlpha),
    );
    // 右下圆环
    canvas.drawCircle(
      Offset(size.width - 70, size.height - 140),
      64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = primary.withValues(alpha: pal.glowRingAlpha),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.isDark != isDark;
}
