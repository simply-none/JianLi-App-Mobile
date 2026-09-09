// 笔记编辑页 —— 2026 视觉重设计（分类/标签 chips 化 + 渐变保存按钮）
//
// 标签能力对齐桌面端 TagSelector：多选彩色 chips（选中 = 标签色软底 + 对勾）、
// 新建标签（同名去重 + PC 同款随机色板）、保存写回 note_book.tags（key JSON 数组）。
// 分类改为 chips 单选（来源已有分类）+ 「＋新建分类」弹窗，替代裸文本框。
// 首批仍为轻量纯文本正文（html 段落化落库，桌面端 vue-quill 可渲染）；
// flutter_quill 富文本工具条编辑器列 P2（接入点在本页替换正文输入框）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import 'note_tag_chip.dart';

/// 笔记编辑页（noteKey 为空 = 新建）
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteKey});

  final String? noteKey;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _category = TextEditingController();
  final Set<String> _selectedTags = {}; // 已选标签 key（note_book.tags 写回值）
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.noteKey != null) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final note = await ref
        .read(noteRepositoryProvider)
        .getNote(widget.noteKey!);
    if (note == null) {
      if (mounted) {
        showFToast(context: context, title: const Text('笔记不存在'));
        context.pop();
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _title.text = note.title == '无标题笔记' ? '' : note.title;
      _content.text = _htmlToText(note.html);
      _category.text = note.category ?? '';
      _selectedTags
        ..clear()
        ..addAll(note.tags);
      _loaded = true;
    });
  }

  /// 简易 html → 纯文本（段落还原；本应用落库的都是我们生成的 <p> 结构）
  static String _htmlToText(String html) {
    return html
        .replaceAll('</p>', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showFToast(context: context, title: const Text('标题不能为空'));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(noteRepositoryProvider);
    if (widget.noteKey == null) {
      await repo.createNote(
        title: title,
        content: _content.text,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        tagKeys: _selectedTags.toList(),
      );
    } else {
      await repo.updateNote(
        widget.noteKey!,
        title: title,
        content: _content.text,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        tagKeys: _selectedTags.toList(),
      );
    }
    if (mounted) context.pop();
  }

  /// 底部抽屉输入（小功能新增统一抽屉化，禁用居中弹窗——见 SKILL.md「UI 体系」约定）
  ///
  /// 键盘避让：padding 叠加 viewInsets.bottom；回车与按钮双通道提交。
  Future<String?> _inputSheet({
    required String title,
    String? subtitle,
    required String hint,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    final value = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: c.theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: c.theme.typography.body.sm.copyWith(
                  color: c.theme.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FTextField(
              control: FTextFieldControl.managed(controller: controller),
              hint: hint,
              autofocus: true,
              onSubmit: (v) => Navigator.pop(c, v),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: confirmLabel,
              icon: FLucideIcons.check,
              onPress: () => Navigator.pop(c, controller.text),
            ),
          ],
        ),
      ),
    );
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 新建分类（底部抽屉，自由命名，与桌面端一致）
  Future<void> _newCategory() async {
    final value = await _inputSheet(
      title: '新建分类',
      hint: '输入分类名',
      confirmLabel: '确定',
    );
    if (value != null && mounted) {
      setState(() => _category.text = value);
    }
  }

  /// 新建标签（底部抽屉；创建后自动选中，同名去重由仓储保证）
  Future<void> _newTag() async {
    final value = await _inputSheet(
      title: '新建标签',
      subtitle: '颜色随机分配，与桌面端观感一致',
      hint: '输入标签名',
      confirmLabel: '创建',
    );
    if (value == null || !mounted) return;
    final tag = await ref.read(noteRepositoryProvider).createTagDef(value);
    if (tag != null && mounted) {
      setState(() => _selectedTags.add(tag.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final categoriesAsync = ref.watch(noteCategoriesProvider);
    final tagDefsAsync = ref.watch(noteTagsProvider);
    final tagDefs = (tagDefsAsync.value ?? const <NoteTag>[])
        .where((d) => !d.deleted)
        .toList();

    return FScaffold(
      header: FHeader.nested(
        title: Text(widget.noteKey == null ? '新建笔记' : '编辑笔记'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: widget.noteKey != null && !_loaded
          ? const Center(child: FCircularProgress())
          : ColoredBox(
              color: AppTokens.pageTint(context),
              // 页面规范：保存/提交按钮固定底部（不随内容滚动），头部不放重复入口
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.pagePadding,
                          12,
                          AppTokens.pagePadding,
                          16,
                        ),
                        children: [
                          // 标题（无 label 大输入，去表单感）
                          FTextField(
                            control: FTextFieldControl.managed(
                              controller: _title,
                            ),
                            hint: '标题',
                          ),
                          const SizedBox(height: 12),
                          // 分类与标签：chips 化编辑卡
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      FLucideIcons.tags,
                                      size: 15,
                                      color: AppTokens.accent(3),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      '分类与标签',
                                      style: t.typography.body.md.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _fieldLabel('分类'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final c
                                        in categoriesAsync.value ??
                                            const <String>[])
                                      _CategoryChip(
                                        label: c,
                                        selected: _category.text == c,
                                        onTap: () => setState(
                                          () => _category.text =
                                              _category.text == c ? '' : c,
                                        ),
                                      ),
                                    _CategoryChip(
                                      label: '新建分类',
                                      icon: FLucideIcons.plus,
                                      selected: false,
                                      onTap: _newCategory,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _fieldLabel('标签（可多选）'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tag in tagDefs)
                                      NoteTagChip(
                                        tag: tag,
                                        selected: _selectedTags.contains(
                                          tag.key,
                                        ),
                                        onTap: () => setState(() {
                                          _selectedTags.contains(tag.key)
                                              ? _selectedTags.remove(tag.key)
                                              : _selectedTags.add(tag.key);
                                        }),
                                      ),
                                    _CategoryChip(
                                      label: '新建标签',
                                      icon: FLucideIcons.plus,
                                      selected: false,
                                      onTap: _newTag,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 正文（多行）
                          FTextField.multiline(
                            control: FTextFieldControl.managed(
                              controller: _content,
                            ),
                            hint: '正文…（纯文本，按行分段）',
                          ),
                        ],
                      ),
                    ),
                    // 底部固定保存条（页面规范：保存/提交按钮统一固定底部，不随内容滚动）
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        8,
                        AppTokens.pagePadding,
                        8,
                      ),
                      child: GradientButton(
                        label: _saving ? '保存中…' : '保存笔记',
                        icon: FLucideIcons.check,
                        onPress: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _fieldLabel(String text) {
    final t = context.theme;
    return Text(
      text,
      style: t.typography.body.xs.copyWith(
        color: t.colors.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 分类 / 新建入口 chip（选中态用笔记域专属琥珀强调色）
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 非空 = 「新建」入口 chip（描边虚位样式 + plus 图标）
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(3);
    final isAdd = icon != null;
    final bg = selected ? accent : (isAdd ? Colors.transparent : t.colors.card);
    final fg = selected ? Colors.white : (isAdd ? accent : t.colors.foreground);
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent
                : (isAdd ? accent.withValues(alpha: 0.5) : t.colors.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdd) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
