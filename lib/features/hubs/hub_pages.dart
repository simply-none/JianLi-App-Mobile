// 分组页（效率 / 内容 / 工具）—— 功能入口卡片列表
//
// 对齐桌面端侧边栏分组的移动端信息架构；
// 入口卡片统一视觉（图标 + 名称 + 描述 + 箭头），点击 push 对应路由。
// 三页结构一致，抽出 _HubTile 共用；取色一律 forui token。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/ui/ui_atoms.dart';

/// 分组入口卡（图标 + 标题 + 描述 + 箭头）
class _HubTile extends StatelessWidget {
  const _HubTile({
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
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(route),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: t.colors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.typography.body.md.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
                ),
              ],
            ),
          ),
          Icon(FLucideIcons.chevronRight, size: 18, color: t.colors.mutedForeground),
        ],
      ),
    );
  }
}

/// 「效率」分组页
class EfficiencyHubPage extends StatelessWidget {
  const EfficiencyHubPage({super.key});

  static const _entries = [
    (FLucideIcons.calendarCheck, '习惯打卡', '每日习惯与连续打卡', '/habit'),
    (FLucideIcons.listTodo, '待办事项', '任务、子任务与重复', '/todo'),
    (FLucideIcons.timer, '番茄钟', '专注计时与记录统计', '/pomodoro'),
    (FLucideIcons.hourglass, '倒计时', '到点提醒的独立计时', '/countdown'),
    (FLucideIcons.bell, '提醒管理', '定点 / 周期 / 多状态', '/reminders'),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('效率')),
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          for (final (icon, title, subtitle, route) in _entries)
            _HubTile(icon: icon, title: title, subtitle: subtitle, route: route),
        ],
      ),
    );
  }
}

/// 「内容」分组页
class ContentHubPage extends StatelessWidget {
  const ContentHubPage({super.key});

  static const _entries = [
    (FLucideIcons.notebookPen, '可归类笔记', '富文本笔记与分类', '/notes'),
    (FLucideIcons.messageSquareText, '主题对话', '情绪与主题记录', '/conversation'),
    (FLucideIcons.bookOpenText, '电子书', 'EPUB / TXT 阅读器', '/ebook'),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('内容')),
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          for (final (icon, title, subtitle, route) in _entries)
            _HubTile(icon: icon, title: title, subtitle: subtitle, route: route),
        ],
      ),
    );
  }
}

/// 「工具」分组页
class ToolsHubPage extends StatelessWidget {
  const ToolsHubPage({super.key});

  static const _entries = [
    (FLucideIcons.keyRound, '2FA 验证器', 'TOTP 动态码', '/twofactor'),
    (FLucideIcons.lock, '账号密码管理', '加密口令库', '/password-vault'),
    (FLucideIcons.shieldCheck, '私密文件保险箱', 'AES-256 加密存储', '/file-vault'),
    (FLucideIcons.qrCode, '二维码', '生成 / 识别 / 历史', '/qr'),
    (FLucideIcons.refreshCw, '局域网同步', '类 LocalSend 双端同步', '/sync'),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('工具')),
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          for (final (icon, title, subtitle, route) in _entries)
            _HubTile(icon: icon, title: title, subtitle: subtitle, route: route),
        ],
      ),
    );
  }
}
