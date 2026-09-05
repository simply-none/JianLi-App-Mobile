// 2FA 动态码条目组件：账户名 + 当前码 + 周期倒计时 + 下一周期码
//
// forui 化改造说明：Material Card + InkWell + LinearProgressIndicator 改为
// AppCard（原子组件）+ FDeterminateProgress；取色/字体全部走 forui token；
// 复制提示 SnackBar → showFToast。
//
// 出码刷新策略：由父页面每秒 setState 传入剩余秒数，本组件负责展示；
// 点击复制当前码到剪贴板。
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/two_factor_account.dart';
import '../services/totp_service.dart';

/// 单条 2FA 账户码展示
class AccountCodeTile extends StatelessWidget {
  const AccountCodeTile({
    super.key,
    required this.account,
    required this.meta,
  });

  final TwoFactorAccount account;
  final TotpWithMeta meta;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 周期进度（0..1），clamp 防御异常 period 数据导致进度条断言失败
    final progress = (meta.remainingSeconds / meta.period).clamp(0.0, 1.0);
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _copy(context),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.displayName,
                        style: t.typography.body.md.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${meta.remainingSeconds}s',
                      style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 当前码：按 3+3 分组展示，符合验证器习惯（等宽字体 + 宽字距）
                    Text(
                      _grouped(meta.code),
                      style: t.typography.body.lg.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '下一码 ${meta.nextCode}',
                      style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground),
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

  /// 6 位码按 3+3 分组；其他位数原样返回
  String _grouped(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    return code;
  }

  /// 复制当前码到剪贴板并弹 toast 提示
  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: meta.code));
    if (context.mounted) {
      showFToast(context: context, title: Text('${account.displayName} 验证码已复制'));
    }
  }
}
