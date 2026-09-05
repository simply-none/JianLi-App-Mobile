// 笔记编辑页 —— 新建/编辑（标题 + 纯文本正文 + 分类），forui 化
//
// 首批用轻量文本编辑（html 段落化落库，桌面端 vue-quill 可正常渲染）；
// flutter_quill 富文本工具条编辑器列 P2（依赖已在 pubspec，接入点在本页替换 FTextField）。
// 保存入口在顶栏右侧勾按钮；反馈走 showFToast（app 根已有 FToaster）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/note_providers.dart';

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
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.noteKey != null) _load();
  }

  Future<void> _load() async {
    final note = await ref.read(noteRepositoryProvider).getNote(widget.noteKey!);
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
      );
    } else {
      await repo.updateNote(
        widget.noteKey!,
        title: title,
        content: _content.text,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: Text(widget.noteKey == null ? '新建笔记' : '编辑笔记'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.check),
            // 保存中禁用（onPress 为 null 即禁用态）
            onPress: _saving ? null : _save,
          ),
        ],
      ),
      child: widget.noteKey != null && !_loaded
          ? const Center(child: FCircularProgress())
          : ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                // 标题
                FTextField(
                  control: FTextFieldControl.managed(controller: _title),
                  label: const Text('标题'),
                  hint: '给笔记起个名字',
                ),
                const SizedBox(height: 12),
                // 分类（可选）
                FTextField(
                  control: FTextFieldControl.managed(controller: _category),
                  hint: '分类（可选）',
                ),
                const SizedBox(height: 12),
                // 正文（多行）
                FTextField.multiline(
                  control: FTextFieldControl.managed(controller: _content),
                  hint: '正文…（纯文本，按行分段）',
                ),
              ],
            ),
    );
  }
}
