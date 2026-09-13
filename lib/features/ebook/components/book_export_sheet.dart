// 电子书导出抽屉（lg = 80vh 定高）—— 排版与「导出笔记」完全同构：
//   ① 标题（导出电子书）+ 关闭
//   ② 搜索栏 + 高级搜索（点 ≡ 打开独立 80vh「高级搜索」抽屉：分类 / 格式多选；
//      已选项在搜索行下方显示，可逐个点掉）
//   ③ 可勾选的滚动列表（每本书：勾选圆点 + 书名 + 作者/分类/格式/已读/划线·笔记）
//   ④ 底部固定三个按钮【导出选中】【导出筛选】【导出所有】
//
// 导出为 .md（书目 + 每本书的标注与笔记正文，见 utils/export_books_markdown.dart）；
// 直接落盘 `Download/渐离App导出/`（未授权回退沙盒）+ 顶部提示（见 app/ui/file_export.dart）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/file_export.dart';
import '../../../app/ui/filter_sheet.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';
import '../utils/export_books_markdown.dart';

/// 打开「导出电子书」抽屉（lg 80vh 定高、键盘覆盖不折叠 —— 三档制红线 #9）
Future<void> showBookExportSheet(BuildContext context) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _BookExportSheet(),
  );
}

class _BookExportSheet extends ConsumerStatefulWidget {
  const _BookExportSheet();

  @override
  ConsumerState<_BookExportSheet> createState() => _BookExportSheetState();
}

class _BookExportSheetState extends ConsumerState<_BookExportSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  /// 已勾选的书（key = 书 filePath，书架内唯一）
  final Set<String> _selectedPaths = {};

  /// 已生效的高级筛选（分类名 / 格式，任一命中）——由「高级搜索」80vh 抽屉设置
  final Set<String> _filterCategories = {};
  final Set<String> _filterFormats = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 书 filePath -> 分类名列表（渲染与导出共用的派生数据）
  Map<String, List<String>> _catsByPath(
    List<EbookCategoryData> cats,
    List<EbookBookCategoryData> bookCats,
  ) {
    final nameById = {for (final c in cats) c.id: c.name};
    final out = <String, List<String>>{};
    for (final bc in bookCats) {
      final name = nameById[bc.categoryId];
      if (name == null) continue;
      out.putIfAbsent(bc.bookPath, () => <String>[]).add(name);
    }
    return out;
  }

  /// 过滤：分类 / 格式（任一命中）+ 关键词（书名 / 文件名 / 作者）
  /// —— 与书架页搜索框「搜索书名与作者…」同语义
  List<EbookBookshelfData> _filtered(
    List<EbookBookshelfData> books,
    Map<String, List<String>> catsByPath,
  ) {
    final kw = _keyword.trim().toLowerCase();
    return books.where((b) {
      if (_filterCategories.isNotEmpty &&
          !_filterCategories.any(
            (catsByPath[b.filePath] ?? const <String>[]).contains,
          )) {
        return false;
      }
      if (_filterFormats.isNotEmpty &&
          !_filterFormats.contains((b.format ?? '').trim().toLowerCase())) {
        return false;
      }
      if (kw.isNotEmpty) {
        final hay =
            '${b.title ?? ''}\n${b.name ?? ''}\n${b.author ?? ''}'
                .toLowerCase();
        if (!hay.contains(kw)) return false;
      }
      return true;
    }).toList();
  }

  /// 导出：`selectedOnly` ? 勾选项 : [pool] 全部（[pool] 为该次导出的候选集：
  /// 传 `filtered` = 当前筛选结果、传全部 = 全部书籍）。
  Future<void> _export(
    List<EbookBookshelfData> pool, {
    required bool selectedOnly,
  }) async {
    final chosen = selectedOnly
        ? [
            for (final b in pool)
              if (_selectedPaths.contains(b.filePath)) b,
          ]
        : pool;
    if (chosen.isEmpty) {
      showFToast(context: context, title: const Text('没有可导出的书籍'));
      return;
    }
    // 导出所需数据现取（不在 build 里缓存实例字段）
    final cats =
        ref.read(categoriesStreamProvider).value ??
        const <EbookCategoryData>[];
    final bookCats =
        ref.read(bookCategoriesStreamProvider).value ??
        const <EbookBookCategoryData>[];
    final annotations =
        ref.read(allAnnotationsStreamProvider).value ??
        const <EbookAnnotationData>[];
    final md = buildBooksMarkdown(
      chosen,
      categoryNamesByPath: _catsByPath(cats, bookCats),
      annotations: annotations,
    );
    await exportTextToDownloadDir(
      context: context,
      text: md,
      filename: '电子书导出_${_fileStamp()}.md',
    );
    if (mounted) Navigator.pop(context);
  }

  static String _fileStamp() {
    final n = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final books =
        ref.watch(bookshelfStreamProvider).value ??
        const <EbookBookshelfData>[];
    final cats =
        ref.watch(categoriesStreamProvider).value ??
        const <EbookCategoryData>[];
    final bookCats =
        ref.watch(bookCategoriesStreamProvider).value ??
        const <EbookBookCategoryData>[];
    final annotations =
        ref.watch(allAnnotationsStreamProvider).value ??
        const <EbookAnnotationData>[];

    final catsByPath = _catsByPath(cats, bookCats);
    final counts = annotationCountsByHash(annotations);
    final filtered = _filtered(books, catsByPath);
    final t = context.theme;

    // 高级搜索的「分类」选项：书架上真实用到的分类名（去重升序）
    final allCategoryNames = catsByPath.values.expand((e) => e).toSet().toList()
      ..sort();
    // 高级搜索的「格式」选项：取自书架上真实存在的格式（去重升序）
    final formats = <String>{
      for (final b in books)
        if ((b.format ?? '').trim().isNotEmpty) b.format!.trim().toLowerCase(),
    }.toList()..sort();

    return SheetSurface(
      child: SizedBox(
        height: sheetMaxHeightFull(context, SheetSize.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: SheetHandle(),
            ),
            // ① 标题 + 关闭（17/Bold + 裸 X，与 SheetScaffold 同规格）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.pagePadding,
                14,
                AppTokens.pagePadding,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('导出电子书', style: sheetTitleStyle(context)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        FLucideIcons.x,
                        size: 18,
                        color: t.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ② 搜索栏 + 高级搜索（≡ 打开独立 80vh 抽屉，分类/格式多时也能完整展示）
            PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索要导出的书名或作者…',
              onChanged: (v) => setState(() => _keyword = v),
              onFilter: () => _openAdvancedFilter(allCategoryNames, formats),
            ),
            // 已生效筛选条件（分类/格式逐个可点掉；无则整块不渲染）
            if (_filterCategories.isNotEmpty || _filterFormats.isNotEmpty)
              _activeFilterRow(context),
            // ③ 可勾选的滚动列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        books.isEmpty ? '暂无电子书' : '没有匹配的书籍',
                        style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        4,
                        AppTokens.pagePadding,
                        8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final b = filtered[i];
                        final stat =
                            counts[b.contentHash ?? ''] ?? (marks: 0, notes: 0);
                        return _BookExportRow(
                          book: b,
                          categoryNames:
                              catsByPath[b.filePath] ?? const <String>[],
                          markCount: stat.marks,
                          noteCount: stat.notes,
                          selected: _selectedPaths.contains(b.filePath),
                          onTap: () => setState(() {
                            _selectedPaths.contains(b.filePath)
                                ? _selectedPaths.remove(b.filePath)
                                : _selectedPaths.add(b.filePath);
                          }),
                        );
                      },
                    ),
            ),
            // ④ 底部固定：导出选中 / 导出筛选 / 导出所有（三键一行，窄屏靠去图标 + 紧间距）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.pagePadding,
                8,
                AppTokens.pagePadding,
                16,
              ),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: GradientButton(
                      label: '导出选中',
                      onPress: () => _export(filtered, selectedOnly: true),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => _export(filtered, selectedOnly: false),
                      child: const Text('导出筛选'),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => _export(books, selectedOnly: false),
                      child: const Text('导出所有'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开「高级搜索」独立抽屉（lg = 80vh 定高）——分类/格式多时也能完整滚动展示。
  /// 打开前从「已生效筛选」初始化草稿；「应用」才写回，关闭/取消不应用。
  Future<void> _openAdvancedFilter(
    List<String> categories,
    List<String> formats,
  ) async {
    final draftCategories = Set<String>.of(_filterCategories);
    final draftFormats = Set<String>.of(_filterFormats);
    final result = await showFilterSheet<(Set<String>, Set<String>)>(
      context: context,
      title: '高级搜索',
      size: SheetSize.lg,
      confirmLabel: '应用',
      resetLabel: '重置',
      body: (c, refresh) => _buildFilterBody(
        categories,
        formats,
        draftCategories,
        draftFormats,
        refresh,
      ),
      onReset: (refresh) {
        draftCategories.clear();
        draftFormats.clear();
        refresh();
      },
      onConfirm: () =>
          (Set<String>.of(draftCategories), Set<String>.of(draftFormats)),
    );
    if (result == null || !mounted) return; // 关闭/取消：不应用
    setState(() {
      _filterCategories
        ..clear()
        ..addAll(result.$1);
      _filterFormats
        ..clear()
        ..addAll(result.$2);
    });
  }

  /// 高级搜索抽屉选项区：分类（可多选）+ 格式（可多选）
  Widget _buildFilterBody(
    List<String> categories,
    List<String> formats,
    Set<String> draftCategories,
    Set<String> draftFormats,
    VoidCallback refresh,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelLabel(context, '分类（可多选）'),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          _panelHint(context, '暂无分类，可在书架右上角「分类管理」新建')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in categories)
                SheetChoiceChip(
                  label: c,
                  selected: draftCategories.contains(c),
                  onTap: () {
                    draftCategories.contains(c)
                        ? draftCategories.remove(c)
                        : draftCategories.add(c);
                    refresh();
                  },
                ),
            ],
          ),
        const SizedBox(height: 14),
        _panelLabel(context, '格式（可多选）'),
        const SizedBox(height: 8),
        if (formats.isEmpty)
          _panelHint(context, '书架暂无书籍')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in formats)
                SheetChoiceChip(
                  label: f.toUpperCase(),
                  selected: draftFormats.contains(f),
                  onTap: () {
                    draftFormats.contains(f)
                        ? draftFormats.remove(f)
                        : draftFormats.add(f);
                    refresh();
                  },
                ),
            ],
          ),
      ],
    );
  }

  /// 已生效筛选条件行：分类/格式逐个可点掉 + 「清除」
  Widget _activeFilterRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        0,
        AppTokens.pagePadding,
        4,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in _filterCategories)
            SoftChip(
              label: '分类：$c',
              color: AppTokens.accent(5),
              alpha: 0.12,
              padding: const EdgeInsets.all(6),
              onRemove: () => setState(() => _filterCategories.remove(c)),
            ),
          for (final f in _filterFormats)
            SoftChip(
              label: '格式：${f.toUpperCase()}',
              color: AppTokens.accent(5),
              alpha: 0.12,
              padding: const EdgeInsets.all(6),
              onRemove: () => setState(() => _filterFormats.remove(f)),
            ),
          SoftChip(
            label: '清除',
            color: context.theme.colors.destructive,
            alpha: 0.12,
            padding: const EdgeInsets.all(6),
            onRemove: () => setState(() {
              _filterCategories.clear();
              _filterFormats.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _panelLabel(BuildContext context, String text) => Text(
        text,
        style: context.theme.typography.body.xs.copyWith(
          color: context.theme.colors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _panelHint(BuildContext context, String text) => Text(
        text,
        style: context.theme.typography.body.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      );
}

/// 单本书勾选行（勾选圆点 + 书名 + 作者/分类/格式/已读/划线·笔记）
class _BookExportRow extends StatelessWidget {
  const _BookExportRow({
    required this.book,
    required this.categoryNames,
    required this.markCount,
    required this.noteCount,
    required this.selected,
    required this.onTap,
  });

  final EbookBookshelfData book;
  final List<String> categoryNames;
  final int markCount;
  final int noteCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(5);
    final author = (book.author ?? '').trim();
    final format = (book.format ?? '').trim().toUpperCase();
    final percent = ((book.percent ?? 0).clamp(0.0, 1.0) * 100)
        .toStringAsFixed(0);
    final meta = [
      if (author.isNotEmpty) author,
      if (categoryNames.isNotEmpty) categoryNames.join(' / '),
      if (format.isNotEmpty) format,
      '已读 $percent%',
      '划线 $markCount · 笔记 $noteCount',
    ].join(' ｜ ');

    return FTappable(
      onPress: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTokens.accentSoft(context, accent) : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.4)
                : t.colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : t.colors.background,
                border: Border.all(
                  color: selected ? accent : t.colors.mutedForeground,
                ),
              ),
              child: selected
                  ? const Icon(FLucideIcons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (book.title ?? book.name ?? '未命名').trim(),
                    style: t.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: t.colors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
