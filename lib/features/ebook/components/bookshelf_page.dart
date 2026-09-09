// 书架页 —— 导入 + 网格封面列表（对标主流阅读 App 书架），forui 化
//
// 数据经顶层 bookshelfStreamProvider（⚠️ 禁止 build 内联 StreamProvider——
// 每次重建都是新 provider，页面永远 loading，实踩见 ebook_providers.dart 头注释）。
// 导入入口在顶栏 +；删除 = 长按书格 → showFDialog 二次确认（破坏性规范）。
import 'package:file_picker/file_picker.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';
import 'book_cell.dart';

/// 书架页
class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelfAsync = ref.watch(bookshelfStreamProvider);

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
      child: ColoredBox(
        color: AppTokens.pageTint(context),
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
            // 页面专属青渐变横幅 + 封面网格（Sliver 组合，横幅随页面滚动）
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PageBanner(
                    icon: FLucideIcons.bookOpenText,
                    title: '电子书',
                    subtitle: 'EPUB / TXT 随身阅读',
                    accentIndex: 5,
                    stats: [('${books.length}', '本藏书')],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.62,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final book = books[i];
                      return BookCell(
                        book: book,
                        onOpen: () => context.push(
                          '/ebook/reader?path=${Uri.encodeComponent(book.filePath)}',
                        ),
                        onRemove: () => _confirmRemove(context, ref, book),
                      );
                    }, childCount: books.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 导入书籍（file_picker 12.x 静态方法，直接返回 List<PlatformFile>）
  Future<void> _import(BuildContext context, WidgetRef ref) async {
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
        title: Text(
          book == null ? '仅支持 EPUB / TXT' : '已导入《${book.title ?? book.name}》',
        ),
      );
    }
  }

  /// 删除确认（破坏性操作规范：showFDialog 二次确认；仅删书架引用不删内容）
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    EbookBookshelfData book,
  ) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (c, style, _) => FDialog(
        builder: (c, style) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将《${book.title ?? book.name}》移出书架？',
              style: style.titleTextStyle,
            ),
            const SizedBox(height: 8),
            Text('将同时删除本地文件副本；阅读进度按内容哈希保留，重新导入可恢复', style: style.bodyTextStyle),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.pop(c),
                  child: const Text('取消'),
                ),
                FButton(
                  variant: FButtonVariant.destructive,
                  onPress: () => Navigator.pop(c, true),
                  child: const Text('移出'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(ebookRepositoryProvider).removeBook(book);
    }
  }
}
