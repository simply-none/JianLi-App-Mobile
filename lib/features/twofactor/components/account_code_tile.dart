// 2FA 动态码条目组件：账户名 + 当前码 + 周期倒计时 + 下一周期码
//
// 出码刷新策略：由父页面每秒 setState 传入剩余秒数，本组件负责展示；
// 点击复制当前码到剪贴板。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final progress = meta.remainingSeconds / meta.period;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${meta.remainingSeconds}s',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 当前码：按 3+3 分组展示，符合验证器习惯
                  Text(
                    _grouped(meta.code),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '下一码 ${meta.nextCode}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 周期倒计时进度条
              LinearProgressIndicator(value: progress, minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }

  /// 6 位码按 3+3 分组；其他位数原样返回
  String _grouped(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    return code;
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: meta.code));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${account.displayName} 验证码已复制')));
    }
  }
}
