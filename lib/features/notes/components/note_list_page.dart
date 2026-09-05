// 笔记列表页 —— 分类筛选 + FTile 列表（forui 化）
//
// 数据源：notesStreamProvider(category)；点击进入详情页（note_detail_page）。
// 分类筛选条：FBadge 当 chip 用（forui 无 chip 组件），选中态用 primary 变体。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/note_item.dart';
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
      child: ColoredBox(
        color: AppTokens.pageTint(context),
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
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    children: [
                      // 页面专属琥珀渐变横幅（与内容分组页「笔记」入口色对齐）
                      PageBanner(
                        icon: FLucideIcons.notebookPen,
                        title: '笔记',
                        subtitle: '随手记录，分类收纳',
                        accentIndex: 3,
                        stats: [
                          (
                            '${notes.length}',
                            _category == null ? '篇笔记' : '篇「$_category」',
                          ),
                          ('${categoriesAsync.value?.length ?? 0}', '个分类'),
                        ],
                      ),
                      StaggerList(
                        children: [
                          for (final note in notes)
                            _NoteCard(
                              note: note,
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

/// 单条笔记卡（专属色图标盘 + 标题 + 摘要 + 箭头），替换原 FTile
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final NoteItem note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      onTap: onTap,
      child: Row(
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
            ),
          ),
          Icon(
            FLucideIcons.chevronRight,
            size: 18,
            color: t.colors.mutedForeground,
          ),
        ],
      ),
    );
  }
}
