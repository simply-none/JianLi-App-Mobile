// 笔记列表页 —— 分类筛选 chips + 摘要卡片列表
//
// 数据源：notesStreamProvider(category)；点击进入详情页（note_detail_page）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(_category == null ? '笔记' : '笔记 · $_category')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/notes/edit'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 分类筛选条
          categoriesAsync.maybeWhen(
            data: (categories) => _buildCategoryChips(categories),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (notes) {
                if (notes.isEmpty) {
                  return const Center(child: Text('暂无笔记（先在桌面端同步数据到本机）'));
                }
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          note.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        onTap: () => context.push('/notes/${Uri.encodeComponent(note.key)}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 分类筛选 chips（全部 + 各分类）
  Widget _buildCategoryChips(List<String> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _category == null,
            onSelected: (_) => setState(() => _category = null),
          ),
          const SizedBox(width: 6),
          for (final c in categories) ...[
            ChoiceChip(
              label: Text(c),
              selected: _category == c,
              onSelected: (_) => setState(() => _category = c),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
