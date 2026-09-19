// P1-6 小纸条 —— 页面（工具分组入口 /slip）
//
// 骨架（对齐「待办化」规范）：
//   头部     ‹ 22 · 小纸条 18/Bold · ⋯（接收常驻开关 / 全部已读 / 清空）
//   统计横幅 PageBanner（未读 / 收到 / 发出）
//   搜索行   ★吸顶锚点（PinnedSearchRow，随滚动常驻视口顶部）
//   Tab 栏   ScopeTabBar：收到的 / 发出的（随滚动移出）
//   列表     卡片（来源 + 时间 + 2 行摘要 + 未读点；单击详情 lg，长按操作菜单）
//   底部条   目标设备 chip + 输入框 + 发送（与主题对话快速输入条同构）
//
// 接收时机：`NoteSlipBootstrap` 两种模式 —— 冷启动常驻 / 仅开页面时可收（页面入页必拉起数据面）。
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/scope_tab_bar.dart';
import '../../../app/ui/sheet_form.dart';
// ⚠️ SheetSize 在 sheet_surface.dart（sheet_form.dart 不 re-export，须双导，红线）
import '../../../app/ui/sheet_surface.dart' show SheetSize;
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart' show EmptyState;
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_discovery.dart';
import '../../../core/sync/sync_service.dart';
import '../../notes/providers/note_providers.dart';
import '../../todo/providers/todo_providers.dart';
import '../models/note_slip.dart';
import '../note_slip_bootstrap.dart';
import '../note_slip_intake.dart';
import '../providers/note_slip_providers.dart';
import '../services/note_slip_client.dart';
import 'note_slip_detail_sheet.dart';

/// Tab 范围
const List<(String, String)> kSlipTabs = [
  (kSlipDirectionIn, '收到的'),
  (kSlipDirectionOut, '发出的'),
];

/// 小纸条页
class NoteSlipPage extends ConsumerStatefulWidget {
  const NoteSlipPage({super.key, this.initialKey});

  /// 通知点击直达：要打开的那条主键（路由查询参数 key）
  final String? initialKey;

  @override
  ConsumerState<NoteSlipPage> createState() => _NoteSlipPageState();
}

class _NoteSlipPageState extends ConsumerState<NoteSlipPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _composeController = TextEditingController();
  String _search = '';
  String _tab = kSlipDirectionIn;
  bool _sending = false;
  bool _scanning = false;
  List<SlipTarget> _targets = [];
  SlipTarget? _current;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 入页必拉起接收能力（「仅开页面时」模式下也保证此刻能收）
      final db = ref.read(appDatabaseProvider);
      NoteSlipBootstrap.registerRoutes(db);
      await NoteSlipBootstrap.ensureDataPlane(ref.read(syncServiceProvider));
      await _loadTargets();
      await _openInitialKey();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final client = ref.read(noteSlipClientProvider);
    final targets = await client.loadTargets();
    final lastIp = await client.lastPeerIp();
    if (!mounted) return;
    setState(() {
      _targets = targets;
      _current = targets.cast<SlipTarget?>().firstWhere(
            (t) => t?.ip == lastIp,
            orElse: () => targets.isEmpty ? null : targets.first,
          );
    });
  }

  /// 通知直达：拉出该条并弹详情抽屉（消费一次性意图）
  Future<void> _openInitialKey() async {
    final key = widget.initialKey;
    if (key == null || key.isEmpty) return;
    ref.read(pendingSlipKeyProvider.notifier).consume();
    final row = await ref.read(noteSlipRepositoryProvider).getByKey(key);
    if (row == null || !mounted) return;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (_) => NoteSlipDetailSheet(item: row),
    );
  }

  // ---------- 设备选择 ----------

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final peers = await SyncDiscovery().scan();
      if (!mounted) return;
      // 排除自己（id = 本机稳定 hash），其余都列（PC 的 platform = 'win32-electron'）
      final list = peers.values.where((p) => p.id != localDeviceId).toList();
      if (list.isEmpty) {
        showFToast(
          context: context,
          title: const Text('未发现设备'),
          description: const Text('请确认对端渐离App 已打开并在同一局域网'),
        );
        return;
      }
      await _pickFromScan(list);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickFromScan(List<PeerDevice> peers) {
    final t = context.theme;
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '选择设备',
        size: SheetSize.sm,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in peers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FTappable(
                  onPress: () {
                    Navigator.pop(c);
                    _setCurrent(SlipTarget(ip: p.ip, name: p.name));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.colors.muted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          p.platform.contains('electron')
                              ? FLucideIcons.monitor
                              : FLucideIcons.smartphone,
                          size: 18,
                          color: t.colors.foreground,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p.name}（${p.ip}）',
                            overflow: TextOverflow.ellipsis,
                            style: t.typography.body.sm.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addManualIp() {
    final controller = TextEditingController();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: true, // 含输入框 → 抽屉抬到键盘上方
      builder: (c) => SheetScaffold(
        title: '手动添加设备',
        size: SheetSize.md,
        body: SheetInputBox(
          controller: controller,
          hintText: '例如 192.168.1.100',
        ),
        bottomBar: [
          Expanded(
            child: SheetActionButton(
              label: '添加',
              onTap: () {
                final ip = controller.text.trim();
                if (ip.isEmpty) return;
                Navigator.pop(c);
                _setCurrent(SlipTarget(ip: ip, name: ip));
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setCurrent(SlipTarget target) async {
    await ref.read(noteSlipClientProvider).rememberTarget(target);
    await _loadTargets();
    if (!mounted) return;
    setState(() => _current = target);
  }

  Future<void> _pickTarget() async {
    final t = context.theme;
    final picked = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '发送到',
        size: SheetSize.md,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _menuTile(c, t, FLucideIcons.scanLine,
                _scanning ? '扫描中…' : '扫描局域网', 'scan'),
            if (_targets.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final target in _targets)
                _menuTile(
                  c,
                  t,
                  FLucideIcons.history,
                  '${target.name}（${target.ip}）',
                  target.ip,
                ),
            ],
            _menuTile(c, t, FLucideIcons.plus, '手动输入 IP', 'manual'),
          ],
        ),
      ),
    );
    if (picked == 'scan') await _scan();
    if (picked == 'manual') await _addManualIp();
    if (picked != null &&
        picked != 'scan' &&
        picked != 'manual' &&
        picked.isNotEmpty) {
      final target = _targets
          .cast<SlipTarget?>()
          .firstWhere((e) => e?.ip == picked, orElse: () => null);
      if (target != null) await _setCurrent(target);
    }
  }

  Widget _menuTile(
    BuildContext sheetContext,
    FThemeData t,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FTappable(
        onPress: () => Navigator.pop(sheetContext, value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: t.colors.muted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: t.colors.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 发送 ----------

  Future<void> _send() async {
    final text = _composeController.text.trim();
    if (text.isEmpty) {
      showFToast(context: context, title: const Text('请输入内容'));
      return;
    }
    final current = _current;
    if (current == null) {
      showFToast(
        context: context,
        title: const Text('请先选择设备'),
        description: const Text('扫描局域网或手动输入 IP'),
      );
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    final r = await ref
        .read(noteSlipClientProvider)
        .send(ip: current.ip, content: text, peerName: current.name);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      _composeController.clear();
      showFToast(
        context: context,
        title: const Text('已发送'),
        description: Text('发往 ${current.name}'),
      );
      return;
    }
    showFToast(
      context: context,
      variant: FToastVariant.destructive,
      title: const Text('发送失败'),
      description: Text(r.error ?? ''),
    );
  }

  // ---------- 头部菜单 ----------

  Future<void> _openMenu() async {
    final alwaysOn = ref.read(slipAlwaysOnProvider).value ?? false;
    final picked = await showSheetActionMenu<String>(
      context,
      title: '小纸条',
      size: SheetSize.md,
      actions: [
        SheetAction(
          alwaysOn ? 'always_off' : 'always_on',
          alwaysOn ? '关闭「后台常驻接收」' : '开启「后台常驻接收」',
          icon: FLucideIcons.power,
        ),
        const SheetAction('read_all', '全部标为已读', icon: FLucideIcons.checkCheck),
        const SheetAction('clear', '清空全部记录',
            icon: FLucideIcons.trash2, destructive: true),
      ],
    );
    if (picked == null) return;
    if (picked == 'always_on' || picked == 'always_off') {
      await ref
          .read(slipAlwaysOnProvider.notifier)
          .set(picked == 'always_on');
      if (picked == 'always_on') {
        await NoteSlipBootstrap.ensureDataPlane(ref.read(syncServiceProvider));
      }
      if (!mounted) return;
      showFToast(
        context: context,
        title: Text(picked == 'always_on'
            ? '已开启：不打开页面也能收'
            : '已关闭：仅打开本页时可收'),
      );
      return;
    }
    if (picked == 'read_all') {
      await ref.read(noteSlipRepositoryProvider).markAllRead();
      return;
    }
    if (picked == 'clear') {
      if (!mounted) return;
      final ok = await showSheetConfirm(
        context,
        title: '清空小纸条',
        message: '将删除本机全部收发记录（不影响对端）。',
        confirmLabel: '清空',
      );
      if (ok != true) return;
      await ref.read(noteSlipRepositoryProvider).clearAll();
    }
  }

  // ---------- 条目交互 ----------

  Future<void> _openDetail(NoteSlipData row) => showFSheet<void>(
        context: context,
        side: FLayout.btt,
        mainAxisMaxRatio: AppTokens.sheetHeightLg,
        resizeToAvoidBottomInset: false,
        builder: (_) => NoteSlipDetailSheet(item: row),
      );

  Future<void> _showRowMenu(NoteSlipData row) async {
    final isUrl = row.kind == kSlipKindUrl;
    final picked = await showSheetActionMenu<String>(
      context,
      title: '小纸条',
      size: SheetSize.md,
      actions: [
        const SheetAction('open', '查看详情', icon: FLucideIcons.expand),
        const SheetAction('copy', '复制内容', icon: FLucideIcons.copy),
        if (isUrl)
          const SheetAction('browser', '用浏览器打开', icon: FLucideIcons.globe),
        const SheetAction('note', '存为笔记', icon: FLucideIcons.notebookPen),
        const SheetAction('todo', '新建待办', icon: FLucideIcons.listTodo),
        const SheetAction('delete', '删除', icon: FLucideIcons.trash2,
            destructive: true),
      ],
    );
    if (picked == null) return;
    switch (picked) {
      case 'open':
        await _openDetail(row);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: row.content ?? ''));
        if (mounted) {
          showFToast(context: context, title: const Text('已复制'));
        }
      case 'browser':
        appRouter.push(
          '/browser?url=${Uri.encodeComponent((row.content ?? '').trim())}',
        );
      case 'note':
        await ref.read(noteRepositoryProvider).createNote(
              title: slipTitleOf(row.content ?? ''),
              content: row.content ?? '',
            );
        if (mounted) {
          showFToast(context: context, title: const Text('已存入笔记'));
        }
      case 'todo':
        final text = row.content ?? '';
        final title = slipTitleOf(text);
        await ref.read(todoRepositoryProvider).addTodo(
              title: title,
              description: text == title ? null : text,
            );
        if (mounted) {
          showFToast(context: context, title: const Text('已新建待办'));
        }
      case 'delete':
        await ref.read(noteSlipRepositoryProvider).deleteByKey(row.key);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final rowsAsync = ref.watch(slipListProvider);
    final keyword = _search.trim().toLowerCase();
    final scoped = [
      for (final row in rowsAsync.value ?? const <NoteSlipData>[])
        if (row.direction == _tab &&
            (keyword.isEmpty ||
                (row.content ?? '').toLowerCase().contains(keyword) ||
                (row.peerName ?? '').toLowerCase().contains(keyword)))
          row,
    ];
    final all = rowsAsync.value ?? const <NoteSlipData>[];
    final unread = all
        .where((r) => r.direction == kSlipDirectionIn && r.read == 0)
        .length;

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
                child: rowsAsync.when(
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
                  data: (_) => CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _banner(context, all, unread),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: PinnedSearchHeader(
                          extent: kSearchRowExtent,
                          child: PinnedSearchRow(
                            controller: _searchController,
                            hintText: '搜索内容或来源…',
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ScopeTabBar<String>(
                          tabs: kSlipTabs,
                          selected: _tab,
                          onSelect: (tab) => setState(() => _tab = tab),
                        ),
                      ),
                      if (scoped.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: FLucideIcons.stickyNote,
                            title: all.isEmpty ? '还没有小纸条' : '没有匹配的小纸条',
                            subtitle: all.isEmpty
                                ? '在下方输入框写一条发给电脑，或从电脑发一条过来'
                                : '换个关键词，或切换上方 Tab',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            AppTokens.pagePadding,
                            4,
                            AppTokens.pagePadding,
                            AppTokens.pageBottomGapOf(context),
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              for (final row in scoped)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _SlipCard(
                                    row: row,
                                    onTap: () => _openDetail(row),
                                    onLongPress: () => _showRowMenu(row),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _composeBar(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部（对齐待办：‹ / 标题 / ⋯）
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
              '小纸条',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: _openMenu,
            child: Icon(
              FLucideIcons.ellipsis,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  /// 统计横幅
  Widget _banner(
    BuildContext context,
    List<NoteSlipData> rows,
    int unread,
  ) =>
      PageBanner(
        icon: FLucideIcons.stickyNote,
        title: '小纸条',
        subtitle: '电脑 ⇄ 手机，文字与链接速传',
        gradient: AppTokens.accentGradient(AppTokens.accent(6)),
        cornerRadius: 22,
        ringDecor: true,
        shadow: false,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        stats: [
          ('$unread', '未读'),
          ('${rows.where((r) => r.direction == kSlipDirectionIn).length}',
              '收到'),
          ('${rows.where((r) => r.direction == kSlipDirectionOut).length}',
              '发出'),
        ],
      );

  /// 底部发送条（目标 chip + 输入框 + 发送钮）
  Widget _composeBar(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.colors.border),
        ),
      ),
      child: Row(
        children: [
          FTappable(
            onPress: _pickTarget,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _current == null
                        ? FLucideIcons.smartphone
                        : FLucideIcons.send,
                    size: 15,
                    color: t.colors.foreground,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      _current?.name ?? '选择设备',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.body.xs.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SheetInputBox(
              controller: _composeController,
              hintText: '写一条发给对端…',
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          TapScale(
            onTap: _sending ? null : _send,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTokens.primaryGradient(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: FCircularProgress(),
                    )
                  : const Icon(
                      FLucideIcons.send,
                      size: 18,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表卡片：来源 + 时间 + 2 行摘要 + 未读点
class _SlipCard extends StatelessWidget {
  const _SlipCard({
    required this.row,
    required this.onTap,
    required this.onLongPress,
  });

  final NoteSlipData row;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final incoming = row.direction == kSlipDirectionIn;
    final unread = incoming && row.read == 0;
    return GestureDetector(
      onLongPress: onLongPress,
      child: FTappable(
        onPress: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.colors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: unread
                  ? t.colors.primary.withValues(alpha: 0.45)
                  : t.colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    incoming
                        ? FLucideIcons.arrowDownToLine
                        : FLucideIcons.arrowUpFromLine,
                    size: 14,
                    color: t.colors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row.peerName ?? '未知设备',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ),
                  if (row.kind == kSlipKindUrl)
                    Icon(
                      FLucideIcons.link,
                      size: 13,
                      color: t.colors.primary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    slipTimeLabel(row.createdAt),
                    style: t.typography.body.xs.copyWith(
                      color: t.colors.mutedForeground,
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: t.colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                row.content ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.sm.copyWith(
                  fontSize: 14,
                  height: 1.5,
                  color: t.colors.foreground,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
