// 2FA 页面：口令解锁 vault → 动态码列表（每秒刷新）
//
// 安全约定：
// - 口令只在解锁瞬间使用，不进任何状态/日志；
// - 解锁后账户明文驻留内存（与桌面端「明文仅驻留内存」策略一致）；
// - 左上角锁按钮可立即清空内存态。
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _unlocked = false;
  bool _unlocking = false;
  String? _error;
  List<TwoFactorAccount> _accounts = const [];
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
      await ref.read(twoFactorAccountsProvider.notifier).unlock(_passphraseController.text);
      final accounts =
          await ref.read(twoFactorAccountsProvider.future).catchError((_) => <TwoFactorAccount>[]);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _unlocked = true;
        _sessionPassphrase = _passphraseController.text;
        _passphraseController.clear();
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '解锁失败：口令错误或 vault 不可达\n$e');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _lock() {
    _ticker?.cancel();
    ref.read(twoFactorAccountsProvider.notifier).lock();
    setState(() {
      _unlocked = false;
      _accounts = const [];
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('2FA 动态码'),
        actions: [
          if (_unlocked)
            IconButton(icon: const Icon(Icons.lock), tooltip: '锁定', onPressed: _lock),
        ],
      ),
      floatingActionButton: _unlocked
          ? FloatingActionButton(
              onPressed: () => _showAddAccountSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: _unlocked ? _buildCodes(context) : _buildUnlockForm(context),
    );
  }

  /// 新增账户弹层（手动填或粘贴 otpauth:// URI）
  Future<void> _showAddAccountSheet(BuildContext context) async {
    final issuer = TextEditingController();
    final account = TextEditingController();
    final secret = TextEditingController();
    String algorithm = 'SHA1';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('粘贴 otpauth:// URI 自动填充'),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (!context.mounted) return;
                  final parsed = parseOtpauthUri(data?.text ?? '');
                  if (parsed == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('剪贴板不是有效的 otpauth://totp 链接')));
                    return;
                  }
                  setSheetState(() {
                    issuer.text = parsed.account.issuer;
                    account.text = parsed.account.account;
                    secret.text = parsed.account.secret;
                    algorithm = parsed.account.algorithm;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issuer,
                decoration: const InputDecoration(
                    labelText: '服务名（如 GitHub）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: account,
                decoration: const InputDecoration(
                    labelText: '账户（邮箱/用户名）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: secret,
                decoration: const InputDecoration(
                    labelText: '密钥（base32）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: algorithm,
                decoration:
                    const InputDecoration(labelText: '算法', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'SHA1', child: Text('SHA1（默认）')),
                  DropdownMenuItem(value: 'SHA256', child: Text('SHA256')),
                  DropdownMenuItem(value: 'SHA512', child: Text('SHA512')),
                ],
                onChanged: (v) => setSheetState(() => algorithm = v ?? 'SHA1'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final s = secret.text.trim().toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '');
                  if (s.isEmpty) return;
                  final now = DateTime.now().toIso8601String();
                  ref.read(twoFactorAccountsProvider.notifier).addAccount(
                        passphrase: _sessionPassphrase,
                        account: TwoFactorAccount(
                          key: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
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
    );
  }

  /// 解锁表单
  Widget _buildUnlockForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.enhanced_encryption, size: 64),
          const SizedBox(height: 12),
          Text(
            '输入 2FA 口令解锁验证器',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passphraseController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '口令',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _unlocking ? null : _unlock(),
          ),
          const SizedBox(height: 10),
          // PoC：选择桌面端导出的 vault 文件（写入 basic_info.twoFactorVaultPath）
          OutlinedButton.icon(
            icon: Icon(_pickedVaultPath == null ? Icons.file_open : Icons.check_circle,
                size: 18),
            label: Text(
              _pickedVaultPath == null
                  ? '选择 vault 文件（桌面端导出的 2FA 保险库）'
                  : '已选择：${_pickedVaultPath!.split(Platform.pathSeparator).last}',
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () async {
              final files = await FilePicker.pickFiles(type: FileType.any);
              final path = files.isNotEmpty ? files.first.path : null;
              if (path != null && mounted) setState(() => _pickedVaultPath = path);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _unlocking ? null : _unlock,
            child: Text(_unlocking ? '解锁中（PBKDF2 运算约数秒）…' : '解锁'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  /// 动态码列表
  Widget _buildCodes(BuildContext context) {
    if (_accounts.isEmpty) {
      return const Center(child: Text('vault 为空，尚未录入任何 2FA 账户'));
    }
    return RefreshIndicator(
      onRefresh: () async => setState(() => _tick++),
      child: ListView.builder(
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final account = _accounts[index];
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
    );
  }
}
