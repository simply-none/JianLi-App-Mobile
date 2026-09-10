// 阅读器页 —— 章节渲染（HTML）+ 上一/下一章 + 进度保存（forui 化）
//
// epub CFI 级精确定位列 P2；首批按「章节索引」保存进度（cfi=chapter:<i>），
// content_hash 与桌面端共享同一身份键，未来同步后可按章节比例近似互通。
// 章节目录走 showFSheet 底部弹层（FTile 列表，当前章 selected 高亮）。
//
// P2 对齐（2026-09-09）：书签 / 批注 / 全文搜索 / 夜间·护眼强制样式。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import '../providers/reader_settings.dart';
import '../repositories/ebook_repository.dart';
import '../services/epub_service.dart';

/// 阅读器页（路由参数：书籍沙盒路径；可选 initialChapter = 从笔记页跳转的指定章节）
class EpubReaderPage extends ConsumerStatefulWidget {
  const EpubReaderPage({
    super.key,
    required this.filePath,
    this.initialChapter,
  });

  final String filePath;

  /// 指定起始章节索引（笔记标注页「跳到该章」用；null = 按已保存进度恢复）
  final int? initialChapter;

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  ParsedBook? _book;
  int _chapter = 0;
  String? _error;
  bool _loading = true;

  /// 跨端身份键（书签/批注/分类关联用，避免依赖沙盒路径）
  String? _contentHash;
  String _format = 'epub';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
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
      // ⚠️ initialChapter（笔记页「跳到该章」传入）优先于已保存进度
      final repo = ref.read(ebookRepositoryProvider);
      final row = await repo.findBookByPath(widget.filePath);
      var restored = 0;
      if (row != null) {
        _contentHash = row.contentHash;
        _format = row.format ?? 'epub';
        final progress = await repo.getProgress(row);
        final cfi = progress?.cfi ?? '';
        restored = cfi.startsWith('chapter:')
            ? int.tryParse(cfi.substring(8)) ?? 0
            : 0;
      }
      final target = widget.initialChapter ?? restored;
      if (mounted && target > 0 && book.chapters.length > target) {
        setState(() => _chapter = target);
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

  /// 当前章节是否已加书签（派生自书签流）
  bool _isBookmarked(List<EbookBookmarkData>? list) =>
      list?.any((b) => b.cfi == 'chapter:$_chapter') ?? false;

  /// 收藏/取消收藏当前章节
  Future<void> _toggleCurrentBookmark() async {
    final hash = _contentHash;
    final book = _book;
    if (hash == null || book == null) return;
    final repo = ref.read(ebookRepositoryProvider);
    final existing = await repo.findBookmark(hash, _chapter);
    if (existing != null) {
      await repo.removeBookmark(existing.id);
      if (mounted) {
        showFToast(context: context, title: const Text('已取消书签'));
      }
      return;
    }
    final percent = book.chapters.isEmpty
        ? 0.0
        : (_chapter + 1) / book.chapters.length * 100;
    await repo.addBookmark(
      filePath: widget.filePath,
      contentHash: hash,
      format: _format,
      chapterIndex: _chapter,
      label: book.chapters[_chapter].title,
      percent: percent,
    );
    if (mounted) showFToast(context: context, title: const Text('已加入书签'));
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final t = context.theme;
    // 阅读设置：主题 + 字号 + 行距（对齐 PC themePresets）
    final settings = ref.watch(readerSettingsProvider);
    final bg = readerBg(settings.theme);
    final text = readerText(settings.theme);

    final html = book == null
        ? ''
        : _chapter < book.chapters.length
        ? _renderHtml(book.chapters[_chapter].html, settings.theme)
        : '';

    return FScaffold(
      // 全屏阅读：关闭 childPad，正文自控边距
      childPad: false,
      header: FHeader.nested(
        title: Text(book?.title ?? '阅读'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.bookmark),
            onPress: book == null ? null : () => _showBookmarkList(),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.search),
            onPress: book == null ? null : () => _showSearch(book),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.highlighter),
            onPress: book == null ? null : () => _showAnnotations(book),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.list),
            onPress: book == null ? null : () => _showChapters(book),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.settings),
            onPress: book == null ? null : () => _showSettings(),
          ),
        ],
      ),
      child: ColoredBox(
        color: bg,
        child: _loading
            ? const Center(child: FCircularProgress())
            : _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: text)),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppTokens.pagePadding),
                      child: HtmlWidget(
                        html,
                        // 主题文本色 / 字号 / 行距（TXT 无内联样式，三主题完整生效；
                        // EPUB 内联 color/background 在 night/eye 下由 _renderHtml 剥离，避免露白底）
                        textStyle: TextStyle(
                          color: text,
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                        ),
                      ),
                    ),
                  ),
                  const FDivider(),
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: _chapter > 0
                              ? () => _goChapter(_chapter - 1)
                              : null,
                          child: const Text('上一章'),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_chapter + 1}/${book!.chapters.length}',
                              style: t.typography.body.sm.copyWith(
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: _chapter < book.chapters.length - 1
                              ? () => _goChapter(_chapter + 1)
                              : null,
                          child: const Text('下一章'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 夜间/护眼主题下剥离 epub 内联 color/background，避免白字白底
  String _renderHtml(String html, ReaderTheme theme) {
    if (theme == ReaderTheme.day) return html;
    return html.replaceAllMapped(
      RegExp(r'style="([^"]*)"', caseSensitive: false),
      (m) {
        final inner = m[1]!
            .replaceAllMapped(
              RegExp(
                r'(?:^|;)\s*(?:color|background|background-color|background-image|'
                r'background-color)\s*:[^;]*;?',
                caseSensitive: false,
              ),
              (_) => '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return inner.isEmpty ? '' : 'style="$inner"';
      },
    );
  }

  /// 书签列表抽屉（按章节跳转 + 收藏/取消收藏当前章）
  void _showBookmarkList() {
    final hash = _contentHash;
    if (hash == null) return;
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (context) {
        final snap = ref.watch(bookmarksStreamProvider(hash));
        final list = snap.value ?? const <EbookBookmarkData>[];
        final current = _isBookmarked(list);
        return SheetSurface(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    8,
                  ),
                  child: Text('书签', style: context.theme.typography.body.lg),
                ),
                Expanded(
                  child: snap.when(
                    loading: () => const Center(child: FCircularProgress()),
                    error: (e, _) => Center(child: Text('加载失败：$e')),
                    data: (_) {
                      if (list.isEmpty) {
                        return const Center(child: Text('还没有书签'));
                      }
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          FTileGroup(
                            divider: FItemDivider.none,
                            children: [
                              for (final b in list)
                                FTile(
                                  title: Text(
                                    b.label ?? '未命名章节',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: b.percent != null
                                      ? Text('${b.percent}%')
                                      : null,
                                  suffix: Row(
                                    spacing: 8,
                                    children: [
                                      FButton(
                                        variant: FButtonVariant.ghost,
                                        onPress: () async {
                                          Navigator.pop(context);
                                          final idx =
                                              int.tryParse(
                                                (b.cfi ?? '').startsWith(
                                                      'chapter:',
                                                    )
                                                    ? (b.cfi ?? '').substring(8)
                                                    : '',
                                              ) ??
                                              _chapter;
                                          await _goChapter(idx);
                                        },
                                        child: const Text('跳转'),
                                      ),
                                      FButton(
                                        variant: FButtonVariant.destructive,
                                        onPress: () async {
                                          await ref
                                              .read(ebookRepositoryProvider)
                                              .removeBookmark(b.id);
                                        },
                                        child: const Icon(FLucideIcons.trash2),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(AppTokens.pagePadding),
                  child: FButton(
                    onPress: () => _toggleCurrentBookmark(),
                    child: Text(current ? '取消收藏本章' : '收藏当前章'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 批注 / 划线 抽屉（按当前章节锚点；划线=markStrong 黄，笔记=note）
  void _showAnnotations(ParsedBook book) {
    final hash = _contentHash;
    if (hash == null) return;
    // 表单状态置于方法作用域，StatefulBuilder 重建时不会被重置
    var adding = false;
    var type = 'markStrong';
    var note = '';
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSt) {
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text('批注', style: context.theme.typography.body.lg),
                  ),
                  Expanded(
                    child: ref
                        .watch(annotationsStreamProvider(hash))
                        .when(
                          loading: () =>
                              const Center(child: FCircularProgress()),
                          error: (e, _) => Center(child: Text('加载失败：$e')),
                          data: (list) {
                            if (list.isEmpty && !adding) {
                              return const Center(child: Text('还没有批注'));
                            }
                            return ListView(
                              padding: const EdgeInsets.only(bottom: 12),
                              children: [
                                if (adding) ...[
                                  Padding(
                                    padding: EdgeInsets.all(
                                      AppTokens.pagePadding,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '类型',
                                          style:
                                              context.theme.typography.body.sm,
                                        ),
                                        const SizedBox(height: 8),
                                        JianliSegmented(
                                          items: const [
                                            (FLucideIcons.highlighter, '划线'),
                                            (FLucideIcons.notebookPen, '笔记'),
                                          ],
                                          selected: type == 'markStrong'
                                              ? 0
                                              : 1,
                                          onSelect: (i) {
                                            setSt(
                                              () => type = i == 0
                                                  ? 'markStrong'
                                                  : 'note',
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        FTextField(
                                          label: const Text('笔记内容（可选）'),
                                          control: FTextFieldControl.managed(
                                            onChange: (v) =>
                                                setSt(() => note = v.text),
                                          ),
                                          maxLines: 3,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          spacing: 8,
                                          children: [
                                            FButton(
                                              variant: FButtonVariant.outline,
                                              onPress: () {
                                                note = '';
                                                setSt(() => adding = false);
                                              },
                                              child: const Text('取消'),
                                            ),
                                            FButton(
                                              onPress: () async {
                                                await ref
                                                    .read(
                                                      ebookRepositoryProvider,
                                                    )
                                                    .addAnnotation(
                                                      filePath: widget.filePath,
                                                      contentHash: hash,
                                                      format: _format,
                                                      anchor:
                                                          'chapter:$_chapter',
                                                      annotatedText: book
                                                          .chapters[_chapter]
                                                          .title,
                                                      note: note.trim().isEmpty
                                                          ? null
                                                          : note.trim(),
                                                      color:
                                                          type == 'markStrong'
                                                          ? 'yellow'
                                                          : '',
                                                      type: type,
                                                    );
                                                note = '';
                                                setSt(() => adding = false);
                                              },
                                              child: const Text('保存'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                FTileGroup(
                                  divider: FItemDivider.none,
                                  children: [
                                    for (final a in list)
                                      FTile(
                                        title: Text(
                                          a.annotatedText ??
                                              (a.type == 'note' ? '笔记' : '划线'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle:
                                            a.note != null && a.note!.isNotEmpty
                                            ? Text(
                                                a.note!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : null,
                                        suffix: Row(
                                          spacing: 8,
                                          children: [
                                            if (a.type == 'markStrong')
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: a.color == 'yellow'
                                                      ? Colors.yellow
                                                      : Colors.grey,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                            FButton(
                                              variant:
                                                  FButtonVariant.destructive,
                                              onPress: () async {
                                                await ref
                                                    .read(
                                                      ebookRepositoryProvider,
                                                    )
                                                    .removeAnnotation(a.id);
                                              },
                                              child: const Icon(
                                                FLucideIcons.trash2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTokens.pagePadding),
                    child: FButton(
                      onPress: () => setSt(() => adding = !adding),
                      child: Text(adding ? '收起' : '添加批注（本章）'),
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

  /// 全文搜索（跨章节匹配并定位跳转）
  void _showSearch(ParsedBook book) {
    var query = '';
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSt) {
              final results = <(int, String, String)>[];
              if (query.isNotEmpty) {
                for (var i = 0; i < book.chapters.length; i++) {
                  final plain = _stripTags(book.chapters[i].html);
                  final lower = plain.toLowerCase();
                  var from = 0;
                  while (true) {
                    final at = lower.indexOf(query.toLowerCase(), from);
                    if (at < 0) break;
                    final start = at < 20 ? 0 : at - 20;
                    final end = (at + query.length + 20).clamp(0, plain.length);
                    results.add((
                      i,
                      book.chapters[i].title,
                      '…${plain.substring(start, end)}…',
                    ));
                    from = at + query.length;
                    if (results.length >= 50) break;
                  }
                  if (results.length >= 50) break;
                }
              }
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text('搜索', style: context.theme.typography.body.lg),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTokens.pagePadding,
                    ),
                    child: FTextField(
                      label: const Text('关键词'),
                      control: FTextFieldControl.managed(
                        onChange: (v) => setSt(() => query = v.text.trim()),
                      ),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(query.isEmpty ? '输入关键词检索全文' : '无匹配结果'),
                          )
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 12),
                            children: [
                              FTileGroup(
                                divider: FItemDivider.none,
                                children: [
                                  for (final r in results)
                                    FTile(
                                      title: Text(
                                        r.$2,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        r.$3,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPress: () {
                                        Navigator.pop(context);
                                        _goChapter(r.$1);
                                      },
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

  /// 粗略去 HTML 标签，便于搜索与片段展示
  String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll('&nbsp;', ' ').trim();

  /// 阅读设置弹层（主题切换 + 字号/行距步进），设置即时持久化并回写阅读页
  void _showSettings() {
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (_) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSt) {
              final s = ref.watch(readerSettingsProvider);
              final t = context.theme;
              final notifier = ref.read(readerSettingsProvider.notifier);
              return Padding(
                padding: EdgeInsets.all(AppTokens.pagePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('阅读设置', style: t.typography.body.lg),
                    const SizedBox(height: 12),
                    Text(
                      '主题',
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    JianliSegmented(
                      items: const [
                        (FLucideIcons.sun, '日间'),
                        (FLucideIcons.moon, '夜间'),
                        (FLucideIcons.eye, '护眼'),
                      ],
                      selected: s.theme.index,
                      onSelect: (i) {
                        notifier.setTheme(ReaderTheme.values[i]);
                        setSt(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('字号', style: t.typography.body.sm),
                        const Spacer(),
                        FButton(
                          variant: FButtonVariant.ghost,
                          child: const Icon(FLucideIcons.minus),
                          onPress: () {
                            notifier.setFontSize(s.fontSize - 1);
                            setSt(() {});
                          },
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${s.fontSize.toInt()}',
                          style: t.typography.body.md,
                        ),
                        const SizedBox(width: 12),
                        FButton(
                          variant: FButtonVariant.ghost,
                          child: const Icon(FLucideIcons.plus),
                          onPress: () {
                            notifier.setFontSize(s.fontSize + 1);
                            setSt(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('行距', style: t.typography.body.sm),
                        const Spacer(),
                        FButton(
                          variant: FButtonVariant.ghost,
                          child: const Icon(FLucideIcons.minus),
                          onPress: () {
                            notifier.setLineHeight(s.lineHeight - 0.1);
                            setSt(() {});
                          },
                        ),
                        const SizedBox(width: 12),
                        Text(
                          s.lineHeight.toStringAsFixed(1),
                          style: t.typography.body.md,
                        ),
                        const SizedBox(width: 12),
                        FButton(
                          variant: FButtonVariant.ghost,
                          child: const Icon(FLucideIcons.plus),
                          onPress: () {
                            notifier.setLineHeight(s.lineHeight + 0.1);
                            setSt(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 章节目录弹层（当前章 selected 高亮）
  void _showChapters(ParsedBook book) {
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null, // 目录可长，允许拖到更高
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  0,
                  AppTokens.pagePadding,
                  8,
                ),
                child: Text('目录', style: context.theme.typography.body.lg),
              ),
              FTileGroup(
                divider: FItemDivider.none,
                children: [
                  for (var i = 0; i < book.chapters.length; i++)
                    FTile(
                      title: Text(
                        book.chapters[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: i == _chapter,
                      onPress: () {
                        Navigator.pop(context);
                        _goChapter(i);
                      },
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
