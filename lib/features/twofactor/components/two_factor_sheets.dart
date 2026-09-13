// 2FA 账户抽屉集 —— 添加/编辑（lg）/ 导出 otpauth 二维码（sm）/ 相机扫码识别（全屏）
//
// 能力对齐 PC 端 twoFactor 的 AddAccountDialog（手动录入 / 扫码 / 粘贴 URI 三方式）与
// AccountCard 的「导出二维码」（供其他验证器迁移）。移动端补充：mobile_scanner 相机
// 直接扫 otpauth 二维码（PC 端是从图片识别，移动端相机更强）。
// 弹窗一律三档制：表单 = lg 定高 / 二维码 = sm，均走共享 SheetScaffold 骨架；
// 打开不自动聚焦（红线 #14⑤），controller 由各自 State 释放。
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../models/two_factor_account.dart';
import '../services/otpauth_parser.dart';

/// 生成 otpauth:// URI（对齐 PC utils/otpauth 的导出格式；issuer 查询参数优先语义）
String buildOtpauthUri(TwoFactorAccount a) {
  String enc(String v) => Uri.encodeComponent(v);
  final label = a.issuer.isEmpty
      ? enc(a.account)
      : '${enc(a.issuer)}:${enc(a.account)}';
  final params = <String, String>{
    'secret': a.secret,
    if (a.issuer.isNotEmpty) 'issuer': a.issuer,
    if (a.algorithm.toUpperCase() != 'SHA1') 'algorithm': a.algorithm.toUpperCase(),
    if (a.digits != 6) 'digits': '${a.digits}',
    if (a.period != 30) 'period': '${a.period}',
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'otpauth://totp/$label?$query';
}

/// 新建 / 编辑账户抽屉（lg 定高）。
/// [initial] 非空 = 编辑；[prefill] 非空 = 预填（扫码/粘贴解析结果，仍按新建保存）。
Future<void> showTwoFactorAccountSheet(
  BuildContext context, {
  required Future<void> Function(TwoFactorAccount account) onSave,
  TwoFactorAccount? initial,
  TwoFactorAccount? prefill,
}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => _AccountFormSheet(
      onSave: onSave,
      initial: initial,
      prefill: prefill,
    ),
  );
}

class _AccountFormSheet extends StatefulWidget {
  const _AccountFormSheet({
    required this.onSave,
    this.initial,
    this.prefill,
  });

  final Future<void> Function(TwoFactorAccount account) onSave;
  final TwoFactorAccount? initial;
  final TwoFactorAccount? prefill;

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  late final TextEditingController _issuer =
      TextEditingController(text: widget.initial?.issuer ?? widget.prefill?.issuer ?? '');
  late final TextEditingController _account =
      TextEditingController(text: widget.initial?.account ?? widget.prefill?.account ?? '');
  late final TextEditingController _secret =
      TextEditingController(text: widget.initial?.secret ?? widget.prefill?.secret ?? '');
  late String _algorithm =
      widget.initial?.algorithm ?? widget.prefill?.algorithm ?? 'SHA1';
  late int _digits = widget.initial?.digits ?? widget.prefill?.digits ?? 6;
  late int _period = widget.initial?.period ?? widget.prefill?.period ?? 30;
  bool _saving = false;

  @override
  void dispose() {
    _issuer.dispose();
    _account.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = _secret.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z2-7]'), '');
    if (s.isEmpty) {
      showFToast(context: context, title: const Text('密钥不能为空'));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final account = TwoFactorAccount(
      key: widget.initial?.key ??
          DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      issuer: _issuer.text.trim(),
      account: _account.text.trim(),
      secret: s,
      algorithm: _algorithm,
      digits: _digits,
      period: _period,
      group: widget.initial?.group,
      sortOrder: widget.initial?.sortOrder,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await widget.onSave(account);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('保存失败'),
          description: Text('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetScaffold(
      title: widget.initial == null ? '新增 2FA 账户' : '编辑 2FA 账户',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          _field(context, '服务名（如 GitHub）',
              SheetInputBox(controller: _issuer, hintText: 'GitHub')),
          _field(context, '账户（邮箱/用户名）',
              SheetInputBox(controller: _account, hintText: 'you@example.com')),
          _field(
            context,
            '密钥（base32）',
            SheetInputBox(
              controller: _secret,
              hintText: 'JBSWY3DPEHPK3PXP',
              // 密钥输入常用大写字母数字
              keyboardType: TextInputType.text,
            ),
          ),
          _field(
            context,
            '算法',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final algo in const ['SHA1', 'SHA256', 'SHA512'])
                  SheetChoiceChip(
                    label: algo,
                    selected: _algorithm == algo,
                    onTap: () => setState(() => _algorithm = algo),
                  ),
              ],
            ),
          ),
          _field(
            context,
            '位数',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in const [6, 8])
                  SheetChoiceChip(
                    label: '$d 位',
                    selected: _digits == d,
                    onTap: () => setState(() => _digits = d),
                  ),
              ],
            ),
          ),
          _field(
            context,
            '周期',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in const [30, 60])
                  SheetChoiceChip(
                    label: '$p 秒',
                    selected: _period == p,
                    onTap: () => setState(() => _period = p),
                  ),
              ],
            ),
          ),
          if (widget.initial == null)
            Text(
              '提示：也可在列表页用「扫码识别」直接扫 otpauth 二维码录入。',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
            ),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: _saving ? '保存中…' : '加密保存',
            icon: FLucideIcons.check,
            onPress: _saving ? null : _save,
          ),
        ),
      ],
    );
  }

  /// 字段组（label 与输入框组内间距 6，§1.4 字段组绑定）
  Widget _field(BuildContext context, String label, Widget input) {
    // label↔输入框间距 = SheetFieldLabel 自带 bottom:6，组内不再叠 spacing
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetFieldLabel(label),
        input,
      ],
    );
  }
}

/// 导出账户 otpauth 二维码（sm 档）：供其他验证器扫码迁移（对齐 PC AccountCard 导出）
Future<void> showTwoFactorQrSheet(BuildContext context, TwoFactorAccount a) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => SheetScaffold(
      title: '导出二维码',
      size: SheetSize.sm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            a.displayName,
            textAlign: TextAlign.center,
            style: c.theme.typography.body.sm.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: QrImageView(
                data: buildOtpauthUri(a),
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Text(
            '用其他验证器 App 扫码即可迁移；二维码含密钥，注意保管',
            textAlign: TextAlign.center,
            style: c.theme.typography.body.xs.copyWith(
              fontSize: 12,
              color: c.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: '复制 otpauth 链接',
            icon: FLucideIcons.copy,
            onPress: () async {
              await Clipboard.setData(
                ClipboardData(text: buildOtpauthUri(a)),
              );
              if (context.mounted) {
                showFToast(context: context, title: const Text('已复制 otpauth 链接'));
              }
            },
          ),
        ),
      ],
    ),
  );
}

/// 相机扫码识别 otpauth（全屏页，识别成功 pop 返回解析出的账户草稿）
Future<TwoFactorAccount?> showTwoFactorScanPage(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<TwoFactorAccount>(
      opaque: true,
      pageBuilder: (_, _, _) => const _OtpScanPage(),
      // 零动画（本工程页面转场统一瞬时切换）
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}

class _OtpScanPage extends StatefulWidget {
  const _OtpScanPage();

  @override
  State<_OtpScanPage> createState() => _OtpScanPageState();
}

class _OtpScanPageState extends State<_OtpScanPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final parsed = parseOtpauthUri(barcode.rawValue ?? '');
      if (parsed != null) {
        _handled = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, parsed.account);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        FLucideIcons.x,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Text(
                  '对准验证器提供的 otpauth 二维码，识别后自动填入',
                  textAlign: TextAlign.center,
                  style: t.typography.body.sm.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
