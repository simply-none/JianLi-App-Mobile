// 应用入口：初始化 Riverpod 容器并挂载根组件
// Material 导入统一用 material_ui（forui 建于其上，勿与 flutter/material 混用，见 SKILL.md）
// show 限定导入调试开关，避免与 material_ui 的导出符号冲突
import 'package:flutter/rendering.dart'
    show
        debugPaintSizeEnabled,
        debugPaintBaselinesEnabled,
        debugRepaintRainbowEnabled;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/notifications/notification_service.dart';
import 'core/sync/device_nickname.dart';

// —— 代码级 paint 调试开关（页面规范，默认全关）——
// 排查布局问题时把对应开关置 true 后热重载（r），用完记得关回 false。
// 仅 debug/profile 构建生效（release 下 assert 被剥离，无效果）。
// 配套的可视化调试面板：flutter run 控制台按 v 打开 DevTools → Widget Inspector。
const bool kDebugPaintSize = false; // 所有组件画青色边框 + padding 可视化（≈ CSS outline）
const bool kDebugPaintBaselines = false; // 文字基线（对齐排 troubleshooting 用）
const bool kDebugRepaintRainbow = false; // 重绘彩虹（颜色变化 = 发生了重绘，查多余重绘）

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = kDebugPaintSize;
  debugPaintBaselinesEnabled = kDebugPaintBaselines;
  debugRepaintRainbowEnabled = kDebugRepaintRainbow;
  // 预加载本机随机昵称（#昵称），保证首页 build 前缓存就绪
  await ensureNickname();
  // ⚠️ 必须在 runApp 前注册通知渠道，否则 reminders 排程的 createNotification 会因
  // channelKey 未注册而静默丢弃（表现 = 所有提醒都不弹系统通知）。awesome_notifications
  // 的 initialize 不依赖 BuildContext，可在 main 直接 await。
  await NotificationService.init();
  runApp(const ProviderScope(child: JianliApp()));
}
