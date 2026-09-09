// 2FA 页面：口令解锁 vault → 动态码列表（每秒刷新）
//
// forui 化改造说明：
// - 骨架改为 FScaffold + FHeader.nested（返回键 + 锁定/新增头部动作）；
// - 解锁表单：FTextField.password + FButton，错误提示改用 FAlert（destructive）；
// - 新增账户弹层：showModalBottomSheet → showFSheet（bottom-to-top），
//   算法下拉 DropdownButtonFormField → FSelect，SnackBar → showFToast；
// - 业务逻辑（vault 解锁 / TOTP 出码 / 会话口令驻留策略）与原来完全一致。
//
// 安全约定：
// - 口令只在解锁瞬间使用，不进任何状态/日志；
// - 解锁后账户明文驻留内存（与桌面端「明文仅驻留内存」策略一致）；
// - 右上角锁按钮可立即清空内存态。
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/two_factor_account.dart';
import '../providers/two_factor_providers.dart';
import '../services/otpauth_parser.dart';
import '../services/totp_service.dart';
import 'account_code_tile.dart';

/// 2FA 主页面
class TwoFactorPage extends ConsumerStatefulWidget {
  const TwoFactorPage({super.key});

  @override
  ConsumerState<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends ConsumerState<TwoFactorPage> {
  final TextEditingController _passphraseController = TextEditingController();
  bool _unlocking = false;
  String? _error;
  String? _pickedVaultPath;

  /// 会话口令（仅解锁期间驻留内存，用于加密回写；锁定/退出即丢——与桌面端同策略）
  String _sessionPassphrase = '';

  /// 每秒 tick，驱动剩余秒数与出码刷新
  Timer? _ticker;
  int _tick = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _passphraseController.dispose();
    // 路由切走即锁定（清空内存态 + 置反开关），满足「路由切换时锁住」
    ref.read(twoFactorAccountsProvider.notifier).lock();
    ref.read(twoFactorUnlockedProvider.notifier).lock();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      // 若用户刚选择了 vault 文件，先写入路径记录再解锁
      final repo = ref.read(twoFactorRepositoryProvider);
      if (_pickedVaultPath != null) {
        await repo.setVaultPath(_pickedVaultPath!);
      }
      await ref
          .read(twoFactorAccountsProvider.notifier)
          .unlock(_passphraseController.text);
      if (!mounted) return;
      setState(() {
        _sessionPassphrase = _passphraseController.text;
        _passphraseController.clear();
      });
      ref.read(twoFactorUnlockedProvider.notifier).unlock();
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '口令错误或 vault 不可达\n$e');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _lock() {
    _ticker?.cancel();
    ref.read(twoFactorAccountsProvider.notifier).lock();
    ref.read(twoFactorUnlockedProvider.notifier).lock();
    setState(() {
      _tick = 0;
      _sessionPassphrase = '';
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(twoFactorAccountsProvider).value ??
        const <TwoFactorAccount>[];
    final unlocked = ref.watch(twoFactorUnlockedProvider);
    return FScaffold(
      header: FHeader.nested(
        title: const Text('2FA 动态码'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          if (unlocked) ...[
            // 新增账户（原 FAB 的替代入口）
            FHeaderAction(
              icon: const Icon(FLucideIcons.plus, size: 20),
              onPress: () => _showAddAccountSheet(context),
              semanticsTooltip: '新增账户',
            ),
            // 锁定：立即清空内存中的账户明文与会话口令
            FHeaderAction(
              icon: const Icon(FLucideIcons.lock, size: 20),
              onPress: _lock,
              semanticsTooltip: '锁定',
            ),
          ],
        ],
      ),
      child: unlocked
          ? _buildCodes(context, accounts)
          : _buildUnlockForm(context),
    );
  }

  /// 新增账户弹层（手动填或粘贴 otpauth:// URI）
  Future<void> _showAddAccountSheet(BuildContext context) async {
    final issuer = TextEditingController();
    final account = TextEditingController();
    final secret = TextEditingController();
    // 算法选择控制器：粘贴 URI 后可直接改值刷新选中项
    final algorithmController = FSelectController<String>(value: 'SHA1');

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 表单较高且可滚动，不限制弹层最大高度
      mainAxisMaxRatio: null,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetSurface(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              16,
              AppTokens.pagePadding,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FButton(
                  variant: FButtonVariant.outline,
                  prefix: const Icon(FLucideIcons.clipboardPaste, size: 18),
                  onPress: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (!context.mounted) return;
                    final parsed = parseOtpauthUri(data?.text ?? '');
                    if (parsed == null) {
                      showFToast(
                        context: context,
                        variant: FToastVariant.destructive,
                        title: const Text('粘贴失败'),
                        description: const Text('剪贴板不是有效的 otpauth://totp 链接'),
                      );
                      return;
                    }
                    setSheetState(() {
                      issuer.text = parsed.account.issuer;
                      account.text = parsed.account.account;
                      secret.text = parsed.account.secret;
                      algorithmController.value = parsed.account.algorithm;
                    });
                  },
                  child: const Text('粘贴 otpauth:// URI 自动填充'),
                ),
                const SizedBox(height: 12),
                FTextField(
                  control: FTextFieldControl.managed(controller: issuer),
                  label: const Text('服务名（如 GitHub）'),
                ),
                const SizedBox(height: 10),
                FTextField(
                  control: FTextFieldControl.managed(controller: account),
                  label: const Text('账户（邮箱/用户名）'),
                ),
                const SizedBox(height: 10),
                FTextField(
                  control: FTextFieldControl.managed(controller: secret),
                  label: const Text('密钥（base32）'),
                ),
                const SizedBox(height: 10),
                FSelect<String>(
                  items: const {
                    'SHA1（默认）': 'SHA1',
                    'SHA256': 'SHA256',
                    'SHA512': 'SHA512',
                  },
                  label: const Text('算法'),
                  hint: '请选择',
                  control: FSelectControl<String>.managed(
                    controller: algorithmController,
                  ),
                ),
                const SizedBox(height: 14),
                FButton(
                  onPress: () {
                    final s = secret.text.trim().toUpperCase().replaceAll(
                      RegExp('[^A-Z2-7]'),
                      '',
                    );
                    if (s.isEmpty) return;
                    final algorithm = algorithmController.value ?? 'SHA1';
                    final now = DateTime.now().toIso8601String();
                    ref
                        .read(twoFactorAccountsProvider.notifier)
                        .addAccount(
                          passphrase: _sessionPassphrase,
                          account: TwoFactorAccount(
                            key: DateTime.now().microsecondsSinceEpoch
                                .toRadixString(36),
                            issuer: issuer.text.trim(),
                            account: account.text.trim(),
                            secret: s,
                            algorithm: algorithm,
                            digits: 6,
                            period: 30,
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('添加并加密保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 解锁表单（pageTint 冷调底 + 专属紫渐变图标盘，与工具分组页「2FA」入口色对齐）
  Widget _buildUnlockForm(BuildContext context) {
    final t = context.theme;
    return ColoredBox(
      color: AppTokens.pageTint(context),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SquircleBox(
                  size: 76,
                  radius: 26,
                  gradient: AppTokens.accentGradient(AppTokens.accent(0)),
                  alignment: Alignment.center,
                  child: const Icon(
                    FLucideIcons.keyRound,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '输入 2FA 口令解锁验证器',
                textAlign: TextAlign.center,
                style: t.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              FTextField.password(
                control: FTextFieldControl.managed(
                  controller: _passphraseController,
                ),
                label: const Text('口令'),
                hint: '与桌面端 2FA 保险库口令一致',
                onSubmit: (_) {
                  if (!_unlocking) _unlock();
                },
              ),
              const SizedBox(height: 10),
              // 选择桌面端导出的 vault 文件（写入 basic_info.twoFactorVaultPath）
              // 注意：FButton 内部 Row 不带 Flexible，长文案会横向溢出 → raw 自组 Row + Expanded 截断
              FButton.raw(
                variant: FButtonVariant.outline,
                onPress: () async {
                  final files = await FilePicker.pickFiles(type: FileType.any);
                  final path = files.isNotEmpty ? files.first.path : null;
                  if (path != null && mounted) {
                    setState(() => _pickedVaultPath = path);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickedVaultPath == null
                            ? FLucideIcons.fileUp
                            : FLucideIcons.circleCheck,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pickedVaultPath == null
                              ? '选择 vault 文件（桌面端导出的 2FA 保险库）'
                              : '已选择：${_pickedVaultPath!.split(Platform.pathSeparator).last}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: context.theme.typography.body.md,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FButton(
                onPress: _unlocking ? null : _unlock,
                child: Text(_unlocking ? '解锁中（PBKDF2 运算约数秒）…' : '解锁'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                FAlert(
                  variant: FAlertVariant.destructive,
                  title: const Text('解锁失败'),
                  subtitle: Text(_error!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 动态码列表（顶部专属紫渐变横幅 + 账户码卡片）
  Widget _buildCodes(BuildContext context, List<TwoFactorAccount> accounts) {
    if (accounts.isEmpty) {
      return const EmptyState(
        icon: FLucideIcons.keyRound,
        title: 'vault 为空',
        subtitle: '点击右上角 + 录入第一个 2FA 账户',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => setState(() => _tick++),
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: ListView(
          padding: EdgeInsets.only(
            top: AppTokens.listTopGapOf(context),
            bottom: AppTokens.pageBottomGapOf(context),
          ),
          children: [
            PageBanner(
              icon: FLucideIcons.keyRound,
              title: '2FA 动态码',
              subtitle: 'TOTP 实时出码，点击卡片复制',
              accentIndex: 0,
              stats: [('${accounts.length}', '已存账户')],
            ),
            for (final account in accounts)
              Builder(
                builder: (context) {
                  final meta = generateTotpWithMeta(
                    account.secret,
                    options: TotpOptions(
                      algorithm: account.algorithm,
                      digits: account.digits,
                      period: account.period,
                    ),
                  );
                  return AccountCodeTile(account: account, meta: meta);
                },
              ),
          ],
        ),
      ),
    );
  }
}
