// 习惯打卡页（forui 化）—— 今日待打卡列表 + 点击打卡 + 近 7 天记录条
//
// 交互：点卡片任意处切换打卡；右侧 7 格小圆点展示近 7 天记录（今天在最右）。
// forui 改造点：FScaffold+FHeader.nested 骨架、AppCard 列表、showFSheet 新建弹层、
// FTextField 输入、FButton 周几选择，取色/字体全部走 forui token。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/animated_check.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
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
    final t = context.theme;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('习惯打卡'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        // 右上角「新建习惯」入口（替代原 FloatingActionButton）
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _showCreateSheet(context, ref),
            semanticsLabel: '新建习惯',
          ),
        ],
      ),
      child: habitsAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '加载失败：$e',
            style: t.typography.body.sm.copyWith(color: t.colors.error),
            textAlign: TextAlign.center,
          ),
        ),
        data: (habits) => checkedAsync.when(
          loading: () => const Center(child: FCircularProgress()),
          error: (e, _) => Center(
            child: Text(
              '加载失败：$e',
              style: t.typography.body.sm.copyWith(color: t.colors.error),
              textAlign: TextAlign.center,
            ),
          ),
          data: (checked) {
            if (habits.isEmpty) {
              return const EmptyState(
                icon: FLucideIcons.calendarCheck,
                title: '暂无启用的习惯',
                subtitle: '点右上角新建，或等桌面端同步',
              );
            }
            return ColoredBox(
              color: AppTokens.pageTint(context),
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  StaggerList(
                    children: [
                      // 页面专属绿渐变横幅（与效率分组页「习惯」入口色对齐）
                      PageBanner(
                        icon: FLucideIcons.calendarCheck,
                        title: '习惯打卡',
                        subtitle: '每天进步一点点，坚持带来大改变',
                        accentIndex: 2,
                        stats: [
                          ('${habits.length}', '启用习惯'),
                          ('${checked.length}', '今日已完成'),
                        ],
                      ),
                      for (var i = 0; i < habits.length; i++)
                        _HabitCard(
                          habit: habits[i],
                          accentIndex: i,
                          checked: checked.contains(habits[i].key),
                          onToggle: () async {
                            await ref
                                .read(habitRepositoryProvider)
                                .toggleCheckin(habits[i].key, DateTime.now());
                          },
                          onDelete: () => ref
                              .read(habitRepositoryProvider)
                              .deleteHabit(habits[i]),
                        ),
                    ],
                  ),
                ],
              ),
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

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FTextField(
                control: FTextFieldControl.managed(controller: nameController),
                label: const Text('习惯名称'),
                hint: '输入习惯名称',
                autofocus: true,
              ),
              const SizedBox(height: 12),
              FTextField(
                control: FTextFieldControl.managed(controller: timeController),
                label: const Text('提醒时刻（HH:mm，留空不提醒）'),
                hint: '08:00',
              ),
              const SizedBox(height: 12),
              // 生效星期（空 = 每天）：选中 secondary / 未选 outline
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FButton(
                      variant: weekDays.contains(d)
                          ? FButtonVariant.secondary
                          : FButtonVariant.outline,
                      size: FButtonSizeVariant.sm,
                      onPress: () => setSheetState(
                        () => weekDays.contains(d)
                            ? weekDays.remove(d)
                            : weekDays.add(d),
                      ),
                      child: Text('周${'一二三四五六日'[d - 1]}'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FButton(
                onPress: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  ref
                      .read(habitRepositoryProvider)
                      .createHabit(
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
    required this.accentIndex,
    required this.checked,
    required this.onToggle,
    required this.onDelete,
  });

  final HabitItem habit;
  final int accentIndex;
  final bool checked;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(accentIndex);
    return AppCard(
      onTap: onToggle,
      child: Row(
        children: [
          SquircleBox(
            size: 42,
            radius: 13,
            gradient: AppTokens.accentGradient(accent),
            alignment: Alignment.center,
            child: Icon(
              FLucideIcons.calendarCheck,
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
                  habit.name,
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '频次 ${habit.freqType}${habit.reminderTimes.isEmpty ? '' : ' · 提醒 ${habit.reminderTimes.join('/')}'}',
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCheck(checked: checked, size: 28),
          const SizedBox(width: 4),
          FButton.icon(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.sm,
            onPress: onDelete,
            semanticsLabel: '删除',
            child: Icon(
              FLucideIcons.trash2,
              size: 18,
              color: t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
