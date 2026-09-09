// 提醒管理页（forui 化）—— 用户提醒列表（定点/周期/多状态）+ 启停 + 编辑
//
// 与桌面端 newTips 页对齐；新增/编辑表单列全：模式(时间/周期)、送达方式(通知/闹钟)、
// 重复(每天/每周/一次性/每月/每小时/每年)、星期、免打扰时段；stateful 仍只读展示（番茄钟拥有）。
// forui 改造点：FScaffold+FHeader.nested 骨架、AppCard 列表行、FSwitch 启停、
// showFSheet 编辑弹层（FTextField + JianliSegmented + FButton 星期选择）；
// 进入页面时 rescheduleAll 重排程，保证通知在 App 被杀后仍可触发。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/reminder_item.dart';
import '../providers/reminder_providers.dart';
import '../repositories/reminder_repository.dart';

/// 提醒管理页
class ReminderListPage extends ConsumerStatefulWidget {
  const ReminderListPage({super.key});

  @override
  ConsumerState<ReminderListPage> createState() => _ReminderListPageState();
}

class _ReminderListPageState extends ConsumerState<ReminderListPage> {
  @override
  void initState() {
    super.initState();
    // 进入页面：申请通知权限 + 重排程全部启用提醒（防止 awesome 原生计划被清理）
    NotificationService.requestPermission();
    ref.read(reminderRepositoryProvider).rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(reminderListProvider);

    return FScaffold(
      header: FHeader.nested(
        title: const Text('提醒管理'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _openEditor(context, ref, null),
            semanticsLabel: '新建提醒',
          ),
        ],
      ),
      child: remindersAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '加载失败：$e',
            style: context.theme.typography.body.sm.copyWith(
              color: context.theme.colors.error,
            ),
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
              padding: EdgeInsets.only(
                top: AppTokens.listTopGapOf(context),
                bottom: AppTokens.pageBottomGapOf(context),
              ),
              children: [
                StaggerList(
                  children: [
                    PageBanner(
                      icon: FLucideIcons.bell,
                      title: '提醒管理',
                      subtitle: '定点 / 周期 / 多状态，一个都不少',
                      accentIndex: 3,
                      stats: [
                        ('${items.length}', '全部提醒'),
                        ('${items.where((e) => e.enabled).length}', '启用中'),
                      ],
                    ),
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

  /// 打开新建/编辑弹层
  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    ReminderItem? initial,
  ) =>
      showFSheet<void>(
        context: context,
        side: FLayout.btt,
        builder: (context) => _ReminderEditor(initial: initial),
      );
}

/// 单条提醒
class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.item});

  final ReminderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final subtitleParts = <String>[
      item.repeatLabel,
      if (!item.isStateful && (item.time?.isNotEmpty ?? false)) item.time!,
      if (item.isStateful && item.statesSummary != null) item.statesSummary!,
      if (item.idleTime != null && item.idleTime != '[]') '含免打扰',
      item.deliveryLabel,
    ];

    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: item.isStateful
          ? null
          : () => showFSheet<void>(
                context: context,
                side: FLayout.btt,
                builder: (ctx) => _ReminderEditor(initial: item),
              ),
      child: Row(
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(
              item.isAlarm ? AppTokens.accent(6) : AppTokens.accent(3),
            ),
            alignment: Alignment.center,
            child: Icon(
              item.isAlarm
                  ? FLucideIcons.alarmClock
                  : (item.isStateful ? FLucideIcons.refreshCw : FLucideIcons.bell),
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
                    decoration: item.enabled ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
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

/// 新建 / 编辑弹层（forui 化，零硬编码色）
class _ReminderEditor extends ConsumerStatefulWidget {
  const _ReminderEditor({this.initial});

  final ReminderItem? initial;

  @override
  ConsumerState<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends ConsumerState<_ReminderEditor> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _time = TextEditingController(text: '09:00');
  final _date = TextEditingController();
  final _interval = TextEditingController(text: '30');
  final _idleStart = TextEditingController(text: '22:00');
  final _idleEnd = TextEditingController(text: '06:00');

  int _modeIndex = 0; // 0=时间 1=周期
  int _deliveryIndex = 0; // 0=通知 1=闹钟
  int _repeatIndex = 0; // 0=每天 1=每周 2=一次性 3=每月 4=每小时 5=每年
  int _unitIndex = 0; // 0=分钟 1=小时 2=天
  final Set<int> _weekDays = {};
  bool _idleEnabled = false;

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    if (it != null) {
      _title.text = it.title;
      _content.text = it.content;
      _modeIndex = it.mode == 'interval' ? 1 : 0;
      _deliveryIndex = it.isAlarm ? 1 : 0;
      _time.text = it.time ?? '09:00';
      _repeatIndex = const {
            'daily': 0,
            'weekly': 1,
            'once': 2,
            'monthly': 3,
            'hourly': 4,
            'yearly': 5,
          }[it.repeat] ??
          0;
      _weekDays.addAll(it.weekDays);
      _date.text = it.date ?? '';
      _interval.text = it.interval ?? '30';
      _unitIndex = const {
            '60000': 0,
            '3600000': 1,
            '86400000': 2,
          }[it.unit] ??
          0;
      if (it.idleTime != null && it.idleTime != '[]') {
        final slots = parseIdleSlots(it.idleTime);
        if (slots.isNotEmpty) {
          _idleEnabled = true;
          _idleStart.text = slots.first.start;
          _idleEnd.text = slots.first.end;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _time.dispose();
    _date.dispose();
    _interval.dispose();
    _idleStart.dispose();
    _idleEnd.dispose();
    super.dispose();
  }

  bool _isValidTime(String s) {
    final p = s.split(':');
    if (p.length != 2) return false;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60;
  }

  bool _isValidDate(String s) {
    final p = s.split('-');
    if (p.length != 3) return false;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return false;
    try {
      DateTime(y, m, d);
      return true;
    } catch (_) {
      return false;
    }
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
      time = _time.text.trim();
      if (!_isValidTime(time)) return;
      repeat = ['daily', 'weekly', 'once', 'monthly', 'hourly', 'yearly'][_repeatIndex];
      if (repeat == 'weekly') wd = _weekDays.toList()..sort();
      if (repeat == 'once' || repeat == 'monthly' || repeat == 'yearly') {
        if (!_isValidDate(_date.text.trim())) return;
        date = _date.text.trim();
        final p = _date.text.trim().split('-');
        dayOfMonth = p[2];
        if (repeat == 'yearly') month = p[1];
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
      id: widget.initial?.id ??
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

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null ? '新建提醒' : '编辑提醒',
                    style: t.typography.body.lg
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FHeaderAction(
                  icon: const Icon(FLucideIcons.x),
                  onPress: () => Navigator.pop(context),
                  semanticsLabel: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 14),
            FTextField(
              control: FTextFieldControl.managed(controller: _title),
              label: const Text('提醒标题'),
              hint: '输入提醒标题',
              autofocus: true,
            ),
            const SizedBox(height: 10),
            FTextField(
              control: FTextFieldControl.managed(controller: _content),
              label: const Text('内容（可选）'),
              hint: '输入提醒内容',
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: '送达方式'),
            JianliSegmented(
              items: const [
                (FLucideIcons.bell, '通知'),
                (FLucideIcons.alarmClock, '闹钟'),
              ],
              selected: _deliveryIndex,
              onSelect: (i) => setState(() => _deliveryIndex = i),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: '模式'),
            JianliSegmented(
              items: const [
                (FLucideIcons.clock, '时间'),
                (FLucideIcons.repeat, '周期'),
              ],
              selected: _modeIndex,
              onSelect: (i) => setState(() => _modeIndex = i),
            ),
            const SizedBox(height: 14),
            if (_modeIndex == 1) ...[
              FTextField(
                control: FTextFieldControl.managed(controller: _interval),
                label: const Text('间隔（数字）'),
                hint: '如 30',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              JianliSegmented(
                items: const [
                  (null, '分钟'),
                  (null, '小时'),
                  (null, '天'),
                ],
                selected: _unitIndex,
                onSelect: (i) => setState(() => _unitIndex = i),
              ),
            ] else ...[
              FTextField(
                control: FTextFieldControl.managed(controller: _time),
                label: const Text('时刻（HH:mm）'),
                hint: '09:00',
              ),
              const SizedBox(height: 10),
              JianliSegmented(
                items: const [
                  (null, '每天'),
                  (null, '每周'),
                  (null, '一次性'),
                  (null, '每月'),
                  (null, '每小时'),
                  (null, '每年'),
                ],
                selected: _repeatIndex,
                onSelect: (i) => setState(() => _repeatIndex = i),
              ),
              const SizedBox(height: 10),
              if (_repeatIndex == 1) ...[
                Text('生效星期',
                    style: t.typography.body.sm
                        .copyWith(color: t.colors.mutedForeground)),
                const SizedBox(height: 6),
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
                      FButton(
                        variant: _weekDays.contains(d.$1)
                            ? FButtonVariant.secondary
                            : FButtonVariant.outline,
                        size: FButtonSizeVariant.sm,
                        onPress: () => setState(() => _weekDays.contains(d.$1)
                            ? _weekDays.remove(d.$1)
                            : _weekDays.add(d.$1)),
                        child: Text('周${d.$2}'),
                      ),
                  ],
                ),
              ] else if (_repeatIndex == 2 || _repeatIndex == 3 || _repeatIndex == 5) ...[
                const SizedBox(height: 4),
                FTextField(
                  control: FTextFieldControl.managed(controller: _date),
                  label: Text(_repeatIndex == 2
                      ? '日期（YYYY-MM-DD）'
                      : _repeatIndex == 5
                          ? '每年这一天（YYYY-MM-DD）'
                          : '每月几号（YYYY-MM-DD，取日）'),
                  hint: '2026-09-10',
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('免打扰时段',
                      style: t.typography.body.sm
                          .copyWith(color: t.colors.mutedForeground)),
                ),
                FSwitch(
                  value: _idleEnabled,
                  onChange: (v) => setState(() => _idleEnabled = v),
                ),
              ],
            ),
            if (_idleEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FTextField(
                      control: FTextFieldControl.managed(controller: _idleStart),
                      label: const Text('起（HH:mm）'),
                      hint: '22:00',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FTextField(
                      control: FTextFieldControl.managed(controller: _idleEnd),
                      label: const Text('止（HH:mm）'),
                      hint: '06:00',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FButton(
              onPress: _save,
              child: Text(widget.initial == null ? '创建' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
