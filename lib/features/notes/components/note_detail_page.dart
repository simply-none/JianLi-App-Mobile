// 笔记详情页 —— flutter_widget_from_html 渲染 vue-quill 富文本 HTML
//
// 说明：flutter-port.md 原计划「flutter_quill 直吃 html」，实测 quill 消费 html
// 需经 delta 转换且兼容性有限；阅读场景改用 flutter_widget_from_html 保真渲染，
// 编辑器（flutter_quill）列入 P2。图片（data URL / 网络）由该库自动处理。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';

import '../models/note_item.dart';
import '../providers/note_providers.dart';

/// 笔记详情页（路由参数：笔记 key）
class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.noteKey});

  final String noteKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(noteRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/notes/edit?noteKey=${Uri.encodeComponent(noteKey)}'),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(noteRepositoryProvider).deleteNote(noteKey);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: FutureBuilder<NoteItem?>(
        future: repo.getNote(noteKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final note = snapshot.data;
          if (note == null) {
            return Center(child: Text('未找到笔记：$noteKey'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  note.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '${note.category ?? '未分类'} · 更新于 ${note.updateTime}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Divider(height: 1),
              Expanded(child: NoteHtmlView(html: note.html)),
            ],
          );
        },
      ),
    );
  }
}

/// HTML 渲染组件（独立小部件，便于测试与复用）
class NoteHtmlView extends StatelessWidget {
  const NoteHtmlView({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HtmlWidget(html),
    );
  }
}
