// 待办月历视图（对齐 PC 日历视图）—— 按 dueDate 把待办聚到对应日期格，点日期查看当天待办
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import '../providers/todo_providers.dart';
import 'todo_sheets.dart';

/// 月历视图
class TodoCalendarView extends StatelessWidget {
  const TodoCalendarView({
    super.key,
    required this.items,
    required this.onPickDay,
  });

  final List<TodoItem> items;
  final void Function(DateTime day, List<TodoItem> dayItems) onPickDay;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final weekLabels = ['日', '一', '二', '三', '四', '五', '六'];
    // 聚合：yyyy-MM-dd -> 待办
    final byDay = <String, List<TodoItem>>{};
    for (final it in items) {
      final d = parseTodoDateTime(it.dueDate);
      if (d == null) continue;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      (byDay[key] ??= []).add(it);
    }

    final now = DateTime.now();
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(now.year, now.month, d);
      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final dayItems = byDay[key] ?? [];
      final isToday = d == now.day;
      cells.add(
        FTappable(
          onPress: () => onPickDay(day, dayItems),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isToday ? t.colors.primary.withValues(alpha: 0.12) : t.colors.muted,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: isToday ? Border.all(color: t.colors.primary) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: t.typography.body.sm.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isToday ? t.colors.primary : t.colors.foreground,
                  ),
                ),
                if (dayItems.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final it in dayItems.take(3))
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: statusMeta(effectiveStatus(it)).color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (dayItems.length > 3)
                        Text('+${dayItems.length - 3}',
                            style: t.typography.body.xs
                                .copyWith(color: t.colors.mutedForeground)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppTokens.pageTint(context),
      child: ListView(
        padding: EdgeInsets.only(
          top: AppTokens.listTopGapOf(context),
          bottom: AppTokens.pageBottomGapOf(context),
          left: AppTokens.pagePaddingOf(context),
          right: AppTokens.pagePaddingOf(context),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.colors.card,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            ),
            child: Column(
              children: [
                Text(
                  '${now.year} 年 ${now.month} 月',
                  style: t.typography.body.lg.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final w in weekLabels)
                      Expanded(
                        child: Center(
                          child: Text(w,
                              style: t.typography.body.xs
                                  .copyWith(color: t.colors.mutedForeground)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.15,
                  children: cells,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 点日期后的当天待办抽屉（底部抽屉）
Future<void> showTodoDaySheet(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
  List<TodoItem> dayItems, {
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) async {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    builder: (c) {
      final t = c.theme;
      final label =
          '${day.month} 月 ${day.day} 日 · 共 ${dayItems.length} 项';
      return SheetSurface(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(c).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: t.typography.body.lg
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(c),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(FLucideIcons.x, size: 18, color: t.colors.foreground),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: dayItems.isEmpty
                    ? Center(
                        child: Text('当天没有待办',
                            style: t.typography.body.sm
                                .copyWith(color: t.colors.mutedForeground)),
                      )
                    : ListView.separated(
                        itemBuilder: (cx, i) {
                          final it = dayItems[i];
                          final meta = statusMeta(effectiveStatus(it));
                          return FTappable(
                            onPress: () async {
                              Navigator.pop(c);
                              final edited = await showTodoEditSheet(
                                context,
                                ref,
                                initial: it,
                                allTodos: allTodos,
                                tags: tags,
                              );
                              if (edited != null) {
                                await ref
                                    .read(todoRepositoryProvider)
                                    .upsertTodo(edited);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: t.colors.muted,
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusMd),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: meta.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(it.title,
                                        style: t.typography.body.md),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemCount: dayItems.length,
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
