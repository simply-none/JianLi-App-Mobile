// 提醒管理页（forui 化）—— 用户提醒列表（定点/周期/多状态）+ 启停开关
//
// 与桌面端 newTips 页对应；新增/编辑表单列 P2（优先保证引擎语义只读 + 启停联动通知）。
// forui 改造点：FScaffold+FHeader.nested 骨架、AppCard 列表行、FSwitch 启停、
// showFSheet 新建弹层（FTextField + FButton 周几选择）；提醒仓储调用原样保留。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import '../models/reminder_item.dart';
import '../providers/reminder_providers.dart';

/// 提醒管理页
class ReminderListPage extends ConsumerWidget {
  const ReminderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(reminderListProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('提醒管理'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        // 右上角「新建提醒」入口（替代原 FloatingActionButton）
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _showCreateSheet(context, ref),
            semanticsLabel: '新建提醒',
          ),
        ],
      ),
      child: remindersAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '加载失败：$e',
            style: context.theme.typography.body.sm
                .copyWith(color: context.theme.colors.error),
            textAlign: TextAlign.center,
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.bellOff,
              title: '暂无提醒',
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
                    for (final item in items) _ReminderTile(item: item),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 新建定点提醒（标题/内容/时刻/星期）
  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final content = TextEditingController();
    final time = TextEditingController(text: '09:00');
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
                control: FTextFieldControl.managed(controller: title),
                label: const Text('提醒标题'),
                hint: '输入提醒标题',
                autofocus: true,
              ),
              const SizedBox(height: 10),
              FTextField(
                control: FTextFieldControl.managed(controller: content),
                label: const Text('内容（可选）'),
                hint: '输入提醒内容',
              ),
              const SizedBox(height: 10),
              FTextField(
                control: FTextFieldControl.managed(controller: time),
                label: const Text('时刻（HH:mm）'),
                hint: '09:00',
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 14),
              FButton(
                onPress: () {
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
    final t = context.theme;
    final subtitleParts = <String>[
      item.modeLabel,
      if (!item.isStateful && (item.time?.isNotEmpty ?? false)) item.time!,
      if (item.isStateful && item.statesSummary != null) item.statesSummary!,
      if (item.idleTime != null && item.idleTime != '[]') '含免打扰',
    ];

    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(AppTokens.accent(3)),
            alignment: Alignment.center,
            child: Icon(
              item.isStateful ? FLucideIcons.refreshCw : FLucideIcons.alarmClock,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration:
                        item.enabled ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
                ),
              ],
            ),
          ),
          FSwitch(
            value: item.enabled,
            // 状态机型提醒不允许启停（权威在番茄钟页）
            enabled: !item.isStateful,
            onChange: (v) =>
                ref.read(reminderRepositoryProvider).toggleEnabled(item, v),
          ),
        ],
      ),
    );
  }
}
