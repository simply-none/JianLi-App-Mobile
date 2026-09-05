// 首页 Dashboard —— 今日概览 + 最近倒计时 + 快捷入口（对标主流效率 App 首页）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/ui_atoms.dart';
import '../providers/dashboard_providers.dart';

/// 首页
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const _quickEntries = [
    (Icons.enhanced_encryption_outlined, '2FA', '/twofactor'),
    (Icons.qr_code_2, '扫码', '/qr'),
    (Icons.add_task, '记待办', '/todo'),
    (Icons.sync_outlined, '同步', '/sync'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('渐离'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            // 今日概览卡
            statsAsync.maybeWhen(
              data: (s) => Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatBlock(
                      value: s.habitProgressLabel,
                      label: '今日习惯',
                      color: scheme.onPrimary,
                    ),
                    StatBlock(value: '${s.todosActive}', label: '进行中待办', color: scheme.onPrimary),
                    StatBlock(value: '${s.pomodoroToday}', label: '今日专注', color: scheme.onPrimary),
                    StatBlock(value: '${s.remindersEnabled}', label: '活跃提醒', color: scheme.onPrimary),
                  ],
                ),
              ),
              orElse: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            const SectionHeader(title: '快捷入口'),
            Row(
              children: [
                for (final (icon, label, route) in _quickEntries)
                  Expanded(
                    child: AppCard(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onTap: () => context.push(route),
                      child: Column(
                        children: [
                          Icon(icon, color: scheme.primary),
                          const SizedBox(height: 6),
                          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
                              const Icon(Icons.hourglass_top, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s.nextCountdownName!)),
                              Icon(Icons.chevron_right, color: scheme.outline),
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
              child: const Row(
                children: [
                  Icon(Icons.bolt_outlined),
                  SizedBox(width: 10),
                  Expanded(child: Text('习惯 · 待办 · 番茄钟 · 倒计时 · 提醒')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SectionHeader(title: '内容与工具'),
            AppCard(
              onTap: () => context.go('/content'),
              child: const Row(
                children: [
                  Icon(Icons.auto_stories_outlined),
                  SizedBox(width: 10),
                  Expanded(child: Text('笔记 · 主题对话 · 电子书')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            AppCard(
              onTap: () => context.go('/tools'),
              child: const Row(
                children: [
                  Icon(Icons.widgets_outlined),
                  SizedBox(width: 10),
                  Expanded(child: Text('2FA · 密码 · 保险箱 · 二维码 · 同步')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
