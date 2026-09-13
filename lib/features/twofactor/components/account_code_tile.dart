// 2FA 动态码条目组件：账户名 + 当前码（大字）+ 周期倒计时
//
// 出码刷新策略：StatefulWidget 内部启动 1s 定时器，每秒按当前时间重新计算 TOTP，
// 保证倒计时秒数与进度条实时刷新；父页面无需为列表项定时 setState。
// 点击复制当前码到剪贴板。
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/squircle_box.dart';
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

class _AccountCodeTileState extends State<AccountCodeTile> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// 6 位码按 3+3 分组；其他位数原样返回
  String _grouped(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    return code;
  }

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
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
    final meta = generateTotpWithMeta(
      account.secret,
      options: TotpOptions(
        algorithm: account.algorithm,
        digits: account.digits,
        period: account.period,
      ),
    );
    // 周期进度（0..1），clamp 防御异常 period 数据导致进度条断言失败
    final progress = (meta.remainingSeconds / meta.period).clamp(0.0, 1.0);

    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _copy(context, meta.code),
      onLongPress: widget.onMenu,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(AppTokens.accent(0)),
            alignment: Alignment.center,
            child: Icon(FLucideIcons.keyRound, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // 当前码：按 3+3 分组展示，等宽 + 大字
                    Expanded(
                      child: Text(
                        _grouped(meta.code),
                        style: t.typography.body.lg.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 28,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 剩余秒数（放大，与当前码基线对齐）
                    Text(
                      '${meta.remainingSeconds}s',
                      style: t.typography.body.lg.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 周期倒计时进度条（forui determinate progress，取值 0..1）
                FDeterminateProgress(value: progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
