// 首页 Dashboard —— 今日概览 + 最近倒计时 + 快捷入口（对标主流效率 App 首页）
// forui 化：主色渐变概览卡 + 原子卡片 + FLucideIcons
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/ui_atoms.dart';
import '../providers/dashboard_providers.dart';

/// 首页
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const _quickEntries = [
    (FLucideIcons.keyRound, '2FA', '/twofactor'),
    (FLucideIcons.qrCode, '扫码', '/qr'),
    (FLucideIcons.listTodo, '记待办', '/todo'),
    (FLucideIcons.refreshCw, '同步', '/sync'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final t = context.theme;

    return FScaffold(
      header: const FHeader(title: Text('渐离')),
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          children: [
            // 今日概览卡（主色渐变横幅）
            statsAsync.maybeWhen(
              data: (s) => Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.colors.primary,
                      Color.lerp(t.colors.primary, Colors.black, 0.25)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatBlock(value: s.habitProgressLabel, label: '今日习惯', color: t.colors.primaryForeground),
                    StatBlock(value: '${s.todosActive}', label: '进行中待办', color: t.colors.primaryForeground),
                    StatBlock(value: '${s.pomodoroToday}', label: '今日专注', color: t.colors.primaryForeground),
                    StatBlock(value: '${s.remindersEnabled}', label: '活跃提醒', color: t.colors.primaryForeground),
                  ],
                ),
              ),
              orElse: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: FCircularProgress(),
                ),
              ),
            ),
            const SectionHeader(title: '快捷入口'),
            Row(
              children: [
                for (final (icon, label, route) in _quickEntries)
                  Expanded(
                    child: AppCard(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onTap: () => context.push(route),
                      child: Column(
                        children: [
                          Icon(icon, color: t.colors.primary, size: 22),
                          const SizedBox(height: 6),
                          Text(label, style: t.typography.body.sm),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // 最近倒计时
            statsAsync.maybeWhen(
              data: (s) => s.nextCountdownName == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        const SectionHeader(title: '正在倒计时'),
                        AppCard(
                          onTap: () => context.push('/countdown'),
                          child: Row(
                            children: [
                              const Icon(FLucideIcons.hourglass, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s.nextCountdownName!)),
                              Icon(FLucideIcons.chevronRight,
                                  size: 18, color: t.colors.mutedForeground),
                            ],
                          ),
                        ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SectionHeader(title: '效率'),
            AppCard(
              onTap: () => context.go('/efficiency'),
              child: Row(
                children: [
                  const Icon(FLucideIcons.zap, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('习惯 · 待办 · 番茄钟 · 倒计时 · 提醒')),
                  Icon(FLucideIcons.chevronRight, size: 18, color: t.colors.mutedForeground),
                ],
              ),
            ),
            const SectionHeader(title: '内容与工具'),
            AppCard(
              onTap: () => context.go('/content'),
              child: Row(
                children: [
                  const Icon(FLucideIcons.bookOpen, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('笔记 · 主题对话 · 电子书')),
                  Icon(FLucideIcons.chevronRight, size: 18, color: t.colors.mutedForeground),
                ],
              ),
            ),
            AppCard(
              onTap: () => context.go('/tools'),
              child: Row(
                children: [
                  const Icon(FLucideIcons.wrench, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('2FA · 密码 · 保险箱 · 二维码 · 同步')),
                  Icon(FLucideIcons.chevronRight, size: 18, color: t.colors.mutedForeground),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
