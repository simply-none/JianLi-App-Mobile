// 首页 Dashboard —— 对齐画布「01b 首页·内容区改版」（390×844，ardot 文件 725406574448005 节点 3:1）
//
// 结构（画布规格）：状态栏 → 问候(22/Bold) + 日期(13/次要) → 英雄卡
//   (168 高 · 圆角 22 · 品牌渐变 + 背景纹理 · 「今日专注」时长 34/Bold + 习惯进度条 318×6)
//   → 效率概览 = 「今日节奏」整卡（三列指标 + 主色渐变迷你进度条 + 1px 竖分隔）
//   → 快捷入口 = 4 张白卡（语义强调色渐变瓷片 30×30 + 白图标 + 主/辅双行）
//   → 更多功能 = 单卡列表（主色渐变瓷片 34×34 + 白图标 + 标题/副标 + chevron + 行分隔线）。
// 内容区区块间距统一 20、卡头间距 12、左右边距 16；背景装饰（渐隐波浪 + 极淡圆/环）由 app.dart
// 根背板统一绘制，页面保持透明透出，无白边。底部导航由 main_shell 的 footer 预留高度。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/card_textures.dart';
import '../../../app/providers/theme_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/ui/banner_texture_sheet.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../core/sync/device_nickname.dart';
import '../providers/dashboard_providers.dart';
import '../widget_snapshot.dart';
import '../../reminder/components/reminder_guard_card.dart';

/// 快捷入口磁贴（图标 / 语义强调色索引 / 标签 / 副标 / 路由）——
/// 图标底盘 = 实色语义渐变瓷片 + 白色图标（对齐工具页视觉语言），
/// 语义色取 AppTokens.accents 强调色板（换肤安全：固定语义色不随 hue 平移）。
const _quickEntries = <(IconData, int, String, String, String)>[
  (FLucideIcons.keyRound, 1, '2FA', '动态口令', '/twofactor'),
  (FLucideIcons.qrCode, 3, '扫码', '识别记录', '/qr'),
  (FLucideIcons.listTodo, 2, '记待办', '快速记录', '/todo'),
  (FLucideIcons.refreshCw, 5, '同步', '数据同步', '/sync'),
];

/// 更多功能条目（图标 / 标题 / 副标 / 路由）—— 单卡列表化，
/// 图标 = 主色渐变瓷片 + 白色图标（跟随主题主色派生）。
const _moreEntries = <(IconData, String, String, String)>[
  (FLucideIcons.zap, '效率中心', '打卡 · 专注 · 统计报告', '/efficiency'),
  (FLucideIcons.bookOpen, '内容库', '笔记 · 对话 · 收藏', '/content'),
  (FLucideIcons.wrench, '工具箱', '密保 · 保险箱 · 2FA', '/tools'),
];

/// 首页
///
/// 数据自动刷新（2026-09-19）：dashboardStatsProvider 是普通 FutureProvider（永久缓存），
/// 而首页分支在底部导航 indexedStack 中**常驻挂载**——切 tab / push 子页都不会触发重建，
/// 所以必须自己感知「首页重新可见」并主动 invalidate：
/// ① go_router 导航 → 栈顶叶子路由变回 '/'（切 tab 返回 / 从功能页 pop 返回）；
/// ② App 回前台且停留在首页。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  /// 上一次栈顶叶子路由位置（null = 尚未采样；首个回调只采样、不刷新，避免冷启动双查）。
  String? _lastLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ② 回前台且停留在首页 → 刷新一次（覆盖后台过夜 / 同步改了数据后回 App）。
    if (state == AppLifecycleState.resumed && _topMatchedLocation() == '/') {
      ref.invalidate(dashboardStatsProvider);
    }
  }

  /// ① 每次导航通知：栈顶叶子路由变回 '/'（首页重新可见）时刷新聚合数据。
  /// 刷新期间旧数据由 AsyncValue 默认的 skipLoadingOnRefresh:true 保留（不闪占位骨架）。
  void _onRouteChanged() {
    final location = _topMatchedLocation();
    final last = _lastLocation;
    _lastLocation = location;
    if (location == '/' && last != null && last != '/') {
      ref.invalidate(dashboardStatsProvider);
    }
  }

  /// 栈顶叶子路由的匹配位置：穿透 ShellRouteMatch（底部导航壳）逐层取 matches.last，
  /// 直到 RouteMatch（push 出来的 ImperativeRouteMatch 也算叶子）——
  /// 这个值对「切 tab / push / pop（含系统返回手势）」都实时正确，
  /// 而 currentConfiguration.uri 会跳过 push 产生的 ImperativeRouteMatch（pop 回首页时探测不到）。
  String _topMatchedLocation() {
    RouteMatchBase m = appRouter.routerDelegate.currentConfiguration.last;
    while (m is ShellRouteMatch) {
      m = m.matches.last;
    }
    return m.matchedLocation;
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    // P0-2 桌面小组件：聚合统计每次变化（进页/切回/回前台自动刷新触发）即写快照
    // 并触发原生重绘。ref.listen 必须写在 build（红线）；fire-and-forget，失败静默。
    ref.listen<AsyncValue<DashboardStats>>(dashboardStatsProvider, (prev, next) {
      final s = next.value;
      if (s != null) updateTodayWidget(s);
    });

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        // 顶部安全区：滚动区限制在状态栏之下
        child: SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            // refresh(.future) 返回真正的查询 Future：下拉转圈等数据实际到位后才收起
            onRefresh: () => ref.refresh(dashboardStatsProvider.future),
            child: ListView(
              // 画布：左右 16 · 顶 8 · 底 24（底部导航由 footer 预留，无需画布的 96）
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _Header(),
                const SizedBox(height: 20),
                statsAsync.maybeWhen(
                  data: (s) => Column(
                    children: [
                      _HeroCard(stats: s),
                      // 进行中的倒计时：沿用改动前的「下次倒计时」入口（无则整条不出现）
                      if (s.nextCountdownName != null) ...[
                        const SizedBox(height: 12),
                        _CountdownBanner(name: s.nextCountdownName!),
                      ],
                    ],
                  ),
                  orElse: () => const _HeroPlaceholder(),
                ),
                // —— 效率概览（改版：整卡「今日节奏」，三列指标 + 主色渐变迷你进度条） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '效率概览'),
                const SizedBox(height: 12),
                statsAsync.maybeWhen(
                  data: (s) => _PaceCard(stats: s),
                  orElse: () => const _PaceCardPlaceholder(),
                ),
                // —— 提醒守护（共享组件：首页 + 提醒列表页共用单一真源） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '提醒守护'),
                const SizedBox(height: 12),
                const ReminderGuardCard(padding: EdgeInsets.zero),
                // —— 快捷入口（改版：语义渐变瓷片 + 白图标 + 主/辅双行文字） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '快捷入口'),
                const SizedBox(height: 12),
                const _QuickRow(entries: _quickEntries),
                // —— 更多功能（改版：单卡列表，主色瓷片行 + chevron + 行分隔线） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '更多功能'),
                const SizedBox(height: 12),
                const _MoreCard(entries: _moreEntries),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「今日节奏」整卡（效率概览改版）：卡头标题 + 三列指标
/// （标签 11/次要 · 数值 17/Bold · 主色渐变迷你进度条），列间 1px 分隔线。
class _PaceCard extends StatelessWidget {
  const _PaceCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final habitProgress = stats.habitsTotal == 0
        ? 0.0
        : (stats.habitsDoneToday / stats.habitsTotal).clamp(0.0, 1.0);
    // 番茄钟条形比例的参考目标：8 轮/日（展示用启发值，仅驱动进度条比例）
    const pomoGoal = 8;
    final pomoProgress = (stats.pomodoroToday / pomoGoal).clamp(0.0, 1.0);
    final todoDone = (stats.todosTotal - stats.todosActive).clamp(
      0,
      stats.todosTotal,
    );
    final todoProgress = stats.todosTotal == 0
        ? 0.0
        : (todoDone / stats.todosTotal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: t.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '今日节奏',
            style: t.typography.body.md.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: t.colors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    label: '习惯',
                    value: '${stats.habitsDoneToday} / ${stats.habitsTotal}',
                    progress: habitProgress,
                  ),
                ),
                _vDivider(context),
                Expanded(
                  child: _metric(
                    context,
                    label: '番茄钟',
                    value: '${stats.pomodoroToday} 轮',
                    progress: pomoProgress,
                  ),
                ),
                _vDivider(context),
                Expanded(
                  child: _metric(
                    context,
                    label: '待办',
                    value: '${stats.todosActive} 项',
                    progress: todoProgress,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单列指标：标签 / 数值 / 迷你进度条（轨道 border 色，填充 = 主色渐变）
  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required double progress,
  }) {
    final t = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: t.typography.body.xs.copyWith(
            fontSize: 11,
            color: t.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.typography.body.md.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.colors.foreground,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: t.colors.border),
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTokens.accentGradient(t.colors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vDivider(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: context.theme.colors.border,
  );
}

/// 「今日节奏」加载占位（同形态卡片 + 转圈）
class _PaceCardPlaceholder extends StatelessWidget {
  const _PaceCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: t.colors.border),
      ),
      child: const Center(child: FCircularProgress()),
    );
  }
}

/// 一排快捷入口磁贴（4 列等分、等高，外层 IntrinsicHeight + stretch）。
class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.entries});

  final List<(IconData, int, String, String, String)> entries;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                icon: entries[i].$1,
                accent: AppTokens.accent(entries[i].$2),
                title: entries[i].$3,
                subtitle: entries[i].$4,
                route: entries[i].$5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个快捷入口磁贴：实色语义渐变瓷片（30×30 · r10）+ 白色图标，
/// 下方主标签 13/SemiBold + 副标 10/次要。
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return TapScale(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: t.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppTokens.accentGradient(accent),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.body.sm.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.colors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.body.xs.copyWith(
                fontSize: 10,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「更多功能」单卡列表：每行 = 主色渐变瓷片（34×34 · r11）+ 白图标
/// + 标题 13.5/SemiBold + 副标 11/次要 + 右侧 chevron，行间 1px 分隔线。
class _MoreCard extends StatelessWidget {
  const _MoreCard({required this.entries});

  final List<(IconData, String, String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: t.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Container(height: 1, color: t.colors.border),
            _MoreRow(
              icon: entries[i].$1,
              title: entries[i].$2,
              subtitle: entries[i].$3,
              route: entries[i].$4,
            ),
          ],
        ],
      ),
    );
  }
}

/// 「更多功能」单行条目（整行可点）
class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return TapScale(
      // ⚠️ 三个 hub（效率中心/内容库/工具箱）是底部导航的分支根路由：
      // 必须用 go 切换分支（底部 tab 同步高亮、indexedStack 保状态），
      // 不能 push —— push 会把 hub 页压进首页分支的栈，导航还停在「首页」。
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppTokens.accentGradient(t.colors.primary),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 11,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              FLucideIcons.chevronRight,
              size: 16,
              color: t.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// 问候 + 日期（画布：greeting 22/Bold，date 13/次要）
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final now = DateTime.now();
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    final greeting = switch (now.hour) {
      >= 5 && < 12 => '早上好',
      >= 12 && < 18 => '下午好',
      _ => '晚上好',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting，$localNickname',
          style: t.typography.body.lg.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: t.colors.foreground,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${now.month}月${now.day}日 星期${weeks[now.weekday - 1]}',
          style: t.typography.body.sm.copyWith(
            fontSize: 13,
            color: t.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// 区块标题：左侧色条 3×16(r1.5) + 标题 16/Bold（画布 section）
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: t.colors.primary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: t.typography.body.md.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: t.colors.foreground,
          ),
        ),
      ],
    );
  }
}

/// 英雄卡（画布 hero：fill×168 · r22 · 渐变 + 背景纹理 · 阴影 y6/b16）
/// 整卡可点击切换背景纹理（独立于功能页横幅，走 homeHeroTextureProvider）。
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final fg = t.colors.primaryForeground;
    final tex = ref.watch(homeHeroTextureProvider).value ?? CardTextures.heroAsset;
    final total = stats.habitsTotal;
    final done = stats.habitsDoneToday;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final habitLeft = (total - done).clamp(0, total);

    return GestureDetector(
      onTap: () => showBannerTextureSheet(
        context,
        currentAsset: tex,
        onPick: (asset) =>
            ref.read(homeHeroTextureProvider.notifier).set(asset),
      ),
      child: Container(
        height: 168,
      decoration: BoxDecoration(
        gradient: AppTokens.primaryGradient(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景纹理：画布节点 8:160「素材装饰」—— 358×168 · r22 · FILL 居中裁切；
            // 合成不透明度 = 填充 0.56 × 节点 0.35（见 CardTextures）
            Opacity(
              opacity: CardTextures.composedOpacity,
              child: Image(
                image: AssetImage(tex),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // 装饰圆 deco2（60Ø · 白 16%，画布 x300 y96）
            Positioned(
              right: -2,
              top: 96,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withValues(alpha: 0.16),
                ),
              ),
            ),
            // label 13（画布 20,20）
            Positioned(
              left: 20,
              top: 20,
              child: Text(
                '今日专注',
                style: t.typography.body.sm.copyWith(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.9),
                ),
              ),
            ),
            // big 34/Bold（画布 20,46）
            Positioned(
              left: 20,
              top: 44,
              child: Text(
                _fmtFocus(stats.pomodoroTodayMinutes),
                style: t.typography.body.lg.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            // sub 13（画布 20,96）
            Positioned(
              left: 20,
              top: 94,
              child: Text(
                '$habitLeft 个习惯待打卡 · ${stats.todosActive} 项待办',
                style: t.typography.body.sm.copyWith(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ),
            // 进度条（画布：轨道 318×6 r3 白22%，填充 196/318 白95%，位于 y132）
            Positioned(
              left: 20,
              right: 20,
              top: 132,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(color: fg.withValues(alpha: 0.22)),
                    FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(color: fg.withValues(alpha: 0.95)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// 今日专注时长格式化：以标准 25 分钟/轮折算（`2h 14m` 形态，与画布一致）。
  String _fmtFocus(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

/// 英雄卡加载占位（同形态渐变 + 转圈）
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: AppTokens.primaryGradient(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(child: FCircularProgress()),
    );
  }
}

/// 进行中的倒计时入口（原首页 hero 下方的 EntryCard，样式改为与磁贴同族的白卡）
class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return TapScale(
      onTap: () => context.push('/countdown'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTokens.accentSoft(context, t.colors.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                FLucideIcons.hourglass,
                size: 20,
                color: t.colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.md.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '正在倒计时',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              FLucideIcons.chevronRight,
              size: 18,
              color: t.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
