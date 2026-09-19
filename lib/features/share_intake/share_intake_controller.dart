// P0-3 系统分享接收 —— 控制器（pendingShareProvider）
//
// 数据流：其他 App「分享到渐离」→ 系统 SEND intent → receive_sharing_intent
// 桥接出文本/链接 → 这里解析成 ShareIntakeItem 写入 pendingShareProvider
// → 根组件（app.dart）ref.listen 到非空即 push /share-intake 落地页（处理抽屉）。
//
// ⚠️ 监听必须早于用户操作注册：startSystemListener 在根组件首帧 postFrame 调用
// （见 app.dart），getInitialMedia 覆盖「冷启动分享」、getMediaStream 覆盖「热启动分享」。
// 只接受 text/url（图片/文件分享 P1 再扩），消费后 reset + 清空，绝不重复弹出。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 待处理的一条分享内容（文本或链接）
class ShareIntakeItem {
  const ShareIntakeItem({required this.text, required this.isUrl});

  /// 分享原文（链接时即完整 URL）
  final String text;

  /// 是否识别为 URL（receive_sharing_intent 的 url 类型，或启发式判定）
  final bool isUrl;

  /// 笔记标题：首行、去协议头、截 30 字
  String get noteTitle {
    var line = text.split('\n').first.trim();
    if (isUrl) line = line.replaceFirst(RegExp(r'^https?://'), '');
    if (line.length > 30) line = line.substring(0, 30);
    return line.isEmpty ? '分享内容' : line;
  }

  /// 待办标题：首行、截 60 字（待办标题宽松些）
  String get todoTitle {
    var line = text.split('\n').first.trim();
    if (line.length > 60) line = line.substring(0, 60);
    return line.isEmpty ? '分享内容' : line;
  }

  /// URL 场景的简短展示（去协议、截 40 字）
  String get displayUrl {
    var t = text.replaceFirst(RegExp(r'^https?://'), '');
    if (t.length > 40) t = '${t.substring(0, 40)}…';
    return t;
  }
}

/// 待处理分享（一次性意图：写入即弹抽屉，消费即清空）
final NotifierProvider<ShareIntakeController, ShareIntakeItem?>
pendingShareProvider =
    NotifierProvider<ShareIntakeController, ShareIntakeItem?>(
      ShareIntakeController.new,
    );

/// 分享接收控制器：挂接系统分享流 + 持有当前待处理项
class ShareIntakeController extends Notifier<ShareIntakeItem?> {
  bool _started = false;
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  ShareIntakeItem? build() => null;

  /// 注册系统分享监听（只允许调用一次；根组件首帧 postFrame 调用）
  void startSystemListener() {
    if (_started) return;
    _started = true;
    // 冷启动分享：引擎起来后一次性拉初始意图
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(_handle, onError: (Object _) {/* 桥异常静默：分享是增强能力 */});
    // 热启动分享：App 在后台时收到分享 → 流式回调
    _sub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handle, onError: (Object _) {});
    ref.onDispose(() => _sub?.cancel());
  }

  void _handle(List<SharedMediaFile> items) {
    // 取走即重置：不 reset 的话 Android 侧会保留 pending intent，下次冷启动重复弹
    ReceiveSharingIntent.instance.reset();
    for (final m in items) {
      // 1.8.1 的 SharedMediaFile：文本/URL/文件路径统一在 path 字段（非空 String）
      final raw = m.path.trim();
      if (raw.isEmpty) continue; // 空分享跳过（图片/文件暂不支持，P1 扩）
      final isUrl =
          m.type == SharedMediaType.url || _looksLikeUrl(raw);
      state = ShareIntakeItem(text: raw, isUrl: isUrl);
      return; // 只取第一条，剩余的丢弃（当前抽屉单条处理）
    }
  }

  /// 落地页关闭后消费：清空当前项
  void consume() => state = null;

  /// 启发式 URL 判定：有 scheme 且无空白
  static bool _looksLikeUrl(String s) {
    if (s.contains('\n') || s.contains(' ')) return false;
    return s.startsWith('http://') ||
        s.startsWith('https://') ||
        RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://\S+$').hasMatch(s);
  }
}
