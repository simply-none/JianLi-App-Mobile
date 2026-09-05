// 私密文件保险箱页 —— 未建库 / 未解锁 / 已解锁三态（对齐桌面端 FileVault 三态 UI）
//
// 导入走 file_picker；预览：图片直接内存渲染，文本/未知类型仅展示大小信息。
// 解密导出到相册/分享属 P2（需系统分享通道）。
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('私密文件保险箱'),
        actions: [
          if (_service.isUnlocked)
            IconButton(
              tooltip: '锁定',
              icon: const Icon(Icons.lock),
              onPressed: () {
                _service.lock();
                setState(() => _files = null);
              },
            ),
        ],
      ),
      floatingActionButton: _service.isUnlocked
          ? FloatingActionButton.extended(
              onPressed: _importFiles,
              icon: const Icon(Icons.upload_file),
              label: const Text('导入'),
            )
          : null,
      body: FutureBuilder<bool>(
        future: _service.hasVault(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final hasVault = snap.data!;
          if (!hasVault) return _buildSetup();
          if (!_service.isUnlocked) return _buildUnlock();
          return _buildList();
        },
      ),
    );
  }

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

  Widget _buildList() {
    return FutureBuilder<List<({FileVaultFile meta, String name})>>(
      future: _service.listFiles(),
      builder: (context, snap) {
        final items = _files ?? snap.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            const SectionHeader(title: '已加密文件'),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(icon: Icons.folder_special, title: '保险箱是空的', subtitle: '点击右下角导入文件')
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final item in items)
                          ListTile(
                            leading: Icon(
                              item.meta.ext?.contains('png') == true ||
                                      item.meta.ext?.contains('jpg') == true ||
                                      item.meta.ext?.contains('jpeg') == true
                                  ? Icons.image_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(item.name),
                            subtitle: Text('${item.meta.size ?? 0} 字节 · ${item.meta.createdAt ?? ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await _service.deleteFile(item.meta);
                                setState(() => _files = null);
                              },
                            ),
                            onTap: () => _preview(item),
                          ),
                      ],
                    ),
            ),
          ],
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.name),
          content: isImage
              ? InteractiveViewer(child: Image.memory(Uint8List.fromList(bytes)))
              : Text('该类型暂不支持预览（${item.meta.ext}），共 ${bytes.length} 字节。\n导出/分享列 P2。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解密失败：$e')));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e')));
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入 ${files.length} 个文件')));
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_special, size: 64),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '口令', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: working ? null : onSubmit,
              child: Text(working ? '处理中（PBKDF2 运算约数秒）…' : actionLabel),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
