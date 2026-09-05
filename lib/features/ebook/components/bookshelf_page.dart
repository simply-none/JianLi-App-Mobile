// 书架页 —— 导入 + 网格封面列表（对标主流阅读 App 书架）
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/ebook_repository.dart';

/// 书架页
class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelfAsync = ref.watch(StreamProvider<List<EbookBookshelfData>>(
      (ref) => ref.watch(ebookRepositoryProvider).watchBookshelf(),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('电子书'),
        actions: [
          IconButton(
            tooltip: '导入 epub/txt',
            icon: const Icon(Icons.add),
            onPressed: () => _import(context, ref),
          ),
        ],
      ),
      body: shelfAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (books) {
          if (books.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book,
              title: '书架空空',
              subtitle: '支持 EPUB / TXT（PDF 列 P2）',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.62,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: books.length,
            itemBuilder: (context, i) {
              final book = books[i];
              return _BookCell(
                book: book,
                onOpen: () => context.push(
                  '/ebook/reader?path=${Uri.encodeComponent(book.filePath)}',
                ),
                onRemove: () => ref.read(ebookRepositoryProvider).removeBook(book),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    // file_picker 12.x：静态方法，直接返回 List<PlatformFile>
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub', 'txt'],
    );
    final path = files.isNotEmpty ? files.first.path : null;
    if (path == null) return;
    final book = await ref.read(ebookRepositoryProvider).importBook(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(book == null ? '仅支持 EPUB / TXT' : '已导入《${book.title ?? book.name}》')),
      );
    }
  }
}

/// 单本书
class _BookCell extends StatelessWidget {
  const _BookCell({required this.book, required this.onOpen, required this.onRemove});

  final EbookBookshelfData book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onOpen,
      onLongPress: onRemove,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.title ?? book.name ?? '未命名',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '已读 ${(book.percent ?? 0).toStringAsFixed(0)}%',
                    style: TextStyle(color: scheme.onSecondaryContainer.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: (book.percent ?? 0).clamp(0.05, 1.0)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
