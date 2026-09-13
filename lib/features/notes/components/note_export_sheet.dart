// 笔记导出抽屉（lg = 80vh 定高）—— 排版自上而下：
//   ① 标题 + 关闭
//   ② 搜索栏 + 高级搜索（点 ≡ 打开独立 80vh「高级搜索」抽屉：分类 / 标签多选；已选项在搜索行下方显示）
//   ③ 可勾选的滚动列表（每条笔记：勾选圆点 + 标题 + 分类/标签/更新时间）
//   ④ 底部固定三个按钮【导出选中】【导出筛选】【导出所有】
//
// 导出为 .md：正文若带 HTML 标签一律转纯文本（见 utils/export_notes_markdown.dart）；
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
import '../models/note_item.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import '../utils/export_notes_markdown.dart';
import 'note_tag_chip.dart';

/// 打开「导出笔记」抽屉（lg 80vh 定高、键盘覆盖不折叠 —— 三档制红线 #9）
Future<void> showNoteExportSheet(BuildContext context) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _NoteExportSheet(),
  );
}

class _NoteExportSheet extends ConsumerStatefulWidget {
  const _NoteExportSheet();

  @override
  ConsumerState<_NoteExportSheet> createState() => _NoteExportSheetState();
}

class _NoteExportSheetState extends ConsumerState<_NoteExportSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  /// 已勾选的笔记 key
  final Set<String> _selectedKeys = {};

  /// 已生效的高级筛选（分类 / 标签，任一命中）——由「高级搜索」80vh 抽屉设置
  final Set<String> _filterCategories = {};
  final Set<String> _filterTagKeys = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 过滤：分类 / 标签（任一命中）+ 关键词（内容 / 标签名）——与列表页 `_filterNotes` 同语义
  List<NoteItem> _filtered(List<NoteItem> notes, List<NoteTag> tagDefs) {
    final kw = _keyword.trim().toLowerCase();
    final nameByKey = {for (final d in tagDefs) d.key: d.name};
    return notes.where((n) {
      if (_filterCategories.isNotEmpty &&
          !_filterCategories.any(n.categories.contains)) {
        return false;
      }
      if (_filterTagKeys.isNotEmpty && !_filterTagKeys.any(n.tags.contains)) {
        return false;
      }
      if (kw.isNotEmpty) {
        final inTagNames = n.tags.any(
          (k) => (nameByKey[k] ?? '').toLowerCase().contains(kw),
        );
        if (!n.searchText.contains(kw) && !inTagNames) return false;
      }
      return true;
    }).toList();
  }

  /// 导出：`selectedOnly` ? 勾选项 : [pool] 全部（[pool] 为该次导出的候选集：
  /// 传 `filtered` = 当前筛选结果、传 `notes` = 全部笔记）。
  Future<void> _export(
    List<NoteItem> pool,
    Map<String, String> tagNameByKey, {
    required bool selectedOnly,
  }) async {
    final chosen = selectedOnly
        ? [for (final n in pool) if (_selectedKeys.contains(n.key)) n]
        : pool;
    if (chosen.isEmpty) {
      showFToast(context: context, title: const Text('没有可导出的笔记'));
      return;
    }
    final md = buildNotesMarkdown(chosen, tagNameByKey);
    await exportTextToDownloadDir(
      context: context,
      text: md,
      filename: '笔记导出_${_fileStamp()}.md',
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
    final notes = ref.watch(notesStreamProvider('')).value ?? const <NoteItem>[];
    final tagDefs = ref.watch(noteTagsProvider).value ?? const <NoteTag>[];
    final categories =
        ref.watch(noteCategoriesProvider).value ?? const <String>[];
    final filtered = _filtered(notes, tagDefs);
    final tagNameByKey = {for (final t in tagDefs) t.key: t.name};
    final t = context.theme;

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
                    child: Text('导出笔记', style: sheetTitleStyle(context)),
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
            // ② 搜索栏 + 高级搜索（≡ 打开独立 80vh 抽屉，分类/标签多时也能完整展示）
            PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索要导出的笔记…',
              onChanged: (v) => setState(() => _keyword = v),
              onFilter: () => _openAdvancedFilter(categories, tagDefs),
            ),
            // 已生效筛选条件（分类/标签逐个可点掉；无则整块不渲染）
            if (_filterCategories.isNotEmpty || _filterTagKeys.isNotEmpty)
              _activeFilterRow(context, tagDefs),
            // ③ 可勾选的滚动列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        notes.isEmpty ? '暂无笔记' : '没有匹配的笔记',
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
                        final n = filtered[i];
                        return _NoteExportRow(
                          note: n,
                          tagNames: [
                            for (final k in n.tags)
                              if ((tagNameByKey[k] ?? '').isNotEmpty)
                                tagNameByKey[k]!,
                          ],
                          selected: _selectedKeys.contains(n.key),
                          onTap: () => setState(() {
                            _selectedKeys.contains(n.key)
                                ? _selectedKeys.remove(n.key)
                                : _selectedKeys.add(n.key);
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
                      onPress: () =>
                          _export(filtered, tagNameByKey, selectedOnly: true),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () =>
                          _export(filtered, tagNameByKey, selectedOnly: false),
                      child: const Text('导出筛选'),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () =>
                          _export(notes, tagNameByKey, selectedOnly: false),
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

  /// 打开「高级搜索」独立抽屉（lg = 80vh 定高）——分类/标签很多时也能完整滚动展示。
  /// 打开前从「已生效筛选」初始化草稿；「应用」才写回，关闭/取消不应用。
  Future<void> _openAdvancedFilter(
    List<String> categories,
    List<NoteTag> tagDefs,
  ) async {
    final draftCategories = Set<String>.of(_filterCategories);
    final draftTags = Set<String>.of(_filterTagKeys);
    final result = await showFilterSheet<(Set<String>, Set<String>)>(
      context: context,
      title: '高级搜索',
      // 80vh：分类/标签多时也能完整展示（用户定案；lg 走 sheetMaxHeightFull 全屏定高）
      size: SheetSize.lg,
      confirmLabel: '应用',
      resetLabel: '重置',
      body: (c, refresh) => _buildFilterBody(
        categories,
        tagDefs,
        draftCategories,
        draftTags,
        refresh,
      ),
      onReset: (refresh) {
        draftCategories.clear();
        draftTags.clear();
        refresh();
      },
      onConfirm: () =>
          (Set<String>.of(draftCategories), Set<String>.of(draftTags)),
    );
    if (result == null || !mounted) return; // 关闭/取消：不应用
    setState(() {
      _filterCategories
        ..clear()
        ..addAll(result.$1);
      _filterTagKeys
        ..clear()
        ..addAll(result.$2);
    });
  }

  /// 高级搜索抽屉选项区：分类（可多选）+ 标签（可多选）
  Widget _buildFilterBody(
    List<String> categories,
    List<NoteTag> tagDefs,
    Set<String> draftCategories,
    Set<String> draftTags,
    VoidCallback refresh,
  ) {
    final activeTags = tagDefs.where((d) => !d.deleted).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelLabel(context, '分类（可多选）'),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          _panelHint(context, '暂无分类')
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
        _panelLabel(context, '标签（可多选）'),
        const SizedBox(height: 8),
        if (activeTags.isEmpty)
          _panelHint(context, '暂无标签，可在编辑笔记时新建')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in activeTags)
                NoteTagChip(
                  tag: tag,
                  selected: draftTags.contains(tag.key),
                  onTap: () {
                    draftTags.contains(tag.key)
                        ? draftTags.remove(tag.key)
                        : draftTags.add(tag.key);
                    refresh();
                  },
                ),
            ],
          ),
      ],
    );
  }

  /// 已生效筛选条件行：分类/标签逐个可点掉 + 「清除」
  Widget _activeFilterRow(BuildContext context, List<NoteTag> tagDefs) {
    final defByKey = {for (final d in tagDefs) d.key: d};
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
              color: AppTokens.accent(3),
              alpha: 0.12,
              padding: const EdgeInsets.all(6),
              onRemove: () => setState(() => _filterCategories.remove(c)),
            ),
          for (final k in _filterTagKeys)
            if (defByKey[k] != null)
              SoftChip(
                label: defByKey[k]!.name,
                color: defByKey[k]!.colorValue,
                alpha: 0.12,
                padding: const EdgeInsets.all(6),
                onRemove: () => setState(() => _filterTagKeys.remove(k)),
              ),
          SoftChip(
            label: '清除',
            color: context.theme.colors.destructive,
            alpha: 0.12,
            padding: const EdgeInsets.all(6),
            onRemove: () => setState(() {
              _filterCategories.clear();
              _filterTagKeys.clear();
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

/// 单条笔记勾选行（勾选圆点 + 标题 + 分类/标签/更新时间）
class _NoteExportRow extends StatelessWidget {
  const _NoteExportRow({
    required this.note,
    required this.tagNames,
    required this.selected,
    required this.onTap,
  });

  final NoteItem note;
  final List<String> tagNames;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final meta = [
      if (note.categories.isNotEmpty) note.categories.join(' / '),
      if (tagNames.isNotEmpty) tagNames.join('、'),
      if (note.updateTime.isNotEmpty) note.updateTime,
    ].join(' ｜ ');

    return FTappable(
      onPress: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.accentSoft(context, AppTokens.accent(3))
              : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected
                ? AppTokens.accent(3).withValues(alpha: 0.4)
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
                color: selected ? AppTokens.accent(3) : t.colors.background,
                border: Border.all(
                  color: selected
                      ? AppTokens.accent(3)
                      : t.colors.mutedForeground,
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
                    note.title,
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
