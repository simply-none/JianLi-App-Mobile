// 书架页 —— 导入 + 网格封面列表（对标主流阅读 App 书架），forui 化
// 导入入口在顶栏 +；导入结果走 showFToast。
import 'package:file_picker/file_picker.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/ebook_repository.dart';

/// 书架页
class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelfAsync = ref.watch(
      StreamProvider<List<EbookBookshelfData>>(
        (ref) => ref.watch(ebookRepositoryProvider).watchBookshelf(),
      ),
    );

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
                    AppTokens.pagePaddingOf(context),
                    12,
                    AppTokens.pagePaddingOf(context),
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
                      return _BookCell(
                        book: book,
                        onOpen: () => context.push(
                          '/ebook/reader?path=${Uri.encodeComponent(book.filePath)}',
                        ),
                        onRemove: () =>
                            ref.read(ebookRepositoryProvider).removeBook(book),
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
        title: Text(
          book == null ? '仅支持 EPUB / TXT' : '已导入《${book.title ?? book.name}》',
        ),
      );
    }
  }
}

/// 单本书（封面占位 + 阅读进度条）
class _BookCell extends StatelessWidget {
  const _BookCell({
    required this.book,
    required this.onOpen,
    required this.onRemove,
  });

  final EbookBookshelfData book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 按标题取专属强调色（同一本书颜色稳定）
    final idx =
        (book.title ?? book.name ?? '').hashCode.abs() %
        AppTokens.accents.length;
    final accent = AppTokens.accent(idx);
    final percent = (book.percent ?? 0).clamp(0.0, 1.0);
    return FTappable(
      onPress: onOpen,
      onLongPress: onRemove,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTokens.accentGradient(accent),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FLucideIcons.bookOpenText,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    book.title ?? book.name ?? '未命名',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: t.typography.body.sm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已读 ${percent.toStringAsFixed(0)}%',
                    style: t.typography.body.xs.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: percent),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
