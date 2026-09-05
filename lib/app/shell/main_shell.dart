// 主壳：forui 底部导航 + 四分支（StatefulShellRoute 保持各 Tab 状态）
//
// 信息架构对标主流效率 App：
//   首页（聚合概览）/ 效率（打卡·待办·番茄钟·倒计时·提醒）/ 内容（笔记·对话·书）/ 工具（2FA·保险箱·密码·二维码·同步）
// forui 约定：FBottomNavigationBar 只能放 FScaffold.footer（不是 Material Scaffold 的 bottomNavigationBar），
// 选中态由 bar 的 index/onChange 驱动，item 本身无 onPress。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 底部导航 destinations 顺序与路由 branches 一一对应
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (FLucideIcons.house, '首页'),
    (FLucideIcons.zap, '效率'),
    (FLucideIcons.bookOpen, '内容'),
    (FLucideIcons.wrench, '工具'),
  ];

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      // childPad 关闭：各 Tab 页面用自身 FScaffold 的 childPad 管理内边距
      childPad: false,
      footer: FBottomNavigationBar(
        index: navigationShell.currentIndex,
        onChange: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        children: [
          for (final (icon, label) in _destinations)
            FBottomNavigationBarItem(icon: Icon(icon), label: Text(label)),
        ],
      ),
      child: navigationShell,
    );
  }
}
