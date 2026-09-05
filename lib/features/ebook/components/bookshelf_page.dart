// 书架页 —— 导入 + 网格封面列表（对标主流阅读 App 书架），forui 化
// 导入入口在顶栏 +；导入结果走 showFToast。
import 'package:file_picker/file_picker.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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

    return FScaffold(
      header: FHeader.nested(
        title: const Text('电子书'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _import(context, ref),
          ),
        ],
      ),
      child: shelfAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (books) {
          if (books.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.bookOpenText,
              title: '书架空空',
              subtitle: '支持 EPUB / TXT（PDF 列 P2）',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
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
      showFToast(
        context: context,
        title: Text(book == null ? '仅支持 EPUB / TXT' : '已导入《${book.title ?? book.name}》'),
      );
    }
  }
}

/// 单本书（封面占位 + 阅读进度条）
class _BookCell extends StatelessWidget {
  const _BookCell({required this.book, required this.onOpen, required this.onRemove});

  final EbookBookshelfData book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: onOpen,
      onLongPress: onRemove,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: t.colors.muted,
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
                    style: t.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '已读 ${(book.percent ?? 0).toStringAsFixed(0)}%',
                    style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: t.colors.primary.withValues(alpha: (book.percent ?? 0).clamp(0.05, 1.0)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
