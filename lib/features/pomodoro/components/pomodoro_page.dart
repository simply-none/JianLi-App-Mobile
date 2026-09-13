// 番茄钟页 —— 三种展示效果（存 basic_info 基础键值表，用户拍板不与 reminders 混存）：
//   normal   普通：主色横幅 + 白卡进度环 + 页底操作条（⚙设置 + ▶重新开始）；⟳ 可切横竖屏
//   clean    清爽：仅内容卡片（进度环大字）+ 设置图标 + 「开始专注」文字按钮（不与时间区抢色）
//   landscape 横屏：大字倒计时（当前字体放大占满全屏，固定 HH:mm:ss，2026-09-13
//     像素级还原布局公式复杂且小屏易算出负尺寸导致进入卡顿闪退，改单 painter 轻量点阵）
//
// 启动语义对齐 PC 持久版（restartStatefulRound）：写 reminders.startTime=now +
// enabled='1'，状态机从专注重开；行不存在先落种子配置（专注 35 / 休息 5）。
// 阶段到点通知由 reschedulePhaseNotifications 排原生 AlarmManager（App 被杀也能触发）。
// 横竖屏：normal 模式头部 ⟳ 循环 auto（跟随系统）/竖/横（偏好持久化 pomodoro.orientation）；
// clean 锁竖屏、landscape 锁横屏（模式即方向）；**离开页面一律恢复跟随系统**（不污染其他页）。
// 长按整页仍可打开配置编辑（与设置按钮同一入口）。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/card_textures.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/ring_progress.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/pomodoro_state_machine.dart';
import '../repositories/pomodoro_repository.dart';

/// 展示效果中文标签（取值清单见仓库 kDisplayModes）
const Map<String, String> kDisplayLabels = {
  'normal': '普通',
  'clean': '清爽',
  'landscape': '横屏',
};

/// 番茄钟页
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  PomodoroSnapshot? _snapshot;
  String? _error;
  Timer? _ticker;

  /// 展示效果（basic_info 键值，normal/clean/landscape）
  String _display = 'normal';

  /// 横竖屏偏好（仅 normal 生效）：auto=跟随系统 / portrait=锁竖 / landscape=锁横
  String _orientationMode = 'auto';

  static const String _kOrientationPref = 'pomodoro.orientation';

  @override
  void initState() {
    super.initState();
    // initState 里不能 read provider，首次加载放到首帧后（见 build 前 didChangeDependencies）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
      _restoreSettings();
      // 进页即重排下两个阶段边界通知（App 长驻后计划仍保鲜）
      PomodoroRepository(ref.read(appDatabaseProvider))
          .reschedulePhaseNotifications();
    });
    // 每秒重算快照（基于 startTime 的纯函数，无副作用）
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _reload());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // ⚠️ 离开页面一律恢复「跟随系统」——横竖屏是页面级设置，不污染其他页面
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// 恢复展示效果 + 横竖屏偏好并应用
  Future<void> _restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrientation = prefs.getString(_kOrientationPref) ?? 'auto';
    final display = await PomodoroRepository(ref.read(appDatabaseProvider))
        .loadDisplay();
    if (!mounted) return;
    setState(() {
      _orientationMode = savedOrientation;
      _display = display;
    });
    await _applyOrientation();
  }

  /// 按展示效果 + （normal 时的）横竖屏偏好算目标方向
  Future<void> _applyOrientation() {
    final orientations = switch (_display) {
      'clean' => [DeviceOrientation.portraitUp],
      'landscape' => [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      // normal：跟随 ⟳ 偏好；auto 全开 = 跟随系统重力，系统锁了旋转则保持当前方向
      _ => switch (_orientationMode) {
        'portrait' => [DeviceOrientation.portraitUp],
        'landscape' => [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        _ => DeviceOrientation.values,
      },
    };
    return SystemChrome.setPreferredOrientations(orientations);
  }

  /// 头部 ⟳（仅 normal 展示效果）：自动 → 竖屏 → 横屏 → 自动，偏好持久化
  Future<void> _cycleOrientation() async {
    final next = switch (_orientationMode) {
      'auto' => 'portrait',
      'portrait' => 'landscape',
      _ => 'auto',
    };
    setState(() => _orientationMode = next);
    await _applyOrientation();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOrientationPref, next);
    if (!mounted) return;
    showFToast(
      context: context,
      title: Text(switch (next) {
        'portrait' => '已锁定竖屏',
        'landscape' => '已锁定横屏',
        _ => '跟随系统旋转',
      }),
    );
  }

  Future<void> _reload() async {
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    try {
      final snapshot = await repo.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// 启动 / 重新开始一轮（写 startTime=now + enabled='1'，PC 持久版语义）
  Future<void> _start() async {
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    await repo.startRound();
    if (!mounted) return;
    showFToast(context: context, title: const Text('已开始专注'));
    _reload();
  }

  /// 设置按钮 / 长按页面 → 编辑番茄钟配置（时长 + 展示效果，PC 同源）
  Future<void> _showConfigSheet() async {
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    final states = await repo.loadStates();
    if (!mounted) return;
    int minutesOf(String key, int fallback) {
      for (final s in states) {
        if (s.key == key) return (s.durationSeconds / 60).ceil();
      }
      return fallback;
    }

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (_) => _PomodoroConfigSheet(
        workMinutes: minutesOf('work', 35),
        restMinutes: minutesOf('rest', 5),
        display: _display,
      ),
    );
    if (!mounted) return;
    // 展示效果可能被改：重读并应用（方向 + 布局）
    final display = await repo.loadDisplay();
    if (!mounted) return;
    setState(() => _display = display);
    await _applyOrientation();
    _reload();
  }

  /// 手动记一条流水（演示写路径；自动化记录随 P2 完整交互接入）
  Future<void> _record() async {
    final snapshot = _snapshot;
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    await repo.recordStatus(
      label: snapshot?.currentState.label ?? '手动记录',
      value: snapshot?.currentState.key ?? 'work',
      mode: 'mobile',
    );
    if (mounted) {
      showFToast(context: context, title: const Text('已写入番茄钟流水'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        // 全局渐变背板由 app.dart 根容器绘制，页面保持透明以透出背板
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(
                // 长按整页 → 编辑配置（与设置按钮同一入口）
                child: GestureDetector(
                  onLongPress: _showConfigSheet,
                  behavior: HitTestBehavior.deferToChild,
                  child: snapshot == null
                      ? _emptyState(context)
                      : switch (_display) {
                          'clean' => _cleanBody(context, snapshot),
                          'landscape' => _segmentBody(context, snapshot),
                          _ =>
                            MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? _normalLandscapeBody(context, snapshot)
                                : _normalPortraitBody(context, snapshot),
                        },
                ),
              ),
              // ⚠️ normal 模式操作条固定页底（不随内容滚动，§1.8 同款心智）；
              // 清爽/横屏模式的按钮在各自布局里（设置在头部、开始专注为文字钮）
              if (snapshot != null && _display == 'normal')
                _normalBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部 =====================
  // normal：‹ / 番茄钟 / ⟳ 横竖屏 / ⏱ 手动记录（⚙ 在页底操作条）
  // clean·landscape：‹ / 番茄钟 / ⚙ 设置（模式即方向，无 ⟳；按钮不与时间区抢色）

  Widget _header(BuildContext context) {
    final t = context.theme;
    final normal = _display == 'normal';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: () => context.pop(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
          Expanded(
            child: Text(
              '番茄钟',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          if (normal)
            TapScale(
              onTap: _cycleOrientation,
              child: Icon(
                FLucideIcons.rotateCw,
                size: 20,
                color: _orientationMode == 'auto'
                    ? t.colors.foreground
                    : t.colors.primary,
              ),
            ),
          if (normal && _snapshot != null)
            TapScale(
              onTap: _record,
              child: Icon(
                FLucideIcons.timer,
                size: 20,
                color: t.colors.foreground,
              ),
            ),
          if (!normal)
            TapScale(
              onTap: _showConfigSheet,
              child: Icon(
                FLucideIcons.settings,
                size: 20,
                color: t.colors.foreground,
              ),
            ),
        ],
      ),
    );
  }

  // ===================== normal：横幅 + 进度环（可滚动），操作条在页底 =====================

  Widget _normalPortraitBody(BuildContext context, PomodoroSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        _banner(context, snapshot),
        const SizedBox(height: 8),
        _ringCard(context, snapshot),
      ],
    );
  }

  /// normal 横屏：左列横幅 + 右列大进度环
  Widget _normalLandscapeBody(BuildContext context, PomodoroSnapshot snapshot) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_banner(context, snapshot)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Center(child: _ringCard(context, snapshot, compact: true)),
          ),
        ],
      ),
    );
  }

  /// normal 页底操作条：「⚙ 设置」+「▶ 重新开始」
  Widget _normalBottomBar(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        8,
        AppTokens.pagePadding,
        AppTokens.pageBottomGapOf(context),
      ),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: _showConfigSheet,
            child: Container(
              height: 48,
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Icon(
                FLucideIcons.settings,
                size: 20,
                color: t.colors.foreground,
              ),
            ),
          ),
          Expanded(
            child: GradientButton(
              label: '重新开始',
              icon: FLucideIcons.play,
              onPress: _start,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== clean 清爽：仅内容卡片 + 低调按钮 =====================

  Widget _cleanBody(BuildContext context, PomodoroSnapshot snapshot) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.pagePadding,
              ),
              child: _ringCard(context, snapshot, showCaption: false),
            ),
          ),
        ),
        // 「开始专注」文字按钮（无底色，不与时间区抢色）
        Padding(
          padding: EdgeInsets.only(bottom: AppTokens.pageBottomGapOf(context)),
          child: _textAction(context, label: '开始专注', onTap: _start),
        ),
      ],
    );
  }

  // ===================== landscape 横屏：大字倒计时（2026-09-13 定案） =====================

  /// 横屏展示主体：当前字体放大、固定 HH:mm:ss、占满全屏。
  /// ⚠️ 不再使用任何自绘时钟（七段数码管 / 点阵两版均在小屏约束下闪退）——
  /// 纯 Text + FittedBox(scaleDown) 兜底：字号给足，超宽只缩小显示，绝无溢出崩溃。
  Widget _segmentBody(BuildContext context, PomodoroSnapshot snapshot) {
    final t = context.theme;
    final s = snapshot.remainingSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String pad(int v) => v.toString().padLeft(2, '0');
    final timeText = '${pad(h)}:${pad(m)}:${pad(sec)}';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 大字时间：占满全屏宽（FittedBox 只缩不放，安全兜底）
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                timeText,
                textAlign: TextAlign.center,
                style: t.typography.body.lg.copyWith(
                  fontSize: 120,
                  fontWeight: FontWeight.w700,
                  color: t.colors.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            snapshot.currentState.label,
            style: t.typography.body.sm.copyWith(
              color: t.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 22),
          _textAction(context, label: '开始专注', onTap: _start),
        ],
      ),
    );
  }

  /// 统计横幅（normal 模式；主色渐变，与待办同款；title = 当前阶段）
  Widget _banner(BuildContext context, PomodoroSnapshot snapshot) => PageBanner(
    icon: FLucideIcons.timer,
    title: snapshot.currentState.label,
    subtitle: '完成后自动进入下一阶段',
    gradient: AppTokens.accentGradient(AppTokens.accent(6)),
    cornerRadius: 22,
    textureAsset: CardTextures.texture11,
    ringDecor: true,
    shadow: false,
    margin: EdgeInsets.zero,
    stats: [
      (_formatSeconds(snapshot.remainingSeconds), '本阶段剩余'),
      ('${snapshot.cycleSeconds ~/ 60}', '周期(分钟)'),
    ],
  );

  /// 阶段语义色：专注=番茄红 / 休息=绿（记录页同口径）；其余走主色
  Color _phaseColor(BuildContext context, PomodoroSnapshot snapshot) {
    final t = context.theme;
    return snapshot.currentState.key == 'work'
        ? AppTokens.accent(6)
        : snapshot.currentState.key == 'rest'
        ? AppTokens.accent(2)
        : t.colors.primary;
  }

  /// 阶段进度环（白卡承托：阶段 SoftChip + 主色进度环 + 大字剩余）。
  /// [compact]=normal 横屏：环径按卡片可用高度自适应（竖屏/清爽固定 200，ListView 高度无界）；
  /// [showCaption]=底部说明文字（清爽模式关闭，界面更净）。
  Widget _ringCard(
    BuildContext context,
    PomodoroSnapshot snapshot, {
    bool compact = false,
    bool showCaption = true,
  }) {
    final t = context.theme;
    final phaseColor = _phaseColor(context, snapshot);
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
      child: LayoutBuilder(
        builder: (context, cons) {
          // 横屏：环径 = 卡片高 - 芯片/说明文字的预留（钳在 120~200）
          final ringSize = compact
              ? (cons.maxHeight - 92).clamp(120.0, 200.0)
              : 200.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SoftChip(
                label: snapshot.currentState.label,
                color: phaseColor,
                leading: Icon(
                  snapshot.currentState.key == 'rest'
                      ? FLucideIcons.coffee
                      : FLucideIcons.briefcase,
                  size: 11,
                  color: phaseColor,
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              RingProgress(
                progress: snapshot.progress,
                size: ringSize,
                strokeWidth: 10,
                color: phaseColor,
                trackColor: t.colors.muted,
                child: Text(
                  _formatSeconds(snapshot.remainingSeconds),
                  style: t.typography.body.lg.copyWith(
                    fontSize: compact ? 34 : 44,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (showCaption) ...[
                SizedBox(height: compact ? 10 : 16),
                Text(
                  '点「重新开始」从专注阶段重开一轮',
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 清爽/横屏模式的低调文字按钮（无底色、主题前景色，不与时间区抢色）
  Widget _textAction(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final t = context.theme;
    return TapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          label,
          style: t.typography.body.sm.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: t.colors.foreground,
          ),
        ),
      ),
    );
  }

  /// 配置缺失 / 未启用的空态：直接给「启动」入口（种子配置由 startRound 落库）
  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyState(
            icon: FLucideIcons.timer,
            title: _error ?? '番茄钟未启动',
            subtitle: '启动后按「专注 35 分钟 / 休息 5 分钟」循环，到点弹系统通知',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GradientButton(
              label: '启动',
              icon: FLucideIcons.play,
              onPress: _start,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

/// 编辑番茄钟配置弹层（md 档输入类）：专注/休息时长 + 展示效果。
/// 时长与桌面端同源 —— 写 reminders.id='pomodoro' 行的 states JSON；
/// 展示效果存 basic_info 基础键值表（用户拍板：不与计时字段混存一表）。
class _PomodoroConfigSheet extends ConsumerStatefulWidget {
  const _PomodoroConfigSheet({
    required this.workMinutes,
    required this.restMinutes,
    required this.display,
  });

  final int workMinutes;
  final int restMinutes;
  final String display;

  @override
  ConsumerState<_PomodoroConfigSheet> createState() =>
      _PomodoroConfigSheetState();
}

class _PomodoroConfigSheetState extends ConsumerState<_PomodoroConfigSheet> {
  late final TextEditingController _work;
  late final TextEditingController _rest;
  late String _display;

  @override
  void initState() {
    super.initState();
    _work = TextEditingController(text: '${widget.workMinutes}');
    _rest = TextEditingController(text: '${widget.restMinutes}');
    _display = widget.display;
  }

  @override
  void dispose() {
    _work.dispose();
    _rest.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final work = int.tryParse(_work.text.trim()) ?? 0;
    final rest = int.tryParse(_rest.text.trim()) ?? 0;
    if (work <= 0 || rest <= 0) {
      showFToast(context: context, title: const Text('专注/休息时长需大于 0 分钟'));
      return;
    }
    final repo = PomodoroRepository(ref.read(appDatabaseProvider));
    repo.updateDurations(workMinutes: work, restMinutes: rest);
    // ⚠️ 必须 await：页面在弹层关闭后立即 loadDisplay 读回展示效果，晚写会读到旧值
    await repo.saveDisplay(_display);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '编辑番茄钟',
      // 内含输入框 → lg 80vh 定高（2026-09-13 全局定案）
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetFieldLabel('专注（分钟）'),
          SheetInputBox(
            controller: _work,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const SheetFieldLabel('休息（分钟）'),
          SheetInputBox(
            controller: _rest,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // 展示效果：清爽 / 普通 / 横屏（存 basic_info 基础键值表）
          const SheetFieldLabel('展示效果'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in PomodoroRepository.kDisplayModes)
                SheetChoiceChip(
                  label: kDisplayLabels[mode] ?? mode,
                  selected: _display == mode,
                  onTap: () => setState(() => _display = mode),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '时长与桌面端同源；横屏为大字倒计时（HH:mm:ss 占满全屏），清爽仅保留时间卡片',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
      bottomBar: sheetBottomActions(
        context,
        actionLabel: '保存',
        actionIcon: FLucideIcons.check,
        onAction: _save,
      ),
    );
  }
}
