// 笔记列表页 —— 对齐待办列表页骨架（主色横幅统计 + 吸顶搜索行 + 条件 chip + 列表）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 笔记18/Bold · 标签管理18 · ＋22（新建）
//   统计横幅 PageBanner 琥珀专属渐变 · r22 · stats 全部/本周更新/标签（随滚动移出）
//   搜索行  ★吸顶锚点（PinnedSearchRow/PinnedSearchHeader，搜索框常驻视口顶部）
//   条件chip 分类 + 标签（多选任一命中）+ 关键词，逐个可点掉（SoftChip）
//   列表    笔记卡（专属色图标盘 + 标签彩点徽标 + 分类/友好时间），分页「加载更多」
//
// 检索能力对齐桌面端 categorizableNotes：关键词（摘要/正文/markdown/富文本 + 标签名，
// 等价 PC 四列 LIKE + tags）；分类与标签筛选走「查询抽屉」（showFilterSheet）。
// 标签管理（重命名/改色/删除）走头部标签图标 → note_sheets.dart。
// 分页：PC 端 10/页 → 内存分页 + 底部「加载更多」（流式数据全量在手，翻页纯展示层）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/filter_sheet.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/note_item.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import 'note_export_sheet.dart';
import 'note_sheets.dart';
import 'note_tag_chip.dart';

/// 笔记列表页
class NoteListPage extends ConsumerStatefulWidget {
  const NoteListPage({super.key});

  @override
  ConsumerState<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends ConsumerState<NoteListPage> {
  /// 笔记域专属琥珀强调色（与内容分组页「笔记」入口色对齐）
  static final Color _accent = AppTokens.accent(3);

  /// 分页展示条数（PC 端每页 10 条）
  static const int _pageSize = 10;

  final Set<String> _selectedCategories = {}; // 已生效分类（多选，任一命中）
  String _keyword = '';
  final Set<String> _selectedTagKeys = {}; // 已生效标签筛选（多选，任一命中）
  final _searchController = TextEditingController();

  /// 当前展示条数（「加载更多」每次 +[_pageSize]；筛选变化时重置）
  int _visible = _pageSize;

  // 查询抽屉内的草稿（打开时从已生效条件初始化，点「查询」才应用）
  final Set<String> _draftCategories = {};
  final Set<String> _draftTags = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(
      notesStreamProvider(_selectedCategories.join('\u0001')),
    );
    final categoriesAsync = ref.watch(noteCategoriesProvider);
    final tagDefs = (ref.watch(noteTagsProvider).value ?? const <NoteTag>[]);

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
                child: notesAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败：$e',
                      textAlign: TextAlign.center,
                      style: context.theme.typography.body.sm.copyWith(
                        color: context.theme.colors.error,
                      ),
                    ),
                  ),
                  data: (notes) => _body(context, notes, tagDefs,
                      categoriesAsync.value ?? const []),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部（对齐待办：‹ / 标题 / 标签管理 / ＋） =====================

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
              _selectedCategories.isEmpty
                  ? '笔记'
                  : '笔记 · ${_selectedCategories.join(' / ')}',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: () => showNoteTagManagerSheet(context, ref),
            child: Icon(FLucideIcons.tags, size: 18, color: t.colors.foreground),
          ),
          TapScale(
            onTap: () => showNoteExportSheet(context),
            child: Icon(
              FLucideIcons.download,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: () => context.push('/notes/edit'),
            child: Icon(FLucideIcons.plus, size: 22, color: t.colors.foreground),
          ),
        ],
      ),
    );
  }

  // ===================== 主体（待办骨架） =====================

  Widget _body(
    BuildContext context,
    List<NoteItem> notes,
    List<NoteTag> tagDefs,
    List<String> categories,
  ) {
    final defByKey = {for (final d in tagDefs) d.key: d};
    final filtered = _filterNotes(notes, tagDefs);
    final shown = filtered.take(_visible).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(context, notes, tagDefs)),
        // ★吸顶锚点：搜索行常驻视口顶部（横幅 / chip 随滚动移出）
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索内容与标签…',
              onChanged: (v) => setState(() {
                _keyword = v;
                _visible = _pageSize;
              }),
              onFilter: () => _openFilterSheet(categories, tagDefs),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _chipsRow(context, tagDefs)),
        if (notes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: true),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, totallyEmpty: false),
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
              delegate: SliverChildListDelegate([
                StaggerList(
                  children: [
                    for (final note in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NoteCard(
                          note: note,
                          defByKey: defByKey,
                          onTap: () => context.push(
                            '/notes/${Uri.encodeComponent(note.key)}',
                          ),
                          onLongPress: () => _noteMenu(context, note),
                        ),
                      ),
                  ],
                ),
                // 分页脚（PC 端 10/页语义的移动端落法）
                if (filtered.length > shown.length)
                  _loadMoreTile(context, filtered.length - shown.length)
                else if (filtered.length > _pageSize)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Center(
                      child: Text(
                        '已全部加载 · 共 ${filtered.length} 篇',
                        style: context.theme.typography.body.xs.copyWith(
                          fontSize: 12,
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（琥珀专属渐变 + 纹理 + 同心圆环，视觉个性比待办单色横幅更足）
  Widget _banner(
    BuildContext context,
    List<NoteItem> notes,
    List<NoteTag> tagDefs,
  ) =>
      PageBanner(
        icon: FLucideIcons.notebookPen,
        title: '笔记',
        subtitle: '随手记录，分类收纳',
        accentIndex: 3,
        cornerRadius: 22,
        ringDecor: true,
        shadow: false,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        stats: [
          ('${notes.length}', '全部'),
          ('${_weeklyCount(notes)}', '本周更新'),
          ('${tagDefs.where((d) => !d.deleted).length}', '标签'),
        ],
      );

  /// 生效条件 chip（关键词/分类/标签逐个可点掉；无生效条件整块不渲染）
  Widget _chipsRow(BuildContext context, List<NoteTag> tagDefs) {
    final defByKey = {for (final d in tagDefs) d.key: d};
    final chips = <Widget>[];
    if (_keyword.trim().isNotEmpty) {
      chips.add(
        _condChip(context, '搜索：${_keyword.trim()}', _accent, () {
          _searchController.clear();
          setState(() => _keyword = '');
        }),
      );
    }
    for (final c in _selectedCategories) {
      chips.add(
        _condChip(context, '分类：$c', _accent,
            () => setState(() => _selectedCategories.remove(c))),
      );
    }
    for (final k in _selectedTagKeys) {
      final tag = defByKey[k];
      if (tag == null) continue;
      chips.add(
        _condChip(
          context,
          tag.name,
          tag.colorValue,
          () => setState(() => _selectedTagKeys.remove(k)),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    chips.add(
      _condChip(context, '清除全部', context.theme.colors.destructive,
          _clearAllFilters),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  /// 生效条件 chip（SoftChip 可点掉形态：底 = 同色 12% · r10 · 11/SemiBold）
  Widget _condChip(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
  ) =>
      SoftChip(
        label: label,
        color: color,
        alpha: 0.12,
        padding: const EdgeInsets.all(6),
        onRemove: onTap,
      );

  /// 空态（对齐待办：图标盘 76 + 16/Bold 标题 + 13/次字）
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
              totallyEmpty ? FLucideIcons.notebookPen : FLucideIcons.searchX,
              size: 32,
              color: _accent,
            ),
          ),
          Text(
            totallyEmpty ? '还没有笔记' : '没有匹配的笔记',
            style: t.typography.body.lg.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          Text(
            totallyEmpty ? '点右上角 ＋ 记下第一笔' : '换个关键词，或清除筛选条件',
            style: t.typography.body.xs.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 「加载更多」脚（剩余 N 篇）
  Widget _loadMoreTile(BuildContext context, int remaining) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: TapScale(
        onTap: () => setState(() => _visible += _pageSize),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.colors.muted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FLucideIcons.chevronDown,
                  size: 14, color: t.colors.mutedForeground),
              const SizedBox(width: 6),
              Text(
                '加载更多 · 还有 $remaining 篇',
                style: t.typography.body.xs.copyWith(
                  fontSize: 13,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 行为 =====================

  /// 双重过滤：标签多选（任一命中）→ 关键词（内容 + 标签名，对齐 PC 语义）
  List<NoteItem> _filterNotes(List<NoteItem> notes, List<NoteTag> tagDefs) {
    final kw = _keyword.trim().toLowerCase();
    return notes.where((note) {
      if (_selectedTagKeys.isNotEmpty &&
          !_selectedTagKeys.any(note.tags.contains)) {
        return false;
      }
      if (kw.isNotEmpty) {
        final inTagNames = note.tags.any(
          (k) => tagDefs
              .where((d) => d.key == k)
              .any((d) => d.name.toLowerCase().contains(kw)),
        );
        if (!note.searchText.contains(kw) && !inTagNames) return false;
      }
      return true;
    }).toList();
  }

  /// 近 7 天更新数（横幅「本周更新」）
  int _weeklyCount(List<NoteItem> notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var count = 0;
    for (final n in notes) {
      final d = DateTime.tryParse(n.updateTime);
      if (d != null && today.difference(DateTime(d.year, d.month, d.day)).inDays <= 6) {
        count++;
      }
    }
    return count;
  }

  /// 打开「查询抽屉」：草稿从已生效条件初始化，重置=清空草稿，查询=应用并关闭
  Future<void> _openFilterSheet(
    List<String> categories,
    List<NoteTag> tagDefs,
  ) async {
    _draftCategories
      ..clear()
      ..addAll(_selectedCategories);
    _draftTags
      ..clear()
      ..addAll(_selectedTagKeys);
    final result = await showFilterSheet<(Set<String>, Set<String>)>(
      context: context,
      body: (context, refresh) =>
          _buildFilterBody(categories, tagDefs, refresh),
      onReset: (refresh) {
        _draftCategories.clear();
        _draftTags.clear();
        refresh();
      },
      onConfirm: () =>
          (Set<String>.of(_draftCategories), Set<String>.of(_draftTags)),
    );
    if (result == null || !mounted) return; // 关闭/取消：不应用
    setState(() {
      _selectedCategories
        ..clear()
        ..addAll(result.$1);
      _selectedTagKeys
        ..clear()
        ..addAll(result.$2);
      _visible = _pageSize;
    });
  }

  /// 查询抽屉选项区：分类单选 + 标签多选
  Widget _buildFilterBody(
    List<String> categories,
    List<NoteTag> tagDefs,
    VoidCallback refresh,
  ) {
    final activeTags = tagDefs.where((d) => !d.deleted).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, '分类（可多选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in categories)
              _CategoryChip(
                label: c,
                selected: _draftCategories.contains(c),
                onTap: () {
                  _draftCategories.contains(c)
                      ? _draftCategories.remove(c)
                      : _draftCategories.add(c);
                  refresh();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _fieldLabel(context, '标签（可多选）'),
        const SizedBox(height: 8),
        if (activeTags.isEmpty)
          Text(
            '暂无标签，可在编辑笔记时新建',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in activeTags)
                NoteTagChip(
                  tag: tag,
                  selected: _draftTags.contains(tag.key),
                  onTap: () {
                    _draftTags.contains(tag.key)
                        ? _draftTags.remove(tag.key)
                        : _draftTags.add(tag.key);
                    refresh();
                  },
                ),
            ],
          ),
      ],
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _keyword = '';
      _selectedCategories.clear();
      _selectedTagKeys.clear();
      _visible = _pageSize;
    });
  }

  /// 单条笔记长按菜单（打开 / 编辑 / 删除）
  Future<void> _noteMenu(BuildContext context, NoteItem note) async {
    final action = await showSheetActionMenu<String>(
      context,
      title: note.title,
      actions: [
        const SheetAction('open', '打开', icon: FLucideIcons.bookOpen),
        const SheetAction('edit', '编辑', icon: FLucideIcons.pencil),
        const SheetAction(
          'delete',
          '删除',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'open':
        context.push('/notes/${Uri.encodeComponent(note.key)}');
      case 'edit':
        context.push('/notes/edit?noteKey=${Uri.encodeComponent(note.key)}');
      case 'delete':
        final ok = await showSheetConfirm(
          context,
          title: '删除笔记',
          message: '确定删除「${note.title}」？删除后不可恢复。',
        );
        if (ok) await ref.read(noteRepositoryProvider).deleteNote(note.key);
    }
  }

  Widget _fieldLabel(BuildContext context, String text) {
    final t = context.theme;
    return Text(
      text,
      style: t.typography.body.xs.copyWith(
        color: t.colors.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 分类筛选 chip（圆角 pill；选中态用笔记域专属琥珀强调色）
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(3);
    final bg = selected ? accent : t.colors.card;
    final fg = selected ? Colors.white : t.colors.foreground;
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: selected ? null : Border.all(color: t.colors.border),
        ),
        child: Text(
          label,
          style: t.typography.body.sm.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 单条笔记卡（三行式，2026-09-14 定：对齐提醒卡片 A / 主题对话卡，采用方案 B
/// 「时间移到标题行行尾」变体）
///
/// R1 图标盘（40·r13 专属琥珀渐变 + notebook-pen）+ 标题（1 行省略）+ 时间 + chevron
/// R2 摘要正文（2 行省略；与标题重复的首行已剔除，无正文则整行不渲染）
/// R3 分类 chip（琥珀软底 + folder 前饰）+ 标签徽标（彩点 + 同色软底）+「+N」溢出
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.defByKey,
    required this.onTap,
    required this.onLongPress,
  });

  /// 笔记域专属琥珀强调色（与内容分组页「笔记」入口色一致）
  static final Color _accent = AppTokens.accent(3);

  /// 标签最多展示个数（超出合并为「+N」，与主题对话卡同规则）
  static const int _maxTags = 4;

  /// 分类最多展示个数
  static const int _maxCategories = 2;

  final NoteItem note;
  final Map<String, NoteTag> defByKey;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 标签 key 无定义的不展示（软删标签仍按定义显示名称与颜色）
    final tags = [
      for (final k in note.tags)
        if (defByKey[k] != null) defByKey[k]!,
    ];
    final shownTags = tags.take(_maxTags).toList();
    final shownCats = note.categories.take(_maxCategories).toList();
    // 溢出一并计入同一个「+N」：分类与标签的隐藏项总数
    final overflow = (tags.length - shownTags.length) +
        (note.categories.length - shownCats.length);
    // 时间：优先更新时间，空则回落创建时间（对齐桌面端 `updateTime || createTime`）
    final timeRaw = note.updateTime.isNotEmpty ? note.updateTime : note.createTime;
    final excerpt = _excerptBody;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        // 列表卡 margin 清零：间距只由外层 Padding(bottom:10) 提供
        //（AppCard 默认 vertical:6 会叠出 22px 大间隙，2026-09-13 用户实指）
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // R1：图标盘 + 标题（弹性省略）+ 时间 + chevron，同排垂直居中
            Row(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTokens.accentGradient(_accent),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    FLucideIcons.notebookPen,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.colors.foreground,
                    ),
                  ),
                ),
                if (timeRaw.isNotEmpty)
                  Text(
                    _friendlyTime(timeRaw),
                    maxLines: 1,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 11,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                Icon(
                  FLucideIcons.chevronRight,
                  size: 18,
                  color: t.colors.mutedForeground,
                ),
              ],
            ),
            // R2：摘要正文（无正文整行不渲染）
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
            // R3：分类 + 标签（Wrap 自动换行；两者皆空则整行不渲染）
            if (shownCats.isNotEmpty || shownTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final c in shownCats)
                    SoftChip(
                      label: c,
                      color: _accent,
                      alpha: 0.10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      leading: Icon(
                        FLucideIcons.folder,
                        size: 11,
                        color: _accent,
                      ),
                    ),
                  for (final tag in shownTags)
                    SoftChip(
                      label: tag.name,
                      color: tag.colorValue,
                      alpha: 0.14,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tag.colorValue,
                        ),
                      ),
                    ),
                  if (overflow > 0) FlatBadge(label: '+$overflow'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 摘要正文：`excerpt` 去掉与标题重复的首行
  ///
  /// 本端 `note_repository._excerptOf` 的写入格式为 `"{title}\n{正文首行}"`，
  /// 首行即标题，直接展示会与 R1 标题重复；桌面端写入的 excerpt 若不与标题
  /// 重复则原样保留（多行合并为一段）。
  String get _excerptBody {
    final lines = note.excerpt
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isNotEmpty && lines.first == note.title.trim()) {
      lines.removeAt(0);
    }
    return lines.join(' ');
  }

  /// 'yyyy-MM-dd HH:mm:ss' → 今天/昨天/M月D日（跨年带年份）
  static String _friendlyTime(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    final hhmm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '今天 $hhmm';
    if (diff == 1) return '昨天 $hhmm';
    if (d.year == now.year) return '${d.month}月${d.day}日';
    return '${d.year}年${d.month}月${d.day}日';
  }
}
