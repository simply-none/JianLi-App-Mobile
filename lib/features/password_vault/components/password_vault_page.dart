// 账号密码管理页 —— 建库/解锁门禁 + 条目列表 + 增改删（对标 Bitwarden 风格的极简版）
//
// 安全约定：口令只在内存（State 字段），锁定/退出即丢；条目明文仅在内存态。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/ui_atoms.dart';
import '../models/password_entry.dart';
import '../providers/password_vault_providers.dart';

/// 密码管理页
class PasswordVaultPage extends ConsumerStatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  ConsumerState<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends ConsumerState<PasswordVaultPage> {
  String? _passphrase; // 仅内存，锁定即清
  bool _working = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final existsAsync = ref.watch(passwordVaultExistsProvider);
    final entriesAsync = ref.watch(passwordVaultEntriesProvider);
    final unlocked = ref.read(passwordVaultEntriesProvider.notifier).isUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账号密码管理'),
        actions: [
          if (unlocked)
            IconButton(
              tooltip: '锁定',
              icon: const Icon(Icons.lock),
              onPressed: () {
                ref.read(passwordVaultEntriesProvider.notifier).lock();
                setState(() => _passphrase = null);
              },
            ),
        ],
      ),
      floatingActionButton: unlocked
          ? FloatingActionButton(
              onPressed: () => _editEntry(null),
              child: const Icon(Icons.add),
            )
          : null,
      body: !unlocked
          ? _buildGate(existsAsync.value ?? false)
          : entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (entries) => entries.isEmpty
                  ? const EmptyState(icon: Icons.key, title: '密码库为空', subtitle: '点击右下角添加第一条')
                  : ListView(
                      children: [
                        for (final e in entries)
                          _EntryTile(
                            entry: e,
                            onEdit: () => _editEntry(e),
                            onDelete: () => ref
                                .read(passwordVaultEntriesProvider.notifier)
                                .deleteEntry(passphrase: _passphrase ?? '', key: e.key),
                          ),
                      ],
                    ),
            ),
    );
  }

  /// 建库 / 解锁 门禁表单
  Widget _buildGate(bool exists) {
    final passController = TextEditingController();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.password, size: 64),
            const SizedBox(height: 12),
            Text(exists ? '输入口令解锁密码库' : '首次使用：设置一个主口令',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '主口令', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _working
                  ? null
                  : () async {
                      setState(() {
                        _working = true;
                        _error = null;
                      });
                      try {
                        final notifier = ref.read(passwordVaultEntriesProvider.notifier);
                        if (exists) {
                          await notifier.unlock(passController.text);
                        } else {
                          await notifier.createVault(passController.text);
                        }
                        if (mounted) _passphrase = passController.text;
                      } catch (e) {
                        if (mounted) _error = '口令错误或操作失败：$e';
                      } finally {
                        if (mounted) setState(() => _working = false);
                      }
                    },
              child: Text(exists ? '解锁' : '创建密码库'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  /// 新增/编辑对话框
  Future<void> _editEntry(PasswordEntry? entry) async {
    final title = TextEditingController(text: entry?.title);
    final username = TextEditingController(text: entry?.username);
    final password = TextEditingController(text: entry?.password);
    final url = TextEditingController(text: entry?.url);
    final note = TextEditingController(text: entry?.note);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry == null ? '新增条目' : '编辑条目'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (c, label, obscure) in [
              (title, '名称', false),
              (username, '账号', false),
              (password, '密码', true),
              (url, '网址', false),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: c,
                  obscureText: obscure,
                  decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
                ),
              ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              ref.read(passwordVaultEntriesProvider.notifier).upsertEntry(
                    passphrase: _passphrase ?? '',
                    key: entry?.key,
                    title: title.text.trim(),
                    username: username.text,
                    password: password.text,
                    url: url.text,
                    note: note.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// 密码条目卡片（账号可见，密码默认遮挡，可复制）
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onEdit, required this.onDelete});

  final PasswordEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              entry.title.isEmpty ? '?' : entry.title.characters.first.toUpperCase(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: Theme.of(context).textTheme.titleSmall),
                if (entry.username.isNotEmpty)
                  Text(entry.username, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制密码',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.password));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('密码已复制')));
            },
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
