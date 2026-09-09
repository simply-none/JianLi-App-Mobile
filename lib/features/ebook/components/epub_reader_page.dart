// 阅读器页 —— 章节渲染（HTML）+ 上一/下一章 + 进度保存（forui 化）
//
// epub CFI 级精确定位列 P2；首批按「章节索引」保存进度（cfi=chapter:<i>），
// content_hash 与桌面端共享同一身份键，未来同步后可按章节比例近似互通。
// 章节目录走 showFSheet 底部弹层（FTile 列表，当前章 selected 高亮）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
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
        final idx = cfi.startsWith('chapter:')
            ? int.tryParse(cfi.substring(8)) ?? 0
            : 0;
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
    final t = context.theme;
    return FScaffold(
      // 全屏阅读：关闭 childPad，正文自控边距
      childPad: false,
      header: FHeader.nested(
        title: Text(book?.title ?? '阅读'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.list),
            onPress: book == null ? null : () => _showChapters(book),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: FCircularProgress())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: AppTokens.pageTint(context),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppTokens.pagePadding),
                      child: HtmlWidget(
                        // 正文字号随全局基准字号体系（阅览模式在根组件驱动主题）
                        book!.chapters[_chapter].html,
                        textStyle: TextStyle(
                          fontSize: t.typography.body.md.fontSize ?? 14,
                          height: 1.8,
                        ),
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
                            '${_chapter + 1}/${book.chapters.length}',
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
