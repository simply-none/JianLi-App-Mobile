// 「效率」分组页 —— 习惯 / 待办 / 番茄钟 / 倒计时 / 提醒 的入口宫格
//
// 对齐桌面端侧边栏「效率工具」分组的移动端信息架构；
// 入口卡片使用统一视觉（图标 + 名称 + 描述），点击 push 对应路由。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/ui/ui_atoms.dart';

/// 效率分组
class EfficiencyHubPage extends StatelessWidget {
  const EfficiencyHubPage({super.key});

  static const _entries = [
    (Icons.event_available, '习惯打卡', '每日习惯与连续打卡', '/habit'),
    (Icons.checklist, '待办事项', '任务、子任务与重复', '/todo'),
    (Icons.timer, '番茄钟', '专注计时与记录统计', '/pomodoro'),
    (Icons.hourglass_bottom, '倒计时', '到点提醒的独立计时', '/countdown'),
    (Icons.notifications_active_outlined, '提醒管理', '定点 / 周期 / 多状态', '/reminders'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('效率')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final (icon, title, subtitle, route) in _entries)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(14),
              onTap: () => context.push(route),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 「内容」分组页 —— 笔记 / 主题对话 / 电子书
class ContentHubPage extends StatelessWidget {
  const ContentHubPage({super.key});

  static const _entries = [
    (Icons.notes, '可归类笔记', '富文本笔记与分类', '/notes'),
    (Icons.forum_outlined, '主题对话', '情绪与主题记录', '/conversation'),
    (Icons.menu_book_outlined, '电子书', 'EPUB / TXT 阅读器', '/ebook'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('内容')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final (icon, title, subtitle, route) in _entries)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(14),
              onTap: () => context.push(route),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Theme.of(context).colorScheme.onTertiaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 「工具」分组页 —— 2FA / 密码管理 / 文件保险箱 / 二维码 / 局域网同步
class ToolsHubPage extends StatelessWidget {
  const ToolsHubPage({super.key});

  static const _entries = [
    (Icons.enhanced_encryption_outlined, '2FA 验证器', 'TOTP 动态码', '/twofactor'),
    (Icons.password_outlined, '账号密码管理', '加密口令库', '/password-vault'),
    (Icons.folder_special_outlined, '私密文件保险箱', 'AES-256 加密存储', '/file-vault'),
    (Icons.qr_code_2, '二维码', '生成 / 识别 / 历史', '/qr'),
    (Icons.sync_outlined, '局域网同步', '类 LocalSend 双端同步', '/sync'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final (icon, title, subtitle, route) in _entries)
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(14),
              onTap: () => context.push(route),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
