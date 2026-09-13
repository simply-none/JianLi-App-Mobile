// 2FA 动态码条目组件：账户名 + 当前码（大字）+ 周期倒计时
//
// 刷新策略（流式倒计时）：Ticker 由 vsync 驱动、每帧按真实时间重算
// 「剩余比例 / 剩余秒数」，环与进度条以 60fps 连续消耗（_progress），
// 秒数文字独立走 _seconds —— 两者均为 ValueNotifier 局部刷新，不整卡重建。
// 码本身只在「周期翻转」（剩余秒数从 1 回升到满）时重算一次。
// 点击复制当前码到剪贴板（不带 3+3 分组空格）。
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/two_factor_account.dart';
import '../services/totp_service.dart';

/// 单条 2FA 账户码展示
class AccountCodeTile extends StatefulWidget {
  const AccountCodeTile({
    super.key,
    required this.account,
    this.onMenu,
  });

  final TwoFactorAccount account;

  /// 长按菜单（编辑 / 导出二维码 / 删除；null = 无长按行为）
  final VoidCallback? onMenu;

  @override
  State<AccountCodeTile> createState() => _AccountCodeTileState();
}

class _AccountCodeTileState extends State<AccountCodeTile>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// 周期剩余比例（0..1），每帧更新（流式消耗）
  final ValueNotifier<double> _progress = ValueNotifier<double>(1);

  /// 剩余秒数（整秒），每帧更新（值不变时 notifier 自动去重）
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);

  /// 当前码（3+3 分组展示用）
  String _code = '';

  /// 当前码原始值（复制用，无空格）
  String _rawCode = '';

  /// 上一帧剩余秒数：用于判定「周期翻转」（从 1 回升 = 新周期，重算码）
  int _lastRemaining = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _refresh());
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant AccountCodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      _lastRemaining = -1; // 账户被替换：下一帧强制重算码
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    _seconds.dispose();
    super.dispose();
  }

  /// 每帧刷新：进度与秒数按真实时间连续重算；码仅周期翻转时重算
  void _refresh() {
    final account = widget.account;
    // 防御异常 period 数据（<1 会导致取模 / 断言问题）
    final period = account.period < 1 ? 30 : account.period;
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = period - (epoch % period);

    if (remaining > _lastRemaining) {
      // 周期翻转或首次计算：重算当前码
      final meta = generateTotpWithMeta(
        account.secret,
        options: TotpOptions(
          algorithm: account.algorithm,
          digits: account.digits,
          period: account.period,
        ),
      );
      _rawCode = meta.code;
      _code = _grouped(meta.code);
      if (mounted) setState(() {});
    }
    _lastRemaining = remaining;

    _progress.value = (remaining / period).clamp(0.0, 1.0);
    _seconds.value = remaining;
  }

  /// 6 位码按 3+3 分组；其他位数原样返回
  String _grouped(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    return code;
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _rawCode));
    if (context.mounted) {
      showFToast(
        context: context,
        title: Text('${widget.account.displayName} 验证码已复制'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final account = widget.account;

    // 方案 A（画布 14 选型板 cardA）：码为唯一主角 —— 左渐变瓷片识别 +
    // 身份行(12/次要) + 大码(26/w900 3+3 分组 + 复制 affordance) + 右侧倒计时环
    // （剩余秒数嵌环心），底部 4px 主色渐变进度条兜底表达剩余周期。
    // 环 / 秒数 / 进度条由 Ticker 每帧驱动（流式消耗），不整卡重建。
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      radius: 18,
      onTap: () => _copy(context),
      onLongPress: widget.onMenu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 主题主色渐变瓷片（跟随换肤；普通圆角 13，弧度对齐画布）
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTokens.accentGradient(t.colors.primary),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(FLucideIcons.keyRound, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: t.typography.body.sm.copyWith(
                        fontSize: 12,
                        height: 1.1,
                        color: t.colors.mutedForeground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 码行 hug 排布：copy 图标紧贴码尾（不能让 Expanded 把它推到行尾悬空）
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _code,
                            style: t.typography.body.lg.copyWith(
                              fontSize: 26,
                              height: 1.1,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w900,
                              color: t.colors.foreground,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 复制 affordance（点击卡片即复制，图标仅作提示）
                          Icon(
                            FLucideIcons.copy,
                            size: 14,
                            color: t.colors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              // 倒计时环：环 = 剩余比例（每帧流式消耗），环心嵌剩余秒数
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 4,
                        color: t.colors.primary,
                        backgroundColor: t.colors.border,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _seconds,
                      builder: (context, seconds, _) => Text(
                        '$seconds s',
                        style: t.typography.body.xs.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: t.colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 周期剩余进度条（4px 细条 · 主色渐变，每帧流式消耗）
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: t.colors.border),
                  ValueListenableBuilder<double>(
                    valueListenable: _progress,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTokens.accentGradient(t.colors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
