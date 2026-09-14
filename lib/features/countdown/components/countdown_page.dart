// 倒计时页 —— 对齐待办列表页骨架（图1：主题色横幅统计 + 吸顶搜索行 + 分段 Tab + 列表）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 倒计时18/Bold · ＋22（新建）
//   统计横幅 PageBanner 主色渐变 · r22 · stats 全部/进行中/已暂停/已结束
//   搜索行  ★吸顶锚点（PinnedSearchRow/PinnedSearchHeader，搜索框常驻视口顶部）
//   Tab 栏  ScopeTabBar：全部 / 进行中 / 已暂停 / 已结束（状态范围，随滚动移出）
//   列表   倒计时卡片（卡片族三行式 · 状态图标盘 + 时间块占整宽 + 状态色圆钮组，无进度环）
// 到点通知：创建/恢复/重置即排系统通知，暂停/删除/完成即取消（见 countdown_repository）；
//   页面 tick 做跨零检测 → sweepExpired 补写 finished + toast（对齐 PC 到点链路）。
// 搜索为页内实时过滤，Tab 前端过滤 —— 不动数据层。
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/scope_tab_bar.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../../../app/ui/datetime_pickers.dart';
import '../repositories/countdown_repository.dart';

/// Tab 状态范围
const List<(String, String)> kCountdownTabs = [
  ('all', '全部'),
  ('running', '进行中'),
  ('paused', '已暂停'),
  ('finished', '已结束'),
];

/// 打开新建 / 编辑表单（页面头部 ＋ 与卡片长按菜单**共用同一入口**，避免交互漂移）
Future<void> _openForm(BuildContext context, CountdownData? initial) =>
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 三档制配对（红线 #9）：lg 定高 + 键盘覆盖不折叠
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (_) => _CountdownFormSheet(initial: initial),
    );

/// 倒计时页
class CountdownPage extends ConsumerStatefulWidget {
  const CountdownPage({super.key});

  @override
  ConsumerState<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends ConsumerState<CountdownPage> {
  Timer? _ticker;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  /// 页内搜索关键词（实时过滤名称）
  String _search = '';

  /// Tab 状态范围
  String _tab = 'all';

  final TextEditingController _searchController = TextEditingController();

  /// 跨零清扫去重锁（tick 每秒触发，避免重复 sweep）
  bool _sweeping = false;

  @override
  void initState() {
    super.initState();
    // 每秒刷新（基于 end_time 时间戳计算，与桌面端同构）+ 跨零检测
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
    _checkExpired();
  }

  /// 跨零检测：running 且已到点 → sweepExpired 补写 finished + toast。
  /// （原生到点通知已由仓库排程负责，这里只补库与页面反馈。）
  Future<void> _checkExpired() async {
    if (_sweeping) return;
    final rows =
        ref.read(countdownListProvider).value ?? const <CountdownData>[];
    final hasExpired = rows.any(
      (r) =>
          r.status == 'running' &&
          (r.endTime ?? 0) > 0 &&
          (r.endTime ?? 0) <= _nowMs,
    );
    if (!hasExpired) return;
    _sweeping = true;
    try {
      final n = await ref.read(countdownRepositoryProvider).sweepExpired();
      if (!mounted || n <= 0) return;
      showFToast(context: context, title: const Text('倒计时结束'));
    } finally {
      _sweeping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final listAsync = ref.watch(countdownListProvider);

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
                child: listAsync.when(
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
                  data: (rows) => _body(context, rows),
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
              '倒计时',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
          TapScale(
            onTap: () => _showFormSheet(),
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

  Widget _body(BuildContext context, List<CountdownData> rows) {
    // 页内过滤：关键词 + 状态 Tab（不动数据层）
    final keyword = _search.trim().toLowerCase();
    final scoped = [
      for (final r in rows)
        if ((_tab == 'all' || r.status == _tab) &&
            (keyword.isEmpty || (r.name ?? '').toLowerCase().contains(keyword)))
          r,
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(context, rows)),
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索倒计时…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ScopeTabBar<String>(
            tabs: kCountdownTabs,
            selected: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: FLucideIcons.hourglass,
              title: '暂无倒计时',
              subtitle: '点右上角 ＋ 新建一个，到点弹系统通知',
            ),
          )
        else if (scoped.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: FLucideIcons.listFilter,
              title: '没有匹配的倒计时',
              subtitle: '换个关键词，或切换上方状态 Tab',
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
                for (final row in scoped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CountdownCard(row: row, nowMs: _nowMs),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（主色渐变，与待办同款：r22 + 同心环装饰）
  Widget _banner(BuildContext context, List<CountdownData> rows) => PageBanner(
    icon: FLucideIcons.hourglass,
    title: '倒计时',
    subtitle: '分秒必争，到点提醒',
    // 统一主题色（与待办横幅同源渐变，换外观色系时整屏跟着走）
    gradient: AppTokens.accentGradient(AppTokens.accent(0)),
    cornerRadius: 22,
    ringDecor: true,
    shadow: false,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    stats: [
      ('${rows.length}', '全部'),
      ('${rows.where((r) => r.status == 'running').length}', '进行中'),
      ('${rows.where((r) => r.status == 'paused').length}', '已暂停'),
      ('${rows.where((r) => r.status == 'finished').length}', '已结束'),
    ],
  );

  // ===================== 新建 / 编辑弹层（lg 定高，对齐图2） =====================

  /// 新建（无 initial）/ 编辑（长按菜单进入）共用同一表单入口 [_openForm]
  Future<void> _showFormSheet({CountdownData? initial}) =>
      _openForm(context, initial);
}

/// 新建 / 编辑倒计时弹层（对齐 PC CountdownDialog：名称 + 设定方式 + 时间设定）。
///
/// 设定方式（2026-09-12 对齐 PC 交互）：
/// - **指定时刻**（datetime）：点行打开 forui 六列中文单位滚轮 `showDateTimeWheelSheet`（年/月/日/时/分/秒，含秒）；
/// - **指定时长**（duration）：年/月/日/时/分/秒 6 个小输入框（年=365 天、月=30 天折算），默认 1 小时。
///
/// controller 归本 State 持有（不走「await 后 dispose」雷区 #14）。
class _CountdownFormSheet extends ConsumerStatefulWidget {
  const _CountdownFormSheet({this.initial});

  final CountdownData? initial;

  @override
  ConsumerState<_CountdownFormSheet> createState() =>
      _CountdownFormSheetState();
}

class _CountdownFormSheetState extends ConsumerState<_CountdownFormSheet> {
  static const int _yearMs = 365 * 86400000; // 年按 365 天折算
  static const int _monthMs = 30 * 86400000; // 月按 30 天折算
  static const int _dayMs = 86400000;
  static const int _hourMs = 3600000;
  static const int _minuteMs = 60000;
  static const int _secondMs = 1000;

  final _nameController = TextEditingController();
  // 指定时长：年/月/日/时/分/秒 六个小输入框
  final _year = TextEditingController(text: '0');
  final _month = TextEditingController(text: '0');
  final _day = TextEditingController(text: '0');
  final _hour = TextEditingController(text: '1');
  final _minute = TextEditingController(text: '0');
  final _second = TextEditingController(text: '0');

  /// 设定方式：duration = 指定时长 / datetime = 指定时刻（与桌面端 mode 字段同值）
  late String _mode;

  /// 指定时刻模式的选中目标
  DateTime? _target;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final row = widget.initial;
    _mode = (row?.mode ?? 'duration') == 'datetime' ? 'datetime' : 'duration';
    _nameController.text = row?.name ?? '';
    if (row != null) {
      final endMs = row.endTime ?? 0;
      if (_mode == 'datetime' && endMs > 0) {
        _target = DateTime.fromMillisecondsSinceEpoch(endMs);
      }
      _fillDuration(row.duration ?? _hourMs);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _year.dispose();
    _month.dispose();
    _day.dispose();
    _hour.dispose();
    _minute.dispose();
    _second.dispose();
    super.dispose();
  }

  /// 把毫秒时长拆进 年/月/日/时/分/秒 六个输入框（编辑回显用）
  void _fillDuration(int ms) {
    var rest = ms;
    int take(int unitMs) {
      final v = rest ~/ unitMs;
      rest -= v * unitMs;
      return v;
    }

    _year.text = '${take(_yearMs)}';
    _month.text = '${take(_monthMs)}';
    _day.text = '${take(_dayMs)}';
    _hour.text = '${take(_hourMs)}';
    _minute.text = '${take(_minuteMs)}';
    _second.text = '${take(_secondMs)}';
  }

  int _durationMsFromInputs() {
    int p(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    return p(_year) * _yearMs +
        p(_month) * _monthMs +
        p(_day) * _dayMs +
        p(_hour) * _hourMs +
        p(_minute) * _minuteMs +
        p(_second) * _secondMs;
  }

  void _submit() {
    final name = _nameController.text.trim().isEmpty
        ? '倒计时'
        : _nameController.text.trim();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repo = ref.read(countdownRepositoryProvider);
    final initial = widget.initial;

    if (_mode == 'datetime') {
      final target = _target;
      if (target == null) {
        showFToast(context: context, title: const Text('请选择目标时刻'));
        return;
      }
      final endMs = target.millisecondsSinceEpoch;
      if (endMs <= nowMs) {
        showFToast(context: context, title: const Text('目标时刻需晚于当前时间'));
        return;
      }
      if (initial == null) {
        repo.create(
          name: name,
          mode: 'datetime',
          endMs: endMs,
          durationMs: endMs - nowMs,
        );
      } else {
        repo.updateTiming(
          row: initial,
          name: name,
          mode: 'datetime',
          endMs: endMs,
          durationMs: endMs - nowMs,
        );
      }
    } else {
      final durationMs = _durationMsFromInputs();
      if (durationMs <= 0) {
        showFToast(context: context, title: const Text('请输入大于 0 的时长'));
        return;
      }
      if (initial == null) {
        repo.create(
          name: name,
          mode: 'duration',
          endMs: nowMs + durationMs,
          durationMs: durationMs,
        );
      } else {
        repo.updateTiming(
          row: initial,
          name: name,
          mode: 'duration',
          endMs: nowMs + durationMs,
          durationMs: durationMs,
        );
      }
    }
    Navigator.pop(context);
  }

  /// 指定时刻：打开 forui 六列中文单位滚轮（年/月/日/时/分/秒，含秒）
  Future<void> _pickTarget() async {
    final picked = await showDateTimeWheelSheet(context, initial: _target);
    if (!mounted) return;
    setState(() => _target = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _editing ? '编辑倒计时' : '新建倒计时',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 名称
          const SheetFieldLabel('名称'),
          SheetInputBox(controller: _nameController, hintText: '给这个倒计时起个名字'),
          const SizedBox(height: 16),
          // 设定方式
          const SheetFieldLabel('设定方式'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SheetChoiceChip(
                label: '指定时长',
                selected: _mode == 'duration',
                onTap: () => setState(() => _mode = 'duration'),
              ),
              SheetChoiceChip(
                label: '指定时刻',
                selected: _mode == 'datetime',
                onTap: () => setState(() => _mode = 'datetime'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 时间设定：指定时刻 = 日期时间选择行；指定时长 = 年月日时分秒六输入（默认 1 小时）
          if (_mode == 'datetime') ...[
            const SheetFieldLabel('目标时刻'),
            FTappable(
              onPress: _pickTarget,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.theme.colors.muted,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: context.theme.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      FLucideIcons.calendar,
                      size: 18,
                      color: context.theme.colors.mutedForeground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _target == null ? '未设置' : _formatTarget(_target!),
                        style: context.theme.typography.body.md,
                      ),
                    ),
                    if (_target != null)
                      GestureDetector(
                        onTap: () => setState(() => _target = null),
                        child: Icon(
                          FLucideIcons.x,
                          size: 16,
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SheetFieldLabel('时长'),
            Row(
              spacing: 6,
              children: [
                for (final (i, unit) in const [
                  '年',
                  '月',
                  '日',
                  '时',
                  '分',
                  '秒',
                ].indexed)
                  Expanded(
                    child: Column(
                      children: [
                        SheetInputBox(
                          controller: [
                            _year,
                            _month,
                            _day,
                            _hour,
                            _minute,
                            _second,
                          ][i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unit,
                          style: context.theme.typography.body.xs.copyWith(
                            fontSize: 12,
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _editing ? '不改时间设定时保留原计时；改了则从现在重新开始' : '开始后到点弹系统通知，App 被杀也能提醒',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
      bottomBar: sheetBottomActions(
        context,
        actionLabel: _editing ? '保存' : '开始',
        actionIcon: _editing ? FLucideIcons.check : FLucideIcons.play,
        onAction: _submit,
      ),
    );
  }

  /// 目标时刻展示：yyyy-MM-dd HH:mm
  String _formatTarget(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// 倒计时卡片（2026-09-14 定稿 · 卡片族三行式 · r16/padding 14）：
///   R1 状态图标盘（40·r13 · 20px 白图标，与提醒 / 主题 / 笔记 / 待办同规格）
///      ＋ 名称 15/SemiBold ＋ 状态 SoftChip；
///   R2 时间块占整宽：主行 20/Bold（剩余时间 / 结束时刻）＋ 副行 12（目标时刻 / 状态说明）；
///   R3 设定方式 FlatBadge ＋ 提醒 chip ┈┈ 40×40 圆钮组。
/// 三态只在三处随状态变：① 状态色 ② 主副行文案 ③ 按钮组 —— 槽位与排布完全一致。
/// ⚠️ 图标盘外圈**不套进度环**（2026-09-14 用户定：环形既读不出剩余比例、又和图标盘抢视觉）。
/// 提醒 chip 读 row.notify（2026-09-14 修：此前恒渲染「提醒 · 声音」）：
///   '1' = 状态色软底「提醒 · 声音」/ '0' = 中性灰「不提醒」。
/// 按钮配色（2026-09-13 定稿）：重置恒灰底灰图标、删除恒红浅底红图标（destructive 14%）；
/// 主操作随状态色：进行中暂停 = 主题色、已暂停继续 = 琥珀。
/// **指定时刻（mode=datetime）不展示重置/暂停**（目标时刻固定，计时类操作无语义），
/// 仅「指定时长」提供；已结束的删除对所有设定方式都保留。
class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({required this.row, required this.nowMs});

  final CountdownData row;
  final int nowMs;

  // —— 卡片族尺寸（2026-09-14 收口 · 与提醒 / 主题 / 笔记 / 待办同规格）——
  /// 图标盘（普通圆角矩形 + 状态色渐变 + 白图标；弧度基准 = 首页快捷入口 40→13）
  static const double _kTileSize = 40;
  static const double _kTileRadius = 13;
  static const double _kTileIconSize = 20;

  static const double _kCardPadding = 14;

  /// chip 内边距（全族统一口径 h8/v3）
  static const double _kChipPadH = 8;
  static const double _kChipPadV = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(countdownRepositoryProvider);
    final t = context.theme;
    final running = row.status == 'running';
    final finished = row.status == 'finished';
    final paused = row.status == 'paused';
    final remaining = paused
        ? (row.pausedRemaining ?? 0)
        : ((row.endTime ?? 0) - nowMs);
    // 剩余时间全部由 R2 主行承载（`_countdownLine`）—— 2026-09-14 用户定：
    // **去掉图标盘外圈的进度环**（环形既看不出剩余比例，又和图标盘抢视觉）

    // 状态语义色：进行中=主题色（换肤联动）/ 已暂停=琥珀 / 已结束=绿（AppTokens.accent 板）
    final statusColor = finished
        ? AppTokens.accent(2)
        : paused
        ? AppTokens.accent(3)
        : t.colors.primary;
    final statusLabel = finished ? '已结束' : paused ? '已暂停' : '进行中';

    // 「指定时长」才有暂停/继续/重置；「指定时刻」目标时刻固定，计时类操作无语义
    final canTimeShift = (row.mode ?? 'duration') != 'datetime';

    // 长按 → 操作菜单（编辑 / 删除）；删除走危险确认抽屉
    Future<void> onLongPress() async {
      final action = await showSheetActionMenu<String>(
        context,
        title: row.name ?? '倒计时',
        actions: [
          const SheetAction('edit', '编辑', icon: FLucideIcons.pencil),
          const SheetAction(
            'delete',
            '删除',
            icon: FLucideIcons.trash2,
            destructive: true,
          ),
        ],
      );
      if (!context.mounted || action == null) return;
      if (action == 'edit') {
        // 编辑复用页面级表单入口（与新建同一函数，避免交互漂移）
        await _openForm(context, row);
        return;
      }
      if (action == 'delete') {
        final ok = await showSheetConfirm(
          context,
          title: '删除倒计时',
          message: '确定删除「${row.name ?? '倒计时'}」？删除后到点通知一并取消。',
        );
        if (ok) await repo.delete(row.key);
      }
    }

    return AppCard(
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(_kCardPadding),
      margin: EdgeInsets.zero,
      elevation: 1,
      // 三行结构：名称行 / 时间块 / 操作行
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // R1：状态图标盘 ＋ 名称 ＋ 状态 chip
          Row(
            children: [
              _iconTile(statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  row.name ?? '倒计时',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SoftChip(
                label: statusLabel,
                color: statusColor,
                alpha: 0.10,
                fontSize: 11,
                height: 1,
                padding: const EdgeInsets.symmetric(
                  horizontal: _kChipPadH,
                  vertical: _kChipPadV,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // R2：时间块占整宽 —— 主行 20/Bold ＋ 副行 12
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    finished
                        ? _targetText(row.endTime ?? 0)
                        : _countdownLine(remaining),
                    maxLines: 1,
                    style: t.typography.body.lg.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      // 已结束的「结束时刻」降级为中性灰 —— 已完成的事不抢眼
                      color: finished
                          ? t.colors.mutedForeground
                          : t.colors.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                finished
                    ? '已结束 · 时长 ${_durationLabel(row.duration ?? 0)}'
                    : paused
                    ? '已暂停 · 目标 ${_targetText(row.endTime ?? 0)}'
                    : '目标 ${_targetText(row.endTime ?? 0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // R3：设定方式 ＋ 提醒 chip ┈┈ 40×40 渐变圆钮组
          Row(
            children: [
              FlatBadge(label: canTimeShift ? '指定时长' : '指定时刻'),
              const SizedBox(width: 6),
              // 提醒 chip 真正读 row.notify（2026-09-14 修：此前恒渲染「提醒 · 声音」）
              (row.notify ?? '1') != '0'
                  ? SoftChip(
                      label: '提醒 · 声音',
                      color: statusColor,
                      alpha: 0.10,
                      fontSize: 11,
                      height: 1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: _kChipPadH,
                        vertical: _kChipPadV,
                      ),
                    )
                  : const FlatBadge(label: '不提醒'),
              const Spacer(),
              // 配色定稿（2026-09-13）：重置恒灰底灰图标、删除恒红浅底红图标；
              // 主操作随状态色（进行中=主题色 / 暂停恢复=琥珀）
              if (finished) ...[
                _CircleAction(
                  icon: FLucideIcons.trash2,
                  label: '删除',
                  bg: t.colors.destructive.withValues(alpha: 0.14),
                  fg: t.colors.destructive,
                  onTap: () => repo.delete(row.key),
                ),
                if (canTimeShift) ...[
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: FLucideIcons.rotateCcw,
                    label: '重置',
                    bg: t.colors.muted,
                    fg: t.colors.mutedForeground,
                    onTap: () => repo.reset(row),
                  ),
                ],
              ] else if (canTimeShift) ...[
                _CircleAction(
                  icon: FLucideIcons.rotateCcw,
                  label: '重置',
                  bg: t.colors.muted,
                  fg: t.colors.mutedForeground,
                  onTap: () => repo.reset(row),
                ),
                const SizedBox(width: 8),
                _CircleAction(
                  icon: running ? FLucideIcons.pause : FLucideIcons.play,
                  label: running ? '暂停' : '继续',
                  bg: running ? statusColor : AppTokens.accent(3),
                  fg: Colors.white,
                  onTap: () => running ? repo.pause(row) : repo.resume(row),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 状态图标盘（卡片族图标瓷片：状态色渐变 + 白图标 · 40×40 r13）
  Widget _iconTile(Color color) {
    return Container(
      width: _kTileSize,
      height: _kTileSize,
      decoration: BoxDecoration(
        gradient: AppTokens.accentGradient(color),
        borderRadius: BorderRadius.circular(_kTileRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        _statusIcon(row.status),
        size: _kTileIconSize,
        color: Colors.white,
      ),
    );
  }

  /// 状态 → 图标盘白图标（与待办 / 主题 / 笔记卡片族同源口径）
  IconData _statusIcon(String? status) => switch (status) {
    'paused' => FLucideIcons.circlePause,
    'finished' => FLucideIcons.circleCheck,
    _ => FLucideIcons.timer,
  };

  /// 目标时刻：今天显示 HH:mm；跨天显示 MM-dd 周E HH:mm（画布方案 B 定稿）
  String _targetText(int endMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(endMs);
    final now = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    final hm = '${p(dt.hour)}:${p(dt.minute)}';
    const week = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return sameDay
        ? hm
        : '${p(dt.month)}-${p(dt.day)} ${week[dt.weekday - 1]} $hm';
  }
}

/// 40×40 圆形操作钮（画布定稿：实心/软底圆 + 18px Lucide 图标居中留白）
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          width: 40,
          height: 40,
          // 渐变提层感：左上微亮 → 右下本色（2026-09-13 画布反馈）
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(bg, Colors.white, 0.22)!, bg],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}

/// 剩余毫秒 → 卡片主行文案：≥1 天 = `9天04:44:27`，否则固定三段 `04:44:27`
/// （补两位，等宽数字对齐跳动）。
/// ⚠️ **紧凑口径**（2026-09-14 用户两次实指）：冒号两侧不加空格（`00 : 59 : 54` →
/// `00:59:54`）、「天」与两侧数字也不加空格（`9 天 04:44:27` → `9天04:44:27`）。
String _countdownLine(int ms) {
  final totalSec = ms <= 0 ? 0 : (ms / 1000).ceil();
  final days = totalSec ~/ 86400;
  final hms = _hmsParts(ms).join(':');
  // 「天」与两侧数字**不留空格**（2026-09-14 用户：`9 天 04:44:27` 间隔太大）；
  // 「天」本身是 CJK 全角字形，自带侧边距，贴紧后仍有可读的呼吸
  return days > 0 ? '${days}天$hms' : hms;
}

/// 时长毫秒 → 人话（已结束副行）：最多取两个最大档
/// （30 分钟 / 1 小时 30 分钟 / 2 天 3 小时；不足 1 分钟兜底）。
String _durationLabel(int ms) {
  final totalSec = ms <= 0 ? 0 : (ms / 1000).round();
  final parts = <String>[
    if (totalSec ~/ 86400 > 0) '${totalSec ~/ 86400} 天',
    if (totalSec % 86400 ~/ 3600 > 0) '${totalSec % 86400 ~/ 3600} 小时',
    if (totalSec % 3600 ~/ 60 > 0) '${totalSec % 3600 ~/ 60} 分钟',
  ];
  if (parts.isEmpty) return '不到 1 分钟';
  return parts.take(2).join(' ');
}

/// 剩余毫秒 → 时:分:秒 三段数值（补两位字符串；天及以上由主行前置，不在此重复）
List<String> _hmsParts(int ms) {
  final totalSec = ms <= 0 ? 0 : (ms / 1000).ceil();
  String p(int v) => v.toString().padLeft(2, '0');
  return [
    p((totalSec % 86400) ~/ 3600),
    p((totalSec % 3600) ~/ 60),
    p(totalSec % 60),
  ];
}
