// 主壳：底部导航 + 四分支（StatefulShellRoute 保持各 Tab 状态）
//
// 信息架构对标主流效率 App：
//   首页（聚合概览）/ 效率（打卡·待办·番茄钟·倒计时·提醒）/ 内容（笔记·对话·书）/ 工具（2FA·保险箱·密码·二维码·同步）
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部导航 destinations 顺序与路由 branches 一一对应
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, '首页'),
    (Icons.bolt_outlined, Icons.bolt, '效率'),
    (Icons.auto_stories_outlined, Icons.auto_stories, '内容'),
    (Icons.widgets_outlined, Icons.widgets, '工具'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          for (final (icon, activeIcon, label) in _destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(activeIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}
