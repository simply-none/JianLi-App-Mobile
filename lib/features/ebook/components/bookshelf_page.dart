// 书架页 —— 导入 + 网格封面列表（对标主流阅读 App 书架），forui 化
//
// 数据经顶层 bookshelfStreamProvider（⚠️ 禁止 build 内联 StreamProvider——
// 每次重建都是新 provider，页面永远 loading，实踩见 ebook_providers.dart 头注释）。
// 导入入口在顶栏 +；删除 = 长按书格 → showFDialog 二次确认（破坏性规范）。
// 分类（2026-09-09）：顶栏「标签」管理分类与给书打标签；顶部 chips 按分类筛选。
import 'package:file_picker/file_picker.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';
import 'book_cell.dart';

/// 书架页
class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  /// 当前选中的分类筛选（null = 全部）
  int? _selectedCat;

  @override
  Widget build(BuildContext context) {
    final shelfAsync = ref.watch(bookshelfStreamProvider);
    final catsAsync = ref.watch(categoriesStreamProvider);
    final bookCatsAsync = ref.watch(bookCategoriesStreamProvider);

    // book_path -> categoryIds
    final bookToCats = <String, Set<int>>{};
    for (final bc in bookCatsAsync.value ?? <EbookBookCategoryData>[]) {
      bookToCats.putIfAbsent(bc.bookPath, () => <int>{}).add(bc.categoryId);
    }
    // id -> category
    final catMap = <int, EbookCategoryData>{};
    for (final c in catsAsync.value ?? <EbookCategoryData>[]) {
      catMap[c.id] = c;
    }

    return FScaffold(
      header: FHeader.nested(
        title: const Text('电子书'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.tags),
            onPress: () => _showCategoryManager(),
          ),
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
            // 按选中分类筛选
            final filtered =
                _selectedCat == null
                    ? books
                    : books
                        .where(
                          (b) =>
                              (bookToCats[b.filePath] ?? {}).contains(
                                _selectedCat,
                              ),
                        )
                        .toList();

            // 分类筛选 chips（有分类才显示；始终用 SliverToBoxAdapter 包裹，
            // 无分类时内部退化为空 SizedBox，避免条件元素触发 lint）
            final catChips =
                catsAsync.value == null || catsAsync.value!.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTokens.pagePadding,
                            ),
                            child: Row(
                              spacing: 8,
                              children: [
                                _catChip('全部', _selectedCat == null, () {
                                  setState(() => _selectedCat = null);
                                }),
                                for (final c in catsAsync.value!)
                                  _catChip(c.name, _selectedCat == c.id, () {
                                    setState(() => _selectedCat = c.id);
                                  }),
                              ],
                            ),
                          ),
                        ],
                      );
            final catSliver = SliverToBoxAdapter(child: catChips);

            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  '该分类下暂无书籍',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
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
                catSliver,
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
                      final book = filtered[i];
                      final labels =
                          (bookToCats[book.filePath] ?? {})
                              .map((id) => catMap[id]?.name ?? '')
                              .where((n) => n.isNotEmpty)
                              .toList();
                      return BookCell(
                        book: book,
                        categoryLabels: labels,
                        onOpen: () => context.push(
                          '/ebook/reader?path=${Uri.encodeComponent(book.filePath)}',
                        ),
                        onRemove: () => _confirmRemove(context, ref, book),
                      );
                    }, childCount: filtered.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 分类筛选 chip
  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    return FButton(
      variant: selected ? FButtonVariant.primary : FButtonVariant.outline,
      onPress: onTap,
      child: Text(label),
    );
  }

  /// 导入书籍（file_picker 12.x 静态方法，用户取消时返回空列表）
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'txt'],
      );
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path == null) return;
      final book = await ref.read(ebookRepositoryProvider).importBook(path);
      if (context.mounted) {
        showFToast(
          context: context,
          title: Text(
            book == null
                ? '仅支持 EPUB / TXT'
                : '已导入《${book.title ?? book.name}》',
          ),
        );
      }
    } catch (e) {
      // 显式暴露导入失败真因（便于定位「导入都报错」根因，而非静默崩溃/被 Future 吞掉）
      if (context.mounted) {
        showFToast(context: context, title: Text('导入失败：$e'));
      }
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

  /// 分类管理：新建分类 + 给书打标签
  void _showCategoryManager() {
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSt) {
              var newName = '';
              final cats = ref.watch(categoriesStreamProvider);
              final bookCatsAsync = ref.watch(bookCategoriesStreamProvider);
              final shelf = ref.watch(bookshelfStreamProvider);
              final allCats = cats.value ?? const <EbookCategoryData>[];
              // id -> category（从实时数据重建，避免传参过期）
              final sheetCatMap = <int, EbookCategoryData>{};
              for (final c in allCats) {
                sheetCatMap[c.id] = c;
              }
              final bookToCats = <String, Set<int>>{};
              for (final bc
                  in bookCatsAsync.value ?? const <EbookBookCategoryData>[]) {
                bookToCats.putIfAbsent(bc.bookPath, () => <int>{}).add(
                  bc.categoryId,
                );
              }
              final books = shelf.value ?? const <EbookBookshelfData>[];

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text(
                      '分类管理',
                      style: context.theme.typography.body.lg,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTokens.pagePadding),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: FTextField(
                            label: const Text('新建分类'),
                            control: FTextFieldControl.managed(
                              onChange: (v) =>
                                  setSt(() => newName = v.text.trim()),
                            ),
                          ),
                        ),
                        FButton(
                          onPress: () async {
                            if (newName.isEmpty) return;
                            await ref
                                .read(ebookRepositoryProvider)
                                .addCategory(newName);
                            newName = '';
                            setSt(() {});
                          },
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  const FDivider(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        FTileGroup(
                          divider: FItemDivider.none,
                          children: [
                            for (final c in allCats)
                              FTile(
                                title: Text(c.name),
                                suffix: FButton(
                                  variant: FButtonVariant.destructive,
                                  onPress: () async {
                                    await ref
                                        .read(ebookRepositoryProvider)
                                        .removeCategory(c.id);
                                  },
                                  child: const Icon(FLucideIcons.tagX),
                                ),
                              ),
                            for (final b in books)
                              FTile(
                                title: Text(
                                  b.title ?? b.name ?? '未命名',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _catNames(
                                    bookToCats[b.filePath] ?? {},
                                    sheetCatMap,
                                  ),
                                ),
                                onPress: () => _editBookCategories(
                                  b,
                                  bookToCats[b.filePath] ?? {},
                                  allCats,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 分类 id 集合转可读名称（无则「未分类」）
  String _catNames(Set<int> ids, Map<int, EbookCategoryData> map) {
    final names = ids
        .map((id) => map[id]?.name ?? '')
        .where((n) => n.isNotEmpty)
        .join('、');
    return names.isEmpty ? '未分类' : names;
  }

  /// 给单本书勾选分类（弹窗内即时切换并落库）
  Future<void> _editBookCategories(
    EbookBookshelfData book,
    Set<int> assigned,
    List<EbookCategoryData> allCats,
  ) async {
    final repo = ref.read(ebookRepositoryProvider);
    final current = <int>{...assigned};
    await showFDialog<bool>(
      context: context,
      builder: (c, style, _) => FDialog(
        builder: (c, style) => StatefulBuilder(
          builder: (c, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '为《${book.title ?? book.name}》选择分类',
                style: style.titleTextStyle,
              ),
              const SizedBox(height: 12),
              if (allCats.isEmpty)
                Text('还没有分类，先在上方新建', style: style.bodyTextStyle)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in allCats)
                      FButton(
                        variant: current.contains(cat.id)
                            ? FButtonVariant.primary
                            : FButtonVariant.outline,
                        onPress: () => setSt(() {
                          if (current.contains(cat.id)) {
                            current.remove(cat.id);
                          } else {
                            current.add(cat.id);
                          }
                        }),
                        child: Text(cat.name),
                      ),
                  ],
                ),
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
                    onPress: () async {
                      for (final id in current.where(
                        (id) => !assigned.contains(id),
                      )) {
                        await repo.assignCategory(book.filePath, id);
                      }
                      for (final id in assigned.where(
                        (id) => !current.contains(id),
                      )) {
                        await repo.unassignCategory(book.filePath, id);
                      }
                      if (c.mounted) Navigator.pop(c);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
