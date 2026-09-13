// 习惯打卡页（forui 化）—— 今日待打卡列表 + 点击打卡 + 近 7 天记录条
//
// 交互：点右侧打卡圆点切换打卡；点卡片其他区域查看详情；底部 7 格小圆点展示近 7 天记录（今天在最右）。
// 结构对齐待办页：自绘头部（_header，18/Bold 标题 + 退回/导出/新建图标）+ 统计横幅
// + 吸顶搜索行（红线 #13：锚点＝搜索框，横幅随滚动移出）+ 卡片列表；
// 弹层走 _habitSheetPanel（卡色底 + r24 顶圆角 + 顶部把手 + sheetTitleStyle 标题 + _sheetButton 按钮），
// 与 todo_sheets 的 _sheetPanel 同源；取色/字体全部走 forui token。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/animated_check.dart';
import '../../../app/ui/datetime_pickers.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../todo/components/todo_chips.dart';
import '../models/habit.dart';
import '../providers/habit_providers.dart';
import 'habit_export_sheet.dart';

/// 习惯打卡页
class HabitPage extends ConsumerStatefulWidget {
  const HabitPage({super.key});

  @override
  ConsumerState<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends ConsumerState<HabitPage> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitListProvider);
    final checkedAsync = ref.watch(todayCheckedProvider);

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        // 全局渐变背板由 app.dart 根容器绘制，页面保持透明以透出背板
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: habitsAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败：$e',
                      style: context.theme.typography.body.sm
                          .copyWith(color: context.theme.colors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (habits) => checkedAsync.when(
                    loading: () => const Center(child: FCircularProgress()),
                    error: (e, _) => Center(
                      child: Text(
                        '加载失败：$e',
                        style: context.theme.typography.body.sm
                            .copyWith(color: context.theme.colors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    data: (checked) =>
                        _habitList(context, ref, habits, checked),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部（对齐待办页头部设计：左右 16 / 上下 12 / 间距 10；标题 18/Bold）
  Widget _header(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: () => context.pop(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
          Expanded(
            child: Text(
              '习惯打卡',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: () => showHabitExportSheet(context),
            child: Icon(
              FLucideIcons.download,
              size: 18,
              color: t.colors.foreground,
            ),
          ),
          TapScale(
            onTap: () => _showCreateSheet(context, ref),
            child: Icon(
              FLucideIcons.plus,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  /// 列表主体（统计横幅 + 吸顶搜索行 + 习惯卡片）
  Widget _habitList(
    BuildContext context,
    WidgetRef ref,
    List<HabitItem> habits,
    Set<String> checked,
  ) {
    if (habits.isEmpty) {
      return const EmptyState(
        icon: FLucideIcons.calendarCheck,
        title: '暂无启用的习惯',
        subtitle: '点右上角新建，或等桌面端同步',
      );
    }
    final filtered = _filterHabits(habits);
    // 卡片色盘按「全部习惯」中的位置取 → 筛选时同一习惯颜色不跳
    final orderByKey = {
      for (var i = 0; i < habits.length; i++) habits[i].key: i,
    };
    return CustomScrollView(
      slivers: [
        // 头部横幅（随滚动移出）
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.pagePadding,
            ),
            // 头部横幅：与待办统计横幅同构（主题紫渐变 + 纹理 + 同心环装饰）
            child: PageBanner(
              icon: FLucideIcons.calendarCheck,
              title: '习惯打卡',
              subtitle: '每天进步一点点，坚持带来大改变',
              gradient: AppTokens.accentGradient(AppTokens.accent(2)),
              ringDecor: true,
              shadow: false,
              // 横向内距由外层 Padding 提供，此处置零避免双 padding 变窄
              margin: EdgeInsets.zero,
              stats: [
                ('${habits.length}', '启用习惯'),
                ('${checked.length}', '今日已完成'),
              ],
            ),
          ),
        ),
        // ★吸顶锚点：搜索行常驻视口顶部（横幅随滚动移出，红线 #13）
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索习惯…',
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: FLucideIcons.searchX,
              title: '没有匹配的习惯',
              subtitle: '换个关键词试试',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              AppTokens.listTopGapOf(context),
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                StaggerList(
                  children: [
                    for (final habit in filtered)
                      _HabitCard(
                        habit: habit,
                        accentIndex: orderByKey[habit.key] ?? 0,
                        checked: checked.contains(habit.key),
                        onToggle: () async {
                          await ref
                              .read(habitRepositoryProvider)
                              .toggleCheckin(habit.key, DateTime.now());
                        },
                        onTapDetails: () =>
                            _showDetailSheet(context, ref, habit),
                        onLongPress: () =>
                            _showActionMenu(context, ref, habit),
                      ),
                  ],
                ),
              ]),
            ),
          ),
      ],
    );
  }

  /// 关键词过滤：名称 / 频次 / 提醒时间（习惯无分类标签，仅关键词匹配）
  List<HabitItem> _filterHabits(List<HabitItem> habits) {
    final kw = _keyword.trim().toLowerCase();
    if (kw.isEmpty) return habits;
    return habits.where((h) {
      final hay = '${h.name} ${h.freqLabel} ${h.reminderTimes.join(' ')}'
          .toLowerCase();
      return hay.contains(kw);
    }).toList();
  }

  /// 新建习惯弹层（名称 / 提醒时刻 / 生效星期）
  /// 对齐待办弹层规范：_sheetPanel（卡色底 + r24 顶圆角 + 把手 + pagePadding 内距 + 滚动）
  /// + sheetTitleStyle 标题 + _pill 选择 chip + _sheetButton 底部按钮。
  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    // 提醒时刻：与提醒管理同款「选择时刻」抽屉（showTimePickerSheet）；
    // 默认 08:00，null 表示「不提醒」（行尾「清除」入口）。
    TimeOfDay? timeValue = const TimeOfDay(hour: 8, minute: 0);
    final weekDays = <int>{};
    final t = context.theme;

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 固定 80vh（不随键盘收缩）：mainAxisMaxRatio 设为 lg=0.80，
      // 且 resizeToAvoidBottomInset=false 让键盘覆盖而非挤压抽屉（设计规范 2026-09-12）。
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _habitSheetPanel(
          context,
          gap: 12,
          children: [
            _sheetHandle(context),
            // 标题行：左「新建习惯」+ 右关闭按钮（点 X 关闭弹窗）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('新建习惯', style: sheetTitleStyle(context)),
                FTappable(
                  onPress: () => Navigator.pop(context),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      FLucideIcons.x,
                      size: 18,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            // 习惯名称：label + 输入框共用一个 Column，内部间距 6，避免外层 Column spacing 把 label 和框撑开。
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(
                  '习惯名称',
                  style: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: t.colors.mutedForeground,
                    ),
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.colors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          type: MaterialType.transparency,
                          child: TextField(
                            controller: nameController,
                            style: t.typography.body.sm.copyWith(
                              fontSize: 14,
                              color: t.colors.foreground,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: '输入习惯名称',
                              hintStyle: t.typography.body.sm.copyWith(
                                fontSize: 14,
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 提醒时刻：label 行 + 时间选择器共用一个 Column，内部间距 6。
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '提醒时刻',
                      style: t.typography.body.sm.copyWith(
                          fontSize: 14,
                          color: t.colors.mutedForeground,
                        ),
                    ),
                    Text(
                      '留空不提醒',
                      style: t.typography.body.sm.copyWith(
                        fontSize: 12,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                FTappable(
                  onPress: () async {
                    final picked = await showTimePickerSheet(
                      context,
                      initial: timeValue,
                      title: '选择提醒时刻',
                    );
                    if (picked != null) setSheetState(() => timeValue = picked);
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: t.colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FLucideIcons.clock,
                          size: 15,
                          color: AppTokens.accent(2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            timeValue == null
                                ? '不提醒'
                                : '${timeValue!.hour.toString().padLeft(2, '0')}:${timeValue!.minute.toString().padLeft(2, '0')}',
                            style: t.typography.body.sm.copyWith(
                              fontSize: 14,
                              color: timeValue == null
                                  ? t.colors.mutedForeground
                                  : t.colors.foreground,
                            ),
                          ),
                        ),
                        if (timeValue != null)
                          GestureDetector(
                            onTap: () =>
                                setSheetState(() => timeValue = null),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                FLucideIcons.x,
                                size: 14,
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          )
                        else
                          Icon(
                            FLucideIcons.chevronDown,
                            size: 16,
                            color: t.colors.mutedForeground,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 重复周期：label + 星期 chips 共用一个 Column，内部间距 10。
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  '重复周期',
                  style: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: t.colors.mutedForeground,
                    ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      _weekChip(
                        context,
                        label: '周${'一二三四五六日'[d - 1]}',
                        selected: weekDays.contains(d),
                        onTap: () => setSheetState(
                          () => weekDays.contains(d)
                              ? weekDays.remove(d)
                              : weekDays.add(d),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
          bottomBar: _sheetButton(
            context,
            label: '创建',
            bg: t.colors.primary,
            fg: t.colors.primaryForeground,
            onTap: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              // 'HH:mm' 与桌面端 reminderTimes 契约一致；null 即不提醒，传空串。
              final reminderTime = timeValue == null
                  ? ''
                  : '${timeValue!.hour.toString().padLeft(2, '0')}:${timeValue!.minute.toString().padLeft(2, '0')}';
              ref
                  .read(habitRepositoryProvider)
                  .createHabit(
                    name: name,
                    weekDays: weekDays.toList()..sort(),
                    reminderTime: reminderTime,
                  );
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  /// 习惯详情（只读）—— 点卡片非打卡区域时弹出：
  /// 展示频次 / 提醒 / 生效星期 + 近 7 天记录 + 删除。
  /// 对齐待办弹层规范：_sheetPanel + 把手 + sheetTitleStyle + _sheetButton。
  Future<void> _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    HabitItem habit,
  ) async {
    final pageContext = context; // 页面级 context：本弹窗关闭后仍可用于再开编辑弹窗
    final t = context.theme;
    final freqLabel = habit.freqLabel;
    final weekLabel = habit.weekDays.isEmpty
        ? '每天'
        : habit.weekDays
            .map((d) => '周${'一二三四五六日'[d - 1]}')
            .join('、');
    final remindLabel = habit.reminderTimes.isEmpty
        ? '无'
        : habit.reminderTimes.join('、');

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 固定 80vh（不随键盘收缩），同新建弹层：mainAxisMaxRatio=lg、resizeToAvoidBottomInset=false。
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (context) => Consumer(
        builder: (context, ref, _) => _habitSheetPanel(
          context,
          gap: 14,
          children: [
            _sheetHandle(context),
            Text(habit.name, style: sheetTitleStyle(context)),
            _DetailRow(label: '频次', value: freqLabel),
            _DetailRow(label: '提醒', value: remindLabel),
            _DetailRow(label: '生效星期', value: weekLabel),
            const SizedBox(height: 14),
            _WeekStrip(
              habit: habit,
              last7: ref.watch(last7CheckedProvider(habit.key)).value ??
                  List.filled(7, false),
              today: DateTime.now(),
            ),
            const SizedBox(height: 20),
          ],
          bottomBar: Row(
            children: [
              Expanded(
                child: _sheetButton(
                  context,
                  label: '编辑习惯',
                  bg: AppTokens.accent(2),
                  fg: t.colors.primaryForeground,
                  onTap: () {
                    Navigator.pop(context);
                    _showEditSheet(pageContext, ref, habit);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sheetButton(
                  context,
                  label: '删除习惯',
                  bg: t.colors.destructive,
                  fg: t.colors.primaryForeground,
                  onTap: () async {
                    final ok = await showSheetConfirm(
                      context,
                      title: '删除习惯',
                      message: '确定删除「${habit.name}」？打卡记录将一并清除，且不可恢复。',
                      confirmLabel: '删除',
                    );
                    if (ok && mounted) {
                      ref.read(habitRepositoryProvider).deleteHabit(habit);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 长按列表项 → 50vh 操作菜单（编辑 / 删除）
  Future<void> _showActionMenu(
    BuildContext context,
    WidgetRef ref,
    HabitItem habit,
  ) async {
    final action = await showSheetActionMenu<String>(
      context,
      title: habit.name,
      size: SheetSize.md,
      actions: const [
        SheetAction('edit', '编辑', icon: FLucideIcons.pencil),
        SheetAction('delete', '删除', icon: FLucideIcons.trash2, destructive: true),
      ],
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      await _showEditSheet(context, ref, habit);
    } else if (action == 'delete') {
      final ok = await showSheetConfirm(
        context,
        title: '删除习惯',
        message: '确定删除「${habit.name}」？打卡记录将一并清除，且不可恢复。',
        confirmLabel: '删除',
      );
      if (ok && context.mounted) {
        ref.read(habitRepositoryProvider).deleteHabit(habit);
      }
    }
  }

  /// 编辑习惯弹层（80vh）—— 与新建同构，预填当前值；保存调 updateHabit。
  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    HabitItem habit,
  ) async {
    final nameController = TextEditingController(text: habit.name);
    TimeOfDay? timeValue = habit.reminderTimes.isNotEmpty
        ? _parseHHmm(habit.reminderTimes.first)
        : null;
    final weekDays = <int>{...habit.weekDays};
    final t = context.theme;

    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 固定 80vh（不随键盘收缩）：与新建/详情弹层一致。
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _habitSheetPanel(
          context,
          gap: 12,
          children: [
            _sheetHandle(context),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('编辑习惯', style: sheetTitleStyle(context)),
                FTappable(
                  onPress: () => Navigator.pop(context),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      FLucideIcons.x,
                      size: 18,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            // 习惯名称
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(
                  '习惯名称',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.mutedForeground,
                  ),
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.colors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          type: MaterialType.transparency,
                          child: TextField(
                            controller: nameController,
                            style: t.typography.body.sm.copyWith(
                              fontSize: 14,
                              color: t.colors.foreground,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: '输入习惯名称',
                              hintStyle: t.typography.body.sm.copyWith(
                                fontSize: 14,
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 提醒时刻
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '提醒时刻',
                      style: t.typography.body.sm.copyWith(
                        fontSize: 14,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                    Text(
                      '留空不提醒',
                      style: t.typography.body.sm.copyWith(
                        fontSize: 12,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                FTappable(
                  onPress: () async {
                    final picked = await showTimePickerSheet(
                      context,
                      initial: timeValue,
                      title: '选择提醒时刻',
                    );
                    if (picked != null) setSheetState(() => timeValue = picked);
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: t.colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FLucideIcons.clock,
                          size: 15,
                          color: AppTokens.accent(2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            timeValue == null
                                ? '不提醒'
                                : '${timeValue!.hour.toString().padLeft(2, '0')}:${timeValue!.minute.toString().padLeft(2, '0')}',
                            style: t.typography.body.sm.copyWith(
                              fontSize: 14,
                              color: timeValue == null
                                  ? t.colors.mutedForeground
                                  : t.colors.foreground,
                            ),
                          ),
                        ),
                        if (timeValue != null)
                          GestureDetector(
                            onTap: () => setSheetState(() => timeValue = null),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                FLucideIcons.x,
                                size: 14,
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          )
                        else
                          Icon(
                            FLucideIcons.chevronDown,
                            size: 16,
                            color: t.colors.mutedForeground,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 重复周期
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  '重复周期',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    color: t.colors.mutedForeground,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      _weekChip(
                        context,
                        label: '周${'一二三四五六日'[d - 1]}',
                        selected: weekDays.contains(d),
                        onTap: () => setSheetState(
                          () => weekDays.contains(d)
                              ? weekDays.remove(d)
                              : weekDays.add(d),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
          bottomBar: _sheetButton(
            context,
            label: '保存',
            bg: t.colors.primary,
            fg: t.colors.primaryForeground,
            onTap: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final reminderTime = timeValue == null
                  ? ''
                  : '${timeValue!.hour.toString().padLeft(2, '0')}:${timeValue!.minute.toString().padLeft(2, '0')}';
              ref.read(habitRepositoryProvider).updateHabit(
                    habit: habit,
                    name: name,
                    weekDays: weekDays.toList()..sort(),
                    reminderTime: reminderTime,
                  );
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}

/// 单个习惯卡片 —— 对齐待办卡片设计语言：
/// 白底 + 1px 边框 + 阴影(level2) + 14 内距；标题 15/SemiBold；
/// 底部补「近 7 天记录条」+「今日状态 chip」（与待办共享 TodoStatusChip）。
/// 交互：点右侧打卡圆点 = 切换打卡；点卡片其余区域 = 查看详情（删除在详情弹层内）。
class _HabitCard extends ConsumerWidget {
  const _HabitCard({
    required this.habit,
    required this.accentIndex,
    required this.checked,
    required this.onToggle,
    required this.onTapDetails,
    this.onLongPress,
  });

  final HabitItem habit;
  final int accentIndex;
  final bool checked;
  final Future<void> Function() onToggle;
  final VoidCallback onTapDetails;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final today = DateTime.now();
    final scheduledToday = habit.isScheduledOn(today);
    final statusLabel =
        checked ? '已完成' : (scheduledToday ? '今日待打卡' : '休息日');
    final statusColor = checked
        ? const Color(0xFF22C55E)
        : (scheduledToday ? AppTokens.accent(2) : t.colors.mutedForeground);

    final last7 =
        ref.watch(last7CheckedProvider(habit.key)).value ??
        List.filled(7, false);

    return AppCard(
      elevation: 2,
      padding: const EdgeInsets.all(14),
      onTap: onTapDetails,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SquircleBox(
                size: 42,
                radius: 13,
                gradient: AppTokens.accentGradient(
                  AppTokens.accent(accentIndex),
                ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        color: checked
                            ? t.colors.mutedForeground
                            : t.colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '频次 ${habit.freqLabel}${habit.reminderTimes.isEmpty ? '' : ' · 提醒 ${habit.reminderTimes.join('/')}'}',
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧打卡圆点：点它才切换打卡（独立手势，不触发卡片详情）。
              // 卡片内不再放删除入口（2026-09-13 用户定），删除统一走详情弹层底栏。
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedCheck(checked: checked, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeekStrip(habit: habit, last7: last7, today: today),
          const SizedBox(height: 10),
          TodoStatusChip(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

/// 近 7 天打卡记录条（今天在最右）：
/// 实心=已打卡 / 空心(主色描边)=未打卡 / 灰=休息日(当天不排程)。
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.habit,
    required this.last7,
    required this.today,
  });

  final HabitItem habit;
  final List<bool> last7; // index 0 = 今天
  final DateTime today;

  static const List<String> _wd = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 今日打卡行的强调色 = 习惯域专属绿（2026-09-13 功能色定案）
    final primary = AppTokens.accent(2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (j) {
        final daysAgo = 6 - j; // j=6 → 今天（最右）
        final date = today.subtract(Duration(days: daysAgo));
        final idx = daysAgo; // last7 已按 0=今天 排列
        final scheduled = habit.isScheduledOn(date);
        final done = idx < last7.length && last7[idx];
        final isToday = daysAgo == 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheduled
                    ? (done ? primary : Colors.transparent)
                    : t.colors.border,
                border: scheduled && !done
                    ? Border.all(color: primary, width: 1.5)
                    : (scheduled
                        ? null
                        : Border.all(color: t.colors.border, width: 1)),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _wd[date.weekday - 1],
              style: t.typography.body.xs.copyWith(
                fontSize: 10,
                color: isToday ? primary : t.colors.mutedForeground,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// 详情弹层信息行（标签 + 值）
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: t.typography.body.sm.copyWith(
                  color: t.colors.mutedForeground,
                ),
            ),
          ),
          Expanded(child: Text(value, style: t.typography.body.sm)),
        ],
      ),
    );
  }
}

// ===================== 弹层共享件（对齐待办弹层设计规范） =====================
//
// 与 todo_sheets.dart 的 _sheetPanel / _sheetHandle / _pill / _sheetButton 同源：
// 卡色底 + r24 顶圆角 + 顶部把手 + pagePadding 内距 + 滚动 + sheetTitleStyle 标题 +
// _sheetButton 底部按钮。集中放此处是因为习惯模块是第二个消费这套规范的模块。

/// 解析 'HH:mm' → TimeOfDay；失败返回 null（视为不提醒）。供编辑弹窗预填提醒时刻。
TimeOfDay? _parseHHmm(String s) {
  final parts = s.split(':');
  final h = int.tryParse(parts[0]);
  final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// 顶部把手（画布 8:16 / 8:92：36×4 · r2 · 居中），底色走 [_stepUp]
///（t.colors.border 与卡底同系，直接用会淡到看不见）。
Widget _sheetHandle(BuildContext c) => Align(
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: _stepUp(c),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

/// 「抬升面再压一档」的灰（画布把手 / 描边这一档）。本主题 muted 与 border 收口成
/// 同一个 surfaceElevated，画布那级灰无从直取，按次字色叠一层派生（亮暗双向自适应）。
Color _stepUp(BuildContext c, {double alpha = 0.26}) => Color.alphaBlend(
      c.theme.colors.mutedForeground.withValues(alpha: alpha),
      c.theme.colors.muted,
    );

/// 弹层外壳（对齐 todo_sheets._sheetScaffold）：卡色底 + r24 顶圆角 + 全屏高 80% 定高
///（不扣键盘，键盘覆盖不折叠）+ pagePadding 内距；[children] 在中间滚动区，
/// [bottomBar] 固定在底部、不随内容滚动。子项间距由 [gap] 控制。
/// 新增/编辑/查看共用此壳，故三者统一 80% 全屏高（设计规范 2026-09-12）。
Widget _habitSheetPanel(
  BuildContext context, {
  required double gap,
  required List<Widget> children,
  Widget? bottomBar,
  SheetSize size = SheetSize.lg,
}) {
  final t = context.theme;
  // 新增/编辑/查看：80% 全屏高（不扣键盘），键盘覆盖时抽屉不重排、不折叠
  // （设计规范 2026-09-12：键盘开合不再收缩抽屉、影响输入体验）。
  final maxH = sheetMaxHeightFull(context, size);
  return SheetSurface(
    color: t.colors.card,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: ConstrainedBox(
      // 固定 80vh：内容少则底部留空，超出则滚动；不能 hug 内容，否则到不了 80%。
      constraints: BoxConstraints.tightFor(height: maxH),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: children,
                ),
              ),
            ),
            if (bottomBar != null) ...[
              const SizedBox(height: 12),
              bottomBar,
            ],
          ],
        ),
      ),
    ),
  );
}


/// 生效星期 chip（矩形 r10 · h34 · w44 · 11/SemiBold），对齐画布设计：
/// 选中 主色14%底 + 主色描边 + 主色字；未选 灰底 + 灰字。固定宽高保证 7 个一行排布。
Widget _weekChip(
  BuildContext c, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  final t = c.theme;
  final col = AppTokens.accent(2);
  return FTappable(
    onPress: onTap,
    child: Container(
      width: 44,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? col.withValues(alpha: 0.14) : t.colors.muted,
        border: Border.all(color: selected ? col : t.colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: t.typography.body.xs.copyWith(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? col : t.colors.mutedForeground,
        ),
      ),
    ),
  );
}

/// 底部按钮（h46 · r14 · 15/SemiBold），对齐 todo_sheets._sheetButton。
Widget _sheetButton(
  BuildContext c, {
  required String label,
  required Color bg,
  required Color fg,
  required VoidCallback onTap,
}) =>
    FTappable(
      onPress: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: c.theme.typography.body.sm.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
