// 提醒守护抽屉（lg）—— 从 reminder_list_page.dart 抽出为共享组件，供首页与提醒列表共用。
//
// 四项系统前置开关 + 后台保活 + 厂商保活路径引导。
//
// 为什么要有这一页：提醒计划存在原生 AlarmManager（App 被杀也能响），但「到底能不能响」
// 取决于系统给不给权限 —— 通知 / 精确闹钟 / 电池优化白名单 / 全屏通知。任一项缺失都表现为
// 「到点不响或不准时」，用户却无从知道该去开哪一个。这里四项并排展示 + 一键修复。
//
// ⚠️ 新增判定项时必须同步三处：`NotificationService.checkCapabilities`、本页、列表页守护卡计数
// （现统一由 `reminder_guard_card.dart` 的 `ReminderGuardCard` 承载卡片）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/android/system_actions.dart';
import '../../../core/notifications/notification_service.dart';

/// 提醒守护弹窗（lg 定高）：四项系统开关 + 后台保活 + 厂商保活路径引导。
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
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
    super.didChangeAppLifecycleState(state);
  }

  /// 重查四项开关 + 保活偏好/服务状态
  Future<void> _refresh() async {
    final caps = await NotificationService.checkCapabilities();
    final guard = KeepAliveGuard(ref.read(appDatabaseProvider));
    final pref = await guard.isPreferred();
    final running = await isKeepAliveRunning();
    if (!mounted) return;
    setState(() {
      _caps = caps;
      _keepAliveOn = pref;
      _keepAliveRunning = running;
    });
  }

  /// 执行一次「修复」动作（+ 忙等标记），完成后重查
  Future<void> _fix(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
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
            'App 切到后台或被系统清理后，已排好的提醒可能被取消。下面四项都开启，提醒才最准时。',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
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
          // ④ 全屏通知（Android 14+ 默认不授予 → 「闹钟」只弹横幅不锁屏全屏）
          _capRow(
            context,
            icon: FLucideIcons.smartphone,
            title: '全屏通知',
            desc: 'Android 14+ 默认关闭；不开则闹钟只弹横幅',
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
          _label(context, '厂商后台限制'),
          Text(
            '若上面都开了仍不准时，多半是系统省电策略在清理后台。请在系统设置里为「渐离App」额外开启：',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.colors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in const [
                  '小米 / 红米：应用设置 → 渐离App → 自启动 + 省电策略「无限制」',
                  '华为 / 荣耀：应用 → 启动管理 → 手动管理（自启动/关联启动/后台活动）',
                  'OPPO / 一加 / realme：电池 → 应用耗电管理 → 允许后台运行 + 允许自启动',
                  'vivo / iQOO：电池 → 后台高耗电 → 允许；i 管家 → 自启动管理',
                  '三星 / 原生：应用 → 渐离App → 电池 → 不受限制',
                ])
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
          ),
          const SizedBox(height: 12),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => openAppSettings(),
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
