// 笔记列表页 —— 关键词页内实时搜索 + 类型/标签走「查询抽屉」（页面操作规范）
//
// 检索能力对齐桌面端 categorizableNotes：
// - 关键词：摘要/正文/markdown/富文本 + 标签名（内存过滤，等价 PC 的四列 LIKE + tags）；
// - 类型（分类）与标签筛选：底部「查询抽屉」（showFilterSheet）——顶部「查询」+关闭、
//   中部选项、底部固定「重置/查询」；已生效条件在搜索框下方以可删除 chip 呈现。
// 数据源：notesStreamProvider(category) + noteTagsProvider（basic_info.note_tags）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/filter_sheet.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/note_item.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import 'note_tag_chip.dart';

/// 笔记列表页
class NoteListPage extends ConsumerStatefulWidget {
  const NoteListPage({super.key});

  @override
  ConsumerState<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends ConsumerState<NoteListPage> {
  String? _category; // 已生效分类；null = 全部
  final _searchController = TextEditingController();
  String _keyword = '';
  final Set<String> _selectedTagKeys = {}; // 已生效标签筛选（多选，任一命中）
  // 查询抽屉内的草稿（打开时从已生效条件初始化，点「查询」才应用）
  String? _draftCategory;
  final Set<String> _draftTags = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider(_category));
    final categoriesAsync = ref.watch(noteCategoriesProvider);
    final tagDefsAsync = ref.watch(noteTagsProvider);
    final tagDefs = tagDefsAsync.value ?? const <NoteTag>[];
    final defByKey = {for (final d in tagDefs) d.key: d};
    final hPad = AppTokens.pagePaddingOf(context);

    return FScaffold(
      header: FHeader.nested(
        title: Text(_category == null ? '笔记' : '笔记 · $_category'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => context.push('/notes/edit'),
          ),
        ],
      ),
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: Column(
          children: [
            // 搜索行：关键词输入 + 筛选入口（页面规范：条件筛选走查询抽屉）
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
              child: Row(
                children: [
                  // 搜索行统一高度 44：输入框与筛选按钮都套固定高度——
                  // forui 控件内部高度会随字号缩放漂移，等高对齐必须双端写死同值
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FTextField(
                        // ⚠️ onChange 是 FTextFieldControl.managed 的参数（收 TextEditingValue），
                        // 不是 FTextField 的命名参数（forui 0.26 实测，写错即编译失败）
                        control: FTextFieldControl.managed(
                          controller: _searchController,
                          onChange: (_) =>
                              setState(() => _keyword = _searchController.text),
                        ),
                        hint: '搜索内容与标签…',
                        size: FTextFieldSizeVariant.sm,
                        prefixBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Icon(FLucideIcons.search, size: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 高度 44 与输入框统一（页面规范：等高对齐双端写死同值）
                  _FilterEntryButton(
                    count: _activeFilterCount,
                    onTap: () => _openFilterSheet(
                      categoriesAsync.value ?? const [],
                      tagDefs,
                    ),
                  ),
                ],
              ),
            ),
            // 已生效筛选（可点掉；关键词由输入框本身呈现，不重复展示）
            if (_category != null || _selectedTagKeys.isNotEmpty)
              _buildAppliedFilters(tagDefs),
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(child: FCircularProgress()),
                error: (e, _) => Center(child: Text('加载失败：$e')),
                data: (notes) {
                  final filtered = _filterNotes(notes, tagDefs);
                  if (notes.isEmpty) {
                    return const EmptyState(
                      icon: FLucideIcons.notebookPen,
                      title: '暂无笔记',
                      subtitle: '点右上角新建，或等桌面端同步',
                    );
                  }
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: FLucideIcons.searchX,
                      title: '没有匹配的笔记',
                      subtitle: '换个关键词，或在查询里放宽条件',
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.only(
                      top: AppTokens.listTopGapOf(context),
                      bottom: AppTokens.pageBottomGapOf(context),
                    ),
                    children: [
                      // 页面专属琥珀渐变横幅（与内容分组页「笔记」入口色对齐）
                      PageBanner(
                        icon: FLucideIcons.notebookPen,
                        title: '笔记',
                        subtitle: '随手记录，分类收纳',
                        accentIndex: 3,
                        stats: [
                          ('${filtered.length}', _isFiltering ? '篇结果' : '篇笔记'),
                          ('${tagDefs.where((d) => !d.deleted).length}', '个标签'),
                        ],
                      ),
                      StaggerList(
                        children: [
                          for (final note in filtered)
                            _NoteCard(
                              note: note,
                              defByKey: defByKey,
                              onTap: () => context.push(
                                '/notes/${Uri.encodeComponent(note.key)}',
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isFiltering =>
      _keyword.trim().isNotEmpty ||
      _category != null ||
      _selectedTagKeys.isNotEmpty;

  int get _activeFilterCount =>
      (_category != null ? 1 : 0) + _selectedTagKeys.length;

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

  /// 打开「查询抽屉」：草稿从已生效条件初始化，重置=清空草稿，查询=应用并关闭
  Future<void> _openFilterSheet(
    List<String> categories,
    List<NoteTag> tagDefs,
  ) async {
    _draftCategory = _category;
    _draftTags
      ..clear()
      ..addAll(_selectedTagKeys);
    final result = await showFilterSheet<(String?, Set<String>)>(
      context: context,
      body: (context, refresh) =>
          _buildFilterBody(categories, tagDefs, refresh),
      onReset: (refresh) {
        _draftCategory = null;
        _draftTags.clear();
        refresh();
      },
      onConfirm: () => (_draftCategory, Set<String>.of(_draftTags)),
    );
    if (result == null || !mounted) return; // 关闭/取消：不应用
    setState(() {
      _category = result.$1;
      _selectedTagKeys
        ..clear()
        ..addAll(result.$2);
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
        _fieldLabel('分类'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CategoryChip(
              label: '全部',
              selected: _draftCategory == null,
              onTap: () {
                _draftCategory = null;
                refresh();
              },
            ),
            for (final c in categories)
              _CategoryChip(
                label: c,
                selected: _draftCategory == c,
                onTap: () {
                  _draftCategory = _draftCategory == c ? null : c;
                  refresh();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _fieldLabel('标签（可多选）'),
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

  Widget _fieldLabel(String text) {
    final t = context.theme;
    return Text(
      text,
      style: t.typography.body.xs.copyWith(
        color: t.colors.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// 已生效筛选摘要（可点掉；关键词由输入框呈现，不重复）
  Widget _buildAppliedFilters(List<NoteTag> tagDefs) {
    final defByKey = {for (final d in tagDefs) d.key: d};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(
        AppTokens.pagePaddingOf(context),
        8,
        AppTokens.pagePaddingOf(context),
        0,
      ),
      child: Row(
        children: [
          if (_category != null) ...[
            _AppliedChip(
              label: '分类：$_category',
              onDelete: () => setState(() => _category = null),
            ),
            const SizedBox(width: 6),
          ],
          for (final k in _selectedTagKeys)
            if (defByKey[k] != null) ...[
              NoteTagChip(
                tag: defByKey[k]!,
                selected: true,
                onTap: () => setState(() => _selectedTagKeys.remove(k)),
              ),
              const SizedBox(width: 6),
            ],
        ],
      ),
    );
  }
}

/// 筛选入口按钮（激活时琥珀软底 + 生效条件数角标）
class _FilterEntryButton extends StatelessWidget {
  const _FilterEntryButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final active = count > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 高度 44 与输入框统一固定（forui 控件内部高度随字号缩放漂移，
        // 等高对齐必须双端写死同值；FTappable 不上报固有高度，IntrinsicHeight 勿用）
        FTappable(
          onPress: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: active
                  ? AppTokens.accentSoft(context, AppTokens.accent(3))
                  : t.colors.card,
              // 圆角同 SquircleBox 规格（ContinuousRectangleBorder 超椭圆）
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              FLucideIcons.slidersHorizontal,
              size: 18,
              color: active ? AppTokens.accent(3) : t.colors.foreground,
            ),
          ),
        ),
        if (active)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTokens.accent(3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: t.typography.body.xs.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 已生效筛选摘要 chip（琥珀软底 + 可点掉）
class _AppliedChip extends StatelessWidget {
  const _AppliedChip({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(3);
    return FTappable(
      onPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(FLucideIcons.x, size: 12, color: accent),
          ],
        ),
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

/// 单条笔记卡（专属色图标盘 + 标题 + 摘要 + 标签彩色徽标 + 箭头）
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.defByKey,
    required this.onTap,
  });

  final NoteItem note;
  final Map<String, NoteTag> defByKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 最多展示 3 个标签，超出合并为 +N（key 无定义的不展示）
    final badges = [
      for (final k in note.tags)
        if (defByKey[k] != null) defByKey[k]!,
    ];
    final shown = badges.take(3).toList();
    final overflow = badges.length - shown.length;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SquircleBox(
            size: 44,
            radius: 14,
            gradient: AppTokens.accentGradient(AppTokens.accent(3)),
            alignment: Alignment.center,
            child: Icon(
              FLucideIcons.notebookPen,
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
                  note.title,
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.excerpt,
                    style: t.typography.body.sm.copyWith(
                      color: t.colors.mutedForeground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in shown) NoteTagBadge(tag: tag),
                      if (overflow > 0)
                        Text(
                          '+$overflow',
                          style: t.typography.body.xs.copyWith(
                            color: t.colors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              FLucideIcons.chevronRight,
              size: 18,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
