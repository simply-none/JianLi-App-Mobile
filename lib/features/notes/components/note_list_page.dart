// 笔记列表页 —— 分类筛选 + FTile 列表（forui 化）
//
// 数据源：notesStreamProvider(category)；点击进入详情页（note_detail_page）。
// 分类筛选条：FBadge 当 chip 用（forui 无 chip 组件），选中态用 primary 变体。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/ui_atoms.dart';
import '../providers/note_providers.dart';

/// 笔记列表页
class NoteListPage extends ConsumerStatefulWidget {
  const NoteListPage({super.key});

  @override
  ConsumerState<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends ConsumerState<NoteListPage> {
  String? _category; // 当前选中分类；null = 全部

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider(_category));
    final categoriesAsync = ref.watch(noteCategoriesProvider);

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
      child: Column(
        children: [
          // 分类筛选条
          categoriesAsync.maybeWhen(
            data: (categories) => _buildCategoryChips(categories),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: FCircularProgress()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (notes) {
                if (notes.isEmpty) {
                  return const EmptyState(
                    icon: FLucideIcons.notebookPen,
                    title: '暂无笔记',
                    subtitle: '点右上角新建，或等桌面端同步',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    FTileGroup(
                      divider: FItemDivider.full,
                      children: [
                        for (final note in notes)
                          FTile(
                            title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              note.excerpt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPress: () =>
                                context.push('/notes/${Uri.encodeComponent(note.key)}'),
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
    );
  }

  /// 分类筛选条（FBadge 当 chip；选中 primary / 未选 outline）
  Widget _buildCategoryChips(List<String> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          _CategoryChip(
            label: '全部',
            selected: _category == null,
            onTap: () => setState(() => _category = null),
          ),
          const SizedBox(width: 6),
          for (final c in categories) ...[
            _CategoryChip(
              label: c,
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// 单个分类筛选 chip（FTappable + FBadge 组合）
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: onTap,
      child: FBadge(
        variant: selected ? FBadgeVariant.primary : FBadgeVariant.outline,
        child: Text(
          label,
          style: t.typography.body.sm.copyWith(
            color: selected ? t.colors.primaryForeground : t.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
