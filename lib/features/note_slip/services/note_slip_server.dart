// P1-6 小纸条 —— 接收端（服务端）
//
// 复用 SyncService 的 47124 数据面（通过 registerRouteHandler 注入，不新开端口）。
// 端点：
//   POST /slip/push  收到一条小纸条 → 写库 + 弹横幅通知（幂等：重复推送不重复弹）
//   GET  /slip/ping  能力探测（供对端判断「是否支持小纸条」）
//
// ⚠️ 幂等注册：`registerRouteHandler` 是全局 list，**重复注册会让同一请求被处理两次**
//（写两条记录 + 弹两次通知），故本类用静态 `_registered` 守卫，`start()` 可反复调用。
import 'dart:convert';
import 'dart:io';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/sync/sync_discovery.dart';
import '../../../core/sync/sync_service.dart';
import '../models/note_slip.dart';
import '../repositories/note_slip_repository.dart';

/// 小纸条接收端
class NoteSlipServer {
  NoteSlipServer(this._db);

  final AppDatabase _db;

  late final NoteSlipRepository _repo = NoteSlipRepository(_db);

  /// 路由注册守卫（见文件头说明）
  static bool _registered = false;

  /// 已注册？
  static bool get registered => _registered;

  /// 注册接收路由（幂等，可反复调用）
  void start() {
    if (_registered) return;
    _registered = true;
    registerRouteHandler(
      (req) => req.uri.path == '/slip/push' && req.method == 'POST',
      _handlePush,
    );
    registerRouteHandler(
      (req) => req.uri.path == '/slip/ping' && req.method == 'GET',
      _handlePing,
    );
  }

  // ---------- 端点 ----------

  Future<void> _handlePush(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final key = (payload['id'] as String? ?? '').trim();
      final content = (payload['content'] as String? ?? '');
      if (key.isEmpty || content.trim().isEmpty) {
        _json(request, {'ok': false, 'error': '参数缺失'}, 400);
        return;
      }
      if (content.length > kSlipMaxChars) {
        _json(request, {'ok': false, 'error': '内容过长'}, 413);
        return;
      }
      final from = payload['from'] as Map<String, dynamic>? ?? const {};
      final peerName = (from['name'] as String? ?? '').trim();
      // 首次收到才弹通知：重复推送（同 id）静默返回成功，不打扰用户
      final fresh = await _repo.upsertIncoming(
        key: key,
        content: content,
        peerName: peerName.isEmpty ? '未知设备' : peerName,
        peerIp: request.connectionInfo?.remoteAddress.address ?? '',
        createdAt: (payload['ts'] as num?)?.toInt(),
      );
      if (fresh) {
        await NotificationService.showNow(
          id: NotificationService.stableId('slip:$key'),
          channelKey: NotificationChannels.slip,
          title: peerName.isEmpty ? '小纸条' : '小纸条 · $peerName',
          body: slipPreviewOf(content),
          payload: {'type': 'slip', 'key': key},
        );
      }
      _json(request, {'ok': true});
    } catch (e) {
      _json(request, {'ok': false, 'error': '$e'}, 500);
    }
  }

  Future<void> _handlePing(HttpRequest request) async {
    _json(request, {
      'ok': true,
      'role': localPlatform,
      'support': true,
    });
  }

  void _json(
    HttpRequest request,
    Map<String, dynamic> data, [
    int status = 200,
  ]) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }
}
