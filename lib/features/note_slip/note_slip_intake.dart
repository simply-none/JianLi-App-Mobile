// P1-6 小纸条 —— 一次性意图（通知点击 → 直达详情）
//
// 与 P0-3 分享接收（pendingShareProvider）同款形态：通知的顶层回调跑在 isolate 里、
// 无法直接导航，故把「要打开哪条」写进这个 Notifier，由根组件（app.dart）监听后 push 路由。
// 消费即清空，绝不重复弹出。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 待打开的小纸条主键（null = 无待处理）
final NotifierProvider<NoteSlipIntakeController, String?>
    pendingSlipKeyProvider =
    NotifierProvider<NoteSlipIntakeController, String?>(
  NoteSlipIntakeController.new,
);

/// 小纸条一次性意图控制器
class NoteSlipIntakeController extends Notifier<String?> {
  @override
  String? build() => null;

  /// 请求打开某条小纸条
  void request(String key) => state = key;

  /// 消费（页面已处理）
  void consume() => state = null;
}
