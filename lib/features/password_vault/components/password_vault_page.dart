// 密码库页 —— 对齐待办列表页骨架（专属色横幅统计 + 吸顶搜索行 + 分类 chips + 条目卡）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 密码库18/Bold · 分享vault · ＋新增 · 锁定（解锁态）
//   统计横幅 PageBanner 蓝专属渐变 · stats 条目/分类/弱密码（随滚动移出）
//   搜索行  ★吸顶锚点（名称/账号/网址/分类四字段，对齐 PC 搜索口径）
//   分类行  SoftChip（从条目聚合去重，对齐 PC 分类过滤）
//   列表    条目卡（首字母盘 + 账号 + OTP/弱密码徽标）；单击=只读详情、长按=操作菜单
//
// 能力对齐 PC 端 passwordVault：字段全集（名称/账号/密码/网址/备注/分类/OTP 密钥）、
// 密码生成器（随机+口令短语双模式）、TOTP 实时码、复制 30 秒自动清空、导出 vault 文件。
// 门禁与内存口令策略与原实现一致：口令只在内存，锁定/退出即丢。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/password_entry.dart';
import '../providers/password_vault_providers.dart';
import '../utils/secure_clipboard.dart';
import 'password_vault_sheets.dart';

/// 密码管理页
class PasswordVaultPage extends ConsumerStatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  ConsumerState<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends ConsumerState<PasswordVaultPage> {
  /// 密码库域专属蓝强调色（与工具分组页「密码管理」入口色对齐）
  static final Color _accent = AppTokens.accent(1);

  String? _passphrase; // 仅内存，锁定即清
  bool _working = false;
  String? _error;

  /// 页内搜索（名称/账号/网址/分类）
  String _search = '';
  final _searchController = TextEditingController();

  /// 分类筛选（null = 全部）
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    // 路由切走即锁定（清空内存明文 + 置反开关），满足「路由切换时锁住」
    ref.read(passwordVaultEntriesProvider.notifier).lock();
    ref.read(passwordVaultUnlockedProvider.notifier).lock();
    super.dispose();
  }

  void _lock() {
    ref.read(passwordVaultEntriesProvider.notifier).lock();
    ref.read(passwordVaultUnlockedProvider.notifier).lock();
    setState(() => _passphrase = null);
  }

  /// 分享 vault 文件（.jlv 加密信封，对齐 PC「另存为」的移动端形态）
  Future<void> _shareVault() async {
    try {
      final path = await ref
          .read(passwordVaultRepositoryProvider)
          .getVaultPath();
      if (!mounted) return;
      if (!File(path).existsSync()) {
        showFToast(context: context, title: const Text('vault 文件不存在'));
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '渐离App 密码库（加密文件，请妥善保管）',
        ),
      );
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('分享失败'),
          description: Text('$e'),
        );
      }
    }
  }

  // ===================== 新增 / 编辑 / 详情 / 菜单 =====================

  Future<void> _openForm({PasswordEntry? initial}) async {
    await showPasswordEntryFormSheet(
      context,
      initial: initial,
      onSave: (entry) => ref
          .read(passwordVaultEntriesProvider.notifier)
          .upsertEntry(passphrase: _passphrase ?? '', entry: entry),
    );
  }

  /// 条目长按菜单（编辑 / 复制账号 / 复制密码 / 删除）
  Future<void> _entryMenu(PasswordEntry entry) async {
    final action = await showSheetActionMenu<String>(
      context,
      title: entry.title,
      actions: const [
        SheetAction('edit', '编辑', icon: FLucideIcons.pencil),
        SheetAction('copyUser', '复制账号', icon: FLucideIcons.user),
        SheetAction('copyPass', '复制密码', icon: FLucideIcons.copy),
        SheetAction(
          'delete',
          '删除',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openForm(initial: entry);
      case 'copyUser':
        await copyWithAutoClear(context, entry.username, '账号');
      case 'copyPass':
        await copyWithAutoClear(context, entry.password, '密码');
      case 'delete':
        final ok = await showSheetConfirm(
          context,
          title: '删除条目',
          message: '确定删除「${entry.title}」？将重新加密写回 vault，不可恢复。',
        );
        if (!ok || !mounted) return;
        await ref
            .read(passwordVaultEntriesProvider.notifier)
            .deleteEntry(passphrase: _passphrase ?? '', key: entry.key);
    }
  }

  /// 单击条目 → 只读详情（防误触，对齐待办详情模式）
  Future<void> _openDetail(PasswordEntry entry) async {
    await showPasswordEntryDetailSheet(
      context,
      entry: entry,
      onEdit: () => _openForm(initial: entry),
    );
  }

  // ===================== 页面 =====================

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final existsAsync = ref.watch(passwordVaultExistsProvider);
    final entriesAsync = ref.watch(passwordVaultEntriesProvider);
    final unlocked = ref.watch(passwordVaultUnlockedProvider);

    if (!unlocked) {
      return _buildGateScaffold(context, existsAsync.value ?? false);
    }
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
              Expanded(
                child: entriesAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败：$e',
                      textAlign: TextAlign.center,
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.error,
                      ),
                    ),
                  ),
                  data: (entries) => _body(context, entries),
                ),
              ),
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
              '密码库',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: _shareVault,
            child: Icon(
              FLucideIcons.share,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: () => _openForm(),
            child: Icon(FLucideIcons.plus, size: 22, color: t.colors.foreground),
          ),
          TapScale(
            onTap: _lock,
            child: Icon(FLucideIcons.lock, size: 18, color: t.colors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<PasswordEntry> entries) {
    final kw = _search.trim().toLowerCase();
    // 分类聚合（对齐 PC：从条目自动去重）
    final categories = <String>{
      for (final e in entries)
        if ((e.category ?? '').isNotEmpty) e.category!,
    }.toList()
      ..sort();
    final filtered = [
      for (final e in entries)
        if ((_category == null || e.category == _category) &&
            (kw.isEmpty ||
                e.title.toLowerCase().contains(kw) ||
                e.username.toLowerCase().contains(kw) ||
                e.url.toLowerCase().contains(kw) ||
                (e.category ?? '').toLowerCase().contains(kw)))
          e,
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageBanner(
            icon: FLucideIcons.lock,
            title: '密码库',
            subtitle: 'AES-256 加密，仅驻留本机内存',
            accentIndex: 1,
            cornerRadius: 22,
            ringDecor: true,
            shadow: false,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            stats: [
              ('${entries.length}', '条目'),
              ('${categories.length}', '分类'),
              ('${entries.where((e) => e.isWeak).length}', '弱密码'),
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
              hintText: '搜索名称、账号、网址、分类…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        // 分类 chips（有分类才显示）
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SoftChip(
                    label: '全部',
                    color: _accent,
                    alpha: _category == null ? 0.18 : 0.08,
                    onTap: _category == null
                        ? null
                        : () => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    SoftChip(
                      label: c,
                      color: _accent,
                      alpha: _category == c ? 0.18 : 0.08,
                      onTap: () => setState(
                        () => _category = _category == c ? null : c,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (entries.isEmpty)
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
                final entry = filtered[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EntryTile(
                    entry: entry,
                    onTap: () => _openDetail(entry),
                    onLongPress: () => _entryMenu(entry),
                  ),
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
            totallyEmpty ? '密码库为空' : '没有匹配的条目',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点右上角 ＋ 添加第一条' : '换个关键词，或切回全部分类',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 门禁骨架（自定义头部 + 居中表单；建库/解锁逻辑不变）
  Widget _buildGateScaffold(BuildContext context, bool exists) {
    final t = context.theme;
    final passController = TextEditingController();
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: Column(
            children: [
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
                        '密码库',
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
                          exists ? '输入口令解锁密码库' : '首次使用：设置一个主口令',
                          style: t.typography.body.lg.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FTextField.password(
                          control: FTextFieldControl.managed(
                            controller: passController,
                          ),
                          label: const Text('主口令'),
                          hint: '仅驻留内存，锁定即清除',
                        ),
                        const SizedBox(height: 12),
                        FButton(
                          onPress: _working
                              ? null
                              : () async {
                                  setState(() {
                                    _working = true;
                                    _error = null;
                                  });
                                  try {
                                    final notifier = ref.read(
                                      passwordVaultEntriesProvider.notifier,
                                    );
                                    if (exists) {
                                      await notifier.unlock(
                                        passController.text,
                                      );
                                    } else {
                                      await notifier.createVault(
                                        passController.text,
                                      );
                                    }
                                    if (mounted) {
                                      _passphrase = passController.text;
                                    }
                                    if (mounted) {
                                      ref
                                          .read(
                                            passwordVaultUnlockedProvider
                                                .notifier,
                                          )
                                          .unlock();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      _error = '口令错误或操作失败：$e';
                                    }
                                  } finally {
                                    if (mounted) setState(() => _working = false);
                                  }
                                },
                          child: Text(exists ? '解锁' : '创建密码库'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          FAlert(
                            variant: FAlertVariant.destructive,
                            title: const Text('操作失败'),
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

/// 密码条目卡片（首字母盘 + 账号 + OTP/弱密码徽标；单击=详情，长按=菜单）
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final PasswordEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      // 列表卡 margin 清零：间距只由外层 Padding(bottom:10) 提供
      margin: EdgeInsets.zero,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.pagePadding,
        vertical: 12,
      ),
      child: Row(
        children: [
          // 首字母徽标（专属蓝强调色渐变底盘）
          SquircleBox(
            size: 44,
            radius: 14,
            gradient: AppTokens.accentGradient(_accentOf(context)),
            alignment: Alignment.center,
            child: Text(
              entry.title.isEmpty
                  ? '?'
                  : entry.title.characters.first.toUpperCase(),
              style: t.typography.body.md.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.username.isEmpty ? '未设置账号' : entry.username,
                        style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.hasOtp)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          FLucideIcons.keyRound,
                          size: 13,
                          color: AppTokens.accent(1),
                        ),
                      ),
                    if (entry.isWeak)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          FLucideIcons.triangleAlert,
                          size: 13,
                          color: t.colors.destructive,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            FLucideIcons.chevronRight,
            size: 18,
            color: t.colors.mutedForeground,
          ),
        ],
      ),
    );
  }

  static Color _accentOf(BuildContext context) => AppTokens.accent(1);
}
