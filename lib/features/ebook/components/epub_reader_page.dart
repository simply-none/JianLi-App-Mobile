// 阅读器页 —— 章节渲染（HTML）+ 上一/下一章 + 进度保存
//
// epub CFI 级精确定位列 P2；首批按「章节索引」保存进度（cfi=chapter:<i>），
// content_hash 与桌面端共享同一身份键，未来同步后可按章节比例近似互通。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../repositories/ebook_repository.dart';
import '../services/epub_service.dart';

/// 阅读器页（路由参数：书籍沙盒路径）
class EpubReaderPage extends ConsumerStatefulWidget {
  const EpubReaderPage({super.key, required this.filePath});

  final String filePath;

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  ParsedBook? _book;
  int _chapter = 0;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final book = await parseBook(widget.filePath);
      if (!mounted) return;
      setState(() {
        _book = book;
        _loading = false;
      });
      // 恢复进度（按书架行 content_hash / path 找上次章节）
      final repo = ref.read(ebookRepositoryProvider);
      final row = await repo.findBookByPath(widget.filePath);
      if (row != null) {
        final progress = await repo.getProgress(row);
        final cfi = progress?.cfi ?? '';
        final idx = cfi.startsWith('chapter:') ? int.tryParse(cfi.substring(8)) ?? 0 : 0;
        if (mounted && idx > 0 && (book.chapters.length > idx)) {
          setState(() => _chapter = idx);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '解析失败：$e';
        _loading = false;
      });
    }
  }

  Future<void> _goChapter(int index) async {
    final book = _book;
    if (book == null || index < 0 || index >= book.chapters.length) return;
    setState(() => _chapter = index);
    // 进度保存（尽力而为，不打断阅读）
    try {
      final repo = ref.read(ebookRepositoryProvider);
      final row = await repo.findBookByPath(widget.filePath);
      if (row != null) {
        final percent = book.chapters.isEmpty
            ? 0.0
            : (index + 1) / book.chapters.length * 100;
        await repo.saveProgress(row, index, percent);
      }
    } catch (_) {
      // 进度保存失败不阻塞阅读（TODO(P2): 记录到错误上报）
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Scaffold(
      appBar: AppBar(
        title: Text(book?.title ?? '阅读'),
        actions: [
          IconButton(
            tooltip: '章节',
            icon: const Icon(Icons.format_list_numbered),
            onPressed: book == null ? null : () => _showChapters(book),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: HtmlWidget(book!.chapters[_chapter].html),
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: _chapter > 0 ? () => _goChapter(_chapter - 1) : null,
                            child: const Text('上一章'),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_chapter + 1}/${book.chapters.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _chapter < book.chapters.length - 1
                                ? () => _goChapter(_chapter + 1)
                                : null,
                            child: const Text('下一章'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showChapters(ParsedBook book) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          for (var i = 0; i < book.chapters.length; i++)
            ListTile(
              dense: true,
              title: Text(book.chapters[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: i == _chapter,
              onTap: () {
                Navigator.pop(context);
                _goChapter(i);
              },
            ),
        ],
      ),
    );
  }
}
