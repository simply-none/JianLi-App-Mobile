// 番茄钟记录页 —— 对齐待办列表页骨架（图1：主题色横幅统计 + 吸顶搜索行 + 分段 Tab + 列表）
//
// 骨架（interaction-patterns.md §三 / todo_page.dart 先例）：
//   头部    ‹22 · 番茄钟记录18/Bold
//   统计横幅 PageBanner 主色渐变 · r22 · stats 今日专注/近 7 天/累计记录（取数逻辑不变）
//   搜索行  ★吸顶锚点，按 label 实时过滤
//   Tab 栏  ScopeTabBar：全部 / 专注 / 休息（按 value 前端过滤，随滚动移出）
//   列表    待办卡片样式（r16 + 类型 SoftChip + 时间 11/muted，work/rest 图标盘语义色保留）
// 统计 FutureBuilder / 流水 StreamBuilder 数据流原样保留；图表视图仍在 PC 端（P2 对齐）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/card_textures.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/scope_tab_bar.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/pomodoro_records_repository.dart';

/// Tab 类型范围（按 value）
const List<(String, String)> kPomodoroRecordTabs = [
  ('all', '全部'),
  ('work', '专注'),
  ('rest', '休息'),
];

/// 番茄钟记录页
class PomodoroRecordsPage extends ConsumerStatefulWidget {
  const PomodoroRecordsPage({super.key});

  @override
  ConsumerState<PomodoroRecordsPage> createState() =>
      _PomodoroRecordsPageState();
}

class _PomodoroRecordsPageState extends ConsumerState<PomodoroRecordsPage> {
  Future<PomodoroStats>? _stats;

  /// 页内搜索关键词（实时过滤 label/时间）
  String _search = '';

  /// Tab 类型范围
  String _tab = 'all';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stats = ref.read(appDatabaseProvider).loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
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
                child: FutureBuilder<PomodoroStats>(
                  future: _stats,
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    return StreamBuilder<List<PomodoroStatusData>>(
                      stream: db.watchRecords(),
                      builder: (context, snap) {
                        final records = snap.data ?? const [];
                        return _body(context, records, stats);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== 头部（对齐待办：‹ / 标题） =====================

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
              '番茄钟记录',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 主体（图1 骨架） =====================

  Widget _body(
    BuildContext context,
    List<PomodoroStatusData> records,
    PomodoroStats? stats,
  ) {
    // 页内过滤：关键词（label/时间）+ 类型 Tab（不动数据层）
    final keyword = _search.trim().toLowerCase();
    final scoped = [
      for (final r in records)
        if ((_tab == 'all' || r.value == _tab) &&
            (keyword.isEmpty ||
                (r.label ?? '').toLowerCase().contains(keyword) ||
                (r.createTime ?? '').contains(keyword)))
          r,
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(context, records, stats)),
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedSearchHeader(
            extent: kSearchRowExtent,
            child: PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索记录…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ScopeTabBar<String>(
            tabs: kPomodoroRecordTabs,
            selected: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
        if (records.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: FLucideIcons.history,
              title: '暂无记录',
              subtitle: '番茄钟启动/切阶段后自动写入流水',
            ),
          )
        else if (scoped.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              icon: FLucideIcons.listFilter,
              title: '没有匹配的记录',
              subtitle: '换个关键词，或切换上方类型 Tab',
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
                for (final r in scoped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecordTile(record: r),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  /// 统计横幅（主色渐变，与待办同款；取数逻辑不变）
  Widget _banner(
    BuildContext context,
    List<PomodoroStatusData> records,
    PomodoroStats? stats,
  ) => PageBanner(
    icon: FLucideIcons.timer,
    title: '专注统计',
    subtitle: '番茄钟流水概览',
    gradient: AppTokens.primaryGradient(context),
    cornerRadius: 22,
    textureAsset: CardTextures.texture11,
    ringDecor: true,
    shadow: false,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    stats: [
      ('${stats?.todayWorkCount ?? 0}', '今日专注'),
      ('${stats?.weekWorkCount ?? 0}', '近 7 天'),
      ('${stats?.totalCount ?? 0}', '累计记录'),
    ],
  );
}

/// 单条流水行（待办 tile 同款：r16 卡 + 类型 SoftChip + 时间；work/rest 图标盘语义色保留）
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final PomodoroStatusData record;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final isWork = record.value == 'work';
    // 类型语义色与番茄钟页同口径：专注=番茄红 / 休息=绿
    final typeColor = isWork
        ? AppTokens.accent(6)
        : record.value == 'rest'
        ? AppTokens.accent(2)
        : t.colors.mutedForeground;
    final typeLabel = record.value == 'work'
        ? '专注'
        : record.value == 'rest'
        ? '休息'
        : (record.value ?? '记录');

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      elevation: 1,
      child: Row(
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(typeColor),
            alignment: Alignment.center,
            child: Icon(
              isWork ? FLucideIcons.briefcase : FLucideIcons.coffee,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: Text(
                        record.label ?? record.value ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.typography.body.sm.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SoftChip(label: typeLabel, color: typeColor),
                  ],
                ),
                if (record.createTime?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.createTime ?? '',
                    style: t.typography.body.xs.copyWith(
                      fontSize: 11,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (record.mode?.isNotEmpty ?? false)
            Text(
              record.mode ?? '',
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                color: t.colors.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
