// 密码库条目抽屉集 —— 新增/编辑（lg）与 只读详情（lg，脱敏 + 按需显示明文 + TOTP 实时码）
//
// 交互对齐待办详情模式：单击条目先看只读详情（防误触），「编辑」由详情底部条进入
// 编辑表单；长按条目 = 操作菜单（编辑/复制/删除）。字段对齐 PC VaultEntry：
// 名称/账号/密码/网址/备注/分类/OTP 密钥（可选，实时出码）。
// 复制走 secure_clipboard（30 秒自动清空，对齐 PC copy 语义）。
// 弹窗一律三档制 lg 定高；打开不自动聚焦；controller 由各自 State 释放。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../models/password_entry.dart';
import '../../twofactor/services/totp_service.dart';
import '../utils/secure_clipboard.dart';
import 'password_generator_sheet.dart';

/// 新增 / 编辑条目抽屉（lg 定高）。[initial] 空 = 新增。
Future<void> showPasswordEntryFormSheet(
  BuildContext context, {
  required Future<void> Function(PasswordEntry entry) onSave,
  PasswordEntry? initial,
}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => _EntryFormSheet(onSave: onSave, initial: initial),
  );
}

class _EntryFormSheet extends StatefulWidget {
  const _EntryFormSheet({required this.onSave, this.initial});

  final Future<void> Function(PasswordEntry entry) onSave;
  final PasswordEntry? initial;

  @override
  State<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<_EntryFormSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _username =
      TextEditingController(text: widget.initial?.username ?? '');
  late final TextEditingController _password =
      TextEditingController(text: widget.initial?.password ?? '');
  late final TextEditingController _url =
      TextEditingController(text: widget.initial?.url ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.initial?.note ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.initial?.category ?? '');
  late final TextEditingController _otp =
      TextEditingController(text: widget.initial?.otpSecret ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _note.dispose();
    _category.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showFToast(context: context, title: const Text('名称不能为空'));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final entry = PasswordEntry(
      key: widget.initial?.key ?? const Uuid().v4(),
      title: title,
      username: _username.text.trim(),
      password: _password.text,
      url: _url.text.trim(),
      note: _note.text.trim(),
      category: _category.text.trim(),
      otpSecret: _otp.text.trim().toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), ''),
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await widget.onSave(entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('保存失败'),
          description: Text('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 密码框（明/暗文切换 + 生成器入口）
  Widget _passwordField() {
    return _PasswordBox(
      controller: _password,
      onGenerate: () async {
        final generated = await showPasswordGeneratorSheet(context);
        if (generated != null && mounted) {
          setState(() => _password.text = generated);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.initial == null ? '新增条目' : '编辑条目',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          _field('名称', SheetInputBox(controller: _title, hintText: '如 GitHub')),
          _field('账号', SheetInputBox(controller: _username, hintText: '用户名 / 邮箱')),
          _field('密码', _passwordField()),
          _field('网址', SheetInputBox(controller: _url, hintText: 'https://…')),
          _field('分类', SheetInputBox(controller: _category, hintText: '如 开发 / 生活')),
          _field('备注（可选）', SheetMultilineBox(controller: _note, hintText: '备注', minLines: 2)),
          _field('OTP 密钥（可选）', SheetInputBox(controller: _otp, hintText: 'base32，留空不启用')),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: _saving ? '保存中…' : '加密保存',
            icon: FLucideIcons.check,
            onPress: _saving ? null : _save,
          ),
        ),
      ],
    );
  }

  // label↔输入框间距 = SheetFieldLabel 自带 bottom:6，组内不再叠 spacing
  Widget _field(String label, Widget input) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetFieldLabel(label),
          input,
        ],
      );
}

/// 密码输入盒（SheetInputBox 同款视觉 + 明/暗文切换 + 生成器入口）
class _PasswordBox extends StatefulWidget {
  const _PasswordBox({required this.controller, required this.onGenerate});

  final TextEditingController controller;
  final VoidCallback onGenerate;

  @override
  State<_PasswordBox> createState() => _PasswordBoxState();
}

class _PasswordBoxState extends State<_PasswordBox> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: widget.controller,
                obscureText: _obscure,
                style: t.typography.body.sm.copyWith(
                  fontSize: 14,
                  color: t.colors.foreground,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '密码',
                  hintStyle: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onGenerate,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                FLucideIcons.wand,
                size: 16,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                _obscure ? FLucideIcons.eye : FLucideIcons.eyeOff,
                size: 16,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 条目只读详情抽屉（lg 定高）：脱敏展示 + 按需显示明文 + TOTP 实时码 + 底部「编辑」
Future<void> showPasswordEntryDetailSheet(
  BuildContext context, {
  required PasswordEntry entry,
  required VoidCallback onEdit,
}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => _EntryDetailSheet(entry: entry, onEdit: onEdit),
  );
}

class _EntryDetailSheet extends StatefulWidget {
  const _EntryDetailSheet({required this.entry, required this.onEdit});

  final PasswordEntry entry;
  final VoidCallback onEdit;

  @override
  State<_EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends State<_EntryDetailSheet> {
  bool _showPassword = false;

  /// TOTP 实时码（未配置 OTP 时为 null）
  Timer? _totpTicker;
  String? _totpCode;
  int _totpRemaining = 30;

  @override
  void initState() {
    super.initState();
    if (widget.entry.hasOtp) _startTotp();
  }

  @override
  void dispose() {
    _totpTicker?.cancel();
    super.dispose();
  }

  void _startTotp() {
    void compute() {
      final secret = widget.entry.otpSecret ?? '';
      if (secret.isEmpty) return;
      final meta = generateTotpWithMeta(
        secret,
        options: const TotpOptions(),
      );
      if (!mounted) return;
      setState(() {
        _totpCode = meta.code;
        _totpRemaining = meta.remainingSeconds;
      });
    }

    compute();
    _totpTicker = Timer.periodic(const Duration(seconds: 1), (_) => compute());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final e = widget.entry;
    return SheetScaffold(
      title: '条目详情',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          // 条目标题（15/Bold，弹窗内字号上限规则）
          Text(
            e.title,
            style: t.typography.body.lg.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((e.category ?? '').isNotEmpty)
            Wrap(
              children: [
                SoftChip(
                  label: e.category!,
                  color: AppTokens.accent(1),
                  alpha: 0.12,
                ),
              ],
            ),
          // 明细行（对齐待办详情 _detailRow 语义）
          if (e.username.isNotEmpty)
            _detailRow(
              context,
              icon: FLucideIcons.user,
              label: '账号',
              value: e.username,
              onCopy: () => copyWithAutoClear(context, e.username, '账号'),
            ),
          if (e.password.isNotEmpty)
            _detailRow(
              context,
              icon: FLucideIcons.lock,
              label: '密码',
              value: _showPassword ? e.password : '•' * 10,
              trailing: GestureDetector(
                onTap: () => setState(() => _showPassword = !_showPassword),
                child: Icon(
                  _showPassword ? FLucideIcons.eyeOff : FLucideIcons.eye,
                  size: 16,
                  color: t.colors.mutedForeground,
                ),
              ),
              onCopy: () => copyWithAutoClear(context, e.password, '密码'),
            ),
          if (e.url.isNotEmpty)
            _detailRow(
              context,
              icon: FLucideIcons.link,
              label: '网址',
              value: e.url,
              onCopy: () => copyWithAutoClear(context, e.url, '网址'),
            ),
          // TOTP 实时码（对齐 PC get-otp：当前码 + 剩余秒数）
          if (e.hasOtp && _totpCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTokens.accentSoft(context, AppTokens.accent(1)),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    FLucideIcons.keyRound,
                    size: 16,
                    color: AppTokens.accent(1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _totpCode!,
                      style: t.typography.body.lg.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_totpRemaining}s',
                    style: t.typography.body.xs.copyWith(
                      color: t.colors.mutedForeground,
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        copyWithAutoClear(context, _totpCode!, '验证码'),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        FLucideIcons.copy,
                        size: 16,
                        color: AppTokens.accent(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (e.note.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetFieldLabel('备注'),
                Text(
                  e.note,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.foreground,
                  ),
                ),
              ],
            ),
          Text(
            '更新于 ${e.updatedAt}',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: '编辑',
            icon: FLucideIcons.pencil,
            onPress: () {
              Navigator.pop(context);
              widget.onEdit();
            },
          ),
        ),
      ],
    );
  }

  /// 明细行：图标 + 62 宽标签 + 值（可复制 / 尾部动作）
  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    VoidCallback? onCopy,
  }) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.colors.mutedForeground),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  FLucideIcons.copy,
                  size: 16,
                  color: t.colors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
