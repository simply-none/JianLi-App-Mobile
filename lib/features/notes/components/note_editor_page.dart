// 笔记编辑页 —— 对齐全 App「新增表单」形态（label 字段组 + 无分组卡 + 底部固定保存）
//
// 标签能力对齐桌面端 TagSelector：多选彩色 chips（选中 = 标签色软底 + 对勾）、
// 新建标签（同名去重 + PC 同款随机色板）、保存写回 note_book.tags（key JSON 数组）。
// 分类 = chips 单选（已有分类 ∪ 当前输入分类）+「＋新建分类」抽屉，保存后 invalidate
// 分类 provider（新建分类立即可见、编辑回显不丢，2026-09-13 修复「新建分类无效」）。
// 正文：透明底 + 描边、随内容增高，并在每次输入后把正在输入行滚动进可视区。
// 首批仍为轻量纯文本正文（html 段落化落库，桌面端 vue-quill 可渲染）；
// flutter_quill 富文本工具条编辑器列 P2（接入点在本页替换正文输入框）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
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
  final Set<String> _selectedCategories = {}; // 多选分类（写回 JSON 数组文本）
  final Set<String> _selectedTags = {}; // 已选标签 key（note_book.tags 写回值）
  bool _loaded = false;
  bool _saving = false;

  /// 正文区滚动定位：随内容增高后，把正在输入行滚进可视区
  final _scrollController = ScrollController();
  final _contentFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.noteKey != null) _load();
    _content.addListener(_scrollCaretIntoView);
  }

  @override
  void dispose() {
    _content.removeListener(_scrollCaretIntoView);
    _scrollController.dispose();
    _title.dispose();
    _content.dispose();
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
      _selectedCategories
        ..clear()
        ..addAll(note.categories);
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
        categories: _selectedCategories.toList(),
        tagKeys: _selectedTags.toList(),
      );
    } else {
      await repo.updateNote(
        widget.noteKey!,
        title: title,
        content: _content.text,
        categories: _selectedCategories.toList(),
        tagKeys: _selectedTags.toList(),
      );
    }
    // 分类来自「已有笔记 distinct」的一次性 FutureProvider——新建分类落库后必须
    // 失效重取，否则 chips 里永远不出现新分类（「新建分类无效」的成因之一）
    ref.invalidate(noteCategoriesProvider);
    if (mounted) context.pop();
  }

  /// 正文输入后把光标所在行滚进可视区（正文随内容增高，超出屏幕后页面需跟随滚动）。
  /// 用 TextPainter 算光标 y → 换算全局坐标 → 与「头部下沿 / 键盘上沿 - 保存条」
  /// 组成的可视窗口比较，越界即驱动 ListView 滚动差值。
  void _scrollCaretIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _contentFieldKey.currentContext;
      final sc = _scrollController;
      if (ctx == null || !sc.hasClients) return;
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;
      final t = context.theme;
      final style = t.typography.body.sm.copyWith(
        fontSize: 14,
        color: t.colors.foreground,
      );
      // 光标在正文区内的 y（TextPainter 布局宽度 = 字段内容宽，容器有 12 水平 padding）
      final tp = TextPainter(
        text: TextSpan(text: _content.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: (renderObject.size.width - 24).clamp(50.0, 4000.0));
      final caretTop = tp
          .getOffsetForCaret(_content.selection.extent, Rect.zero)
          .dy;
      final caretBottom = caretTop + tp.preferredLineHeight;

      final fieldTop = renderObject.localToGlobal(Offset.zero).dy;
      final mq = MediaQuery.of(context);
      final keyboard = mq.viewInsets.bottom;
      // 可视窗口：头部/横幅以下 ~120，键盘上方再留保存条 ~90
      final topLimit = 120.0;
      final bottomLimit = mq.size.height - keyboard - 90.0;
      var delta = 0.0;
      if (caretBottom > bottomLimit) {
        delta = caretBottom - bottomLimit;
      } else if (fieldTop + caretTop < topLimit) {
        delta = fieldTop + caretTop - topLimit;
      }
      if (delta.abs() < 1) return;
      final target = (sc.offset + delta).clamp(0.0, sc.position.maxScrollExtent);
      sc.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  /// 底部抽屉输入（小功能新增统一抽屉化，禁用居中弹窗——见 SKILL.md「UI 体系」约定）
  ///
  /// lg 档（内含输入框，80vh 定高）；打开不自动聚焦（红线 #14⑤），
  /// controller 由 [_EditorPromptSheet] 的 State 释放（不跟 await 之后的调用点）。
  Future<String?> _inputSheet({
    required String title,
    String? subtitle,
    required String hint,
    required String confirmLabel,
  }) async {
    final value = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => _EditorPromptSheet(
        title: title,
        subtitle: subtitle,
        hint: hint,
        confirmLabel: confirmLabel,
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
      // 多选语义：新建分类追加进选中集合（不再覆盖此前选择）
      setState(() => _selectedCategories.add(value));
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

  /// 表单分组卡（方案A：一字段组一卡）——卡壳用 [AppCard]（padding 14 / margin 0 /
  /// elevation 1），卡内「label + 字段」；卡片负责分组，输入盒负责强调可编辑区。
  Widget _formCard(Widget child) => AppCard(
    padding: const EdgeInsets.all(14),
    margin: EdgeInsets.zero,
    elevation: 1,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final categoriesAsync = ref.watch(noteCategoriesProvider);
    final tagDefsAsync = ref.watch(noteTagsProvider);
    final tagDefs = (tagDefsAsync.value ?? const <NoteTag>[])
        .where((d) => !d.deleted)
        .toList();
    // chips 数据源 = 已有分类 ∪ 当前选中的分类（新建分类立即可见、编辑回显不丢失）
    final existingCats = categoriesAsync.value ?? const <String>[];
    final cats = <String>[
      for (final c in _selectedCategories)
        if (!existingCats.contains(c)) c,
      ...existingCats,
    ];
    // 正文样式（TextField 与 TextPainter 共用，保证光标行高计算一致）
    final contentStyle = t.typography.body.sm.copyWith(
      fontSize: 14,
      color: t.colors.foreground,
    );

    return FScaffold(
      // ⚠️ childPad:false：页面边距只由 ListView 的 pagePadding 提供
      //（scaffold 默认 childPadding 会再叠一层 → 左右 ~26px，与其他新增页不一致）
      childPad: false,
      header: FHeader.nested(
        // 标题左对齐（forui 默认 Alignment.center 会居中）——紧贴返回按钮右侧
        titleAlignment: Alignment.centerLeft,
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
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.pagePadding,
                          12,
                          AppTokens.pagePadding,
                          16,
                        ),
                        children: [
                          // 分组卡 · 标题（方案A：一字段组一卡，卡内 label + 字段）
                          _formCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SheetFieldLabel('标题'),
                                SheetInputBox(
                                  controller: _title,
                                  hintText: '给这篇笔记起个标题',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 分组卡 · 分类 + 标签（同卡内两段：label + chips）
                          _formCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SheetFieldLabel('分类'),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final c in cats)
                                      _CategoryChip(
                                        label: c,
                                        selected: _selectedCategories.contains(c),
                                        onTap: () => setState(() {
                                          _selectedCategories.contains(c)
                                              ? _selectedCategories.remove(c)
                                              : _selectedCategories.add(c);
                                        }),
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
                                const SheetFieldLabel('标签'),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tag in tagDefs)
                                      NoteTagChip(
                                        tag: tag,
                                        selected: _selectedTags.contains(tag.key),
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
                          const SizedBox(height: 10),
                          // 分组卡 · 正文（透明底 + 描边，随内容增高）
                          _formCard(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SheetFieldLabel('正文'),
                                Container(
                                  key: _contentFieldKey,
                                  constraints: const BoxConstraints(
                                    minHeight: 180,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTokens.inputBorder(context),
                                    ),
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: TextField(
                                      controller: _content,
                                      maxLines: null,
                                      minLines: 1,
                                      style: contentStyle,
                                      cursorColor: t.colors.primary,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        border: InputBorder.none,
                                        hintText: '纯文本，按行分段…',
                                        hintStyle: contentStyle.copyWith(
                                          color: t.colors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
}

/// 分类 / 新建入口 chip（选中 / 强调色跟随**外观主题色**，随换肤动态变化）
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
    // 选中 / 强调色跟随**外观主题色**（随换肤动态变化），不再写死笔记域琥珀
    final accent = t.colors.primary;
    final isAdd = icon != null;
    final bg = selected ? accent : (isAdd ? t.colors.muted : t.colors.card);
    final fg = selected ? Colors.white : (isAdd ? accent : t.colors.foreground);
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

/// 轻量输入抽屉本体（lg 档）：controller 由自身 State 释放（红线：controller
/// 生命周期跟 State，不跟 await 之后的调用点）；打开不自动聚焦。
class _EditorPromptSheet extends StatefulWidget {
  const _EditorPromptSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String hint;
  final String confirmLabel;

  @override
  State<_EditorPromptSheet> createState() => _EditorPromptSheetState();
}

class _EditorPromptSheetState extends State<_EditorPromptSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.title,
      // 内含输入框 → lg 80vh 定高（2026-09-13 全局定案）
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: context.theme.typography.body.sm.copyWith(
                fontSize: 12,
                color: context.theme.colors.mutedForeground,
              ),
            ),
          SheetInputBox(controller: _controller, hintText: widget.hint),
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
            label: widget.confirmLabel,
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(context, _controller.text),
          ),
        ),
      ],
    );
  }
}
