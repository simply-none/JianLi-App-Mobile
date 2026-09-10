// 书籍「笔记 / 标注」页 —— 按 content_hash 汇总本书全部划线与笔记，**全量展示不截断**
//
// 入口：书架长按封面 → 底部抽屉 →「笔记标注」→ push 本页（路由 /ebook/notes）。
// 数据：直接复用已有的 `ebook_annotation`（与桌面端逐列对齐），按 content_hash 关联，
//       移动端现有 anchor 语义为 `chapter:<i>`（CFI 化后本页无需改动，只影响章节名推断）。
// ⚠️ 用户明确要求：划线原文与笔记正文**一律完整展开**（禁用 maxLines / ellipsis 省略）。
//    所以本页不使用任何截断；章节名允许省略（非笔记内容）。
import 'dart:io';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';
import '../services/epub_service.dart';

/// 笔记/标注筛选档位
enum _NotesTab { all, marks, notes }

/// 书籍笔记标注页
class BookNotesPage extends ConsumerStatefulWidget {
  const BookNotesPage({
    super.key,
    required this.filePath,
    required this.contentHash,
    this.title,
  });

  /// 书籍沙盒路径（用于解析章节名与跳转阅读）
  final String filePath;

  /// 跨端稳定身份键（笔记/标注按此关联，不依赖路径）
  final String contentHash;

  /// 书名（用于标题栏）
  final String? title;

  @override
  ConsumerState<BookNotesPage> createState() => _BookNotesPageState();
}

class _BookNotesPageState extends ConsumerState<BookNotesPage> {
  _NotesTab _tab = _NotesTab.all;

  /// 章节名缓存（异步解析原书得到，失败则降级不显示章节行）
  List<String> _chapterTitles = const [];

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  /// 解析原书取章节名（失败/文件缺失静默降级为空列表）
  Future<void> _loadChapters() async {
    List<String> titles = const [];
    try {
      if (File(widget.filePath).existsSync()) {
        final book = await parseBook(widget.filePath);
        titles = book.chapters.map((c) => c.title).toList();
      }
    } catch (_) {
      // 解析失败不影响笔记正文展示
    }
    if (!mounted) return;
    setState(() => _chapterTitles = titles);
  }

  /// 是否为「笔记」类型（其余一律视作划线/标注）
  bool _isNote(EbookAnnotationData a) => (a.type ?? '').trim() == 'note';

  /// 类型标签 + 图标
  (String, IconData) _typeMeta(String? type) {
    switch ((type ?? '').trim()) {
      case 'highlight':
        return ('高亮', FLucideIcons.highlighter);
      case 'underline':
        return ('下划线', FLucideIcons.underline);
      case 'mark':
        return ('横线', FLucideIcons.strikethrough);
      case 'markStrong':
        return ('强调线', FLucideIcons.highlighter);
      case 'note':
        return ('笔记', FLucideIcons.notebookPen);
      default:
        return ('标注', FLucideIcons.highlighter);
    }
  }

  /// 标注色（取自 DB 的 color 字段，语义色跨端共享，故不做主题色映射）
  Color _colorOf(FThemeData t, String? name) {
    switch ((name ?? '').trim().toLowerCase()) {
      case 'yellow':
        return Colors.amber;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'pink':
        return Colors.pink;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'red':
        return Colors.red;
      default:
        return t.colors.primary;
    }
  }

  /// 从 anchor 推断章节名（当前语义 `chapter:<i>`）
  String? _chapterTitleOf(String? anchor) {
    final a = (anchor ?? '').trim();
    if (!a.startsWith('chapter:')) return null;
    final idx = int.tryParse(a.substring('chapter:'.length).trim());
    if (idx == null || idx < 0 || idx >= _chapterTitles.length) return null;
    return _chapterTitles[idx];
  }

  /// 从 anchor 解析章节索引（用于「跳到该章」）
  int? _chapterIndexOf(String? anchor) {
    final a = (anchor ?? '').trim();
    if (!a.startsWith('chapter:')) return null;
    return int.tryParse(a.substring('chapter:'.length).trim());
  }

  /// 时间展示（DB 存 ISO 字符串，裁到分钟）
  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    return iso
        .replaceAll('T', ' ')
        .substring(0, iso.length >= 16 ? 16 : iso.length);
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: Text(widget.title ?? '笔记标注'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: widget.contentHash.isEmpty
            ? const EmptyState(
                icon: FLucideIcons.highlighter,
                title: '该书暂无内容标识',
                subtitle: '无法关联笔记，重新导入后可正常查看',
              )
            : ref
                  .watch(annotationsStreamProvider(widget.contentHash))
                  .when(
                    loading: () => const Center(child: FCircularProgress()),
                    error: (e, _) => EmptyState(
                      icon: FLucideIcons.highlighter,
                      title: '加载失败：$e',
                    ),
                    data: _buildData,
                  ),
      ),
    );
  }

  /// 列表主体（筛选 + 统计 + 全量卡片）
  Widget _buildData(List<EbookAnnotationData> all) {
    final t = context.theme;
    if (all.isEmpty) {
      return const EmptyState(
        icon: FLucideIcons.highlighter,
        title: '还没有笔记与标注',
        subtitle: '在阅读器顶栏「批注」里添加划线或笔记后会出现在这里',
      );
    }
    final marks = all.where((a) => !_isNote(a)).toList();
    final notes = all.where(_isNote).toList();
    final list = switch (_tab) {
      _NotesTab.marks => marks,
      _NotesTab.notes => notes,
      _ => all,
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              12,
              AppTokens.pagePadding,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JianliSegmented(
                  items: const [
                    (FLucideIcons.layers, '全部'),
                    (FLucideIcons.highlighter, '划线'),
                    (FLucideIcons.notebookPen, '笔记'),
                  ],
                  selected: _tab.index,
                  onSelect: (i) => setState(() => _tab = _NotesTab.values[i]),
                ),
                const SizedBox(height: 10),
                Text(
                  '共 ${all.length} 条 · 划线 ${marks.length} · 笔记 ${notes.length}',
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: _tab == _NotesTab.notes
                  ? FLucideIcons.notebookPen
                  : FLucideIcons.highlighter,
              title: _tab == _NotesTab.notes ? '暂无笔记' : '暂无划线',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              0,
              AppTokens.pagePadding,
              24,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _card(context, list[i]),
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }

  /// 单条笔记/标注卡片（正文与笔记完整展开）
  Widget _card(BuildContext context, EbookAnnotationData a) {
    final t = context.theme;
    final isNote = _isNote(a);
    final color = _colorOf(t, a.color);
    final meta = _typeMeta(a.type);
    final text = (a.annotatedText ?? '').trim();
    final note = (a.note ?? '').trim();
    final chapterTitle = _chapterTitleOf(a.anchor);
    final chapterIndex = _chapterIndexOf(a.anchor);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTokens.accentSoft(context, color),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(meta.$2, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      meta.$1,
                      style: t.typography.body.xs.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isNote && (a.color ?? '').trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  a.color!,
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(a),
                child: Icon(
                  FLucideIcons.trash2,
                  size: 18,
                  color: t.colors.destructive,
                ),
              ),
            ],
          ),
          if (chapterTitle != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  FLucideIcons.bookOpen,
                  size: 13,
                  color: t.colors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    chapterTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.xs.copyWith(
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
                if (chapterIndex != null)
                  GestureDetector(
                    onTap: () => _jumpChapter(chapterIndex),
                    child: Text(
                      '跳到该章',
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: color.withValues(alpha: 0.75),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                text,
                // ⚠️ 用户要求：原文不省略，完整展开
                style: t.typography.body.md.copyWith(height: 1.7),
              ),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.accentSoft(context, color),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FLucideIcons.penLine, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '笔记',
                        style: t.typography.body.xs.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    // ⚠️ 用户要求：笔记不省略，完整展开
                    style: t.typography.body.sm.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
          ],
          if ((a.createdAt ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  FLucideIcons.clock,
                  size: 12,
                  color: t.colors.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  _fmtTime(a.createdAt),
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 跳转到阅读器对应章节（路由参数 chapter 由阅读页消费）
  void _jumpChapter(int index) {
    context.push(
      '/ebook/reader?path=${Uri.encodeComponent(widget.filePath)}&chapter=$index',
    );
  }

  /// 删除确认（全局规范：一律底部抽屉，红线 #10）
  Future<void> _confirmDelete(EbookAnnotationData a) async {
    final ok = await showFSheet<bool>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('删除这条标注？', style: c.theme.typography.body.lg),
              const SizedBox(height: 8),
              Text(
                '删除后不可恢复',
                style: c.theme.typography.body.sm.copyWith(
                  color: c.theme.colors.mutedForeground,
                ),
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
                      variant: FButtonVariant.destructive,
                      onPress: () => Navigator.pop(c, true),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await ref.read(ebookRepositoryProvider).removeAnnotation(a.id);
      if (mounted) {
        showFToast(context: context, title: const Text('已删除'));
      }
    }
  }
}
