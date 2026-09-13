// 2FA 页面 —— 对齐待办列表页骨架（专属色横幅统计 + 吸顶搜索行 + 账户码卡片）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 2FA 验证器18/Bold · ＋新增 · ⋯菜单（导出/锁定）（解锁态）
//   统计横幅 PageBanner 紫专属渐变 · stats 账户/强算法/周期（随滚动移出）
//   搜索行  ★吸顶锚点（搜索服务名与账户）
//   列表    账户码卡片（当前码 + 下一码 + 周期倒计时），单击复制、长按菜单
//
// 能力对齐 PC 端 twoFactor：添加三方式（手动 / 相机扫码 / 粘贴 otpauth URI）、
// 编辑账户（算法/位数/周期全参数）、导出 otpauth 二维码（迁移用）、删除、立即锁定。
// 门禁页双模式（对齐桌面端 open-vault / create-vault）：
//   - 未建库 → 「设置主口令 + 二次确认」新建本机 vault（沙盒 twofactor-vault.jlv）；
//   - 已有库 → 口令解锁，或再次选择 vault 文件导入（切换/迁移）。
// 另支持「导出本机 vault」到 `Download/渐离App 备份/`（未授权回退沙盒），供迁移/备份。
//
// 安全约定：
// - 口令只在解锁瞬间使用，不进任何状态/日志；
// - 解锁后账户明文驻留内存（与桌面端「明文仅驻留内存」策略一致）；
// - 右上角锁按钮可立即清空内存态。
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../core/android/media_scan.dart';
import '../../../core/storage/public_downloads.dart';
import '../models/two_factor_account.dart';
import '../providers/two_factor_providers.dart';
import '../services/otpauth_parser.dart';
import 'account_code_tile.dart';
import 'two_factor_sheets.dart';

/// 2FA 导出目录名（`Download/渐离App 备份/`，与文件互传同一 Download 根下；
/// 未授权或创建失败时回退沙盒 `Documents/渐离App 备份/`）。
const String kTwoFactorBackupDirName = '渐离App 备份';

/// 2FA 主页面
class TwoFactorPage extends ConsumerStatefulWidget {
  const TwoFactorPage({super.key});

  @override
  ConsumerState<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends ConsumerState<TwoFactorPage> {
  /// 2FA 域专属紫强调色（与工具分组页「2FA」入口色对齐）
  static final Color _accent = AppTokens.accent(0);

  final TextEditingController _passphraseController = TextEditingController();
  /// 新建模式下的二次确认口令
  final TextEditingController _confirmController = TextEditingController();
  bool _unlocking = false;
  String? _error;
  String? _pickedVaultPath;

  /// 会话口令（仅解锁期间驻留内存，用于加密回写；锁定/退出即丢——与桌面端同策略）
  String _sessionPassphrase = '';

  /// 页内搜索（服务名/账户）
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void deactivate() {
    // 路由切走即锁定（清空内存态 + 置反开关），满足「路由切换时锁住」。
    // ⚠️ 用 deactivate 而非 dispose：dispose 时 widget 已卸载，Riverpod 3.x 禁止再读 ref
    // （抛 "Using ref when ... unmounted is unsafe"）；deactivate 时 widget 仍 mounted，
    // 且打开子 sheet（showFSheet 是覆盖式 ModalRoute，不触发本页 deactivate）不受影响。
    ref.read(twoFactorAccountsProvider.notifier).lock();
    ref.read(twoFactorUnlockedProvider.notifier).lock();
    super.deactivate();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 解锁（含「选择新 vault 文件后解锁」的路径写入）
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '口令错误或 vault 不可达\n$e');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  /// 首次建库（新建本机 vault：设置主口令 + 二次确认；建库即解锁进入列表）
  Future<void> _createVault() async {
    final pass = _passphraseController.text;
    final confirm = _confirmController.text;
    if (pass.isEmpty) {
      setState(() => _error = '主口令不能为空');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = '两次输入的口令不一致');
      return;
    }
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      await ref.read(twoFactorAccountsProvider.notifier).createVault(pass);
      if (!mounted) return;
      setState(() {
        _sessionPassphrase = pass;
        _passphraseController.clear();
        _confirmController.clear();
      });
      ref.read(twoFactorUnlockedProvider.notifier).unlock();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '创建失败：$e');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  /// 导出本机 vault 加密文件到 `Download/渐离App 备份/`（未授权回退沙盒）
  Future<void> _exportVault() async {
    try {
      final path = await ref.read(twoFactorRepositoryProvider).getVaultPath();
      if (!mounted) return;
      if (path == null || !File(path).existsSync()) {
        showFToast(context: context, title: const Text('尚无 vault 文件可导出'));
        return;
      }
      await ensurePublicDownloadsPermission();
      final isPublic = await hasPublicDownloadsAccess();
      final dir = await moduleDownloadDir(kTwoFactorBackupDirName);
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-')
          .substring(0, 19);
      final file = File(
        p.join(dir.path, 'twofactor-vault_$stamp.jlv'),
      );
      await File(path).copy(file.path);
      // 触发 MediaStore 索引，文件管理器立即可见（静默，失败不影响已写入）
      await scanFileInMediaStore(file.path);
      if (!mounted) return;
      showFToast(
        context: context,
        title: const Text('已导出 vault'),
        description: Text(
          '已保存到 ${file.path}${isPublic ? '' : '（未授权存储，暂存应用沙盒）'}',
        ),
      );
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('导出失败'),
          description: Text('$e'),
        );
      }
    }
  }

  void _lock() {
    ref.read(twoFactorAccountsProvider.notifier).lock();
    ref.read(twoFactorUnlockedProvider.notifier).lock();
    setState(() {
      _sessionPassphrase = '';
    });
  }

  // ===================== 添加三方式（手动 / 扫码 / 粘贴） =====================

  /// 头部 ＋：操作菜单（sm 档共享操作菜单）
  Future<void> _addAccountMenu() async {
    final action = await showSheetActionMenu<String>(
      context,
      title: '新增 2FA 账户',
      actions: const [
        SheetAction('manual', '手动录入', icon: FLucideIcons.pencil),
        SheetAction('scan', '扫码识别', icon: FLucideIcons.scanLine),
        SheetAction('paste', '粘贴 otpauth 链接', icon: FLucideIcons.clipboardPaste),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'manual':
        await _openAccountSheet();
      case 'scan':
        final parsed = await showTwoFactorScanPage(context);
        if (!mounted) return;
        if (parsed == null) return;
        await _openAccountSheet(prefill: parsed);
      case 'paste':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (!mounted) return;
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
        await _openAccountSheet(prefill: parsed.account);
    }
  }

  /// 打开新增/编辑表单（lg 三档制抽屉；保存回调写回 vault）
  Future<void> _openAccountSheet({
    TwoFactorAccount? initial,
    TwoFactorAccount? prefill,
  }) async {
    await showTwoFactorAccountSheet(
      context,
      initial: initial,
      prefill: prefill,
      onSave: (account) async {
        final notifier = ref.read(twoFactorAccountsProvider.notifier);
        if (initial == null) {
          await notifier.addAccount(
            passphrase: _sessionPassphrase,
            account: account,
          );
        } else {
          await notifier.updateAccount(
            passphrase: _sessionPassphrase,
            account: account,
          );
        }
      },
    );
  }

  /// 账户长按菜单（复制 / 编辑 / 导出二维码 / 删除）
  Future<void> _accountMenu(TwoFactorAccount account) async {
    final action = await showSheetActionMenu<String>(
      context,
      title: account.displayName,
      actions: const [
        SheetAction('edit', '编辑账户', icon: FLucideIcons.pencil),
        SheetAction('qr', '导出二维码', icon: FLucideIcons.qrCode),
        SheetAction(
          'delete',
          '删除账户',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openAccountSheet(initial: account);
      case 'qr':
        await showTwoFactorQrSheet(context, account);
      case 'delete':
        final ok = await showSheetConfirm(
          context,
          title: '删除账户',
          message: '确定删除「${account.displayName}」？将重新加密写回 vault，不可恢复。',
        );
        if (!ok || !mounted) return;
        try {
          await ref
              .read(twoFactorAccountsProvider.notifier)
              .removeAccount(
                passphrase: _sessionPassphrase,
                key: account.key,
              );
        } catch (e) {
          if (mounted) {
            showFToast(
              context: context,
              variant: FToastVariant.destructive,
              title: const Text('删除失败'),
              description: Text('$e'),
            );
          }
        }
    }
  }

  // ===================== 页面 =====================

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(twoFactorAccountsProvider).value ??
        const <TwoFactorAccount>[];
    final unlocked = ref.watch(twoFactorUnlockedProvider);

    if (!unlocked) {
      // 已建库 → 解锁；未建库 → 新建。异步未就绪时按「解锁」兜底渲染（与历史行为一致，
      // 避免已建库用户瞬间闪到新建模式）。
      final exists =
          ref.watch(twoFactorVaultExistsProvider).value ?? true;
      return _buildUnlockScaffold(context, vaultExists: exists);
    }
    return _buildCodesScaffold(context, accounts);
  }

  /// 解锁态骨架（对齐待办：自定义头部 + 滚动体）
  Widget _buildCodesScaffold(
    BuildContext context,
    List<TwoFactorAccount> accounts,
  ) {
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(child: _body(context, accounts)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: () => context.pop(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
          Expanded(
            child: Text(
              '2FA 验证器',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: _addAccountMenu,
            child: Icon(FLucideIcons.plus, size: 22, color: t.colors.foreground),
          ),
          TapScale(
            onTap: _vaultMenu,
            child: Icon(
              FLucideIcons.ellipsisVertical,
              size: 20,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: _lock,
            child: Icon(FLucideIcons.lock, size: 18, color: t.colors.foreground),
          ),
        ],
      ),
    );
  }

  /// 头部溢出菜单（解锁态）：导出 vault / 立即锁定
  Future<void> _vaultMenu() async {
    final action = await showSheetActionMenu<String>(
      context,
      title: '2FA 验证器',
      actions: const [
        SheetAction('export', '导出 vault 文件', icon: FLucideIcons.download),
        SheetAction('lock', '立即锁定', icon: FLucideIcons.lock),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'export':
        await _exportVault();
      case 'lock':
        _lock();
    }
  }

  Widget _body(BuildContext context, List<TwoFactorAccount> accounts) {
    final kw = _search.trim().toLowerCase();
    final filtered = kw.isEmpty
        ? accounts
        : accounts
              .where(
                (a) =>
                    a.issuer.toLowerCase().contains(kw) ||
                    a.account.toLowerCase().contains(kw) ||
                    a.displayName.toLowerCase().contains(kw),
              )
              .toList();
    final strongAlgo = accounts
        .where((a) => a.algorithm.toUpperCase() != 'SHA1')
        .length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageBanner(
            icon: FLucideIcons.keyRound,
            title: '2FA 验证器',
            subtitle: 'TOTP 实时出码，点击卡片复制',
            accentIndex: 0,
            cornerRadius: 22,
            ringDecor: true,
            shadow: false,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            stats: [
              ('${accounts.length}', '账户'),
              ('$strongAlgo', '强算法'),
            ],
          ),
        ),
        // ★吸顶锚点：搜索行
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索服务名与账户…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        if (accounts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: true),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: false),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              AppTokens.listTopGapOf(context),
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final account = filtered[i];
                return AccountCodeTile(
                  account: account,
                  onMenu: () => _accountMenu(account),
                );
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
  }

  /// 空态（对齐待办）
  Widget _emptyState(BuildContext context, {required bool totallyEmpty}) {
    final t = context.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              totallyEmpty ? FLucideIcons.keyRound : FLucideIcons.searchX,
              size: 32,
              color: _accent,
            ),
          ),
          Text(
            totallyEmpty ? 'vault 为空' : '没有匹配的账户',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点右上角 ＋ 录入第一个 2FA 账户' : '换个关键词再试',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 门禁页（专属紫渐变图标盘）。
  /// [vaultExists] = 本机已有 vault → 解锁模式；否则 → 新建模式（设置主口令 + 二次确认）。
  /// 两模式均保留「选择 vault 文件」入口（新建时为备选路径，解锁时用于切换/迁移）。
  Widget _buildUnlockScaffold(
    BuildContext context, {
    required bool vaultExists,
  }) {
    final t = context.theme;
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: Column(
            children: [
              // 门禁页头部（返回）
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  spacing: 10,
                  children: [
                    TapScale(
                      onTap: () => context.pop(),
                      child: Icon(
                        FLucideIcons.chevronLeft,
                        size: 22,
                        color: t.colors.foreground,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '2FA 验证器',
                        style: t.typography.body.lg.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: t.colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
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
                            gradient: AppTokens.accentGradient(_accent),
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
                          vaultExists ? '输入 2FA 口令解锁验证器' : '首次使用：设置一个主口令',
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
                          label: Text(vaultExists ? '口令' : '主口令'),
                          hint: vaultExists
                              ? '与桌面端 2FA 保险库口令一致'
                              : '仅驻留内存，锁定即清除',
                          onSubmit: (_) {
                            if (!_unlocking) {
                              vaultExists ? _unlock() : _createVault();
                            }
                          },
                        ),
                        // 新建模式：二次确认口令（防手误导致自建库打不开）
                        if (!vaultExists) ...[
                          const SizedBox(height: 10),
                          FTextField.password(
                            control: FTextFieldControl.managed(
                              controller: _confirmController,
                            ),
                            label: const Text('确认口令'),
                            hint: '再次输入以确认',
                            onSubmit: (_) {
                              if (!_unlocking) _createVault();
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        // 选择 vault 文件（写入 basic_info.twoFactorVaultPath）
                        // 注意：FButton 内部 Row 不带 Flexible，长文案会横向溢出 → raw 自组 Row + Expanded 截断
                        FButton.raw(
                          variant: FButtonVariant.outline,
                          onPress: () async {
                            final files = await FilePicker.pickFiles(
                              type: FileType.any,
                            );
                            final path = files.isNotEmpty
                                ? files.first.path
                                : null;
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
                                        ? '选择 vault 文件导入（桌面端导出的 2FA 保险库）'
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
                          // 未建库时若已选外部 vault 文件 → 走解锁（该文件即活动库）；否则走新建
                          onPress: _unlocking
                              ? null
                              : (vaultExists || _pickedVaultPath != null
                                    ? _unlock
                                    : _createVault),
                          child: Text(
                            _unlocking
                                ? '${vaultExists || _pickedVaultPath != null ? '解锁' : '创建'}中（PBKDF2 运算约数秒）…'
                                : (vaultExists
                                      ? '解锁'
                                      : (_pickedVaultPath != null
                                            ? '导入并解锁'
                                            : '创建 2FA 保险库')),
                          ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
