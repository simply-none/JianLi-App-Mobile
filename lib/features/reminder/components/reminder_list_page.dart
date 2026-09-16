// 提醒管理页 —— 对齐待办列表页骨架（图1：主题色横幅统计 + 吸顶搜索行 + 分段 Tab + 列表）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部     ‹22 · 提醒18/Bold · ＋22（新建）
//   守护卡   提醒守护 N/4（点开 lg 抽屉：四项系统开关一键修复 + 后台保活开关 + 厂商保活路径引导）
//   统计横幅 PageBanner 主色渐变 · r22 · stats 全部/定点/周期/启用中
//   搜索行   ★吸顶锚点（PinnedSearchRow/PinnedSearchHeader），按标题/内容实时过滤
//   Tab 栏   ScopeTabBar：全部 / 定点 / 周期 / 多状态（按 mode 切范围，随滚动移出）
//   列表     待办卡片样式（r16 + 模式 SoftChip + 规则文案 + FSwitch 启停）
// 编辑弹层对齐图2：lg 定高（SheetScaffold 居中把手 + 17/Bold 标题 + 底部固定保存条），
// 字段组 = label(14/muted) 在上 + 输入框在下；送达方式选「闹钟」时惰性申请精确闹钟权限。
// 调度链路不动：saveReminder/toggleEnabled → reminder_repository（delivery=alarm=
// 精确闹钟+全屏+连响+贪睡；notification=普通系统通知）。stateful（番茄钟）仍只读展示。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/scope_tab_bar.dart';
import '../../../app/ui/datetime_pickers.dart';
import '../../todo/components/todo_sheets.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/reminder_item.dart';
import '../providers/reminder_providers.dart';
import '../repositories/reminder_repository.dart';
import 'reminder_guard_card.dart';

/// Tab 状态/模式范围
const List<(String, String)> kReminderTabs = [
  ('all', '全部'),
  ('time', '定点'),
  ('interval', '周期'),
  ('stateful', '多状态'),
];

/// 打开新建/编辑弹层（页面头部 ＋ / 条目点击 / 长按菜单**共用同一入口**，避免交互漂移）
Future<void> _openReminderEditor(BuildContext context, ReminderItem? initial) =>
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (context) => _ReminderEditor(initial: initial),
    );

/// 提醒管理页
class ReminderListPage extends ConsumerStatefulWidget {
  const ReminderListPage({super.key});

  @override
  ConsumerState<ReminderListPage> createState() => _ReminderListPageState();
}

class _ReminderListPageState extends ConsumerState<ReminderListPage> {
  /// 页内搜索关键词（实时过滤标题/内容）
  String _search = '';

  /// Tab 范围（mode）
  String _tab = 'all';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 进入页面：申请通知权限 + 重排程全部启用提醒（防止 awesome 原生计划被清理）
    NotificationService.requestPermission();
    ref.read(reminderRepositoryProvider).rescheduleAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final remindersAsync = ref.watch(reminderListProvider);

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: remindersAsync.when(
                  loading: () => const Center(child: FCircularProgress()),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败：$e',
                      textAlign: TextAlign.center,
                      style: t.typography.body.sm.copyWith(
                        color: t.colors.error,
                      ),
                    ),
                  ),
                  data: (items) => _body(context, items),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部（对齐待办：‹ / 标题 / ＋） =====================

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
              '提醒',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: () => _openReminderEditor(context, null),
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

  // ===================== 主体（图1 骨架） =====================

  Widget _body(BuildContext context, List<ReminderItem> items) {
    // 页内过滤：关键词（标题/内容）+ 模式 Tab（不动数据层）
    final keyword = _search.trim().toLowerCase();
    final scoped = [
      for (final item in items)
        if ((_tab == 'all' || item.mode == _tab) &&
            (keyword.isEmpty ||
                item.title.toLowerCase().contains(keyword) ||
                item.content.toLowerCase().contains(keyword)))
          item,
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(context, items)),
        SliverToBoxAdapter(child: ReminderGuardCard()),
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索提醒…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ScopeTabBar<String>(
            tabs: kReminderTabs,
            selected: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: FLucideIcons.bellOff,
              title: '暂无提醒',
              subtitle: '点右上角 ＋ 新建，到点弹系统通知或闹钟响铃',
            ),
          )
        else if (scoped.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: FLucideIcons.listFilter,
              title: '没有匹配的提醒',
              subtitle: '换个关键词，或切换上方模式 Tab',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              4,
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (final item in scoped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReminderTile(item: item),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（主色渐变，与待办同款）
  Widget _banner(BuildContext context, List<ReminderItem> items) => PageBanner(
    icon: FLucideIcons.bell,
    title: '提醒',
    subtitle: '定点 / 周期 / 多状态，一个都不少',
    gradient: AppTokens.accentGradient(AppTokens.accent(3)),
    cornerRadius: 22,
    ringDecor: true,
    shadow: false,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    stats: [
      ('${items.length}', '全部'),
      ('${items.where((e) => e.mode == 'time').length}', '定点'),
      ('${items.where((e) => e.mode == 'interval').length}', '周期'),
      ('${items.where((e) => e.enabled).length}', '启用中'),
    ],
  );

}

/// 单条提醒（待办 tile 同款：r16 卡 + 模式 SoftChip + 规则文案 + FSwitch 启停）
class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.item});

  final ReminderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final disabled = !item.enabled;

    // 模式语义色：定点=琥珀 / 周期=绿 / 多状态=红（番茄钟品牌色）；停用态整体转灰
    final modeColor = disabled
        ? t.colors.mutedForeground
        : item.isStateful
            ? AppTokens.accent(6)
            : item.mode == 'interval'
                ? AppTokens.accent(2)
                : AppTokens.accent(3);

    // 图标：多状态=计时器 / 周期=循环 / 定点=闹钟(送达为闹钟)或铃铛
    final iconData = item.isStateful
        ? FLucideIcons.timer
        : item.mode == 'interval'
            ? FLucideIcons.repeat
            : (item.isAlarm ? FLucideIcons.alarmClock : FLucideIcons.bell);

    final iconGradient = disabled
        ? AppTokens.accentGradient(t.colors.mutedForeground)
        : AppTokens.accentGradient(modeColor);

    // R2 规则摘要：状态机 / 间隔 / 重复 + 时刻 + 送达 + 免打扰时段（有则列）
    final idle = parseIdleSlots(item.idleTime);
    final intervalPart = (!item.isStateful &&
            item.mode == 'interval' &&
            item.interval?.isNotEmpty == true)
        ? '每 ${item.interval}${unitShortLabel(item.unit)}'
        : null;
    final subtitleParts = <String>[
      if (item.isStateful && item.statesSummary != null) item.statesSummary!,
      if (intervalPart != null) intervalPart!,
      if (!item.isStateful && item.mode != 'interval') item.repeatLabel,
      if (!item.isStateful &&
          item.mode != 'interval' &&
          item.time?.isNotEmpty == true)
        item.time!,
      item.deliveryLabel,
      if (idle.isNotEmpty) '免打扰 ${idle.first.start}-${idle.first.end}',
    ];

    final titleStyle = t.typography.body.sm.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: disabled ? t.colors.mutedForeground : t.colors.foreground,
      decoration: disabled ? TextDecoration.lineThrough : null,
    );

    // 长按 → 操作菜单【编辑 / 停用·启用 / 删除】（stateful=番茄钟托管，只读不响应长按）
    Future<void> onLongPress() async {
      if (item.isStateful) return;
      final enabled = item.enabled;
      final action = await showSheetActionMenu<String>(
        context,
        title: item.title,
        actions: [
          const SheetAction('edit', '编辑', icon: FLucideIcons.pencil),
          SheetAction(
            'toggle',
            enabled ? '停用' : '启用',
            icon: enabled ? FLucideIcons.circlePause : FLucideIcons.circlePlay,
          ),
          const SheetAction(
            'delete',
            '删除',
            icon: FLucideIcons.trash2,
            destructive: true,
          ),
        ],
      );
      if (!context.mounted || action == null) return;
      final repo = ref.read(reminderRepositoryProvider);
      if (action == 'edit') {
        await _openReminderEditor(context, item);
      } else if (action == 'toggle') {
        await repo.toggleEnabled(item, !enabled);
      } else if (action == 'delete') {
        final ok = await showSheetConfirm(
          context,
          title: '删除提醒',
          message: '确定删除「${item.title}」？删除后本地通知计划一并取消。',
        );
        if (ok) await repo.deleteReminder(item.id);
      }
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        elevation: 1,
        onTap: item.isStateful
            ? null
            : () => _openReminderEditor(context, item),
        child: Opacity(
          opacity: disabled ? 0.6 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // R1：图标 + 标题 + 模式标签 + 开关（同排）
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: iconGradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Icon(iconData, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      spacing: 6,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        SoftChip(label: item.modeLabel, color: modeColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FSwitch(
                    value: item.enabled,
                    // 状态机型提醒不允许启停（权威在番茄钟页）
                    enabled: !item.isStateful,
                    onChange: (v) => ref
                        .read(reminderRepositoryProvider)
                        .toggleEnabled(item, v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // R2：规则摘要（含免打扰时段）
              Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  color: t.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              // R3：下次触发 / 前台驱动 / 已停用
              Text(
                item.nextTriggerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: disabled
                      ? t.colors.mutedForeground
                      : t.colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新建 / 编辑弹层（图2 同构：lg 定高 + 字段组；controller 归本 State 持有，雷区 #14）
class _ReminderEditor extends ConsumerStatefulWidget {
  const _ReminderEditor({this.initial});

  final ReminderItem? initial;

  @override
  ConsumerState<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends ConsumerState<_ReminderEditor> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  TimeOfDay _timeValue = const TimeOfDay(hour: 9, minute: 0); // 定点时刻（选择器）
  DateTime? _dateValue; // 月/年重复的基准日期（选择器）
  final _interval = TextEditingController(text: '30');
  final _idleStart = TextEditingController(text: '22:00');
  final _idleEnd = TextEditingController(text: '06:00');

  int _modeIndex = 0; // 0=时间 1=周期
  int _deliveryIndex = 0; // 0=通知 1=闹钟
  int _repeatIndex = 0; // 0=每天 1=每周 2=一次性 3=每月 4=每小时 5=每年
  int _unitIndex = 0; // 0=分钟 1=小时 2=天
  final Set<int> _weekDays = {};
  bool _idleEnabled = false;

  /// 「闹钟和提醒」（精确闹钟）是否可用；选「闹钟」送达且未开启时内联提示「可能延迟几分钟」
  bool _exactAlarmOk = true;

  static const _repeatOptions = [
    ('daily', '每天'),
    ('weekly', '每周'),
    ('once', '一次性'),
    ('monthly', '每月'),
    ('hourly', '每小时'),
    ('yearly', '每年'),
  ];

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    if (it != null) {
      _title.text = it.title;
      _content.text = it.content;
      _modeIndex = it.mode == 'interval' ? 1 : 0;
      _deliveryIndex = it.isAlarm ? 1 : 0;
      _timeValue = _parseTimeOfDay(it.time) ?? const TimeOfDay(hour: 9, minute: 0);
      _repeatIndex =
          const {
            'daily': 0,
            'weekly': 1,
            'once': 2,
            'monthly': 3,
            'hourly': 4,
            'yearly': 5,
          }[it.repeat] ??
          0;
      _weekDays.addAll(it.weekDays);
      _dateValue = DateTime.tryParse(it.date ?? '');
      _interval.text = it.interval ?? '30';
      _unitIndex =
          const {'60000': 0, '3600000': 1, '86400000': 2}[it.unit] ?? 0;
      if (it.idleTime != null && it.idleTime != '[]') {
        final slots = parseIdleSlots(it.idleTime);
        if (slots.isNotEmpty) {
          _idleEnabled = true;
          _idleStart.text = slots.first.start;
          _idleEnd.text = slots.first.end;
        }
      }
    }
    _checkExactAlarm();
  }

  /// 查一次「闹钟和提醒」权限（决定「闹钟」送达下方是否显示降级提示）
  Future<void> _checkExactAlarm() async {
    final ok = await NotificationService.exactAlarmAllowed;
    if (mounted) setState(() => _exactAlarmOk = ok);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();


    _interval.dispose();
    _idleStart.dispose();
    _idleEnd.dispose();
    super.dispose();
  }

  /// 选择器值行（muted 容器 + 图标 + 当前值 + 下拉箭头；点击开选择抽屉）
  Widget pickerRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final t = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetFieldLabel(label),
        FTappable(
          onPress: onTap,
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
                Icon(icon, size: 15, color: t.colors.mutedForeground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: t.colors.foreground,
                    ),
                  ),
                ),
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
    );
  }

  /// 'HH:mm' → TimeOfDay（旧数据回显用；解析失败回落默认 09:00）
  TimeOfDay? _parseTimeOfDay(String? raw) {
    final p = raw?.split(':');
    if (p == null || p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _isValidTime(String s) {
    final p = s.split(':');
    if (p.length != 2) return false;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60;
  }


  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    final mode = _modeIndex == 1 ? 'interval' : 'time';
    final delivery = _deliveryIndex == 1 ? 'alarm' : 'notification';
    String? time;
    String? repeat;
    List<int> wd = [];
    String? date;
    String? interval;
    String? unit;
    String? month;
    String? dayOfMonth;

    if (mode == 'interval') {
      interval = int.tryParse(_interval.text.trim()) != null
          ? _interval.text.trim()
          : '30';
      unit = ['60000', '3600000', '86400000'][_unitIndex];
    } else {
      time =
          '${_timeValue.hour.toString().padLeft(2, '0')}:${_timeValue.minute.toString().padLeft(2, '0')}';
      repeat = _repeatOptions[_repeatIndex].$1;
      if (repeat == 'weekly') wd = _weekDays.toList()..sort();
      if (repeat == 'once' || repeat == 'monthly' || repeat == 'yearly') {
        final d = _dateValue;
        if (d == null) return;
        date =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        dayOfMonth = d.day.toString();
        if (repeat == 'yearly') month = d.month.toString();
      }
    }

    String? idleTime;
    if (_idleEnabled &&
        _isValidTime(_idleStart.text.trim()) &&
        _isValidTime(_idleEnd.text.trim())) {
      idleTime = ReminderRepository.encodeIdleSlots([
        IdleSlot(start: _idleStart.text.trim(), end: _idleEnd.text.trim()),
      ]);
    }

    final item = ReminderItem(
      id:
          widget.initial?.id ??
          'mobile:${DateTime.now().millisecondsSinceEpoch}',
      mode: mode,
      title: title,
      content: _content.text.trim(),
      enabled: true,
      weekDays: wd,
      time: time,
      date: date,
      repeat: repeat,
      interval: interval,
      unit: unit,
      month: month,
      dayOfMonth: dayOfMonth,
      idleTime: idleTime,
      source: '',
      delivery: delivery,
      statesSummary: null,
      loop: '1',
    );
    ref.read(reminderRepositoryProvider).saveReminder(item);
    Navigator.pop(context);
  }

  /// 选「闹钟」送达方式时惰性申请精确闹钟权限（Android 12+ 需去系统设置开「闹钟和提醒」）
  Future<void> _ensureAlarmPermission() async {
    if (await NotificationService.exactAlarmAllowed) {
      if (mounted) setState(() => _exactAlarmOk = true);
      return;
    }
    final ok = await NotificationService.requestExactAlarmPermission();
    if (mounted) setState(() => _exactAlarmOk = ok);
    if (!ok && mounted) {
      showFToast(
        context: context,
        title: const Text('未授予「闹钟和提醒」权限'),
        description: const Text('闹钟可能延迟几分钟，可在「提醒守护」里再开启'),
      );
    }
  }

  /// 闹钟降级提示：未开「闹钟和提醒」时明确写清后果（不阻断保存，用户可自行去开）
  Widget _alarmDowngradeHint(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.accent(3).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            FLucideIcons.triangleAlert,
            size: 14,
            color: AppTokens.accent(3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '「闹钟和提醒」未开启，响铃可能延迟几分钟',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.foreground,
              ),
            ),
          ),
          GestureDetector(
            onTap: _ensureAlarmPermission,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
              child: Text(
                '去开启',
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.accent(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetScaffold(
      title: widget.initial == null ? '新建提醒' : '编辑提醒',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 提醒标题（不 autofocus —— 打开弹窗不抢焦点，§1.9）
          const SheetFieldLabel('提醒标题'),
          SheetInputBox(controller: _title, hintText: '输入提醒标题'),
          const SizedBox(height: 16),
          // 内容（可选）：多行随内容增长
          const SheetFieldLabel('内容（可选）'),
          SheetMultilineBox(controller: _content, hintText: '输入提醒内容'),
          const SizedBox(height: 16),
          // 送达方式
          const SheetFieldLabel('送达方式'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SheetChoiceChip(
                label: '通知',
                selected: _deliveryIndex == 0,
                leading: Icon(
                  FLucideIcons.bell,
                  size: 14,
                  color: _deliveryIndex == 0
                      ? AppTokens.accent(3)
                      : t.colors.mutedForeground,
                ),
                onTap: () => setState(() => _deliveryIndex = 0),
              ),
              SheetChoiceChip(
                label: '闹钟',
                selected: _deliveryIndex == 1,
                leading: Icon(
                  FLucideIcons.alarmClock,
                  size: 14,
                  color: _deliveryIndex == 1
                      ? AppTokens.accent(3)
                      : t.colors.mutedForeground,
                ),
                onTap: () {
                  setState(() => _deliveryIndex = 1);
                  _ensureAlarmPermission();
                },
              ),
            ],
          ),
          // 选「闹钟」且未开「闹钟和提醒」→ 明确写出降级后果（不阻断保存）
          if (_deliveryIndex == 1 && !_exactAlarmOk) ...[
            const SizedBox(height: 8),
            _alarmDowngradeHint(context),
          ],
          const SizedBox(height: 16),
          // 模式
          const SheetFieldLabel('模式'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SheetChoiceChip(
                label: '时间',
                selected: _modeIndex == 0,
                onTap: () => setState(() => _modeIndex = 0),
              ),
              SheetChoiceChip(
                label: '周期',
                selected: _modeIndex == 1,
                onTap: () => setState(() => _modeIndex = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_modeIndex == 1) ...[
            // 周期：间隔数值 + 单位
            const SheetFieldLabel('间隔（数字）'),
            SheetInputBox(
              controller: _interval,
              hintText: '如 30',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in const ['分钟', '小时', '天'].indexed)
                  SheetChoiceChip(
                    label: label,
                    selected: _unitIndex == i,
                    onTap: () => setState(() => _unitIndex = i),
                  ),
              ],
            ),
          ] else ...[
            // 定点：时刻 + 重复
            pickerRow(
              context,
              label: '时刻',
              value: '${_timeValue.hour.toString().padLeft(2, '0')}:${_timeValue.minute.toString().padLeft(2, '0')}',
              icon: FLucideIcons.clock,
              onTap: () async {
                final picked = await showTimePickerSheet(
                  context,
                  initial: _timeValue,
                  title: '选择时刻',
                );
                if (picked != null && mounted) {
                  setState(() => _timeValue = picked);
                }
              },
            ),
            const SizedBox(height: 16),
            const SheetFieldLabel('重复'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, option) in _repeatOptions.indexed)
                  SheetChoiceChip(
                    label: option.$2,
                    selected: _repeatIndex == i,
                    onTap: () => setState(() => _repeatIndex = i),
                  ),
              ],
            ),
            if (_repeatIndex == 1) ...[
              const SizedBox(height: 12),
              const SheetFieldLabel('生效星期'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in const [
                    (1, '一'),
                    (2, '二'),
                    (3, '三'),
                    (4, '四'),
                    (5, '五'),
                    (6, '六'),
                    (0, '日'),
                  ])
                    SheetChoiceChip(
                      label: '周${d.$2}',
                      selected: _weekDays.contains(d.$1),
                      onTap: () => setState(
                        () => _weekDays.contains(d.$1)
                            ? _weekDays.remove(d.$1)
                            : _weekDays.add(d.$1),
                      ),
                    ),
                ],
              ),
            ] else if (_repeatIndex == 2 ||
                _repeatIndex == 3 ||
                _repeatIndex == 5) ...[
              const SizedBox(height: 12),
              SheetFieldLabel(
                _repeatIndex == 2
                    ? '日期'
                    : _repeatIndex == 5
                    ? '每年这一天'
                    : '每月几号',
              ),
              pickerRow(
                context,
                label: '基准日期',
                value: _dateValue == null
                    ? '请选择日期'
                    : '${_dateValue!.year.toString().padLeft(4, '0')}-${_dateValue!.month.toString().padLeft(2, '0')}-${_dateValue!.day.toString().padLeft(2, '0')}',
                icon: FLucideIcons.calendarDays,
                onTap: () async {
                  final picked = await showTodoDateTimeSheet(
                    context,
                    initial: _dateValue,
                    dateOnly: true,
                  );
                  if (picked != null && mounted) {
                    setState(() => _dateValue = picked);
                  }
                },
              ),
            ],
          ],
          const SizedBox(height: 16),
          // 免打扰时段
          SheetSwitchRow(
            label: '免打扰时段',
            value: _idleEnabled,
            icon: FLucideIcons.moon,
            onChange: (v) => setState(() => _idleEnabled = v),
          ),
          if (_idleEnabled) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SheetFieldLabel('起（HH:mm）'),
                      SheetInputBox(controller: _idleStart, hintText: '22:00'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SheetFieldLabel('止（HH:mm）'),
                      SheetInputBox(controller: _idleEnd, hintText: '06:00'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomBar: sheetBottomActions(
        context,
        actionLabel: widget.initial == null ? '创建' : '保存',
        actionIcon: FLucideIcons.check,
        onAction: _save,
      ),
    );
  }
}
