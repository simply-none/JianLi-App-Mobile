// 习惯打卡页 —— 今日待打卡列表 + 点击打卡 + 近 7 天记录条
//
// 交互：点卡片任意处切换打卡；右侧 7 格小方块展示近 7 天记录（今天在最右）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/ui_atoms.dart';
import '../models/habit.dart';
import '../providers/habit_providers.dart';

/// 习惯打卡页
class HabitPage extends ConsumerWidget {
  const HabitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final checkedAsync = ref.watch(todayCheckedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('习惯打卡')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (habits) => checkedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (checked) {
            if (habits.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available,
                title: '暂无启用的习惯',
                subtitle: '点右下角新建，或等桌面端同步',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final habit in habits)
                  _HabitCard(
                    habit: habit,
                    checked: checked.contains(habit.key),
                    onToggle: () async {
                      await ref
                          .read(habitRepositoryProvider)
                          .toggleCheckin(habit.key, DateTime.now());
                    },
                    onDelete: () =>
                        ref.read(habitRepositoryProvider).deleteHabit(habit),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 新建习惯弹层（名称 / 提醒时刻 / 生效星期）
  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final timeController = TextEditingController(text: '08:00');
    final weekDays = <int>{};

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '习惯名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: '提醒时刻（HH:mm，留空不提醒）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // 生效星期（空 = 每天）
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text('周${'一二三四五六日'[d - 1]}'),
                      selected: weekDays.contains(d),
                      onSelected: (v) {
                        setSheetState(() =>
                            v ? weekDays.add(d) : weekDays.remove(d));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  ref.read(habitRepositoryProvider).createHabit(
                        name: name,
                        weekDays: weekDays.toList()..sort(),
                        reminderTime: timeController.text.trim(),
                      );
                  Navigator.pop(context);
                },
                child: const Text('创建'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个习惯卡片
class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.checked,
    required this.onToggle,
    required this.onDelete,
  });

  final HabitItem habit;
  final bool checked;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          checked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: checked ? scheme.primary : scheme.outline,
          size: 28,
        ),
        title: Text(
          habit.name,
          style: TextStyle(
            decoration: checked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '频次 ${habit.freqType}${habit.reminderTimes.isEmpty ? '' : ' · 提醒 ${habit.reminderTimes.join('/')}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WeekStrip(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}

/// 近 7 天打卡记录条（简化：仅展示占位，数据接入见 recentCheckinMap）
class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == 6 ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            ),
          ),
      ],
    );
  }
}
