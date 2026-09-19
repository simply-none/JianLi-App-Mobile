// 提醒守护卡（小卡「提醒守护 N/4」）—— 从 reminder_list_page.dart 抽出为共享组件，
// 供首页「提醒守护」栏与提醒列表页共用（单一真源）。
//
// 自管理四项前置条件状态（`NotificationService.checkCapabilities`），点开 `ReminderGuardSheet`
// 逐项处理；弹窗关闭后重查刷新。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/notifications/notification_service.dart';
import 'reminder_guard_sheet.dart';

/// 提醒守护卡：到点提醒能否可靠响起的**唯一自查入口**（常驻显示，点开 lg 抽屉逐项处理）。
///
/// 四项全部就绪 → 绿色「已就绪」；否则琥珀色 + 「N/4 项已就绪」，避免用户以为「列表变少了」式的困惑。
/// ⚠️ 判定项与 `NotificationService.checkCapabilities` 一一对应，新增项要同步这里与抽屉。
class ReminderGuardCard extends StatefulWidget {
  const ReminderGuardCard({super.key, this.padding});

  /// 外间距。默认值适配「无外层水平 padding 的滚动容器」（提醒列表页）；
  /// 首页 ListView 已带 16 水平 padding，传 `EdgeInsets.zero` 即可避免双重内缩。
  final EdgeInsetsGeometry? padding;

  @override
  State<ReminderGuardCard> createState() => _ReminderGuardCardState();
}

class _ReminderGuardCardState extends State<ReminderGuardCard> {
  /// 四项前置条件（null = 还没查完，不显示守护卡）。
  /// 明细见 `NotificationService.checkCapabilities`。
  ({
    bool notifications,
    bool exactAlarm,
    bool batteryOptimizationOff,
    bool fullScreenIntent,
  })?
  _caps;

  @override
  void initState() {
    super.initState();
    _checkCaps();
  }

  Future<void> _checkCaps() async {
    final caps = await NotificationService.checkCapabilities();
    if (mounted) setState(() => _caps = caps);
  }

  Future<void> _openGuardSheet() async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (_) => const ReminderGuardSheet(),
    );
    if (mounted) await _checkCaps();
  }

  @override
  Widget build(BuildContext context) {
    final caps = _caps;
    final t = context.theme;
    final ready = caps != null &&
        caps.notifications &&
        caps.exactAlarm &&
        caps.batteryOptimizationOff &&
        caps.fullScreenIntent;
    final readyCount = caps == null
        ? 0
        : [
            caps.notifications,
            caps.exactAlarm,
            caps.batteryOptimizationOff,
            caps.fullScreenIntent,
          ].where((e) => e).length;
    final color = ready ? AppTokens.accent(2) : AppTokens.accent(3);
    final text = caps == null
        ? '正在检查提醒是否可靠…'
        : ready
        ? '提醒守护已就绪，到点会准时响起'
        : '提醒守护 $readyCount/4 项已就绪，到点可能不响';

    return Padding(
      padding: widget.padding ??
          const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FTappable(
        onPress: _openGuardSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                ready ? FLucideIcons.circleCheck : FLucideIcons.shieldAlert,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    color: t.colors.foreground,
                  ),
                ),
              ),
              Text(
                ready ? '查看' : '去开启',
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Icon(FLucideIcons.chevronRight, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
