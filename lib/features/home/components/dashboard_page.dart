// 首页 Dashboard —— 1:1 对齐画布「01 首页·浅色」（390×844，ardot 文件 724742991017068 节点 5:26）
//
// 结构（画布规格）：状态栏 → 问候(22/Bold) + 日期(13/次要) → 英雄卡
//   (168 高 · 圆角 22 · 品牌渐变 + 背景纹理 · 「今日专注」时长 34/Bold + 习惯进度条 318×6)
//   → 区块标题(色条 3×16 + 16/Bold) + 三宫格磁贴（效率概览 / 快捷入口 / 更多功能 同一套样式）。
// 内容区 itemSpacing 统一 20、左右边距 16；背景装饰（渐隐波浪 + 极淡圆/环）由 app.dart
// 根背板统一绘制，页面保持透明透出，无白边。底部导航由 main_shell 的 footer 预留高度。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/card_textures.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../core/sync/device_nickname.dart';
import '../providers/dashboard_providers.dart';

/// 快捷入口磁贴（图标 / 标签 / 副标 / 路由）—— 与改动前的首页 4 个入口一致，
/// 样式改套「效率概览」同款磁贴；4 列窄格放不下副标，此处副标留空（dense 模式不渲染）。
const _quickEntries = <(IconData, String, String, String)>[
  (FLucideIcons.keyRound, '2FA', '', '/twofactor'),
  (FLucideIcons.qrCode, '扫码', '', '/qr'),
  (FLucideIcons.listTodo, '记待办', '', '/todo'),
  (FLucideIcons.refreshCw, '同步', '', '/sync'),
];

/// 更多功能磁贴（图标 / 标题 / 副标 / 路由）
const _moreEntries = <(IconData, String, String, String)>[
  (FLucideIcons.zap, '效率中心', '打卡 · 专注', '/efficiency'),
  (FLucideIcons.bookOpen, '内容库', '笔记 · 对话', '/content'),
  (FLucideIcons.wrench, '工具箱', '密保 · 保险箱', '/tools'),
];

/// 首页
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        // 顶部安全区：滚动区限制在状态栏之下
        child: SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardStatsProvider),
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
                // —— 效率概览（画布原区块） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '效率概览'),
                const SizedBox(height: 20),
                statsAsync.maybeWhen(
                  data: (s) => _TileRow(entries: _overviewEntries(s)),
                  orElse: () => const _TilesPlaceholder(),
                ),
                // —— 快捷入口（原 4 个快捷磁贴，套用与效率概览一致的样式） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '快捷入口'),
                const SizedBox(height: 20),
                const _TileRow.dense(entries: _quickEntries),
                // —— 更多功能（原「效率 / 内容与工具」入口，套用与效率概览一致的样式） ——
                const SizedBox(height: 20),
                const _SectionHeader(title: '更多功能'),
                const SizedBox(height: 20),
                const _TileRow(entries: _moreEntries),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 效率概览磁贴（数据驱动）
List<(IconData, String, String, String)> _overviewEntries(DashboardStats s) => [
  (
    FLucideIcons.calendarCheck,
    '习惯',
    '今日 ${s.habitsDoneToday} / ${s.habitsTotal}',
    '/habit',
  ),
  (
    FLucideIcons.timer,
    '番茄钟',
    '${s.pomodoroToday} 轮 · ${s.pomodoroToday * 25}m',
    '/pomodoro',
  ),
  (FLucideIcons.listTodo, '待办', '${s.todosActive} 项待处理', '/todo'),
];

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
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final fg = t.colors.primaryForeground;
    final total = stats.habitsTotal;
    final done = stats.habitsDoneToday;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final habitLeft = (total - done).clamp(0, total);

    return Container(
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
            const Opacity(
              opacity: CardTextures.composedOpacity,
              child: Image(
                image: AssetImage(CardTextures.heroAsset),
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
                _fmtFocus(stats.pomodoroToday * 25),
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

/// 一排磁贴（等分撑满；3 列间距 12 / 4 列（dense）间距 8）。
/// 外层 IntrinsicHeight + stretch 保证同一行磁贴等高（副标换行也不会参差）。
class _TileRow extends StatelessWidget {
  const _TileRow({required this.entries}) : dense = false;

  const _TileRow.dense({required this.entries}) : dense = true;

  final List<(IconData, String, String, String)> entries;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final gap = dense ? 8.0 : 12.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: _Tile(
                icon: entries[i].$1,
                title: entries[i].$2,
                subtitle: entries[i].$3,
                route: entries[i].$4,
                dense: dense,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个磁贴（画布：fill · r16 · 卡底 · pad14 · itemSpacing6；图标 22 主色，标题 15/Bold，副标 12/次要）
/// dense（4 列）时改为居中、收紧内边距与字号，避免窄格挤压换行。
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return TapScale(
      onTap: () => context.push(route),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 14,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: dense
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 20 : 22, color: t.colors.primary),
            SizedBox(height: dense ? 8 : 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: dense ? TextAlign.center : TextAlign.left,
              style: t.typography.body.md.copyWith(
                fontSize: dense ? 13 : 15,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
            if (!dense) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 磁贴加载占位（3 个等高空卡）
class _TilesPlaceholder extends StatelessWidget {
  const _TilesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: t.colors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
