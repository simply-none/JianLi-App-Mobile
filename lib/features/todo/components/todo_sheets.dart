// 待办模块底部抽屉集合（页面操作规范：弹窗一律使用底部抽屉 showFSheet + SheetSurface）
//
// 覆盖 PC 待办的全部交互：状态选择、标签多选+新建、父任务多选、自定义日期时间选择、
// 记录进展（写入主题对话）、筛选条件、新增/编辑表单。所有抽屉统一走 _sheetScaffold
// （顶部标题+关闭、中部滚动、底部按钮），高度按内容自适应（高表单 0.92vh）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../conversation/repositories/conversation_repository.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import '../providers/todo_providers.dart';

// ===================== 统一抽屉入口（键盘兼容） =====================
//
// ⚠️ 关键修复：forui 的 showFSheet 默认 mainAxisMaxRatio = 9/16。键盘弹起时，
// 路由可用高度变为「屏幕高 - 键盘高」，抽屉最大高度被压成剩余高度的 56% → 极小、看不到内容。
// 这里把 mainAxisMaxRatio 置空，改由 _sheetScaffold 的 maxRatio(0.9) 决定高度；配合
// resizeToAvoidBottomInset:true（默认），键盘弹起时整个抽屉抬到键盘上方，内容在
// SingleChildScrollView 内可滚动，不再被压扁。
Future<T?> _showTodoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool resizeToAvoidBottomInset = true,
}) =>
    showFSheet<T>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      builder: builder,
    );

// ===================== 通用抽屉骨架 =====================

Widget _sheetScaffold({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget>? bottomBar,
  double maxRatio = 0.9,
  bool keyboard = false,
}) {
  final t = context.theme;
  final h = MediaQuery.of(context).size.height * maxRatio;
  // 键盘抽屉改为「整张抬到键盘上方」（见 _showTodoSheet），无需在内部塞入
  // viewInsets.bottom 的额外底部留白（那会把内容高度再吃掉一截→压扁）。
  // 这里仅给表单类抽屉一点点底部呼吸距离。
  return SheetSurface(
    padding: keyboard ? const EdgeInsets.fromLTRB(16, 16, 16, 16) : null,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: t.typography.body.lg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(FLucideIcons.x, size: 18, color: t.colors.foreground),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: body,
            ),
          ),
          if (bottomBar != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(spacing: 10, children: bottomBar),
            ),
        ],
      ),
    ),
  );
}

/// 选择型 chip（左侧可带色点；选中态显示勾）
Widget _choiceChip(
  BuildContext context, {
  required String label,
  bool selected = false,
  Color? color,
  Widget? leading,
  VoidCallback? onTap,
}) {
  final t = context.theme;
  final c = color ?? t.colors.primary;
  return FTappable(
    onPress: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.14) : t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: selected ? c : t.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          if (selected) ...[
            Icon(FLucideIcons.check, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: t.typography.body.sm.copyWith(
              color: selected ? c : t.colors.foreground,
            ),
          ),
        ],
      ),
    ),
  );
}

// ===================== 1. 状态选择 =====================

Future<String?> showTodoStatusSheet(
  BuildContext context, {
  String? current,
}) async {
  return _showTodoSheet<String?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '状态',
      body: StatefulBuilder(
        builder: (c, setInner) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in kTodoStatusOptions)
                _choiceChip(
                  c,
                  label: opt.$2,
                  selected: current == opt.$1,
                  color: statusMeta(opt.$1).color,
                  onTap: () => Navigator.pop(c, opt.$1),
                ),
            ],
          );
        },
      ),
    ),
  );
}

// ===================== 2. 标签多选 + 新建 =====================

Future<List<String>?> showTodoTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<TodoTagView> tags,
  required List<String> selected,
}) async {
  final draft = List<String>.from(selected);
  final controller = TextEditingController();
  return _showTodoSheet<List<String>?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '标签',
      keyboard: true,
      body: StatefulBuilder(
        builder: (c, setInner) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FTextField(
                      control: FTextFieldControl.managed(controller: controller),
                      hint: '新建标签',
                      autofocus: false,
                      onSubmit: (_) async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        final tag = await ref
                            .read(todoRepositoryProvider)
                            .addTag(name);
                        if (!draft.contains(tag.key)) draft.add(tag.key);
                        controller.clear();
                        setInner(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton(
                    variant: FButtonVariant.outline,
                    onPress: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      final tag = await ref
                          .read(todoRepositoryProvider)
                          .addTag(name);
                      if (!draft.contains(tag.key)) draft.add(tag.key);
                      controller.clear();
                      setInner(() {});
                    },
                    child: const Icon(FLucideIcons.plus),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    _choiceChip(
                      c,
                      label: tag.name,
                      selected: draft.contains(tag.key),
                      color: _parseColor(tag.color),
                      onTap: () {
                        if (draft.contains(tag.key)) {
                          draft.remove(tag.key);
                        } else {
                          draft.add(tag.key);
                        }
                        setInner(() {});
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '完成',
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(c, draft),
          ),
        ),
      ],
    ),
  );
}

// ===================== 3. 父任务多选 =====================

/// 取某 key 的所有后代 key（避免父子环）
Set<String> _descendantKeys(List<TodoItem> all, String key) {
  final result = <String>{};
  final queue = [key];
  while (queue.isNotEmpty) {
    final cur = queue.removeLast();
    for (final it in all.where((t) => t.parentIds.contains(cur))) {
      if (result.add(it.key)) queue.add(it.key);
    }
  }
  return result;
}

Future<List<String>?> showTodoParentSheet(
  BuildContext context, {
  required List<TodoItem> candidates,
  required List<String> selected,
  String? excludeKey,
}) async {
  final draft = List<String>.from(selected);
  // 排除自身及其后代，避免循环父子
  final blocked = excludeKey == null
      ? <String>{}
      : {excludeKey, ..._descendantKeys(candidates, excludeKey)};
  final pool = candidates.where((t) => !blocked.contains(t.key)).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return _showTodoSheet<List<String>?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '父任务',
      body: StatefulBuilder(
        builder: (c, setInner) {
          if (pool.isEmpty) {
            return Text(
              '暂无可关联的父任务',
              style: c.theme.typography.body.sm
                  .copyWith(color: c.theme.colors.mutedForeground),
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final it in pool)
                _choiceChip(
                  c,
                  label: it.title,
                  selected: draft.contains(it.key),
                  onTap: () {
                    if (draft.contains(it.key)) {
                      draft.remove(it.key);
                    } else {
                      draft.add(it.key);
                    }
                    setInner(() {});
                  },
                ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '完成',
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(c, draft),
          ),
        ),
      ],
    ),
  );
}

// ===================== 4. 自定义日期时间选择 =====================

Future<DateTime?> showTodoDateTimeSheet(
  BuildContext context, {
  DateTime? initial,
  bool dateOnly = false,
}) async {
  // 状态需在 StatefulBuilder 之外持有，避免每次 rebuild 被重置
  var selected = initial;
  var display = DateTime(
    (initial ?? DateTime.now()).year,
    (initial ?? DateTime.now()).month,
    1,
  );
  final weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

  return _showTodoSheet<DateTime?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: dateOnly ? '结束日期' : '日期与时间',
      body: StatefulBuilder(
        builder: (c, setInner) {
          Widget buildGrid() {
            final firstWeekday = display.weekday % 7; // 0=周日
            final daysInMonth =
                DateTime(display.year, display.month + 1, 0).day;
            final cells = <Widget>[];
            for (var i = 0; i < firstWeekday; i++) {
              cells.add(const SizedBox.shrink());
            }
            for (var d = 1; d <= daysInMonth; d++) {
              final day = DateTime(display.year, display.month, d);
              final sel = selected != null &&
                  selected!.year == day.year &&
                  selected!.month == day.month &&
                  selected!.day == day.day;
              cells.add(
                FTappable(
                  onPress: () => setInner(() => selected = day),
                  child: Container(
                    alignment: Alignment.center,
                    height: 38,
                    decoration: BoxDecoration(
                      color: sel
                          ? c.theme.colors.primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusSm),
                      border: sel
                          ? Border.all(color: c.theme.colors.primary)
                          : null,
                    ),
                    child: Text(
                      '$d',
                      style: c.theme.typography.body.sm.copyWith(
                        color: sel
                            ? c.theme.colors.primary
                            : c.theme.colors.foreground,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FTappable(
                      onPress: () => setInner(() => display = DateTime(
                          display.year, display.month - 1, 1)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(FLucideIcons.chevronLeft, size: 18),
                      ),
                    ),
                    Text(
                      '${display.year} 年 ${display.month} 月',
                      style: c.theme.typography.body.md
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    FTappable(
                      onPress: () => setInner(() => display = DateTime(
                          display.year, display.month + 1, 1)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(FLucideIcons.chevronRight, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final w in weekLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: c.theme.typography.body.xs.copyWith(
                              color: c.theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.05,
                  children: cells,
                ),
              ],
            );
          }

          Widget stepper(
            String label,
            int value,
            void Function(int) onChanged,
          ) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: c.theme.colors.muted,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Column(
                  children: [
                    Text(label,
                        style: c.theme.typography.body.xs
                            .copyWith(color: c.theme.colors.mutedForeground)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FTappable(
                          onPress: () => onChanged(value - 1),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(FLucideIcons.minus, size: 16),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$value',
                            textAlign: TextAlign.center,
                            style: c.theme.typography.body.lg
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FTappable(
                          onPress: () => onChanged(value + 1),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(FLucideIcons.plus, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final hour = selected?.hour ?? 9;
          final minute = selected?.minute ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildGrid(),
              if (!dateOnly) ...[
                const SizedBox(height: 14),
                Row(
                  spacing: 12,
                  children: [
                    stepper('时', hour, (v) {
                      final nv = (v % 24 + 24) % 24;
                      setInner(() => selected = DateTime(
                          selected?.year ?? DateTime.now().year,
                          selected?.month ?? DateTime.now().month,
                          selected?.day ?? DateTime.now().day,
                          nv,
                          minute));
                    }),
                    stepper('分', minute, (v) {
                      final nv = (v % 60 + 60) % 60;
                      setInner(() => selected = DateTime(
                          selected?.year ?? DateTime.now().year,
                          selected?.month ?? DateTime.now().month,
                          selected?.day ?? DateTime.now().day,
                          hour,
                          nv));
                    }),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (initial != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: FTappable(
                    onPress: () => Navigator.pop(c, null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '清除',
                        style: c.theme.typography.body.sm.copyWith(
                          color: c.theme.colors.destructive,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '确定',
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(c, selected),
          ),
        ),
      ],
    ),
  );
}

// ===================== 5. 记录进展（写入主题对话） =====================

Future<void> showRecordProgressSheet(
  BuildContext context,
  WidgetRef ref,
  TodoItem item,
) async {
  final controller = TextEditingController();
  return _showTodoSheet<void>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '记录进展',
      keyboard: true,
      body: StatefulBuilder(
        builder: (c, setInner) {
          final t = c.theme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '主题：${item.title}',
                style: t.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '将作为一条对话写入该主题，便于日后回看进展',
                style: t.typography.body.sm
                    .copyWith(color: t.colors.mutedForeground),
              ),
              const SizedBox(height: 12),
              FTextField(
                control: FTextFieldControl.managed(controller: controller),
                hint: '本次进展…',
                minLines: 3,
                maxLines: 6,
                autofocus: true,
              ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: () async {
              final content = controller.text.trim();
              if (content.isEmpty) {
                showFToast(
                  context: c,
                  variant: FToastVariant.destructive,
                  title: const Text('进展内容不能为空'),
                );
                return;
              }
              final themeId = await ref
                  .read(conversationRepositoryProvider)
                  .findOrCreateThemeByTitle(item.title);
              await ref
                  .read(conversationRepositoryProvider)
                  .addMessage(themeId: themeId, content: content);
              if (c.mounted) {
                showFToast(
                  context: c,
                  title: const Text('已记录到主题对话'),
                );
                Navigator.pop(c);
              }
            },
          ),
        ),
      ],
    ),
  );
}

// ===================== 6. 筛选条件 =====================

Future<TodoFilterState?> showTodoFilterSheet(
  BuildContext context, {
  required TodoFilterState current,
  required List<TodoTagView> tags,
}) async {
  // TodoFilterState 字段为 final，草稿用本地可变变量承载，确认时再构造新状态
  var draftPriority = current.priority;
  var draftStatus = current.status;
  final draftTags = {...current.tagKeys};
  var draftShowCompleted = current.showCompleted;
  var draftShowTemplates = current.showTemplates;
  var draftGroup = current.groupBy;
  return _showTodoSheet<TodoFilterState?>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setInner) {
        final t = c.theme;
        Widget section(String title, List<Widget> chips) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                  const SizedBox(height: 16),
                ],
              );

          final groupLabels = {
            TodoGroupBy.none: '无',
            TodoGroupBy.status: '按状态',
            TodoGroupBy.due: '按到期',
            TodoGroupBy.parent: '按父任务',
          };

          return _sheetScaffold(
            context: c,
            title: '筛选',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section(
                  '优先级',
                [
                  _choiceChip(c, label: '全部', selected: draftPriority == null,
                      onTap: () => setInner(() => draftPriority = null)),
                  for (final p in kTodoPriorityOptions)
                    _choiceChip(
                      c,
                      label: p.$2,
                      selected: draftPriority == p.$1,
                      color: priorityColor(p.$1),
                      onTap: () => setInner(() => draftPriority = p.$1),
                    ),
                ],
              ),
              section(
                '状态',
                [
                  _choiceChip(c, label: '全部', selected: draftStatus == null,
                      onTap: () => setInner(() => draftStatus = null)),
                  for (final s in kTodoStatusOptions)
                    _choiceChip(
                      c,
                      label: s.$2,
                      selected: draftStatus == s.$1,
                      color: statusMeta(s.$1).color,
                      onTap: () => setInner(() => draftStatus = s.$1),
                    ),
                ],
              ),
              if (tags.isNotEmpty)
                section(
                  '标签（任一命中）',
                  [
                    for (final tag in tags)
                      _choiceChip(
                        c,
                        label: tag.name,
                        selected: draftTags.contains(tag.key),
                        color: _parseColor(tag.color),
                        onTap: () => setInner(() {
                          if (draftTags.contains(tag.key)) {
                            draftTags.remove(tag.key);
                          } else {
                            draftTags.add(tag.key);
                          }
                        }),
                      ),
                  ],
                ),
              section(
                '显示',
                [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('显示已完成'),
                      FSwitch(
                        value: draftShowCompleted,
                        onChange: (v) =>
                            setInner(() => draftShowCompleted = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('显示重复模板'),
                      FSwitch(
                        value: draftShowTemplates,
                        onChange: (v) =>
                            setInner(() => draftShowTemplates = v),
                      ),
                    ],
                  ),
                ],
              ),
              section(
                '分组方式',
                [
                  for (final g in TodoGroupBy.values)
                    _choiceChip(
                      c,
                      label: groupLabels[g]!,
                      selected: draftGroup == g,
                      onTap: () => setInner(() => draftGroup = g),
                    ),
                ],
              ),
            ],
          ),
          bottomBar: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.outline,
                onPress: () => setInner(() {
                  draftPriority = null;
                  draftStatus = null;
                  draftTags.clear();
                  draftShowCompleted = true;
                  draftShowTemplates = false;
                  draftGroup = TodoGroupBy.none;
                }),
                child: const Text('重置'),
              ),
            ),
            Expanded(
              child: GradientButton(
                label: '应用',
                icon: FLucideIcons.check,
                onPress: () => Navigator.pop(
                  c,
                  TodoFilterState(
                    search: current.search,
                    priority: draftPriority,
                    status: draftStatus,
                    tagKeys: draftTags,
                    showCompleted: draftShowCompleted,
                    showTemplates: draftShowTemplates,
                    groupBy: draftGroup,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ===================== 7. 新增 / 编辑表单 =====================

class _TodoEditSheet extends StatefulWidget {
  const _TodoEditSheet({
    required this.initial,
    required this.allTodos,
    required this.tags,
    required this.ref,
  });

  final TodoItem initial;
  final List<TodoItem> allTodos;
  final List<TodoTagView> tags;
  final WidgetRef ref;

  @override
  State<_TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<_TodoEditSheet> {
  late final TextEditingController _titleC;
  late final TextEditingController _descC;
  late final TextEditingController _intervalC;
  late String _priority;
  late String _status;
  DateTime? _dueDate;
  bool _reminderOn = false;
  int _remindCount = 1;
  int _remindInterval = 30;
  String _remindUnit = 'minute';
  bool _recurrenceOn = false;
  String _recurrenceRule = 'daily';
  int _recurrenceInterval = 1;
  List<int> _weekdays = const [1];
  DateTime? _recurrenceEnd;
  late List<String> _parentKeys;
  late List<String> _tagKeys;

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    _titleC = TextEditingController(text: it.title == '（无标题）' ? '' : it.title);
    _descC = TextEditingController(text: it.description);
    _intervalC = TextEditingController(text: '${it.recurrenceInterval}');
    _priority = it.priority;
    _status = it.status ?? (it.completed ? 'completed' : 'not_started');
    _dueDate = parseTodoDateTime(it.dueDate);
    _reminderOn = it.deadlineReminder == 1;
    _remindCount = it.remindCount;
    _remindInterval = it.remindInterval;
    _remindUnit = it.remindIntervalUnit;
    _recurrenceOn = it.isTemplate;
    _recurrenceRule = it.recurrenceRule ?? 'daily';
    _recurrenceInterval = it.recurrenceInterval;
    _weekdays = List<int>.from(it.recurrenceWeekdays);
    _recurrenceEnd = parseTodoDateTime(it.recurrenceEnd);
    _parentKeys = List<String>.from(it.parentIds);
    _tagKeys = List<String>.from(it.tags);
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _intervalC.dispose();
    super.dispose();
  }

  void _setState(void Function() fn) => setState(fn);

  /// 周期实例不允许编辑重复规则（build 与 _save 共用）
  bool get allowRecurrence => widget.initial.isRecurrenceInstance != 1;

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: context.theme.typography.body.sm
              .copyWith(color: context.theme.colors.mutedForeground),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.theme;

    return _sheetScaffold(
      context: context,
      title: widget.initial.createTime == null ? '新增待办' : '编辑待办',
      keyboard: true,
      maxRatio: 0.94,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleC,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '标题',
              border: InputBorder.none,
              hintStyle: t.typography.body.lg
                  .copyWith(color: t.colors.mutedForeground),
            ),
            style: t.typography.body.lg
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          FTextField(
            control: FTextFieldControl.managed(controller: _descC),
            hint: '描述（可选）',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          // 优先级
          _fieldLabel('优先级'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kTodoPriorityOptions)
                _choiceChip(
                  context,
                  label: p.$2,
                  selected: _priority == p.$1,
                  color: priorityColor(p.$1),
                  onTap: () => _setState(() => _priority = p.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 状态
          _fieldLabel('状态'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in kTodoStatusOptions)
                _choiceChip(
                  context,
                  label: s.$2,
                  selected: _status == s.$1,
                  color: statusMeta(s.$1).color,
                  onTap: () => _setState(() => _status = s.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 到期时间
          _fieldLabel('到期时间'),
          FTappable(
            onPress: () async {
              final d = await showTodoDateTimeSheet(
                context,
                initial: _dueDate,
              );
              if (mounted) _setState(() => _dueDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Icon(FLucideIcons.calendar, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? '未设置'
                          : _formatDateTime(_dueDate!),
                      style: t.typography.body.md,
                    ),
                  ),
                  if (_dueDate != null)
                    GestureDetector(
                      onTap: () => _setState(() => _dueDate = null),
                      child: Icon(FLucideIcons.x, size: 16, color: t.colors.mutedForeground),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 截止提醒
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(FLucideIcons.bell, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 8),
                  const Text('截止提醒'),
                ],
              ),
              FSwitch(
                value: _reminderOn,
                onChange: (v) => _setState(() => _reminderOn = v),
              ),
            ],
          ),
          if (_reminderOn) ...[
            const SizedBox(height: 10),
            Text('提前 $_remindCount 次 · 间隔 $_remindInterval ${_remindUnit == 'hour' ? '小时' : '分钟'}（移动端于截止时刻提醒一次）',
                style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground)),
          ],
          const SizedBox(height: 16),
          // 重复
          if (allowRecurrence) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(FLucideIcons.repeat, size: 18, color: t.colors.mutedForeground),
                    const SizedBox(width: 8),
                    const Text('重复'),
                  ],
                ),
                FSwitch(
                  value: _recurrenceOn,
                  onChange: (v) => _setState(() => _recurrenceOn = v),
                ),
              ],
            ),
            if (_recurrenceOn) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choiceChip(context, label: '每天', selected: _recurrenceRule == 'daily',
                      onTap: () => _setState(() => _recurrenceRule = 'daily')),
                  _choiceChip(context, label: '每周', selected: _recurrenceRule == 'weekly',
                      onTap: () => _setState(() => _recurrenceRule = 'weekly')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('每'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: FTextField(
                      control: FTextFieldControl.managed(
                        controller: _intervalC,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmit: (v) => _setState(() {
                        _recurrenceInterval = int.tryParse(v) ?? 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_recurrenceRule == 'weekly' ? '周' : '天'),
                ],
              ),
              if (_recurrenceRule == 'weekly') ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var w = 0; w < 7; w++)
                      _choiceChip(
                        context,
                        label: ['日', '一', '二', '三', '四', '五', '六'][w],
                        selected: _weekdays.contains(w),
                        onTap: () => _setState(() {
                          if (_weekdays.contains(w)) {
                            _weekdays.remove(w);
                          } else {
                            _weekdays.add(w);
                          }
                          if (_weekdays.isEmpty) _weekdays = [w];
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              FTappable(
                onPress: () async {
                  final d = await showTodoDateTimeSheet(
                    context,
                    initial: _recurrenceEnd,
                    dateOnly: true,
                  );
                  if (mounted) _setState(() => _recurrenceEnd = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.colors.muted,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: t.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(FLucideIcons.calendar, size: 18, color: t.colors.mutedForeground),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _recurrenceEnd == null ? '结束日期（可选）' : _fmtDate(_recurrenceEnd!),
                          style: t.typography.body.md,
                        ),
                      ),
                      if (_recurrenceEnd != null)
                        GestureDetector(
                          onTap: () => _setState(() => _recurrenceEnd = null),
                          child: Icon(FLucideIcons.x, size: 16, color: t.colors.mutedForeground),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          // 父任务
          _fieldLabel('父任务'),
          FTappable(
            onPress: () async {
              final res = await showTodoParentSheet(
                context,
                candidates: widget.allTodos,
                selected: _parentKeys,
                excludeKey: widget.initial.key,
              );
              if (res != null && mounted) _setState(() => _parentKeys = res);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Icon(FLucideIcons.userPlus, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _parentKeys.isEmpty
                        ? Text('选择父任务（可选）', style: t.typography.body.md)
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _parentKeys
                                .map((k) => Chip(
                                      label: Text(
                                        widget.allTodos
                                                .firstWhere((e) => e.key == k,
                                                    orElse: () => widget.initial)
                                                .title,
                                        style: t.typography.body.xs,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 标签
          _fieldLabel('标签'),
          FTappable(
            onPress: () async {
              final res = await showTodoTagSheet(
                context,
                widget.ref,
                tags: widget.tags,
                selected: _tagKeys,
              );
              if (res != null && mounted) _setState(() => _tagKeys = res);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Icon(FLucideIcons.tag, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tagKeys.isEmpty
                        ? Text('选择标签（可选）', style: t.typography.body.md)
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _tagKeys
                                .map((k) {
                                  final tag = widget.tags
                                      .firstWhere((e) => e.key == k,
                                          orElse: () => const TodoTagView(
                                              key: '', name: '?', color: '#888888'));
                                  return Chip(
                                    label: Text(tag.name,
                                        style: t.typography.body.xs),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  );
                                })
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: () => _save(),
          ),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('标题不能为空'),
      );
      return;
    }
    final now = _now();
    final completed = _status == 'completed';
    final item = TodoItem(
      key: widget.initial.key,
      title: title,
      description: _descC.text.trim(),
      completed: completed,
      priority: _priority,
      dueDate: _dueDate == null ? null : _formatDateTime(_dueDate!),
      completedTime: completed
          ? (widget.initial.completed ? widget.initial.completedTime ?? now : now)
          : null,
      tags: _tagKeys,
      status: _status,
      deadlineReminder: _reminderOn ? 1 : 0,
      remindCount: _remindCount,
      remindInterval: _remindInterval,
      remindIntervalUnit: _remindUnit,
      createTime: widget.initial.createTime ?? now,
      updateTime: now,
      sortOrder: widget.initial.sortOrder,
      parentIds: _parentKeys,
      recurrenceRule: (_recurrenceOn && allowRecurrence) ? _recurrenceRule : null,
      recurrenceInterval: _recurrenceInterval,
      recurrenceWeekdays: (_recurrenceOn && _recurrenceRule == 'weekly')
          ? _weekdays
          : const [],
      recurrenceEnd: _recurrenceEnd == null ? null : _fmtDate(_recurrenceEnd!),
      recurrenceId: widget.initial.recurrenceId,
      isRecurrenceInstance: widget.initial.isRecurrenceInstance,
    );
    Navigator.pop(context, item);
  }

  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 打开新增/编辑抽屉，返回保存后的 TodoItem（取消返回 null）
Future<TodoItem?> showTodoEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required TodoItem initial,
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) {
  return _showTodoSheet<TodoItem?>(
    context: context,
    builder: (c) => _TodoEditSheet(
      initial: initial,
      allTodos: allTodos,
      tags: tags,
      ref: ref,
    ),
  );
}

// ===================== 8. 操作菜单 + 删除确认 =====================

/// 单条待办的操作项
enum TodoAction { edit, record, delete }

/// 操作菜单（底部抽屉）：编辑 / 记录进展 / 删除
Future<void> showTodoActionSheet(
  BuildContext context,
  WidgetRef ref,
  TodoItem item, {
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) async {
  final action = await _showTodoSheet<TodoAction?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '操作',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionRow(
            c,
            label: '编辑',
            icon: FLucideIcons.pencil,
            onTap: () => Navigator.pop(c, TodoAction.edit),
          ),
          _actionRow(
            c,
            label: '记录进展',
            icon: FLucideIcons.bell,
            onTap: () => Navigator.pop(c, TodoAction.record),
          ),
          _actionRow(
            c,
            label: '删除',
            icon: FLucideIcons.trash2,
            destructive: true,
            onTap: () => Navigator.pop(c, TodoAction.delete),
          ),
        ],
      ),
    ),
  );
  if (action == null) return;
  final repo = ref.read(todoRepositoryProvider);
  if (!context.mounted) return;
  switch (action) {
    case TodoAction.edit:
      if (!context.mounted) return;
      final edited = await showTodoEditSheet(
        context,
        ref,
        initial: item,
        allTodos: allTodos,
        tags: tags,
      );
      if (edited != null) await repo.upsertTodo(edited);
    case TodoAction.record:
      if (!context.mounted) return;
      await showRecordProgressSheet(context, ref, item);
    case TodoAction.delete:
      if (!context.mounted) return;
      final ok = await showTodoConfirmSheet(
        context,
        '删除待办',
        '确定删除「${item.title}」及其全部子任务？',
      );
      if (ok == true) await repo.deleteTodo(item.key);
  }
}

Widget _actionRow(
  BuildContext context, {
  required String label,
  required IconData icon,
  bool destructive = false,
  required VoidCallback onTap,
}) {
  final t = context.theme;
  final color = destructive ? t.colors.destructive : t.colors.foreground;
  return FTappable(
    onPress: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 14),
          Text(label, style: t.typography.body.md.copyWith(color: color)),
        ],
      ),
    ),
  );
}

/// 通用删除/危险确认（底部抽屉，取消/关闭返回 false 或 null，确认返回 true）
Future<bool?> showTodoConfirmSheet(
  BuildContext context,
  String title,
  String message,
) async {
  return _showTodoSheet<bool>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: title,
      body: Text(
        message,
        style: c.theme.typography.body.md,
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: FButton(
            variant: FButtonVariant.destructive,
            onPress: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ),
      ],
    ),
  );
}

// ===================== 工具 =====================

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF8b5cf6);
  try {
    return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) |
        (hex.length == 7 ? 0xFF000000 : 0));
  } catch (_) {
    return const Color(0xFF8b5cf6);
  }
}
