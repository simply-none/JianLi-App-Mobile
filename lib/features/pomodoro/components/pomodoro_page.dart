// 番茄钟页 —— **页面内本地计时**（2026-09-13 重构；用户定案：移动端逻辑独立于 PC，用主流番茄钟应用方案）
//
// 与旧版（持久状态机 + 原生 AlarmManager 阶段通知）最大的区别：
//   1. 只有点「开始专注」才起表；**离开页面（dispose）或 App 切后台（paused/hidden）立即停表**；
//      停表后按「周期规则」（basic_info 键 `pomodoro_cycle_rule`）处置**未完成的一轮**：
//        · restart = 未完成重新开始（默认）→ 丢弃进度，下次从专注满时长起；
//        · resume  = 未完成继续上一轮        → 记住**专注阶段**剩余秒数，下次进页面点「继续」接着走；
//      ⚠️ 规则**仅作用于专注阶段**（休息阶段未完成一律丢弃）；进度只在离开时落盘（键 `pomodoro_progress`），
//      走完一轮 / 点「重新开始」/ 规则切回 restart 时清除。
//   2. 「开始专注 / 暂停 / 继续」+「重新开始」；阶段完成自动进入下一阶段（专注↔休息循环）；
//   3. 阶段完成时写一条 `pomodoro_status` 流水（value = work/rest）+ 发提示音（走通知渠道，见下）+ 触感；
//   4. 不再读/写 `reminders.startTime`，不再排任何原生阶段通知；
//   5. 时长配置仍读 `reminders(id='pomodoro').states`（与桌面端同源，设置弹窗照旧读写）。
//
// 提示音：页面在前台时用 `NotificationService.showNow`（番茄钟渠道 playSound + 横幅）——
//   比 `SystemSound.play` 可靠（后者依赖系统「触摸音效」开关，关了就无声）。
//
// 三种展示效果（basic_info 键 `pomodoro_display`）：normal 普通 / clean 清爽 / landscape 横屏大字；
//   展示效果即方向（clean 锁竖 / landscape 锁横 / normal 跟随系统），**离开页面恢复跟随系统**。
// 头部统一 `‹ 番茄钟 [记录][设置]`（已删 ⟳ 横竖屏循环与 `pomodoro.orientation` 偏好）。
// 底部统一 `[开始专注/暂停/继续] [重新开始]`（三种展示效果一致）。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/anim/jianli_haptics.dart';
import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/ring_progress.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/pomodoro_state_machine.dart';
import '../repositories/pomodoro_repository.dart';
import 'pomodoro_records_sheet.dart';

/// 展示效果中文标签（取值清单见仓库 kDisplayModes）
const Map<String, String> kDisplayLabels = {
  'normal': '普通',
  'clean': '清爽',
  'landscape': '横屏',
};

/// 周期规则中文标签（取值清单见仓库 kCycleRules）
const Map<String, String> kCycleRuleLabels = {
  'restart': '未完成重新开始',
  'resume': '未完成继续上一轮',
};

/// 默认阶段（配置缺失/未落库时的兜底：专注 35 / 休息 5）
const PomodoroStateDef _kDefaultWork = PomodoroStateDef(
  key: 'work',
  label: '专注',
  durationSeconds: 35 * 60,
);
const PomodoroStateDef _kDefaultRest = PomodoroStateDef(
  key: 'rest',
  label: '休息',
  durationSeconds: 5 * 60,
);

/// 番茄钟页
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage>
    with WidgetsBindingObserver {
  /// 展示效果（basic_info 键值，normal/clean/landscape）
  String _display = 'normal';

  /// 阶段定义 [work, rest]（时长配置源；页面内计时用）
  List<PomodoroStateDef> _phases = const [_kDefaultWork, _kDefaultRest];

  /// 当前阶段下标（0=专注 / 1=休息）
  int _phaseIndex = 0;

  /// 当前阶段剩余秒数
  int _remainingSeconds = _kDefaultWork.durationSeconds;

  /// 是否已开始过一轮（区分「空闲」与「已暂停」）
  bool _started = false;

  /// 是否正在走表（false 且 _started = 已暂停）
  bool _running = false;

  /// 周期规则（basic_info 键 `pomodoro_cycle_rule`）：未完成的一轮「重新开始」还是「继续上一轮」
  String _cycleRule = PomodoroRepository.kCycleRuleRestart;

  /// 本轮是否「活跃」（已开始且尚未按规则处置）—— 保证「离开」只处置一次
  /// （Android 切后台会连发 hidden + paused，用本开关幂等）
  bool _roundActive = false;

  /// 是否刚从后台返回（resumed 时按需还原未完成进度）
  bool _wentBackground = false;

  /// 离开时暂存的专注剩余秒数（内存兜底：防「切后台→立刻返回」时异步落盘还没写完，
  /// 导致 `resumed` 读库读不到 → 还原失败）；被还原消费后置空，DB 里的值不动。
  int? _pendingResumeSeconds;

  Timer? _ticker;
  String? _error;

  /// 仓库实例缓存 —— `dispose()` 里不能再安全访问 `ref`，
  /// 而离开页面需要落盘未完成进度，故首次取用后缓存复用（db 是全局单例，缓存无副作用）。
  PomodoroRepository? _repoCache;

  PomodoroRepository get _repo =>
      _repoCache ??= PomodoroRepository(ref.read(appDatabaseProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // initState 里不能 read provider，首次加载放到首帧后
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    // 离开页面：按「周期规则」处置未完成的一轮（异步落盘，不阻塞退出）
    _persistOnLeave();
    // ⚠️ 离开页面一律恢复「跟随系统」——横竖屏是页面级设置，不污染其他页面
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// App 切后台（paused/hidden）等同「离开页面」：停表 + 按规则处置未完成的一轮；
  /// 回到前台（resumed）时重读配置 —— 规则为「继续上一轮」且进度有效时还原为「已暂停」，
  /// 等用户点「继续」才接着走（仍遵守「手动开始才计时」）。
  /// ⚠️ `inactive` 是瞬态（下拉通知栏/权限框），不触发，避免误停。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentBackground = true;
      _persistOnLeave();
      _stopAndReset();
    } else if (state == AppLifecycleState.resumed && _wentBackground) {
      _wentBackground = false;
      _loadConfig();
    }
  }

  // ===================== 配置 =====================

  static PomodoroStateDef? _pick(List<PomodoroStateDef> states, String key) {
    for (final s in states) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// 读取展示效果 + 周期规则 + 阶段时长配置，并应用方向。
  ///
  /// **不改动正在走的计时**（`_started == true` 时只刷新配置）；
  /// 空闲时按周期规则决定「剩余时间」从哪来：规则=resume 且存在有效的未完成专注进度 →
  /// 还原为「已暂停」（`_started = true, _running = false`，按钮显示「继续」），否则从专注满时长起。
  Future<void> _loadConfig() async {
    final repo = _repo;
    try {
      final display = await repo.loadDisplay();
      final rule = await repo.loadCycleRule();
      final states = await repo.loadStates();
      final work = _pick(states, 'work') ?? _kDefaultWork;
      final rest = _pick(states, 'rest') ?? _kDefaultRest;

      int? restored;
      if (!_started) {
        if (rule == PomodoroRepository.kCycleRuleResume) {
          // ① 先取「离开时暂存的内存值」（避免异步落盘未完成时的竞态）
          final pending = _pendingResumeSeconds;
          if (pending != null && pending > 0 && pending < work.durationSeconds) {
            restored = pending;
          } else {
            // ② 跨页面/跨启动：读库
            final p = await repo.loadProgress();
            // 有效条件：剩余为正且小于当前专注时长（否则残局无意义 → 清除）
            if (p != null && p.remainingSeconds < work.durationSeconds) {
              restored = p.remainingSeconds;
            } else if (p != null) {
              await repo.clearProgress();
            }
          }
        } else {
          // 规则为「重新开始」：残留进度一律作废
          await repo.clearProgress();
        }
      }

      if (!mounted) return;
      setState(() {
        _display = display;
        _cycleRule = rule;
        _phases = [work, rest];
        _error = null;
        if (!_started) {
          _phaseIndex = 0;
          if (restored != null) {
            _remainingSeconds = restored;
            _started = true; // 已还原 → 按钮显示「继续」
            _running = false;
            _roundActive = false; // 还原但未走表：离开时不覆盖已保存的进度
            _pendingResumeSeconds = null; // 已消费（DB 值保留，供换页/重启后再取）
          } else {
            _remainingSeconds = work.durationSeconds;
            _pendingResumeSeconds = null;
          }
        }
      });
      await _applyOrientation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// 按展示效果应用方向（clean 锁竖 / landscape 锁横 / normal 跟随系统）
  Future<void> _applyOrientation() {
    final orientations = switch (_display) {
      'clean' => [DeviceOrientation.portraitUp],
      'landscape' => [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      _ => DeviceOrientation.values,
    };
    return SystemChrome.setPreferredOrientations(orientations);
  }

  /// 设置按钮 / 长按页面 → 编辑番茄钟配置（时长 + 展示效果，时长与 PC 同源）
  Future<void> _showConfigSheet() async {
    final repo = _repo;
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
        cycleRule: _cycleRule,
      ),
    );
    if (!mounted) return;
    // 时长/展示效果/周期规则可能被改：重读并应用（方向 + 布局 + 未完成进度取舍）
    await _loadConfig();
  }

  // ===================== 计时 =====================

  PomodoroStateDef get _phase => _phases[_phaseIndex];

  int get _phaseDuration => _phase.durationSeconds;

  double get _progress => _phaseDuration <= 0
      ? 0
      : ((_phaseDuration - _remainingSeconds) / _phaseDuration).clamp(0.0, 1.0);

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    if (!mounted || !_running) return;
    if (_remainingSeconds > 1) {
      setState(() => _remainingSeconds--);
      return;
    }
    _completePhase();
  }

  /// 当前阶段到点：写流水 + 提示音/触感，并自动进入下一阶段（继续走表）
  Future<void> _completePhase() async {
    final finished = _phase;
    final nextIndex = (_phaseIndex + 1) % _phases.length;
    final next = _phases[nextIndex];
    setState(() {
      _phaseIndex = nextIndex;
      _remainingSeconds = next.durationSeconds;
      _running = true;
    });
    // 到点反馈：通知渠道提示音 + 横幅（前台可靠发声）+ 触感
    haptic(HapticType.success, context);
    showFToast(
      context: context,
      title: Text('${finished.label}结束 · 进入${next.label}'),
    );
    try {
      await NotificationService.showNow(
        id: NotificationService.stableId('pomodoro:now'),
        channelKey: NotificationChannels.pomodoro,
        title: '${finished.label}结束',
        body: '进入「${next.label}」（约 ${next.durationSeconds ~/ 60} 分钟）',
      );
    } catch (_) {}
    // 写一条流水（value = 完成的阶段 key）
    try {
      await _repo.recordStatus(
        label: finished.label,
        value: finished.key,
        mode: 'mobile',
      );
    } catch (_) {}
  }

  /// 主按钮：空闲→开始 / 运行中→暂停 / 已暂停→继续
  void _toggleRun() {
    if (!_started) {
      // 全新一轮：作废任何残留的未完成进度
      _clearProgress();
      setState(() {
        _phaseIndex = 0;
        _remainingSeconds = _phases.first.durationSeconds;
        _started = true;
        _running = true;
        _roundActive = true;
        _pendingResumeSeconds = null;
      });
      _startTicker();
      return;
    }
    if (_running) {
      setState(() {
        _roundActive = true;
        _running = false;
      });
      _stopTicker();
    } else {
      setState(() {
        _roundActive = true;
        _running = true;
      });
      _startTicker();
    }
  }

  /// 重新开始：丢弃当前进度，回到「专注」满时长并立即走表（全新一轮）
  void _restart() {
    _stopTicker();
    // 丢弃进度 = 已保存的未完成进度一并作废
    _clearProgress();
    setState(() {
      _phaseIndex = 0;
      _remainingSeconds = _phases.first.durationSeconds;
      _started = true;
      _running = true;
      _roundActive = true;
      _pendingResumeSeconds = null;
    });
    _startTicker();
  }

  /// 停表并复位到「空闲」（离开页面 / 切后台）
  void _stopAndReset() {
    _stopTicker();
    _roundActive = false;
    if (!mounted) return;
    setState(() {
      _started = false;
      _running = false;
      _phaseIndex = 0;
      _remainingSeconds = _phases.first.durationSeconds;
    });
  }

  // ===================== 周期规则：未完成进度的落盘 / 清除 =====================

  /// 离开页面 / 切后台时按「周期规则」处置未完成的一轮（`_roundActive` 保证每轮只处置一次）。
  /// 规则**仅作用于专注阶段**——休息阶段未完成一律丢弃。
  void _persistOnLeave() {
    if (!_roundActive) return;
    _roundActive = false;
    final repo = _repo;
    final unfinishedWork = _phaseIndex == 0 && _remainingSeconds > 0;
    final resume = _cycleRule == PomodoroRepository.kCycleRuleResume;
    // 内存兜底（供「切后台→立刻返回」即时还原，不受异步落盘时序影响）
    _pendingResumeSeconds = (resume && unfinishedWork) ? _remainingSeconds : null;
    if (resume && unfinishedWork) {
      unawaited(_saveProgress(repo, _remainingSeconds));
    } else {
      unawaited(_clearSavedProgress(repo));
    }
  }

  Future<void> _saveProgress(PomodoroRepository repo, int remainingSeconds) async {
    try {
      await repo.saveProgress(remainingSeconds: remainingSeconds);
    } catch (_) {}
  }

  Future<void> _clearSavedProgress(PomodoroRepository repo) async {
    try {
      await repo.clearProgress();
    } catch (_) {}
  }

  /// 作废残留的未完成进度（全新一轮 / 重新开始）
  void _clearProgress() {
    unawaited(_clearSavedProgress(_repo));
  }

  // ===================== 构建 =====================

  @override
  Widget build(BuildContext context) {
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
                  child: _error != null
                      ? _errorState(context)
                      : switch (_display) {
                          'clean' => _cleanBody(context),
                          'landscape' => _segmentBody(context),
                          _ =>
                            MediaQuery.of(context).orientation ==
                                    Orientation.landscape
                                ? _normalLandscapeBody(context)
                                : _normalPortraitBody(context),
                        },
                ),
              ),
              // 底部操作条固定页底（不随内容滚动，§1.8 同款心智）；三种展示效果一致
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部：统一 `‹ 番茄钟 [记录] [设置]`（三种展示效果一致；已删 ⟳ 横竖屏循环）
  Widget _header(BuildContext context) {
    final t = context.theme;
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
          // 记录 → 番茄钟周期弹窗（底部固定导出）
          TapScale(
            onTap: () => showPomodoroRecordsSheet(context),
            child: Icon(
              FLucideIcons.history,
              size: 20,
              color: t.colors.foreground,
            ),
          ),
          // 设置 → 时长 + 展示效果（原页底 ⚙ 移到头部）
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

  /// 底部操作条：[开始专注/暂停/继续] + [重新开始]
  Widget _bottomBar(BuildContext context) {
    final primaryLabel = !_started
        ? '开始专注'
        : _running
        ? '暂停'
        : '继续';
    final primaryIcon = (!_started || !_running)
        ? FLucideIcons.play
        : FLucideIcons.pause;
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
          Expanded(
            child: GradientButton(
              label: primaryLabel,
              icon: primaryIcon,
              onPress: _toggleRun,
            ),
          ),
          Expanded(
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _restart,
              child: const Text('重新开始'),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== normal：横幅 + 进度环（计时卡占满剩余高度），操作条在页底 =====================

  /// normal 竖屏：横幅固定在上，**计时卡占满剩余高度**、卡内内容垂直居中（2026-09-13 用户实指）。
  /// ⚠️ 用 `Expanded`（拿到紧约束）而非 `ListView`——旧写法卡片只按内容 hug，下方留大片空白。
  Widget _normalPortraitBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          _banner(context),
          const SizedBox(height: 8),
          // AppCard = Container(width:∞) + Padding(margin)，在紧约束下会撑满；卡内 Column 已 center
          Expanded(child: _ringCard(context)),
        ],
      ),
    );
  }

  /// normal 横屏：左列横幅 + 右列大进度环
  Widget _normalLandscapeBody(BuildContext context) {
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
              children: [_banner(context)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Center(child: _ringCard(context, compact: true)),
          ),
        ],
      ),
    );
  }

  // ===================== clean 清爽：仅内容卡片 + 低调按钮 =====================

  Widget _cleanBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        child: _ringCard(context, showCaption: false),
      ),
    );
  }

  // ===================== landscape 横屏：大字倒计时 =====================

  /// 横屏展示主体：当前字体放大、固定 HH:mm:ss、占满全屏。
  /// 纯 Text + FittedBox(scaleDown) 兜底：字号给足，超宽只缩小显示，绝无溢出崩溃。
  Widget _segmentBody(BuildContext context) {
    final t = context.theme;
    final s = _remainingSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String pad(int v) => v.toString().padLeft(2, '0');
    final timeText = '${pad(h)}:${pad(m)}:${pad(sec)}';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            _phase.label,
            style: t.typography.body.sm.copyWith(
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 统计横幅（normal 模式；主色渐变，与待办同款；title = 当前阶段）
  Widget _banner(BuildContext context) => PageBanner(
    icon: FLucideIcons.timer,
    title: _phase.label,
    subtitle: '完成后自动进入下一阶段',
    gradient: AppTokens.accentGradient(AppTokens.accent(6)),
    cornerRadius: 22,
    ringDecor: true,
    shadow: false,
    margin: EdgeInsets.zero,
    stats: [
      (_formatSeconds(_remainingSeconds), '本阶段剩余'),
      ('${_phaseDuration ~/ 60}', '本阶段(分钟)'),
    ],
  );

  /// 阶段语义色：专注=番茄红 / 休息=绿（记录弹窗同口径）；其余走主色
  Color _phaseColor(BuildContext context) {
    final t = context.theme;
    return _phase.key == 'work'
        ? AppTokens.accent(6)
        : _phase.key == 'rest'
        ? AppTokens.accent(2)
        : t.colors.primary;
  }

  /// 阶段进度环（白卡承托：阶段 SoftChip + 主色进度环 + 大字剩余）。
  /// [compact]=normal 横屏：环径按卡片可用高度自适应（竖屏/清爽固定 200，ListView 高度无界）；
  /// [showCaption]=底部说明文字（清爽模式关闭，界面更净）。
  Widget _ringCard(
    BuildContext context, {
    bool compact = false,
    bool showCaption = true,
  }) {
    final t = context.theme;
    final phaseColor = _phaseColor(context);
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
      child: LayoutBuilder(
        builder: (context, cons) {
          // 环径自适应卡片可用高度（钳 120~200）：高卡取上限 200（观感稳定），
          // 矮卡（小屏 / 横屏）自动缩小，避免内容超出卡片（卡已撑满剩余高度，溢出即红屏）。
          final ringSize = (cons.maxHeight - (compact ? 92 : 110)).clamp(
            120.0,
            200.0,
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SoftChip(
                label: _phase.label,
                color: phaseColor,
                leading: Icon(
                  _phase.key == 'rest'
                      ? FLucideIcons.coffee
                      : FLucideIcons.briefcase,
                  size: 11,
                  color: phaseColor,
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              RingProgress(
                progress: _progress,
                size: ringSize,
                strokeWidth: 10,
                color: phaseColor,
                trackColor: t.colors.muted,
                child: Text(
                  _formatSeconds(_remainingSeconds),
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
                  _running
                      ? '到点自动进入下一阶段'
                      : _started
                      ? '已暂停，点「继续」接着走'
                      : '点「开始专注」，到点自动进入下一阶段',
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

  /// 配置读取失败态（正常流程不会出现）
  Widget _errorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyState(
            icon: FLucideIcons.timer,
            title: _error ?? '番茄钟加载失败',
            subtitle: '下拉重试，或进入设置检查时长配置',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GradientButton(
              label: '重试',
              icon: FLucideIcons.refreshCw,
              onPress: _loadConfig,
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

/// 编辑番茄钟配置弹层（lg 80vh 定高）：专注/休息时长 + 展示效果 + 周期规则。
/// 时长与桌面端同源 —— 写 reminders.id='pomodoro' 行的 states JSON；
/// 展示效果与周期规则存 basic_info 基础键值表（用户拍板：不与计时字段混存一表）。
class _PomodoroConfigSheet extends ConsumerStatefulWidget {
  const _PomodoroConfigSheet({
    required this.workMinutes,
    required this.restMinutes,
    required this.display,
    required this.cycleRule,
  });

  final int workMinutes;
  final int restMinutes;
  final String display;

  /// 周期规则：未完成的一轮如何处置（restart / resume）
  final String cycleRule;

  @override
  ConsumerState<_PomodoroConfigSheet> createState() =>
      _PomodoroConfigSheetState();
}

class _PomodoroConfigSheetState extends ConsumerState<_PomodoroConfigSheet> {
  late final TextEditingController _work;
  late final TextEditingController _rest;
  late String _display;
  late String _rule;

  @override
  void initState() {
    super.initState();
    _work = TextEditingController(text: '${widget.workMinutes}');
    _rest = TextEditingController(text: '${widget.restMinutes}');
    _display = widget.display;
    _rule = widget.cycleRule;
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
    await repo.updateDurations(workMinutes: work, restMinutes: rest);
    // ⚠️ 必须 await：页面在弹层关闭后立即 loadDisplay/loadCycleRule 读回，晚写会读到旧值
    await repo.saveDisplay(_display);
    await repo.saveCycleRule(_rule);
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
          // 周期规则：未完成的一轮如何处置（存 basic_info 基础键值表）
          const SheetFieldLabel('周期规则'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rule in PomodoroRepository.kCycleRules)
                SheetChoiceChip(
                  label: kCycleRuleLabels[rule] ?? rule,
                  selected: _rule == rule,
                  onTap: () => setState(() => _rule = rule),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '「未完成」= 一轮结束前离开页面或切到其他应用',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '计时只在进入本页并点「开始专注」后进行，离开页面即停止。\n'
            '「未完成重新开始」= 丢弃进度，下次从专注满时长重来；'
            '「未完成继续上一轮」= 记住专注阶段的剩余时间（不限时长），下次进页面点「继续」接着走。'
            '规则仅作用于专注阶段；时长与桌面端同源，横屏为大字倒计时（HH:mm:ss 占满全屏）',
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
