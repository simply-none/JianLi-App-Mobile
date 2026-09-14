// 书架页 —— 对齐待办列表页骨架（专属色横幅统计 + 吸顶搜索行 + 分类 chips + 网格/列表）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 电子书18/Bold · 传书 · 分类管理 · ＋导入
//   统计横幅 PageBanner 青专属渐变 · stats 本藏书/在读/分类（随滚动移出）
//   搜索行  ★吸顶锚点（PinnedSearchRow，搜索书名/作者；右侧筛选钮 = 排序+视图抽屉）
//   分类行  SoftChip 横向滚动（全部 + 各分类，可点选）
//   书架    网格（3 列 BookCell）/ 列表（_BookRow 行卡）双视图，排序持久化
//
// 数据经顶层 bookshelfStreamProvider（⚠️ 禁止 build 内联 StreamProvider——
// 每次重建都是新 provider，页面永远 loading，实踩见 ebook_providers.dart 头注释）。
// 长按书格 = 动作菜单（笔记标注 → /ebook/notes 页面 / 移出书架 → sm 确认抽屉）。
// 分类（2026-09-09）：头部「标签」管理分类与给书打标签；排序/视图存 SharedPreferences。
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_discovery.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';
import '../services/ebook_transfer.dart';
import 'book_cell.dart';
import 'book_export_sheet.dart';

/// 书架页
class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  /// 书架域专属青强调色（与内容分组页「电子书」入口色对齐）
  static final Color _accent = AppTokens.accent(5);

  /// 当前选中的分类筛选（null = 全部）
  int? _selectedCat;

  /// 页内搜索（书名/作者）
  String _search = '';
  final _searchController = TextEditingController();

  /// 传书抽屉：手动设备 IP 输入控制器（SheetInputBox 需要；dispose 释放）
  final _transferIpController = TextEditingController();

  /// 排序：recent=最近阅读 / added=添加时间 / title=书名（持久化）
  String _sortBy = 'recent';

  /// 视图：grid=网格 / list=列表（持久化）
  String _viewMode = 'grid';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transferIpController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortBy = sp.getString('ebook_sort') ?? _sortBy;
      _viewMode = sp.getString('ebook_view') ?? _viewMode;
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('ebook_sort', _sortBy);
    await sp.setString('ebook_view', _viewMode);
  }

  @override
  Widget build(BuildContext context) {
    // 进入书架即注册 /ebook/* 接收路由（否则电脑端主动来拉时手机还没挂上端点）
    ref.watch(ebookTransferProvider);
    final shelfAsync = ref.watch(bookshelfStreamProvider);
    final catsAsync = ref.watch(categoriesStreamProvider);
    final bookCatsAsync = ref.watch(bookCategoriesStreamProvider);
    // 全量批注流（跨书）——卡片上的「划线 / 笔记」数量
    final annoAsync = ref.watch(allAnnotationsStreamProvider);
    final t = context.theme;

    // content_hash -> 划线/笔记数量（共享判据与分桶，见 ebook_repository.dart）
    final annoByHash = annotationCountsByHash(
      annoAsync.value ?? const <EbookAnnotationData>[],
    );

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
    final cats = catsAsync.value ?? const <EbookCategoryData>[];

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        // 全局渐变背板由 app.dart 根容器绘制，页面保持透明以透出背板
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: shelfAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败：$e',
                      textAlign: TextAlign.center,
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.error,
                      ),
                    ),
                  ),
                  data: (books) => _body(
                    context,
                    books,
                    cats,
                    bookToCats,
                    catMap,
                    annoByHash,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部（对齐待办：‹ / 标题 / 传书 / 分类 / ＋） =====================

  Widget _header(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: () => context.pop(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
          Expanded(
            child: Text(
              '电子书',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: _showTransferSheet,
            child: Icon(
              FLucideIcons.arrowLeftRight,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: _showCategoryManager,
            child: Icon(FLucideIcons.tags, size: 18, color: t.colors.foreground),
          ),
          TapScale(
            onTap: () => showBookExportSheet(context),
            child: Icon(
              FLucideIcons.download,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: () => _import(context, ref),
            child: Icon(FLucideIcons.plus, size: 22, color: t.colors.foreground),
          ),
        ],
      ),
    );
  }

  // ===================== 主体（待办骨架） =====================

  Widget _body(
    BuildContext context,
    List<EbookBookshelfData> books,
    List<EbookCategoryData> cats,
    Map<String, Set<int>> bookToCats,
    Map<int, EbookCategoryData> catMap,
    Map<String, ({int marks, int notes})> annoByHash,
  ) {
    final kw = _search.trim().toLowerCase();
    final filtered = _sortBooks([
      for (final b in books)
        if ((_selectedCat == null ||
                (bookToCats[b.filePath] ?? {}).contains(_selectedCat)) &&
            (kw.isEmpty ||
                (b.title ?? '').toLowerCase().contains(kw) ||
                (b.name ?? '').toLowerCase().contains(kw) ||
                (b.author ?? '').toLowerCase().contains(kw)))
          b,
    ]);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _banner(context, books, cats),
        ),
        // ★吸顶锚点：搜索行常驻视口顶部（横幅 / 分类行随滚动移出）
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索书名与作者…',
              onChanged: (v) => setState(() => _search = v),
              onFilter: _showViewSheet,
            ),
          ),
        ),
        // 分类筛选行（有分类才显示；SoftChip 横向滚动）
        if (cats.isNotEmpty)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                spacing: 6,
                children: [
                  SoftChip(
                    label: '全部',
                    color: _accent,
                    alpha: _selectedCat == null ? 0.18 : 0.08,
                    onTap: _selectedCat == null
                        ? null
                        : () => setState(() => _selectedCat = null),
                  ),
                  for (final c in cats)
                    SoftChip(
                      label: c.name,
                      color: _accent,
                      alpha: _selectedCat == c.id ? 0.18 : 0.08,
                      onTap: () => setState(
                        () => _selectedCat =
                            _selectedCat == c.id ? null : c.id,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (books.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: true),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: false),
          )
        else if (_viewMode == 'grid')
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              AppTokens.listTopGapOf(context),
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    // 0.62 → 0.58：书格多了一行「划线/笔记」，放宽高度保证小屏（360dp）不溢出
                    childAspectRatio: 0.58,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final book = filtered[i];
                final labels = (bookToCats[book.filePath] ?? {})
                    .map((id) => catMap[id]?.name ?? '')
                    .where((n) => n.isNotEmpty)
                    .toList();
                final stats =
                    annoByHash[book.contentHash ?? ''] ??
                    (marks: 0, notes: 0);
                return BookCell(
                  book: book,
                  categoryLabels: labels,
                  markCount: stats.marks,
                  noteCount: stats.notes,
                  onOpen: () => _openBook(book),
                  onMenu: () => _showBookActionsSheet(book),
                );
              }, childCount: filtered.length),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              AppTokens.listTopGapOf(context),
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final book = filtered[i];
                final labels = (bookToCats[book.filePath] ?? {})
                    .map((id) => catMap[id]?.name ?? '')
                    .where((n) => n.isNotEmpty)
                    .toList();
                final stats =
                    annoByHash[book.contentHash ?? ''] ??
                    (marks: 0, notes: 0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookRow(
                    book: book,
                    categoryLabels: labels,
                    markCount: stats.marks,
                    noteCount: stats.notes,
                    onOpen: () => _openBook(book),
                    onMenu: () => _showBookActionsSheet(book),
                  ),
                );
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（青专属渐变 + 纹理 + 同心圆环）
  Widget _banner(
    BuildContext context,
    List<EbookBookshelfData> books,
    List<EbookCategoryData> cats,
  ) =>
      PageBanner(
        icon: FLucideIcons.bookOpenText,
        title: '电子书',
        subtitle: 'EPUB / TXT 随身阅读',
        accentIndex: 5,
        cornerRadius: 22,
        ringDecor: true,
        shadow: false,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        stats: [
          ('${books.length}', '本藏书'),
          ('${books.where((b) => (b.percent ?? 0) > 0).length}', '在读'),
          ('${cats.length}', '分类'),
        ],
      );

  /// 空态（对齐待办）
  Widget _emptyState(BuildContext context, {required bool totallyEmpty}) {
    final t = context.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              totallyEmpty ? FLucideIcons.bookOpenText : FLucideIcons.searchX,
              size: 32,
              color: _accent,
            ),
          ),
          Text(
            totallyEmpty ? '书架空空' : '没有匹配的书籍',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点右上角 ＋ 导入第一本（支持 EPUB / TXT）' : '换个关键词，或切回全部分类',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 排序 + 视图抽屉（sm 档，点选即生效并持久化——对齐待办「显示风格」交互）
  Future<void> _showViewSheet() async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '排序与视图',
        size: SheetSize.sm,
        body: StatefulBuilder(
          builder: (c, setInner) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetFieldLabel('排序'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label) in const [
                        ('recent', '最近阅读'),
                        ('added', '添加时间'),
                        ('title', '书名'),
                      ])
                        SheetChoiceChip(
                          label: label,
                          selected: _sortBy == value,
                          color: _accent,
                          onTap: () {
                            setState(() => _sortBy = value);
                            setInner(() {});
                            _savePrefs();
                          },
                        ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetFieldLabel('视图'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label, icon) in const [
                        ('grid', '网格', FLucideIcons.layoutGrid),
                        ('list', '列表', FLucideIcons.layoutList),
                      ])
                        SheetChoiceChip(
                          label: label,
                          selected: _viewMode == value,
                          color: _accent,
                          leading: Icon(
                            icon,
                            size: 14,
                            color: _viewMode == value
                                ? _accent
                                : c.theme.colors.mutedForeground,
                          ),
                          onTap: () {
                            setState(() => _viewMode = value);
                            setInner(() {});
                            _savePrefs();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 排序（recent=最近阅读 / added=添加时间 / title=书名）
  List<EbookBookshelfData> _sortBooks(List<EbookBookshelfData> books) {
    final list = [...books];
    switch (_sortBy) {
      case 'added':
        list.sort((a, b) => (b.addedAt ?? '').compareTo(a.addedAt ?? ''));
      case 'title':
        list.sort(
          (a, b) => (a.title ?? a.name ?? '').compareTo(b.title ?? b.name ?? ''),
        );
      default:
        list.sort((a, b) => (b.lastReadAt ?? '').compareTo(a.lastReadAt ?? ''));
    }
    return list;
  }

  /// 打开一本书；同步过来的对端记录其 file_path 是对方路径、本机并无文件，
  /// 此时提示用「传书」拉取，避免打开一个空阅读页。
  void _openBook(EbookBookshelfData book) {
    if (!File(book.filePath).existsSync()) {
      showFToast(context: context, title: const Text('该书文件不在本机，请用「传书」从电脑导入'));
      return;
    }
    context.push('/ebook/reader?path=${Uri.encodeComponent(book.filePath)}');
  }

  /// 分类筛选 chip（旧版 FButton chips 已由 SoftChip 分类行替代）

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
      // 此处 context 是入参（非 State.context），守卫必须用 context.mounted
      if (context.mounted) {
        showFToast(
          context: context,
          title: Text(
            book == null ? '仅支持 EPUB / TXT' : '已导入《${book.title ?? book.name}》',
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

  /// 长按封面的动作菜单（**md 档 = 50vh**，2026-09-13 用户定；共享操作菜单默认 sm 30vh，
  /// 此处显式提档以留出更宽松的点击区）：「笔记标注」/「移出书架」
  ///
  /// 笔记标注 → push `/ebook/notes`（独立页面全量展示，不折叠省略）；
  /// 移出书架 → 仍走 `_confirmRemove` 的 sm 确认抽屉。
  Future<void> _showBookActionsSheet(EbookBookshelfData book) async {
    final hash = book.contentHash ?? '';
    final action = await showSheetActionMenu<String>(
      context,
      title: '《${book.title ?? book.name ?? '未命名'}》',
      size: SheetSize.md,
      actions: const [
        SheetAction('notes', '笔记标注', icon: FLucideIcons.highlighter),
        SheetAction(
          'remove',
          '移出书架',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'notes':
        if (hash.isEmpty) {
          showFToast(
            context: context,
            title: const Text('该书暂无内容标识，无法查看笔记'),
          );
          return;
        }
        context.push(
          '/ebook/notes?path=${Uri.encodeComponent(book.filePath)}'
          '&hash=${Uri.encodeComponent(hash)}'
          '&title=${Uri.encodeComponent(book.title ?? book.name ?? '笔记标注')}',
        );
      case 'remove':
        await _confirmRemove(context, ref, book);
    }
  }

  /// 删除确认（sm 共享确认抽屉；仅删书架引用不删内容）
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    EbookBookshelfData book,
  ) async {
    final confirmed = await showSheetConfirm(
      context,
      title: '移出书架',
      message: '将《${book.title ?? book.name}》移出书架？将同时删除本地文件副本；'
          '阅读进度按内容哈希保留，重新导入可恢复。',
      confirmLabel: '移出',
    );
    if (confirmed) {
      await ref.read(ebookRepositoryProvider).removeBook(book);
    }
  }

  /// 分类管理（lg 定高三档制）：新建分类 + 分类删除 + 给书打标签
  void _showCategoryManager() {
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (sheetContext) => SheetScaffold(
        title: '分类管理',
        size: SheetSize.lg,
        body: StatefulBuilder(
          builder: (sheetContext, setSt) {
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
              bookToCats
                  .putIfAbsent(bc.bookPath, () => <int>{})
                  .add(bc.categoryId);
            }
            final books = shelf.value ?? const <EbookBookshelfData>[];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                // 新建分类输入行
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FTextField(
                        label: const Text('新建分类'),
                        control: FTextFieldControl.managed(
                          onChange: (v) => newName = v.text.trim(),
                        ),
                      ),
                    ),
                    FButton(
                      onPress: () async {
                        if (newName.isEmpty) return;
                        await ref
                            .read(ebookRepositoryProvider)
                            .addCategory(newName);
                        setSt(() {});
                      },
                      child: const Text('添加'),
                    ),
                  ],
                ),
                // 分类行（名称 + 删除）
                if (allCats.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in allCats)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sheetContext.theme.colors.muted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.name,
                                style: sheetContext.theme.typography.body.sm
                                    .copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
                                  await ref
                                      .read(ebookRepositoryProvider)
                                      .removeCategory(c.id);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Icon(
                                  FLucideIcons.tagX,
                                  size: 14,
                                  color: sheetContext.theme.colors.destructive,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                // 书籍行（点按 → 给书打分类）
                for (final b in books)
                  FTappable(
                    onPress: () => _editBookCategories(
                      b,
                      bookToCats[b.filePath] ?? {},
                      allCats,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sheetContext.theme.colors.muted,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title ?? b.name ?? '未命名',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: sheetContext
                                      .theme.typography.body.sm
                                      .copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _catNames(
                                    bookToCats[b.filePath] ?? {},
                                    sheetCatMap,
                                  ),
                                  style: sheetContext
                                      .theme.typography.body.xs
                                      .copyWith(
                                    color: sheetContext
                                        .theme.colors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            FLucideIcons.chevronRight,
                            size: 16,
                            color:
                                sheetContext.theme.colors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 跨端传书抽屉：扫描设备 → 选设备 → 选方向（从电脑导入 / 导入到电脑）
  /// → 勾选多本 → 底部「传输选中(N)」一键批量传输。
  ///
  /// ⚠️ 表单/流程状态全部放在本方法作用域（StatefulBuilder 的 builder 闭包内变量
  /// 每次 setSt 重建都会被重置，见 SKILL 红线）。勾选集合用 `checked` 存书的 filePath
  /// （双端 filePath 唯一），切换方向/设备时清空，避免跨端混选。
  Future<void> _showTransferSheet() async {
    final discovery = SyncDiscovery();
    var peers = <PeerDevice>[];
    var selectedIndex = -1;
    var direction = 0; // 0=从电脑导入（拉），1=导入到电脑（推）
    var remoteBooks = <RemoteBook>[];
    var scanning = false;
    var loading = false;
    var checked = <String>{}; // 已勾选书的 filePath
    var transferring = false;
    var progressText = '';
    // 传书记录日志：逐本记录成功/失败及原因，便于排查失败（不持久化，关抽屉即清空）
    var transferLog = <({bool ok, String line})>[];

    // 申请公共 Download 写权限（系统文件管理器可见的保存目录）；未授权 booksDir 自动回退沙盒
    await EbookRepository.ensurePublicDownloadsPermission();

    // 固定保存目录：一次性算出，传书页常显，方便用户在文件管理器定位
    var saveDirPath = '';
    var saveDirFallback = false;
    try {
      saveDirPath = (await EbookRepository.booksDir).path;
      saveDirFallback = !await EbookRepository.hasPublicDownloadsAccess();
    } catch (_) {
      // 取不到目录就隐藏保存目录行（不影响导入）
    }

    Future<void> loadRemote(
      PeerDevice peer,
      void Function(void Function()) setSt,
    ) async {
      setSt(() => loading = true);
      final books = await ref
          .read(ebookTransferProvider)
          .fetchRemoteBooks(peer);
      setSt(() {
        remoteBooks = books;
        loading = false;
      });
    }

    void toggle(String key, void Function(void Function()) setSt) {
      if (transferring) return;
      setSt(() {
        if (checked.contains(key)) {
          checked.remove(key);
        } else {
          checked.add(key);
        }
      });
    }

    Future<void> transferSelected(
      PeerDevice peer,
      void Function(void Function()) setSt,
    ) async {
      final items = direction == 0
          ? remoteBooks.where((b) => checked.contains(b.filePath)).toList()
          : localBooksForChecked(checked);
      final total = items.length;
      if (total == 0) return;
      setSt(() {
        transferring = true;
        transferLog.clear();
      });
      var okCount = 0;
      var failCount = 0;
      final dirLabel = direction == 0 ? '←导入' : '→传出';
      for (var i = 0; i < total; i++) {
        final item = items[i];
        final String name;
        if (direction == 0) {
          name = (item as RemoteBook).display;
        } else {
          final b = item as EbookBookshelfData;
          name = b.title ?? b.name ?? '未命名';
        }
        setSt(() => progressText = '传输中 ${i + 1}/$total · $name');
        final r = direction == 0
            ? await ref
                  .read(ebookTransferProvider)
                  .downloadBook(peer, item as RemoteBook)
            : await ref
                  .read(ebookTransferProvider)
                  .uploadBook(peer, item as EbookBookshelfData);
        if (r.ok) {
          okCount++;
        } else {
          failCount++;
        }
        // 逐本记录结果 + 失败原因，供下方「传书记录」日志排查
        final time = DateTime.now().toIso8601String().substring(11, 19);
        transferLog.add((
          ok: r.ok,
          line: '[$time] $dirLabel $name · ${r.ok ? '成功' : '失败：${r.message}'}',
        ));
        setSt(() {}); // 刷新传书记录日志（逐本实时显示）
      }
      setSt(() {
        transferring = false;
        checked.clear();
        progressText = '';
      });
      if (mounted) {
        showFToast(
          context: context,
          title: Text(
            '已传输 $okCount 本${failCount > 0 ? '，$failCount 本失败' : ''}',
          ),
        );
      }
    }

    if (!mounted) return;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 三档制 lg（长流程抽屉）；键盘不折叠，IP 输入框被键盘遮住时点空白收起
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final t = ctx.theme;
          final shelf = ref.watch(bookshelfStreamProvider);
          final localBooks = shelf.value ?? const <EbookBookshelfData>[];
          final peer = selectedIndex >= 0 && selectedIndex < peers.length
              ? peers[selectedIndex]
              : null;

          // 当前方向下的书目 filePath 列表（用于全选判定）
          final currentKeys = direction == 0
              ? remoteBooks.map((b) => b.filePath).toList()
              : localBooks.map((b) => b.filePath).toList();
          final selCount = currentKeys
              .where((k) => checked.contains(k))
              .length;
          final allSelected =
              currentKeys.isNotEmpty && selCount == currentKeys.length;
          final hasSelection = peer != null && selCount > 0;

          // 自绘小按钮（与 SheetInputBox 同高 40，见 interaction-patterns §4.6）
          Widget sheetAction({
            required String label,
            required VoidCallback? onTap,
            bool primary = false,
            IconData? icon,
          }) => TapScale(
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: primary ? AppTokens.primaryGradient(context) : null,
                color: primary ? null : t.colors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 14,
                      color: primary ? Colors.white : t.colors.mutedForeground,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary ? Colors.white : t.colors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          );

          // 书目勾选行（拉取 = 远端书目；传出 = 本地书架），key = filePath
          Widget bookRow(String title, String? subtitle, String key) {
            final selected = checked.contains(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FTappable(
                onPress: () => toggle(key, setSt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTokens.accentSoft(context, AppTokens.accent(5))
                        : t.colors.muted,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppTokens.accent(5)
                              : t.colors.background,
                          border: Border.all(
                            color: selected
                                ? AppTokens.accent(5)
                                : t.colors.mutedForeground,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                FLucideIcons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: t.typography.body.sm.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null && subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                style: t.typography.body.xs.copyWith(
                                  fontSize: 12,
                                  color: t.colors.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SheetScaffold(
            title: '传书',
            size: SheetSize.lg,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 固定保存目录（文件管理器可定位；未授权回退沙盒时提示）
                if (saveDirPath.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.colors.muted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FLucideIcons.folderOpen,
                          size: 14,
                          color: t.colors.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            saveDirFallback
                                ? '保存目录（未授权，暂存沙盒）：$saveDirPath'
                                : '保存目录：$saveDirPath',
                            style: t.typography.body.xs.copyWith(
                              fontSize: 12,
                              color: t.colors.mutedForeground,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: saveDirPath),
                            );
                            if (mounted) {
                              showFToast(
                                context: context,
                                title: const Text('已复制保存目录'),
                              );
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              '复制',
                              style: t.typography.body.xs.copyWith(
                                fontSize: 12,
                                color: t.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // 手动添加 / 扫描（§4.6：与输入框并排的按钮全自绘等高 40）
                const SheetFieldLabel('手动添加设备 IP'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SheetInputBox(
                        controller: _transferIpController,
                        hintText: '如 10.0.2.2（模拟器宿主）',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 6),
                    sheetAction(
                      label: '添加',
                      primary: true,
                      onTap: () {
                        final ip = _transferIpController.text.trim();
                        if (ip.isEmpty) {
                          showFToast(
                            context: ctx,
                            title: const Text('请先输入设备 IP'),
                          );
                          return;
                        }
                        setSt(() {
                          peers = [
                            ...peers,
                            PeerDevice(
                              ip: ip,
                              name: '手动设备 $ip',
                              id: ip,
                              platform: 'unknown',
                            ),
                          ];
                          selectedIndex = peers.length - 1;
                          checked.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    sheetAction(
                      label: scanning ? '扫描中…' : '扫描',
                      icon: FLucideIcons.scanLine,
                      onTap: scanning
                          ? null
                          : () async {
                              setSt(() => scanning = true);
                              final found = await discovery.scan();
                              setSt(() {
                                peers = found.values.toList();
                                scanning = false;
                              });
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 方向切换（选中设备后出现）
                if (peer != null) ...[
                  JianliSegmented(
                    items: const [
                      (FLucideIcons.download, '从这台导入'),
                      (FLucideIcons.upload, '传到这台'),
                    ],
                    selected: direction,
                    onSelect: (i) {
                      setSt(() {
                        direction = i;
                        checked.clear();
                      });
                      if (i == 0) loadRemote(peer, setSt);
                    },
                  ),
                  const SizedBox(height: 10),
                  // 已选计数（传输中变进度）+ 全选/取消全选
                  if (currentKeys.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transferring ? progressText : '已选 $selCount 本',
                            style: t.typography.body.sm.copyWith(
                              color: t.colors.mutedForeground,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: transferring
                              ? null
                              : () => setSt(() {
                                  if (allSelected) {
                                    checked.removeAll(currentKeys);
                                  } else {
                                    checked.addAll(currentKeys);
                                  }
                                }),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              allSelected ? '取消全选' : '全选',
                              style: t.typography.body.sm.copyWith(
                                fontSize: 13,
                                color: t.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
                // 列表区：未选设备 = 设备列表；已选 = 当前方向的书目勾选列表
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: FCircularProgress()),
                  )
                else if (peer == null && peers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        '未发现设备，可扫描或手填 IP',
                        style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                      ),
                    ),
                  )
                else if (peer == null)
                  for (var i = 0; i < peers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FTappable(
                        onPress: () {
                          setSt(() {
                            selectedIndex = i;
                            checked.clear();
                          });
                          if (direction == 0) {
                            loadRemote(peers[i], setSt);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selectedIndex == i
                                ? AppTokens.accentSoft(
                                    context,
                                    AppTokens.accent(5),
                                  )
                                : t.colors.muted,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusMd,
                            ),
                            border: selectedIndex == i
                                ? Border.all(
                                    color: AppTokens.accent(
                                      5,
                                    ).withValues(alpha: 0.5),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                FLucideIcons.smartphone,
                                size: 16,
                                color: selectedIndex == i
                                    ? AppTokens.accent(5)
                                    : t.colors.mutedForeground,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      peers[i].name,
                                      style: t.typography.body.sm.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      peers[i].ip,
                                      style: t.typography.body.xs.copyWith(
                                        fontSize: 12,
                                        color: t.colors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedIndex == i)
                                Icon(
                                  FLucideIcons.circleCheck,
                                  size: 16,
                                  color: AppTokens.accent(5),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                else ...[
                  if (direction == 0)
                    for (final b in remoteBooks)
                      bookRow(
                        b.display,
                        b.size == null
                            ? b.format
                            : '${b.format} · ${(b.size! / 1024 / 1024).toStringAsFixed(1)}MB',
                        b.filePath,
                      )
                  else
                    for (final b in localBooks)
                      bookRow(
                        b.title ?? b.name ?? '未命名',
                        b.format,
                        b.filePath,
                      ),
                ],
                // 传书记录（有记录才显示；最多展示最近 6 条，完整内容可复制）
                if (transferLog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.colors.card,
                      border: Border.all(color: t.colors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '传书记录',
                                style: t.typography.body.sm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: transferLog
                                        .map((e) => e.line)
                                        .join('\n'),
                                  ),
                                );
                                if (mounted) {
                                  showFToast(
                                    context: context,
                                    title: const Text('已复制传书记录'),
                                  );
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  '复制',
                                  style: t.typography.body.xs.copyWith(
                                    fontSize: 12,
                                    color: t.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setSt(() => transferLog.clear()),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  '清空',
                                  style: t.typography.body.xs.copyWith(
                                    fontSize: 12,
                                    color: t.colors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final e in transferLog.toList().reversed.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              e.line,
                              style: t.typography.body.xs.copyWith(
                                fontSize: 12,
                                color: e.ok
                                    ? t.colors.mutedForeground
                                    : t.colors.destructive,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // 底部固定：一键批量传输（选中后才出现）
            bottomBar: !hasSelection
                ? null
                : [
                    Expanded(
                      child: GradientButton(
                        label: transferring ? '传输中…' : '传输选中 ($selCount)',
                        icon: FLucideIcons.arrowLeftRight,
                        onPress: transferring
                            ? null
                            : () => transferSelected(peer, setSt),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  /// 取勾选的本地书（按 filePath 命中），用于批量上传
  List<EbookBookshelfData> localBooksForChecked(Set<String> checked) {
    // 需要实时书架数据；借由 provider 读一次快照
    final localBooks =
        ref.read(bookshelfStreamProvider).value ?? const <EbookBookshelfData>[];
    return localBooks.where((b) => checked.contains(b.filePath)).toList();
  }

  /// 分类 id 集合转可读名称（无则「未分类」）
  String _catNames(Set<int> ids, Map<int, EbookCategoryData> map) {
    final names = ids
        .map((id) => map[id]?.name ?? '')
        .where((n) => n.isNotEmpty)
        .join('、');
    return names.isEmpty ? '未分类' : names;
  }

  /// 给单本书勾选分类（底部抽屉内即时切换并落库）
  Future<void> _editBookCategories(
    EbookBookshelfData book,
    Set<int> assigned,
    List<EbookCategoryData> allCats,
  ) async {
    final repo = ref.read(ebookRepositoryProvider);
    final current = <int>{...assigned};
    await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          12,
          AppTokens.pagePadding,
          12,
        ),
        child: SafeArea(
          // ⚠️ 表单状态（current）必须提到 builder 之外，StatefulBuilder 闭包内的
          // 局部 var 每次 setSt 重建都会被重置（SKILL 红线）
          child: StatefulBuilder(
            builder: (c, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '为《${book.title ?? book.name}》选择分类',
                  style: c.theme.typography.body.lg,
                ),
                const SizedBox(height: 12),
                if (allCats.isEmpty)
                  Text(
                    '还没有分类，先在分类管理里新建',
                    style: c.theme.typography.body.sm.copyWith(
                      color: c.theme.colors.mutedForeground,
                    ),
                  )
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
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: () => Navigator.pop(c, false),
                        child: const Text('取消'),
                      ),
                    ),
                    Expanded(
                      child: FButton(
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
                          if (c.mounted) Navigator.pop(c, true);
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 书架列表视图行卡（青专属色封面盘 + 书名/作者 + 进度 + 分类徽标）
class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.categoryLabels,
    this.markCount = 0,
    this.noteCount = 0,
    required this.onOpen,
    required this.onMenu,
  });

  final EbookBookshelfData book;
  final List<String> categoryLabels;

  /// 划线（非 note 类批注）数量
  final int markCount;

  /// 笔记（note 类批注）数量
  final int noteCount;

  final VoidCallback onOpen;
  final VoidCallback onMenu;

  /// 左图标尺寸与弧度（弧度按卡片族口径 40→13 等比推导：48 × 13/40 ≈ 15.6 → 16）
  static const double _kIconSize = 48;
  static const double _kIconRadius = 16;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 按标题取专属强调色（与 BookCell 同一 hash 口径，同一本书两视图同色）
    final idx =
        (book.title ?? book.name ?? '').hashCode.abs() % AppTokens.accents.length;
    final accent = AppTokens.accent(idx);
    final percent = (book.percent ?? 0).clamp(0.0, 1.0);
    final author = (book.author ?? '').trim();
    return AppCard(
      // 列表卡 margin 清零：间距只由外层 Padding(bottom:10) 提供
      margin: EdgeInsets.zero,
      onTap: onOpen,
      onLongPress: onMenu,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // 左图标：与提醒 / 待办卡片族**同源配方** —— 普通圆角矩形 + accentGradient + 白图标
          // （原 SquircleBox 超椭圆的弧度与卡片族不一致，2026-09-14 用户实指「参考提醒卡片」）
          Container(
            width: _kIconSize,
            height: _kIconSize,
            decoration: BoxDecoration(
              gradient: AppTokens.accentGradient(accent),
              // 弧度按卡片族口径等比推导（40 → 13），故 48 → 16
              borderRadius: BorderRadius.circular(_kIconRadius),
            ),
            alignment: Alignment.center,
            child: const Icon(
              FLucideIcons.bookOpenText,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title ?? book.name ?? '未命名',
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 作者靠左、已读/笔记/标注靠右 → 两端对齐。
                    // 无作者时 Expanded 仍占满左半，右侧统计列保持对齐（不左右横跳）。
                    Expanded(
                      child: Text(
                        author,
                        style: t.typography.body.xs.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已读 ${(percent * 100).toStringAsFixed(0)}%',
                      style: t.typography.body.xs.copyWith(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // 划线 / 笔记数量（与笔记页同口径，见 isNoteAnnotation）
                    const SizedBox(width: 10),
                    Icon(
                      FLucideIcons.highlighter,
                      size: 12,
                      color: t.colors.mutedForeground,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$markCount',
                      style: t.typography.body.xs.copyWith(
                        fontSize: 11,
                        color: t.colors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(
                      FLucideIcons.notebookPen,
                      size: 12,
                      color: t.colors.mutedForeground,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$noteCount',
                      style: t.typography.body.xs.copyWith(
                        fontSize: 11,
                        color: t.colors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (categoryLabels.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final label in categoryLabels)
                        SoftChip(label: label, color: accent, alpha: 0.10),
                    ],
                  ),
                ],
                // 进度细条（与 BookCell 底部进度条同语义）
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 3,
                    backgroundColor: t.colors.muted,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
