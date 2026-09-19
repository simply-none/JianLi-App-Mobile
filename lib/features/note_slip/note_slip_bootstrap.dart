// P1-6 小纸条 —— 接收引导（冷启动 / 进页面两种时机）
//
// 背景：移动端 47124 数据面与 UDP 响应器原本只在「同步页 / 文件互传页」首次打开时才启动，
// 不开页面就收不到 PC 推来的小纸条。本文件把「何时拉起接收能力」收口成一处：
//
//   [registerRoutes]  注册 /slip/* 路由（幂等）——**任何模式下都必须调用**，
//                     否则即使数据面由别的页面拉起，请求也会落到 404。
//   [ensureDataPlane] 拉起数据面 + UDP 响应器（幂等）——仅「常驻模式」调用。
//
// 两种模式（用户在小纸条页切换，存 basic_info `slip_always_on`）：
//   - 冷启动常驻（'1'）：首帧即拉起 → 不打开 App 也能收（进程活着期间）。
//   - 仅开页面时可收（'0'，默认）：进小纸条页才拉起；后台/未开页收不到。
//
// ⚠️ 副作用说明：数据面是**全局共享**的（同步页 / 互传页也会拉起），所以即便选了
// 「仅开页面时」，只要用户开过同步页/互传页，服务同样在跑、照样能收到 —— 这是既有
// 机制的自然结果，不是 bug，文档里说明即可，不做「强行关闭」。
import '../../core/db/app_database.dart';
import '../../core/sync/device_nickname.dart';
import '../../core/sync/sync_discovery.dart';
import '../../core/sync/sync_service.dart';
import 'services/note_slip_server.dart';

/// 小纸条接收引导
class NoteSlipBootstrap {
  NoteSlipBootstrap._();

  static bool _routesRegistered = false;
  static bool _dataPlaneStarted = false;

  /// 注册接收路由（幂等；两种模式都要调）
  static void registerRoutes(AppDatabase db) {
    if (_routesRegistered) return;
    _routesRegistered = true;
    NoteSlipServer(db).start();
  }

  /// 数据面是否已由本引导拉起
  static bool get dataPlaneStarted => _dataPlaneStarted;

  /// 拉起接收所需的数据面（47124 HTTP + 47123 UDP 响应器），幂等。
  ///
  /// 失败静默：局域网端口被占 / 无网络是小概率但非致命，不能因此打断启动。
  static Future<bool> ensureDataPlane(SyncService sync) async {
    if (_dataPlaneStarted) return true;
    _dataPlaneStarted = true;
    try {
      await sync.startServer(name: localBroadcastName, id: localDeviceId);
      await SyncDiscovery().startResponder(
        name: localBroadcastName,
        id: localDeviceId,
      );
      return true;
    } catch (_) {
      // 端口被占等异常：下次进页面会再试（_dataPlaneStarted 不回退，避免反复重试刷日志）
      return false;
    }
  }
}
