// 分组页（效率 / 内容 / 工具）—— 2026 视觉重设计
//
// 专属色入口卡（EntryCard：渐变超椭圆图标底盘）+ 页面底色冷调 + 分节 stagger 入场。
// 入口清单与桌面端「侧边栏分组」对齐；每个入口带专属强调色索引，个性不撞色。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui/entry_card.dart';
import '../../app/ui/settings_panel.dart';
import '../../app/ui/stagger_list.dart';

/// 入口元组：图标 / 标题 / 描述 / 路由 / 专属色索引
typedef _Entry = (IconData, String, String, String, int);

/// 「效率」分组页
class EfficiencyHubPage extends StatelessWidget {
  const EfficiencyHubPage({super.key});

  static const List<_Entry> _entries = [
    (FLucideIcons.calendarCheck, '习惯打卡', '每日习惯与连续打卡', '/habit', 2),
    (FLucideIcons.listTodo, '待办事项', '任务、子任务与重复', '/todo', 1),
    (FLucideIcons.timer, '番茄钟', '专注计时与记录统计', '/pomodoro', 6),
    (FLucideIcons.hourglass, '倒计时', '到点提醒的独立计时', '/countdown', 0),
    (FLucideIcons.bell, '提醒管理', '定点 / 周期 / 多状态', '/reminders', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: const Text('效率'),
        suffixes: const [SettingsButton()],
      ),
      child: _HubList(entries: _entries),
    );
  }
}

/// 「内容」分组页
class ContentHubPage extends StatelessWidget {
  const ContentHubPage({super.key});

  static const List<_Entry> _entries = [
    (FLucideIcons.notebookPen, '可归类笔记', '富文本笔记与分类', '/notes', 3),
    (FLucideIcons.messageSquareText, '主题对话', '情绪与主题记录', '/conversation', 4),
    (FLucideIcons.bookOpenText, '电子书', 'EPUB / TXT 阅读器', '/ebook', 5),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: const Text('内容'),
        suffixes: const [SettingsButton()],
      ),
      child: _HubList(entries: _entries),
    );
  }
}

/// 「工具」分组页
class ToolsHubPage extends StatelessWidget {
  const ToolsHubPage({super.key});

  static const List<_Entry> _entries = [
    (FLucideIcons.keyRound, '2FA 验证器', 'TOTP 动态码', '/twofactor', 0),
    (FLucideIcons.lock, '账号密码管理', '加密口令库', '/password-vault', 1),
    (FLucideIcons.shieldCheck, '私密文件保险箱', 'AES-256 加密存储', '/file-vault', 2),
    (FLucideIcons.qrCode, '二维码', '生成 / 识别 / 历史', '/qr', 3),
    (FLucideIcons.refreshCw, '局域网同步', '类 LocalSend 双端同步', '/sync', 5),
    (FLucideIcons.arrowLeftRight, '文件互传', '双端批量收发文件', '/file-transfer', 4),
    (FLucideIcons.scanQrCode, '隔空互传', '屏幕二维码 → 摄像头直传', '/ferry', 6),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: const Text('工具'),
        suffixes: const [SettingsButton()],
      ),
      child: _HubList(entries: _entries),
    );
  }
}

/// 分组页共用列表：底色冷调 + stagger 入场
class _HubList extends StatelessWidget {
  const _HubList({required this.entries});

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTokens.pageTint(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          8,
          AppTokens.pagePadding,
          32,
        ),
        children: [
          StaggerList(
            delayStep: 60,
            children: [
              for (final (icon, title, subtitle, route, accentIndex) in entries)
                EntryCard(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  accentIndex: accentIndex,
                  onTap: () => context.push(route),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
