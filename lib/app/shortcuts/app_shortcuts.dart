// P0-4 快捷动作分发（统一入口）
//
// 来源两条，都走同一条「quick_action extra → Dart 分发」管道：
//   ① 长按图标快捷方式 = Android 原生**静态 shortcuts**（res/xml/shortcuts.xml +
//      manifest MainActivity 内 meta-data「android.app.shortcuts」），每条 intent
//      带 quick_action extra；
//   ② 快捷磁贴「渐离打卡」= JianliQuickTileService 拉起 MainActivity 带同名 extra。
// 两条都在 MainActivity（onCreate/onNewIntent）暂存进 companion pendingQuickAction，
// Dart 侧经 SystemActionsChannel.takeQuickAction 拉走（冷启动 postFrame + resumed
// 各轮询一次，取走即清空）后调本函数路由。
//
// ⚠️ 为什么不用 quick_actions 包做动态快捷方式：pub 解析落到了 1.1.1（无 setItems
// API，2026-09-19 实测编译错），且静态 shortcuts 零依赖、与磁贴共用一条 extra 管道，
// 维护面更小。改快捷方式文案/图标：res/xml/shortcuts.xml + res/values/strings.xml。
import '../router/app_router.dart';

/// 分发快捷动作到对应功能页（动作名与 shortcuts.xml 的 extra value 一一对应）
void handleAppShortcut(String action) {
  switch (action) {
    case 'new_note':
      appRouter.push('/notes/edit'); // 无 noteKey = 直接进新建
    case 'scan':
      appRouter.push('/qr');
    case 'focus':
      appRouter.push('/pomodoro');
    case 'habit':
      appRouter.push('/habit');
  }
}
