// 提醒守护抽屉（lg）—— 从 reminder_list_page.dart 抽出为共享组件，供首页与提醒列表共用。
//
// 四项系统前置开关 + 后台保活 + 前置显示/厂商保活路径引导。
//
// 为什么要有这一页：提醒计划存在原生 AlarmManager（App 被杀也能响），但「到底能不能响」
// 取决于系统给不给权限 —— 通知 / 精确闹钟 / 电池优化白名单 / 全屏通知。任一项缺失都表现为
// 「到点不响或不准时」，用户却无从知道该去开哪一个。这里四项并排展示 + 一键修复。
//
// ⚠️ 新增判定项时必须同步三处：`NotificationService.checkCapabilities`、本页、列表页守护卡计数
// （现统一由 `reminder_guard_card.dart` 的 `ReminderGuardCard` 承载卡片）。
//
// 2026-09-18 补充两块「文案级」引导（判定项不变，故守护卡 4 项计数与列表页不动）：
//   ① 前置可见性：系统通知只有渠道重要性为 High 才会「悬浮横幅」（heads-up），且厂商 ROM 的
//      「悬浮通知 / 锁屏显示」开关可能单独关着 → 逐厂商给出路径（对齐用户诉求「像倒计时那样
//      直接在前置屏幕上看到」）。这条 App 无法代开，只能引导。
//   ② 系统设置往返后**立即重排**：`_fix` 把用户送去系统设置页 → 返回时绕开 app.dart 的
//      5 分钟回前台自愈节流，直接跑一次 `healAlarmSchedules`，让刚授予的权限立刻生效
//      （否则用户点完「去开启」回来发现状态是「已开启」但提醒仍不准时，会以为没用）。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/alarm_bootstrap.dart';
import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/android/system_actions.dart';
import '../../../core/notifications/notification_service.dart';

/// 提醒守护弹窗（lg 定高）：四项系统开关 + 后台保活 + 前置显示/厂商保活路径引导。
/// 公开组件，首页与提醒列表共用。
class ReminderGuardSheet extends ConsumerStatefulWidget {
  const ReminderGuardSheet({super.key});

  @override
  ConsumerState<ReminderGuardSheet> createState() => _ReminderGuardSheetState();
}

class _ReminderGuardSheetState extends ConsumerState<ReminderGuardSheet>
    with WidgetsBindingObserver {
  /// 四项系统开关（null = 还没查完）
  ({
    bool notifications,
    bool exactAlarm,
    bool batteryOptimizationOff,
    bool fullScreenIntent,
  })?
  _caps;

  /// 保活偏好（库）+ 服务实际是否在跑（原生）
  bool _keepAliveOn = false;
  bool _keepAliveRunning = false;

  /// 正在处理某项（防连点）
  bool _busy = false;

  /// 原生排程诊断快照（`sys.alarmDiagnostics`）：真机上「到底排上没有」此前只能靠现象猜，
  /// 这里把客观事实显示出来 —— 原生计划条数 / 下一条时刻 / 待机分组 / 省电 / Doze。
  Map<String, Object?> _diag = {};

  /// 是否刚把用户送去系统设置页（点了任一「去开启」）——决定回前台时是否强制重排一次。
  /// 「通知权限」是系统对话框、其余是设置 Activity，两者都会让 App 走 inactive/paused，
  /// 故统一置位；返回后无论权限是否真的授到，重排一次都是无害且必要的（幂等）。
  bool _pendingSettingsReturn = false;

  @override
  void initState() {
    super.initState();
    // 「去开启」多数会跳到系统设置页/弹系统对话框，用户回来后本页还开着 ——
    // 监听生命周期在 resumed 时重查状态，否则开关状态会一直显示成旧值。
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      super.didChangeAppLifecycleState(state);
      return;
    }
    // 从系统设置页回来：**强制重排一次提醒计划**，让刚授予的权限立刻生效。
    // 为什么必须在这里做：app.dart 的回前台自愈有 5 分钟节流，用户「去开启 → 返回」通常
    // 只隔几秒，会被节流吃掉 → 表现为「状态显示已开启，但提醒还是不准时」。
    // 这里直接调 healAlarmSchedules（不经节流），授完权限随即重排，立即生效。
    if (_pendingSettingsReturn) {
      _pendingSettingsReturn = false;
      unawaited(_healAfterSettings());
    } else if (!_busy) {
      _refresh();
    }
    super.didChangeAppLifecycleState(state);
  }

  /// 系统设置往返后：重排全部提醒计划 → 重查四项状态（顺序固定，状态必须是重排后的真实值）。
  Future<void> _healAfterSettings() async {
    try {
      await healAlarmSchedules(ref.read(appDatabaseProvider));
    } catch (_) {
      // 自愈失败不崩页：状态重查照旧，用户可再点一次「去开启」
    }
    if (mounted) await _refresh();
  }

  /// 重查四项开关 + 保活偏好/服务状态 + 原生排程诊断
  Future<void> _refresh() async {
    final caps = await NotificationService.checkCapabilities();
    final guard = KeepAliveGuard(ref.read(appDatabaseProvider));
    final pref = await guard.isPreferred();
    final running = await isKeepAliveRunning();
    final diag = await alarmDiagnostics();
    if (!mounted) return;
    setState(() {
      _caps = caps;
      _keepAliveOn = pref;
      _keepAliveRunning = running;
      _diag = diag;
    });
  }

  /// 执行一次「修复」动作（+ 忙等标记），完成后重查
  Future<void> _fix(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    // 标记「用户被送去系统设置/系统对话框」→ 返回时强制重排一次（见 didChangeAppLifecycleState）
    _pendingSettingsReturn = true;
    try {
      await action();
    } catch (_) {
      // 修复动作失败不崩页：状态重查后仍显示未开启，用户可再试
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  /// 后台保活开关
  Future<void> _toggleKeepAlive(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    final guard = KeepAliveGuard(ref.read(appDatabaseProvider));
    final started = await guard.setPreferred(on);
    if (!mounted) return;
    setState(() {
      _keepAliveOn = on;
      _keepAliveRunning = on && started;
      _busy = false;
    });
    if (on && !started) {
      showFToast(
        context: context,
        title: const Text('未能启动后台保活'),
        description: const Text('请确认已开启通知权限，部分系统还需允许「后台运行」'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final caps = _caps;

    return SheetScaffold(
      title: '提醒守护',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'App 切到后台或被系统清理后，已排好的提醒可能被取消。下面四项都开启，提醒才最准时；'
            '再按「前置显示」把悬浮横幅打开，到点就能直接在屏幕上看到，不用下拉通知栏。',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          _diagCard(context),
          const SizedBox(height: 16),
          _label(context, '系统开关'),
          // ① 通知权限（Android 13+ 运行时权限；不授予 → 到点完全不弹）
          _capRow(
            context,
            icon: FLucideIcons.bell,
            title: '通知权限',
            desc: '未开启时到点不会弹任何提醒',
            ok: caps?.notifications ?? false,
            actionLabel: '去开启',
            onFix: () => _fix(() async {
              await NotificationService.requestPermission();
            }),
          ),
          // ② 精确闹钟（Android 12+「闹钟和提醒」；不授予 → 退化为不精确，可能延迟几分钟）
          _capRow(
            context,
            icon: FLucideIcons.alarmClock,
            title: '闹钟和提醒',
            desc: '未开启时闹钟会变成不精确，可能延迟几分钟',
            ok: caps?.exactAlarm ?? false,
            actionLabel: '去开启',
            onFix: () => _fix(() async {
              await NotificationService.requestExactAlarmPermission();
            }),
          ),
          // ③ 忽略电池优化（未忽略 → Doze 下闹钟可能被延后）
          _capRow(
            context,
            icon: FLucideIcons.batteryCharging,
            title: '忽略电池优化',
            desc: '未忽略时息屏省电可能把提醒推迟',
            ok: caps?.batteryOptimizationOff ?? false,
            actionLabel: '去开启',
            onFix: () => _fix(() async {
              await NotificationService.requestIgnoreBatteryOptimizations();
            }),
          ),
          // ④ 全屏通知（Android 14+ 默认不授予 → 息屏时「闹钟」只弹横幅、不亮屏全屏）
          _capRow(
            context,
            icon: FLucideIcons.smartphone,
            title: '全屏通知',
            desc: 'Android 14+ 默认关闭；息屏时闹钟不亮屏全屏',
            ok: caps?.fullScreenIntent ?? false,
            actionLabel: '去开启',
            onFix: () => _fix(() async {
              await NotificationService.openFullScreenIntentSettings();
            }),
          ),
          const SizedBox(height: 6),
          _label(context, '后台保活'),
          _keepAliveCard(context),
          const SizedBox(height: 18),
          _label(context, '前置显示（不拉通知栏也能看到）'),
          Text(
            '系统通知默认只进通知栏。想让提醒像倒计时那样直接弹在屏幕上方（悬浮横幅），'
            '除上面的「通知权限」外，还需在系统里允许本 App 的「横幅 / 悬浮通知」与「锁屏显示」：',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          _bulletBlock(context, const [
            '小米 / 红米：设置 → 通知与控制中心 → 渐离App → 悬浮通知 + 锁屏显示',
            '华为 / 荣耀：设置 → 通知 → 渐离App → 横幅 + 锁屏通知',
            'OPPO / 一加 / realme：设置 → 通知与状态栏 → 渐离App → 横幅通知 + 锁屏通知',
            'vivo / iQOO：设置 → 通知 → 渐离App → 悬浮通知 + 锁屏显示',
            '原生 / 三星：设置 → 应用 → 渐离App → 通知 → 允许横幅 + 锁屏显示',
          ]),
          const SizedBox(height: 10),
          _noteBlock(
            context,
            'Android 14 及以上：系统默认关闭「全屏通知」，需在上面第 ④ 项单独开启，'
            '否则息屏时闹钟只弹横幅、不会亮屏全屏。',
          ),
          const SizedBox(height: 10),
          _noteBlock(
            context,
            '「闹钟送达」的每天/每周提醒已直接写入系统时钟 App（标签以「渐离App」开头），'
            '由系统触发、最可靠。注意：删除或修改提醒后，系统时钟里的旧闹钟不会自动消失，'
            '请在时钟 App 中手动删除对应条目。',
          ),
          const SizedBox(height: 18),
          _label(context, '厂商后台限制'),
          Text(
            '若上面都开了仍不准时，多半是系统省电策略在清理后台。请在系统设置里为「渐离App」额外开启：',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          _bulletBlock(context, const [
            '小米 / 红米：应用设置 → 渐离App → 自启动 + 省电策略「无限制」',
            '华为 / 荣耀：应用 → 启动管理 → 手动管理（自启动/关联启动/后台活动）',
            'OPPO / 一加 / realme：电池 → 应用耗电管理 → 允许后台运行 + 允许自启动',
            'vivo / iQOO：电池 → 后台高耗电 → 允许；i 管家 → 自启动管理',
            '三星 / 原生：应用 → 渐离App → 电池 → 不受限制',
          ]),
          const SizedBox(height: 12),
          FButton(
            variant: FButtonVariant.outline,
            // 去系统设置页改（悬浮通知 / 电池策略等）后回来同样强制重排一次，
            // 与「去开启」一致 —— 用户在这里改的正是影响提醒准时的设置。
            onPress: () {
              _pendingSettingsReturn = true;
              unawaited(openAppSettings());
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FLucideIcons.externalLink, size: 15),
                SizedBox(width: 8),
                Text('打开应用设置'),
              ],
            ),
          ),
        ],
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '完成',
            onPress: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: context.theme.typography.body.sm.copyWith(
        fontSize: 14,
        color: context.theme.colors.mutedForeground,
      ),
    ),
  );

  /// 原生排程诊断卡：**真机上判断「提醒为什么没响」的第一现场**。
  ///
  /// - 计划 0 条 ⇒ 压根没排上（原生桥失败且 awesome 兜底也失败，或提醒未启用）；
  /// - 计划 >0 但到点不响 ⇒ 先看「系统认账」行：**系统没有这条计划 = 计划被 ROM 清掉**；
  ///   系统认账了却不响 = 投递被推迟/冻结，用 logcat `JianliAlarm` 分流（见红线 #36）；
  /// - `standbyBucket`：**5 = 豁免（最佳）**、10=活跃、20=工作、30=常用、40=罕见、
  ///   45=受限（系统会推迟全部 alarms，「切后台不响、回前台补触发」最常见成因）。
  Widget _diagCard(BuildContext context) {
    final t = context.theme;
    final n = (_diag['scheduled'] as int?) ?? 0;
    final bucket = (_diag['standbyBucket'] as int?) ?? -1;
    final powerSave = _diag['powerSave'] == true;
    final idle = _diag['deviceIdle'] == true;
    final keepAlive = _diag['keepAliveRunning'] == true;

    // App 自己的登记表（写于 setAlarmClock 成功时）
    int? nextAt;
    final entries = _diag['entries'];
    if (entries is Map && entries.isNotEmpty) {
      final vals = entries.values.whereType<int>().toList()..sort();
      if (vals.isNotEmpty) nextAt = vals.first;
    }
    // 系统认账的下一条（AlarmManager.getNextAlarmClock；-1 = 系统里没有）
    final sysRaw = (_diag['nextSystemAlarmAt'] as int?) ?? -1;
    final nextSys = sysRaw > 0 ? sysRaw : null;
    // 关键分流：App 登记了计划但系统不认账 ⇒ 计划被 ROM 清理/覆盖
    final systemMissing = nextAt != null && nextSys == null;

    final restricted = bucket == 45 || bucket == 40;
    final color = n == 0
        ? t.colors.destructive
        : restricted
            ? AppTokens.accent(3)
            : AppTokens.accent(2);

    // 待机分组语义：5=豁免（EXEMPTED，最佳值，比 10 还高）
    String bucketLabel;
    switch (bucket) {
      case 5:
        bucketLabel = '豁免';
        break;
      case 10:
        bucketLabel = '活跃';
        break;
      case 20:
        bucketLabel = '工作';
        break;
      case 30:
        bucketLabel = '常用';
        break;
      case 40:
        bucketLabel = '罕见';
        break;
      case 45:
        bucketLabel = '受限';
        break;
      default:
        bucketLabel = bucket >= 0 ? '$bucket' : '—';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                n == 0 ? FLucideIcons.circleAlert : FLucideIcons.circleCheck,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '原生排程',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                ),
              ),
              Text(
                '$n 条',
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '下一条：${nextAt == null ? '—' : _fmtClock(nextAt)}'
            ' · 系统认账：${nextSys == null ? '无 ⚠' : _fmtClock(nextSys)}'
            '${bucket >= 0 ? ' · 分组 $bucketLabel' : ''}'
            '${powerSave ? ' · 省电模式' : ''}'
            '${idle ? ' · Doze 中' : ''}',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              height: 1.5,
              color: t.colors.mutedForeground,
            ),
          ),
          Text(
            '后台保活：${keepAlive ? '运行中' : '未运行 ⚠'}'
            '（状态栏常驻通知「渐离App 正在守护提醒」应在）',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              height: 1.5,
              color: t.colors.mutedForeground,
            ),
          ),
          if (n == 0) ...[
            const SizedBox(height: 6),
            Text(
              '系统里没有排上任何提醒计划。请确认上面四项都已开启，再回到提醒列表让 App 重排一次。',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.5,
                color: t.colors.destructive,
              ),
            ),
          ] else if (systemMissing) ...[
            const SizedBox(height: 6),
            Text(
              'App 已登记计划，但系统不认账（AlarmManager 里没有下一条）——'
              '计划被系统/ROM 清理了。回到提醒列表让 App 重排；反复出现请检查厂商后台限制。',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.5,
                color: t.colors.destructive,
              ),
            ),
          ] else if (restricted) ...[
            const SizedBox(height: 6),
            Text(
              '系统正在限制本 App 的后台（待机分组 ${bucket == 45 ? '受限' : '罕见'}），'
              '到点的计划会被推迟，直到你打开 App。请按下面「厂商后台限制」把本 App 设为不受限制。',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.5,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 毫秒时间戳 → `MM-DD HH:mm`（今年省略年份，够用且短）
  String _fmtClock(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }

  /// 逐条引导块（muted 底 · r14）：厂商路径清单共用，避免两处各写一份样式。
  Widget _bulletBlock(BuildContext context, List<String> lines) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '· $line',
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  height: 1.5,
                  color: t.colors.foreground,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 补充说明块（琥珀 12% 底 · r14）：放「容易漏掉的一句」系统差异说明。
  Widget _noteBlock(BuildContext context, String text) {
    final t = context.theme;
    final color = AppTokens.accent(3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FLucideIcons.info, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.5,
                color: t.colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单项系统开关行：图标 + 标题 + 说明 + 右侧「已开启」或「去开启」
  Widget _capRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required bool ok,
    required String actionLabel,
    required Future<void> Function() onFix,
  }) {
    final t = context.theme;
    final color = ok ? AppTokens.accent(2) : AppTokens.accent(3);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    height: 1.4,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (ok)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FLucideIcons.circleCheck, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '已开启',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            )
          else
            FTappable(
              onPress: _busy ? null : () => onFix(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Text(
                  actionLabel,
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 后台保活卡：开关 + 说明 + 运行状态
  Widget _keepAliveCard(BuildContext context) {
    final t = context.theme;
    final color = _keepAliveRunning ? AppTokens.accent(2) : t.colors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FLucideIcons.activity, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '后台保活',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                ),
              ),
              FSwitch(value: _keepAliveOn, onChange: _toggleKeepAlive),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '开启后通知栏会常驻一条「渐离App 正在守护提醒」，把 App 留在后台，'
            '降低系统把提醒计划一并清理的概率（可在系统设置里把这条静音）。',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              height: 1.5,
              color: t.colors.mutedForeground,
            ),
          ),
          if (_keepAliveOn) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _keepAliveRunning
                      ? FLucideIcons.circleCheck
                      : FLucideIcons.circleAlert,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(
                  _keepAliveRunning
                      ? '守护中（常驻通知已开启）'
                      : '未生效，下次打开 App 时会自动重试',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
