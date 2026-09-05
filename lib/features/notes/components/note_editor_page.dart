// 笔记编辑页 —— 新建/编辑（标题 + 纯文本正文 + 分类）
//
// 首批用轻量文本编辑（html 段落化落库，桌面端 vue-quill 可正常渲染）；
// flutter_quill 富文本工具条编辑器列 P2（依赖已在 pubspec，接入点在本页替换 TextField）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('笔记不存在')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题不能为空')));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteKey == null ? '新建笔记' : '编辑笔记'),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: widget.noteKey != null && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(hintText: '标题', border: InputBorder.none),
                ),
                const Divider(),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                    hintText: '分类（可选）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    hintText: '正文…（纯文本，按行分段）',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
    );
  }
}
