// 首页 Dashboard —— 2026 视觉重设计
//
// 结构：大标题问候（渐变徽章）→ 渐变英雄卡（装饰圆 + 数字滚动）→ 最近倒计时
//       → 专属色快捷磁贴 → 彩色分组入口卡；整页按节 stagger 入场。
// 视觉基调：页面底色叠主色冷调（pageTint），告别「纯白 + 白卡描边」。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/animated_stat.dart';
import '../../../app/ui/entry_card.dart';
import '../../../app/ui/settings_panel.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/tap_scale.dart';
import '../../../app/ui/ui_atoms.dart';
import '../providers/dashboard_providers.dart';
import '../../../core/sync/device_nickname.dart';

/// 首页
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  // 快捷磁贴：图标 / 标签 / 路由 / 专属色索引
  static const _quickEntries = [
    (FLucideIcons.keyRound, '2FA', '/twofactor', 0),
    (FLucideIcons.qrCode, '扫码', '/qr', 5),
    (FLucideIcons.listTodo, '记待办', '/todo', 2),
    (FLucideIcons.refreshCw, '同步', '/sync', 3),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return FScaffold(
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardStatsProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePaddingOf(context),
              16,
              AppTokens.pagePaddingOf(context),
              32,
            ),
            children: [
              StaggerList(
                delayStep: 70,
                children: [
                  const _Header(),
                  const SizedBox(height: 20),
                  statsAsync.maybeWhen(
                    data: (s) => Column(
                      children: [
                        _HeroCard(
                          habitLabel: s.habitProgressLabel,
                          todosActive: '${s.todosActive}',
                          pomodoroToday: '${s.pomodoroToday}',
                          remindersEnabled: '${s.remindersEnabled}',
                        ),
                        if (s.nextCountdownName != null) ...[
                          const SizedBox(height: 8),
                          EntryCard(
                            icon: FLucideIcons.hourglass,
                            title: s.nextCountdownName!,
                            subtitle: '正在倒计时',
                            accentIndex: 3,
                            onTap: () => context.push('/countdown'),
                          ),
                        ],
                      ],
                    ),
                    orElse: () => const _HeroPlaceholder(),
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader(title: '快捷入口'),
                  Row(
                    children: [
                      for (final (icon, label, route, accentIndex)
                          in _quickEntries)
                        Expanded(
                          child: _QuickTile(
                            icon: icon,
                            label: label,
                            route: route,
                            accentIndex: accentIndex,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader(title: '效率'),
                  EntryCard(
                    icon: FLucideIcons.zap,
                    title: '效率中心',
                    subtitle: '习惯 · 待办 · 番茄钟 · 倒计时 · 提醒',
                    accentIndex: 0,
                    onTap: () => context.go('/efficiency'),
                  ),
                  const SectionHeader(title: '内容与工具'),
                  EntryCard(
                    icon: FLucideIcons.bookOpen,
                    title: '内容库',
                    subtitle: '笔记 · 主题对话 · 电子书',
                    accentIndex: 4,
                    onTap: () => context.go('/content'),
                  ),
                  EntryCard(
                    icon: FLucideIcons.wrench,
                    title: '工具箱',
                    subtitle: '2FA · 密码 · 保险箱 · 二维码 · 同步',
                    accentIndex: 2,
                    onTap: () => context.go('/tools'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大标题问候：应用名 + 日期 + 渐变徽章
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final now = DateTime.now();
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localNickname,
                style: t.typography.body.lg.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${now.month} 月 ${now.day} 日 · 周${weeks[now.weekday - 1]}',
                style: t.typography.body.sm.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SettingsButton(),
      ],
    );
  }
}

/// 渐变英雄卡：装饰圆 + 四项统计（数字滚动）
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.habitLabel,
    required this.todosActive,
    required this.pomodoroToday,
    required this.remindersEnabled,
  });

  final String habitLabel;
  final String todosActive;
  final String pomodoroToday;
  final String remindersEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTokens.primaryGradient(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTokens.elevation(context, level: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(right: -36, top: -36, child: _decoCircle(120, 0.10)),
            Positioned(right: 44, bottom: -48, child: _decoCircle(96, 0.08)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(context, habitLabel, '今日习惯'),
                  _stat(context, todosActive, '进行中待办'),
                  _stat(context, pomodoroToday, '今日专注'),
                  _stat(context, remindersEnabled, '活跃提醒'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decoCircle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  Widget _stat(BuildContext context, String value, String label) {
    final t = context.theme;
    final fg = t.colors.primaryForeground;
    final valueStyle = t.typography.body.lg.copyWith(
      color: fg,
      fontSize: 22,
      fontWeight: FontWeight.w800,
    );
    final labelStyle = t.typography.body.xs.copyWith(
      color: fg.withValues(alpha: 0.75),
    );
    final numeric = double.tryParse(value) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (numeric)
          AnimatedStat(value: double.parse(value), style: valueStyle)
        else
          Text(value, style: valueStyle),
        const SizedBox(height: 4),
        Text(label, style: labelStyle),
      ],
    );
  }
}

/// 英雄卡加载占位（同形态渐变 + 转圈）
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        gradient: AppTokens.primaryGradient(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTokens.elevation(context, level: 3),
      ),
      child: const Center(child: FCircularProgress()),
    );
  }
}

/// 专属色快捷磁贴：强调色软底 + 渐变超椭圆图标
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.accentIndex,
  });

  final IconData icon;
  final String label;
  final String route;
  final int accentIndex;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(accentIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TapScale(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTokens.accentSoft(context, accent),
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          ),
          child: Column(
            children: [
              SquircleBox(
                size: 42,
                radius: 14,
                gradient: AppTokens.accentGradient(accent),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: t.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
