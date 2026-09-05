// 提醒管理页 —— 用户提醒列表（定点/周期/多状态）+ 启停开关
//
// 与桌面端 newTips 页对应；新增/编辑表单列 P2（优先保证引擎语义只读 + 启停联动通知）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/ui_atoms.dart';
import '../models/reminder_item.dart';
import '../providers/reminder_providers.dart';

/// 提醒管理页
class ReminderListPage extends ConsumerWidget {
  const ReminderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(reminderListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('提醒管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: '暂无提醒',
              subtitle: '点右下角新建，或等桌面端同步',
            );
          }
          return ListView(
            children: [
              for (final item in items) _ReminderTile(item: item),
            ],
          );
        },
      ),
    );
  }

  /// 新建定点提醒（标题/内容/时刻/星期）
  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final content = TextEditingController();
    final time = TextEditingController(text: '09:00');
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
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '提醒标题', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: content,
                decoration: const InputDecoration(
                    labelText: '内容（可选）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: time,
                decoration: const InputDecoration(
                    labelText: '时刻（HH:mm）', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text('周${'一二三四五六日'[d - 1]}'),
                      selected: weekDays.contains(d),
                      onSelected: (v) =>
                          setSheetState(() => v ? weekDays.add(d) : weekDays.remove(d)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final t = title.text.trim();
                  final timeParts = time.text.trim().split(':');
                  if (t.isEmpty || timeParts.length != 2) return;
                  ref.read(reminderRepositoryProvider).createReminder(
                        title: t,
                        content: content.text.trim(),
                        time: time.text.trim(),
                        weekDays: weekDays.toList()..sort(),
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

/// 单条提醒
class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.item});

  final ReminderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleParts = <String>[
      item.modeLabel,
      if (!item.isStateful && (item.time?.isNotEmpty ?? false)) item.time!,
      if (item.isStateful && item.statesSummary != null) item.statesSummary!,
      if (item.idleTime != null && item.idleTime != '[]') '含免打扰',
    ];

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            item.isStateful ? Icons.autorenew : Icons.alarm,
            color: item.enabled ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        decoration: item.enabled ? null : TextDecoration.lineThrough,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
          Switch(
            value: item.enabled,
            // 状态机型提醒不允许启停（权威在番茄钟页）
            onChanged: item.isStateful
                ? null
                : (v) =>
                    ref.read(reminderRepositoryProvider).toggleEnabled(item, v),
          ),
        ],
      ),
    );
  }
}
