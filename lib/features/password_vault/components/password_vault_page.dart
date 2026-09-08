// 账号密码管理页 —— 建库/解锁门禁 + 条目列表 + 增改删（对标 Bitwarden 风格的极简版）
//
// forui 化改造说明：
// - 骨架改为 FScaffold + FHeader.nested（返回键 + 新增/锁定头部动作）；
// - 门禁表单：FTextField.password + FButton，错误提示改用 FAlert（destructive）；
// - 增改弹窗：AlertDialog → showFDialog + FDialog（内含 FTextField 表单）；
// - 条目行：AppCard + FButton.icon（复制/编辑/删除），SnackBar → showFToast；
// - 业务逻辑（建库/解锁/条目增改删/内存口令策略）与原来完全一致。
//
// 安全约定：口令只在内存（State 字段），锁定/退出即丢；条目明文仅在内存态。
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
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
  void dispose() {
    // 路由切走即锁定（清空内存明文 + 置反开关），满足「路由切换时锁住」
    ref.read(passwordVaultEntriesProvider.notifier).lock();
    ref.read(passwordVaultUnlockedProvider.notifier).state = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final existsAsync = ref.watch(passwordVaultExistsProvider);
    final entriesAsync = ref.watch(passwordVaultEntriesProvider);
    final unlocked = ref.watch(passwordVaultUnlockedProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('账号密码管理'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          if (unlocked) ...[
            // 新增条目（原 FAB 的替代入口）
            FHeaderAction(
              icon: const Icon(FLucideIcons.plus, size: 20),
              onPress: () => _editEntry(null),
              semanticsTooltip: '新增条目',
            ),
            // 锁定：清空内存口令
            FHeaderAction(
              icon: const Icon(FLucideIcons.lock, size: 20),
              onPress: () {
                ref.read(passwordVaultEntriesProvider.notifier).lock();
                ref.read(passwordVaultUnlockedProvider.notifier).state = false;
                setState(() => _passphrase = null);
              },
              semanticsTooltip: '锁定',
            ),
          ],
        ],
      ),
      child: !unlocked
          ? _buildGate(existsAsync.value ?? false)
          : entriesAsync.when(
              loading: () => const Center(child: FCircularProgress()),
              error: (e, _) => Center(
                child: Text(
                  '加载失败：$e',
                  style: t.typography.body.sm.copyWith(color: t.colors.error),
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? const EmptyState(
                      icon: FLucideIcons.keyRound,
                      title: '密码库为空',
                      subtitle: '点击右上角 + 添加第一条',
                    )
                  : ColoredBox(
                      color: AppTokens.pageTint(context),
                      child: ListView(
                        padding: EdgeInsets.only(
                          top: AppTokens.listTopGapOf(context),
                          bottom: AppTokens.pageBottomGapOf(context),
                        ),
                        children: [
                          // 页面专属蓝渐变横幅（与工具分组页「密码管理」入口色对齐）
                          PageBanner(
                            icon: FLucideIcons.lock,
                            title: '账号密码管理',
                            subtitle: 'AES-256 加密，仅驻留本机内存',
                            accentIndex: 1,
                            stats: [('${entries.length}', '已存条目')],
                          ),
                          StaggerList(
                            children: [
                              for (final e in entries)
                                _EntryTile(
                                  entry: e,
                                  onEdit: () => _editEntry(e),
                                  onDelete: () => ref
                                      .read(
                                        passwordVaultEntriesProvider.notifier,
                                      )
                                      .deleteEntry(
                                        passphrase: _passphrase ?? '',
                                        key: e.key,
                                      ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }

  /// 建库 / 解锁 门禁表单（pageTint 冷调底 + 专属蓝渐变图标盘）
  Widget _buildGate(bool exists) {
    final t = context.theme;
    final passController = TextEditingController();
    return ColoredBox(
      color: AppTokens.pageTint(context),
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
                  gradient: AppTokens.accentGradient(AppTokens.accent(1)),
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
                control: FTextFieldControl.managed(controller: passController),
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
                            await notifier.unlock(passController.text);
                          } else {
                            await notifier.createVault(passController.text);
                          }
                          if (mounted) _passphrase = passController.text;
                          if (mounted) {
                            ref
                                    .read(
                                      passwordVaultUnlockedProvider.notifier,
                                    )
                                    .state =
                                true;
                          }
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
    );
  }

  /// 新增/编辑条目（底部抽屉——小功能新增/编辑统一抽屉化；
  /// 表单较高：SingleChildScrollView + mainAxisMaxRatio null 允许拖高）
  Future<void> _editEntry(PasswordEntry? entry) async {
    final title = TextEditingController(text: entry?.title);
    final username = TextEditingController(text: entry?.username);
    final password = TextEditingController(text: entry?.password);
    final url = TextEditingController(text: entry?.url);
    final note = TextEditingController(text: entry?.note);

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 表单较高且可滚动，不限制弹层最大高度
      mainAxisMaxRatio: null,
      builder: (context) => SheetSurface(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry == null ? '新增条目' : '编辑条目',
                style: context.theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FTextField(
                control: FTextFieldControl.managed(controller: title),
                label: const Text('名称'),
              ),
              const SizedBox(height: 8),
              FTextField(
                control: FTextFieldControl.managed(controller: username),
                label: const Text('账号'),
              ),
              const SizedBox(height: 8),
              // 密码输入框：自带明/暗文切换
              FTextField.password(
                control: FTextFieldControl.managed(controller: password),
                label: const Text('密码'),
              ),
              const SizedBox(height: 8),
              FTextField(
                control: FTextFieldControl.managed(controller: url),
                label: const Text('网址'),
              ),
              const SizedBox(height: 8),
              FTextField(
                control: FTextFieldControl.managed(controller: note),
                label: const Text('备注'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                spacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    onPress: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Expanded(
                    child: GradientButton(
                      label: '保存',
                      icon: FLucideIcons.check,
                      onPress: () {
                        ref
                            .read(passwordVaultEntriesProvider.notifier)
                            .upsertEntry(
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 密码条目卡片（账号可见，密码默认遮挡，可复制）
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final PasswordEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // 首字母徽标（专属蓝强调色渐变底盘）
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(AppTokens.accent(1)),
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
                if (entry.username.isNotEmpty)
                  Text(
                    entry.username,
                    style: t.typography.body.sm.copyWith(
                      color: t.colors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 复制密码
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: () {
              Clipboard.setData(ClipboardData(text: entry.password));
              showFToast(context: context, title: const Text('密码已复制'));
            },
            child: const Icon(FLucideIcons.copy, size: 18),
          ),
          // 编辑
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: onEdit,
            child: const Icon(FLucideIcons.pencil, size: 18),
          ),
          // 删除（破坏性操作：图标用 destructive 色）
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: onDelete,
            child: Icon(
              FLucideIcons.trash2,
              size: 18,
              color: t.colors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}
