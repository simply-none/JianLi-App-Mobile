// 私密文件保险箱页 —— 对齐待办列表页骨架（专属色横幅统计 + 吸顶搜索行 + 文件卡）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 文件保险箱18/Bold · 导入 · 锁定（解锁态）
//   统计横幅 PageBanner 绿专属渐变 · stats 文件数/总大小/种类（随滚动移出）
//   搜索行  ★吸顶锚点（搜索文件名）
//   列表    文件卡（扩展名图标盘 + 名称 + 大小/时间）；单击=预览、长按=操作菜单
//
// 能力对齐 PC 端 fileVault：导入（多选）、解密预览、导出/分享（移动端以 share_plus
// 分享明文临时文件承载 PC 的「导出到所选目录」）、删除、立即锁定、三态门禁。
// 预览/导出的解密逻辑与原实现一致；明文仅进临时文件，分享面板关闭即弃。
// 门禁走共享三态：未建库（设密）/ 未解锁 / 已解锁，业务逻辑不变。
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/card_textures.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/file_vault_repository.dart';

/// 文件保险箱页
class FileVaultPage extends ConsumerStatefulWidget {
  const FileVaultPage({super.key});

  @override
  ConsumerState<FileVaultPage> createState() => _FileVaultPageState();
}

class _FileVaultPageState extends ConsumerState<FileVaultPage> {
  /// 保险箱域专属绿强调色（与工具分组页「保险箱」入口色对齐）
  static final Color _accent = AppTokens.accent(2);

  final _passController = TextEditingController();
  bool _working = false;
  String? _error;
  List<({FileVaultFile meta, String name})>? _files;

  /// 页内搜索（文件名）
  String _search = '';
  final _searchController = TextEditingController();

  FileVaultService get _service => ref.read(fileVaultServiceProvider);

  @override
  void dispose() {
    _passController.dispose();
    _searchController.dispose();
    // 路由切走即锁定（清零内存密钥 + 置反开关），满足「路由切换时锁住」
    _service.lock();
    ref.read(fileVaultUnlockedProvider.notifier).lock();
    super.dispose();
  }

  void _lock() {
    _service.lock();
    ref.read(fileVaultUnlockedProvider.notifier).lock();
    setState(() {
      _files = null;
      _search = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(fileVaultUnlockedProvider);
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: FutureBuilder<bool>(
            future: _service.hasVault(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: FCircularProgress());
              }
              final hasVault = snap.data!;
              return Column(
                children: [
                  _header(context, showActions: hasVault && unlocked),
                  Expanded(
                    child: !hasVault
                        ? _buildSetup()
                        : !unlocked
                            ? _buildUnlock()
                            : _buildList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ===================== 头部（对齐待办：‹ / 标题 / 导入 / 锁定） =====================

  Widget _header(BuildContext context, {required bool showActions}) {
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
              '文件保险箱',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          if (showActions) ...[
            TapScale(
              onTap: _importFiles,
              child: Icon(
                FLucideIcons.plus,
                size: 22,
                color: t.colors.foreground,
              ),
            ),
            TapScale(
              onTap: _lock,
              child: Icon(
                FLucideIcons.lock,
                size: 18,
                color: t.colors.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== 门禁（建库 / 解锁，业务逻辑不变） =====================

  Widget _buildSetup() => _GateForm(
        passController: _passController,
        title: '首次使用：设置保险箱口令',
        actionLabel: '创建保险箱',
        working: _working,
        error: _error,
        onSubmit: () async {
          setState(() {
            _working = true;
            _error = null;
          });
          try {
            await _service.setPassword(_passController.text);
            if (mounted) {
              ref.read(fileVaultUnlockedProvider.notifier).unlock();
            }
          } catch (e) {
            if (mounted) _error = '$e';
          } finally {
            if (mounted) setState(() => _working = false);
          }
        },
      );

  Widget _buildUnlock() => _GateForm(
        passController: _passController,
        title: '输入口令解锁保险箱',
        actionLabel: '解锁',
        working: _working,
        error: _error,
        onSubmit: () async {
          setState(() {
            _working = true;
            _error = null;
          });
          try {
            await _service.unlock(_passController.text);
            if (mounted) {
              ref.read(fileVaultUnlockedProvider.notifier).unlock();
            }
          } catch (e) {
            if (mounted) _error = '口令错误：$e';
          } finally {
            if (mounted) setState(() => _working = false);
          }
        },
      );

  // ===================== 已解锁：文件列表 =====================

  Widget _buildList() {
    return FutureBuilder<List<({FileVaultFile meta, String name})>>(
      future: _service.listFiles(),
      builder: (context, snap) {
        final items = _files ?? snap.data;
        if (items == null) {
          return const Center(child: FCircularProgress());
        }
        final kw = _search.trim().toLowerCase();
        final filtered = kw.isEmpty
            ? items
            : items.where((it) => it.name.toLowerCase().contains(kw)).toList();
        final totalBytes = items.fold<int>(
          0,
          (sum, it) => sum + (int.tryParse(it.meta.size ?? '') ?? 0),
        );
        final exts = {
          for (final it in items)
            (it.meta.ext ?? '?').split('.').last.toLowerCase(),
        };

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageBanner(
                icon: FLucideIcons.folderLock,
                title: '私密文件保险箱',
                subtitle: 'AES-256 加密存储，随开随取',
                accentIndex: 2,
                cornerRadius: 22,
                textureAsset: CardTextures.texture11,
                ringDecor: true,
                shadow: false,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                stats: [
                  ('${items.length}', '文件'),
                  (_humanSize(totalBytes), '总大小'),
                  ('${exts.length}', '种类'),
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
                  hintText: '搜索文件名…',
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
            if (items.isEmpty)
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
                    final item = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileTile(
                        item: item,
                        onTap: () => _preview(item),
                        onLongPress: () => _fileMenu(item),
                      ),
                    );
                  }, childCount: filtered.length),
                ),
              ),
          ],
        );
      },
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
              totallyEmpty ? FLucideIcons.folderLock : FLucideIcons.searchX,
              size: 32,
              color: _accent,
            ),
          ),
          Text(
            totallyEmpty ? '保险箱是空的' : '没有匹配的文件',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点头部 ＋ 导入第一个加密文件' : '换个关键词再试',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 行为 =====================

  /// 文件长按菜单（预览 / 导出分享 / 删除）
  Future<void> _fileMenu(({FileVaultFile meta, String name}) item) async {
    final action = await showSheetActionMenu<String>(
      context,
      title: item.name,
      actions: const [
        SheetAction('preview', '预览', icon: FLucideIcons.eye),
        SheetAction('share', '导出 / 分享', icon: FLucideIcons.share),
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
      case 'preview':
        await _preview(item);
      case 'share':
        await _shareFile(item);
      case 'delete':
        await _deleteFile(item);
    }
  }

  /// 解密到临时文件并经系统分享面板导出（对齐 PC「导出到所选目录」的移动端形态：
  /// 明文仅写入临时文件，由用户经分享面板另存，关闭即弃）
  Future<void> _shareFile(({FileVaultFile meta, String name}) item) async {
    try {
      final bytes = await _service.decryptFile(item.meta);
      final dir = await getTemporaryDirectory();
      final safeName = item.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '渐离App 保险箱导出：${item.name}',
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

  Future<void> _deleteFile(({FileVaultFile meta, String name}) item) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除文件',
      message: '确定删除「${item.name}」？密文与元数据将一并删除，不可恢复。',
    );
    if (!ok) return;
    await _service.deleteFile(item.meta);
    if (mounted) setState(() => _files = null); // 触发重载
  }

  /// 预览（lg 三档制抽屉；图片内存渲染可缩放，其他类型给出导出入口）
  Future<void> _preview(({FileVaultFile meta, String name}) item) async {
    try {
      final bytes = await _service.decryptFile(item.meta);
      if (!mounted) return;
      final isImage = [
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
      ].any((e) => (item.meta.ext ?? '').toLowerCase().contains(e));
      await showFSheet<void>(
        context: context,
        side: FLayout.btt,
        mainAxisMaxRatio: AppTokens.sheetHeightLg,
        resizeToAvoidBottomInset: false,
        builder: (c) => SheetScaffold(
          title: '预览',
          size: SheetSize.lg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              // 条目名（15/Bold，弹窗内字号上限规则）
              Text(
                item.name,
                style: c.theme.typography.body.lg.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: isImage
                    ? // 限定高度防溢出，支持缩放/平移查看
                    InteractiveViewer(
                        child: Center(
                          child: Image.memory(Uint8List.fromList(bytes)),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 8,
                          children: [
                            Icon(
                              FLucideIcons.file,
                              size: 40,
                              color: c.theme.colors.mutedForeground,
                            ),
                            Text(
                              '该类型暂不支持直接预览（${item.meta.ext}），'
                              '共 ${_humanSize(bytes.length)}',
                              textAlign: TextAlign.center,
                              style: c.theme.typography.body.sm.copyWith(
                                color: c.theme.colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          bottomBar: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.outline,
                onPress: () => Navigator.pop(c),
                child: const Text('关闭'),
              ),
            ),
            Expanded(
              child: GradientButton(
                label: '导出 / 分享',
                icon: FLucideIcons.share,
                onPress: () {
                  Navigator.pop(c);
                  _shareFile(item);
                },
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('解密失败'),
          description: Text('$e'),
        );
      }
    }
  }

  /// 选择并导入文件（file_picker 12.x 静态 API）
  Future<void> _importFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    for (final f in files) {
      final path = f.path;
      if (path == null) continue;
      try {
        await _service.importFile(path);
      } catch (e) {
        if (mounted) {
          showFToast(
            context: context,
            variant: FToastVariant.destructive,
            title: const Text('导入失败'),
            description: Text('$e'),
          );
        }
      }
    }
    if (mounted) {
      showFToast(context: context, title: Text('已导入 ${files.length} 个文件'));
      setState(() => _files = null); // 触发重载
    }
  }
}

/// 建库/解锁共用表单（专属绿渐变图标盘；业务逻辑不变）
class _GateForm extends StatelessWidget {
  const _GateForm({
    required this.passController,
    required this.title,
    required this.actionLabel,
    required this.working,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController passController;
  final String title;
  final String actionLabel;
  final bool working;
  final String? error;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SquircleBox(
                size: 76,
                radius: 26,
                gradient: AppTokens.accentGradient(AppTokens.accent(2)),
                alignment: Alignment.center,
                child: const Icon(
                  FLucideIcons.folderLock,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FTextField.password(
              control: FTextFieldControl.managed(controller: passController),
              label: const Text('口令'),
              hint: '仅驻留内存，锁定即清除',
            ),
            const SizedBox(height: 12),
            FButton(
              onPress: working ? null : onSubmit,
              child: Text(working ? '处理中（PBKDF2 运算约数秒）…' : actionLabel),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              FAlert(
                variant: FAlertVariant.destructive,
                title: const Text('操作失败'),
                subtitle: Text(error!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个加密文件行（扩展名图标盘 + 名称 + 大小/时间）；单击=预览、长按=菜单
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final ({FileVaultFile meta, String name}) item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// 按扩展名选择图标：图片类用图片图标，其余用通用文件图标
  IconData get _icon {
    final ext = item.meta.ext ?? '';
    final isImage = ['png', 'jpg', 'jpeg'].any((e) => ext.contains(e));
    return isImage ? FLucideIcons.image : FLucideIcons.file;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      // 列表卡 margin 清零：间距只由外层 Padding(bottom:10) 提供
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.pagePadding,
        vertical: 12,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          SquircleBox(
            size: 44,
            radius: 14,
            gradient: AppTokens.accentGradient(AppTokens.accent(2)),
            alignment: Alignment.center,
            child: Icon(_icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_humanSize(int.tryParse(item.meta.size ?? '') ?? 0)} · ${item.meta.createdAt ?? ''}',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 11,
                    color: t.colors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            FLucideIcons.chevronRight,
            size: 18,
            color: t.colors.mutedForeground,
          ),
        ],
      ),
    );
  }
}

/// 字节数 → 人类可读大小（页面与文件行卡共用）
String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
