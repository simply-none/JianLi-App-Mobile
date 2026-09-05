// 私密文件保险箱页 —— 未建库 / 未解锁 / 已解锁三态（对齐桌面端 FileVault 三态 UI）
//
// forui 化改造说明：
// - 骨架改为 FScaffold + FHeader.nested（返回键 + 锁定头部动作）；
// - 门禁表单：FTextField.password + FButton，错误提示改用 FAlert（destructive）；
// - 导入入口由 FAB.extended 移至 SectionHeader.trailing（原子组件）；
// - 文件行：AppCard + FButton.icon（删除），预览弹窗 AlertDialog → showFDialog + FDialog；
// - SnackBar → showFToast；解密/导入/删除业务逻辑与原来完全一致。
//
// 导入走 file_picker；预览：图片直接内存渲染，文本/未知类型仅展示大小信息。
// 解密导出到相册/分享属 P2（需系统分享通道）。
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/squircle_box.dart';
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
  final _passController = TextEditingController();
  bool _working = false;
  String? _error;
  List<({FileVaultFile meta, String name})>? _files;

  FileVaultService get _service => ref.read(fileVaultServiceProvider);

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('私密文件保险箱'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          // 锁定：清空内存中的密钥与文件列表
          if (_service.isUnlocked)
            FHeaderAction(
              icon: const Icon(FLucideIcons.lock, size: 20),
              onPress: () {
                _service.lock();
                setState(() => _files = null);
              },
              semanticsTooltip: '锁定',
            ),
        ],
      ),
      child: FutureBuilder<bool>(
        future: _service.hasVault(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: FCircularProgress());
          }
          final hasVault = snap.data!;
          if (!hasVault) return _buildSetup();
          if (!_service.isUnlocked) return _buildUnlock();
          return _buildList();
        },
      ),
    );
  }

  /// 首次使用：建库表单
  Widget _buildSetup() {
    return _GateForm(
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
        } catch (e) {
          if (mounted) _error = '$e';
        } finally {
          if (mounted) setState(() => _working = false);
        }
      },
    );
  }

  /// 解锁表单
  Widget _buildUnlock() {
    return _GateForm(
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
        } catch (e) {
          if (mounted) _error = '口令错误：$e';
        } finally {
          if (mounted) setState(() => _working = false);
        }
      },
    );
  }

  /// 已解锁：加密文件列表
  Widget _buildList() {
    return FutureBuilder<List<({FileVaultFile meta, String name})>>(
      future: _service.listFiles(),
      builder: (context, snap) {
        final items = _files ?? snap.data;
        if (items == null) {
          return const Center(child: FCircularProgress());
        }
        return ColoredBox(
          color: AppTokens.pageTint(context),
          child: Column(
            children: [
              // 导入入口（原 FAB.extended 改置区块尾部动作）
              SectionHeader(title: '已加密文件', trailing: '导入', onTrailingTap: _importFiles),
              Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: FLucideIcons.folderLock,
                      title: '保险箱是空的',
                      subtitle: '点击右上角「导入」添加文件',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final item in items)
                          _FileTile(
                            item: item,
                            onTap: () => _preview(item),
                            onDelete: () async {
                              await _service.deleteFile(item.meta);
                              setState(() => _files = null); // 触发重载
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
        );
      },
    );
  }

  /// 预览（图片内存渲染；其他类型仅提示）
  Future<void> _preview(({FileVaultFile meta, String name}) item) async {
    try {
      final bytes = await _service.decryptFile(item.meta);
      if (!mounted) return;
      final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp']
          .any((e) => (item.meta.ext ?? '').toLowerCase().contains(e));
      await showFDialog<void>(
        context: context,
        builder: (context, style, _) => FDialog(
          builder: (context, style) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: style.titleTextStyle),
              const SizedBox(height: 12),
              if (isImage)
                // 限定高度防止大图撑爆对话框，支持缩放/平移查看
                SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: InteractiveViewer(
                    child: Center(child: Image.memory(Uint8List.fromList(bytes))),
                  ),
                )
              else
                Text(
                  '该类型暂不支持预览（${item.meta.ext}），共 ${bytes.length} 字节。\n导出/分享列 P2。',
                  style: style.bodyTextStyle,
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    onPress: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ),
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

/// 建库/解锁共用表单
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
            Icon(FLucideIcons.folderLock, size: 56, color: t.colors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.typography.body.lg.copyWith(fontWeight: FontWeight.w600),
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

/// 单个加密文件行（图标按类型区分 + 名称/元信息 + 删除）
class _FileTile extends StatelessWidget {
  const _FileTile({required this.item, required this.onTap, required this.onDelete});

  final ({FileVaultFile meta, String name}) item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
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
                  style: t.typography.body.md.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.meta.size ?? 0} 字节 · ${item.meta.createdAt ?? ''}',
                  style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 删除（破坏性操作：图标用 destructive 色）
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: onDelete,
            child: Icon(FLucideIcons.trash2, size: 18, color: t.colors.destructive),
          ),
        ],
      ),
    );
  }
}
