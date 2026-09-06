// 文件互传 · 接收端（服务端）—— 处理 /file/offer、/file/data、/file/end 三端点
//
// 复用 SyncService 的 47124 数据面（通过 registerRouteHandler 注入，不新开端口）。
// 接收目录：沙盒 Documents/渐离App文件互传/；文件名安全化 + 重名去重 ` (n)`；
// 接收成功写 file_transfer 历史（direction='receive'），页面 watch 流据此弹 Toast。
//
// 已实现的增强（2026-09-06 之后）：
//   #9  重名策略：rename=追加 (n)（默认） / overwrite=覆盖（读 TransferSettings）
//   #13 断点续传：offer 响应带回各文件已收 .part 偏移；data 支持 from= 追加写 + hash 播种
//   #14 会话加密（默认关）：offer 协商 AES-256-CTR 会话密钥，data 流解密
//   #15 接收端询问模式：关「自动接收」时不再直接拒绝，经 askStream 等 UI 答复
//   #17 并发守卫：同一时刻仅一个接收批次
//   #20 历史超阈值自动清理最旧
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as crypt;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_discovery.dart';
import '../../../core/sync/sync_service.dart';
import '../models/transfer_models.dart';
import '../models/transfer_utils.dart';
import '../repositories/transfer_repository.dart';

/// 询问模式：等待 UI 答复的接收请求
class IncomingAsk {
  const IncomingAsk({
    required this.tid,
    required this.name,
    required this.count,
    required this.total,
  });
  final String tid;
  final String name;
  final int count;
  final int total;
}

/// 待收批次里的一个文件
class _OfferFile {
  _OfferFile({
    required this.fid,
    required this.name,
    required this.size,
    this.mime,
  });
  final String fid;
  final String name;
  final int size;
  final String? mime;
}

/// 待收批次（一次 offer 一批）
class _Offer {
  _Offer({required this.peerName, required this.peerIp, required this.files});
  final String peerName;
  final String peerIp;
  final Map<String, _OfferFile> files;
}

/// 捕获 sha256 分块转换产出的 Digest
/// （dart:convert 的 ChunkedConversionSinkBase 自 Dart 3.9 起不再公开导出，
/// startChunkedConversion 只要求 `Sink<Digest>`，直接实现即可）
class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? result;
  @override
  void add(crypto.Digest d) => result = d;
  @override
  void close() {}
}

/// 接收端服务
class TransferServer {
  TransferServer(this._db, this._settings);

  final AppDatabase _db;
  final TransferSettings _settings;

  late final TransferRepository _repo = TransferRepository(_db);

  /// 待收批次（key = tid）
  final Map<String, _Offer> _offers = {};
  /// 收端逐文件接收到的 sha256（'tid|fid' → hex），_handleEnd 比对发送端在 /file/end 带来的 hash
  final Map<String, String> _hashes = {};
  /// 加密会话：tid → {key, iv}
  final Map<String, ({List<int> key, List<int> iv})> _encSessions = {};
  /// 并发守卫：同一时刻仅一个接收批次
  String? _activeReceiveTid;
  /// 询问模式：tid → 等待 UI 答复的 completer
  final Map<String, Completer<bool>> _pendingAsk = {};
  final StreamController<IncomingAsk> _askController =
      StreamController<IncomingAsk>.broadcast();

  /// 询问模式事件流（页面订阅后弹窗）
  Stream<IncomingAsk> get askStream => _askController.stream;

  /// UI 对用户答复（接收/拒绝），唤醒 _handleOffer 中 await 的 _askAccept
  void answerAsk(String tid, bool accept) {
    _pendingAsk.remove(tid)?.complete(accept);
  }

  void dispose() {
    _askController.close();
  }

  /// 接收目录（沙盒 Documents/渐离App文件互传/，不存在则创建）
  Future<String> receiveDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(dir.path, kTransferDirName));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  /// 注册 /file/* 三端点到同步数据面（幂等，全局只注册一次）
  void registerRoutes() {
    registerRouteHandler(
      (r) => r.method == 'POST' && r.uri.path == '/file/offer',
      _handleOffer,
    );
    registerRouteHandler(
      (r) => r.method == 'POST' && r.uri.path == '/file/data',
      _handleData,
    );
    registerRouteHandler(
      (r) => r.method == 'POST' && r.uri.path == '/file/end',
      _handleEnd,
    );
  }

  // ---- 端点处理 ----

  Future<void> _handleOffer(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final tid = payload['tid'] as String? ?? '';

      // #17 并发守卫
      if (_activeReceiveTid != null && _activeReceiveTid != tid) {
        _json(req, {'ok': false, 'reason': 'busy'}, 429);
        return;
      }
      if (_pendingAsk.isNotEmpty && !_pendingAsk.containsKey(tid)) {
        _json(req, {'ok': false, 'reason': 'busy'}, 429);
        return;
      }

      final files = (payload['files'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (f) => _OfferFile(
              fid: f['fid'] as String? ?? '',
              name: f['name'] as String? ?? '未命名文件',
              size: (f['size'] as num?)?.toInt() ?? 0,
              mime: f['mime'] as String?,
            ),
          )
          .toList();

      // #16 磁盘预估：仅计算总大小（移动端无可靠 free-space API，做软预估不硬拒）
      final total = files.fold<int>(0, (s, f) => s + f.size);

      // #14 加密会话：发送端带 enc 才建立；本端确认后随响应回 enc:true
      ({List<int> key, List<int> iv})? encSession;
      final encPayload = payload['enc'] as Map?;
      if (encPayload != null) {
        try {
          final dec = decodeEncSession(
            encPayload['key'] as String,
            encPayload['iv'] as String,
          );
          encSession = (key: dec['key']!, iv: dec['iv']!);
          _encSessions[tid] = encSession;
        } catch (_) {
          _encSessions.remove(tid);
        }
      }

      // #15 询问模式：关自动接收时不立即拒绝，先等 UI 答复
      if (!_settings.autoAccept) {
        final accept = await _askAccept(
          tid,
          (payload['from'] as Map?)?['name'] as String? ?? '未知设备',
          files.length,
          total,
        );
        if (!accept) {
          _json(req, {'ok': false, 'reason': 'rejected'}, 403);
          _encSessions.remove(tid);
          return;
        }
      }

      // #13 断点续传：检查已有 .part 偏移，随 accepted 带回
      final dir = await receiveDir();
      final accepted = files.map((f) {
        // #14 加密传输不做续传：CTR keystream 只能从块边界对齐，无法任意字节续传，
        // 故加密批次整文件重发（仍正确，仅失去续传优化）。
        if (encSession != null) {
          return {'fid': f.fid, 'resumeFrom': 0};
        }
        var resumeFrom = 0;
        final part = File(p.join(dir, recvPartName(f.name, f.size)));
        if (f.size > 0 && part.existsSync()) {
          final sz = part.lengthSync();
          if (sz > 0 && sz < f.size) resumeFrom = sz;
        }
        return {'fid': f.fid, 'resumeFrom': resumeFrom};
      }).toList();

      _activeReceiveTid = tid;
      _offers[tid] = _Offer(
        peerName: (payload['from'] as Map?)?['name'] as String? ?? '未知设备',
        peerIp: req.connectionInfo?.remoteAddress.address ?? '',
        files: {for (final f in files) f.fid: f},
      );
      _json(req, {
        'ok': true,
        'accepted': accepted,
        'me': {
          'name': localDeviceName,
          'id': localDeviceId,
          'platform': localPlatform,
        },
        'enc': encSession != null,
      });
    } catch (e) {
      _json(req, {'ok': false, 'error': '$e'}, 400);
    }
  }

  Future<void> _handleData(HttpRequest req) async {
    final tid = req.uri.queryParameters['tid'] ?? '';
    final fid = req.uri.queryParameters['fid'] ?? '';
    final from = int.tryParse(req.uri.queryParameters['from'] ?? '0') ?? 0;
    final offer = _offers[tid];
    if (offer == null || !offer.files.containsKey(fid)) {
      _json(req, {'ok': false, 'reason': 'unknown tid/fid'}, 404);
      return;
    }
    final of = offer.files[fid]!;
    final dir = await receiveDir();
    final part = File(p.join(dir, recvPartName(of.name, of.size)));
    final enc = _encSessions[tid];
    // #13 续传：已存在部分 → 追加写 + 用已有字节给 hash 播种（最终 hash = 全文件）
    final resume = from > 0 && part.existsSync();
    final hash = await _receiveHashing(req, part, resume: resume, enc: enc);
    _hashes['$tid|$fid'] = hash;
    final bytes = await part.length();
    _json(req, {'ok': true, 'received': bytes});
  }

  Future<void> _handleEnd(HttpRequest req) async {
    final tid = req.uri.queryParameters['tid'] ?? '';
    final fid = req.uri.queryParameters['fid'] ?? '';
    final offer = _offers[tid];
    final of = offer?.files[fid];
    if (offer == null || of == null) {
      _json(req, {'ok': false, 'reason': 'unknown tid/fid'}, 404);
      return;
    }
    final dir = await receiveDir();
    final part = File(p.join(dir, recvPartName(of.name, of.size)));
    if (!part.existsSync()) {
      _json(req, {'ok': false, 'reason': 'no part file'}, 400);
      return;
    }
    String? expectedHash;
    try {
      final bodyStr = await utf8.decoder.bind(req).join();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>? ?? {};
      expectedHash = body['hash'] as String?;
    } catch (_) {
      // 无 body 则跳过校验
    }
    // #9 重名策略
    var finalName = _dedupeName(dir, of.name);
    if (_settings.renameStrategy == 'overwrite') {
      final target = File(p.join(dir, safeFileName(of.name)));
      if (target.existsSync()) {
        try {
          await target.delete();
        } catch (_) {}
      }
      finalName = safeFileName(of.name);
    }
    final finalPath = p.join(dir, finalName);
    await part.rename(finalPath);
    // 双重校验：size + sha256
    final size = await File(finalPath).length();
    final sizeOk = of.size <= 0 || size == of.size;
    final storedHash = _hashes['$tid|$fid'];
    final hashOk = expectedHash == null || storedHash == null || storedHash == expectedHash;
    final ok = sizeOk && hashOk;
    String? error;
    if (!sizeOk) error = 'size mismatch';
    else if (!hashOk) error = 'hash mismatch';
    if (!ok) {
      try {
        await File(finalPath).delete();
      } catch (_) {}
    }
    await _repo.add(
      tid: tid,
      fid: fid,
      direction: 'receive',
      peerName: offer.peerName,
      peerIp: offer.peerIp,
      fileName: finalName,
      size: size,
      mime: of.mime,
      path: ok ? finalPath : '',
      status: ok ? 'done' : 'failed',
      error: error,
    );
    _hashes.remove('$tid|$fid');
    _recycle(tid, fid);
    await _repo.trim(1000); // #20
    _json(req, {'ok': ok, 'path': finalPath, 'error': error});
  }

  // ---- 内部辅助 ----

  /// 边收边算 sha256 并落盘（流式，不整文件入内存）。
  /// [resume]=true 时先读取已有 .part 字节给 hash 播种（断点续传）。
  /// [enc] 非空时对请求流解密（AES-256-CTR）后再哈希 + 落盘。
  Future<String> _receiveHashing(
    HttpRequest req,
    File part, {
    required bool resume,
    required ({List<int> key, List<int> iv})? enc,
  }) async {
    final out = resume
        ? part.openWrite(mode: FileMode.append)
        : part.openWrite();
    final digestSink = _DigestSink();
    final hashSink = crypto.sha256.startChunkedConversion(digestSink);
    if (resume) {
      final existing = await part.readAsBytes();
      hashSink.add(existing);
    }
    if (enc != null) {
      // AES-256-CTR 解密（cryptography 流 API：源流作为首个位置参数；CTR 无 MAC 用 Mac.empty）
      final aesCtr = crypt.AesCtr.with256bits(
        macAlgorithm: crypt.MacAlgorithm.empty,
      );
      final key = await aesCtr.newSecretKeyFromBytes(enc.key);
      final decrypted = aesCtr.decryptStream(
        req,
        secretKey: key,
        nonce: enc.iv,
        mac: crypt.Mac.empty,
      );
      await for (final chunk in decrypted) {
        hashSink.add(chunk);
        out.add(chunk);
      }
    } else {
      await for (final chunk in req) {
        hashSink.add(chunk);
        out.add(chunk);
      }
    }
    await out.close();
    hashSink.close();
    return digestSink.result?.toString() ?? '';
  }

  /// 重名去重：追加 ` (n)`，保留扩展名
  String _dedupeName(String dir, String raw) {
    final safe = safeFileName(raw);
    var candidate = safe;
    var n = 1;
    while (File(p.join(dir, candidate)).existsSync()) {
      final ext = fileExt(safe);
      final base = ext.isEmpty ? safe : safe.substring(0, safe.length - ext.length);
      candidate = '$base ($n)$ext';
      n++;
    }
    return candidate;
  }

  /// 等待 UI 对「是否接收」的答复（询问模式）；超时默认拒绝（避免 UI 未回应时挂起）
  Future<bool> _askAccept(String tid, String name, int count, int total) {
    final c = Completer<bool>();
    _pendingAsk[tid] = c;
    _askController.add(IncomingAsk(tid: tid, name: name, count: count, total: total));
    Timer(const Duration(seconds: 60), () {
      if (_pendingAsk.containsKey(tid)) answerAsk(tid, false);
    });
    return c.future;
  }

  /// 收端某文件完成（成功或失败）后从内存批次回收；整批收完则删除批次
  void _recycle(String tid, String fid) {
    final offer = _offers[tid];
    if (offer == null) return;
    offer.files.remove(fid);
    if (offer.files.isEmpty) {
      _offers.remove(tid);
      if (_activeReceiveTid == tid) _activeReceiveTid = null;
      _encSessions.remove(tid);
    }
    _hashes.remove('$tid|$fid');
  }

  void _json(HttpRequest req, Map<String, dynamic> data, [int status = 200]) {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(data));
    req.response.close();
  }
}

/// 接收端服务 provider：创建时即向同步数据面注册 /file/* 路由（幂等）
final Provider<TransferServer> transferServerProvider = Provider<TransferServer>(
  (ref) {
    final srv = TransferServer(
      ref.watch(appDatabaseProvider),
      ref.watch(transferSettingsProvider),
    );
    srv.registerRoutes();
    return srv;
  },
);

/// 文件互传设置 provider（单例，唯一事实源）
final Provider<TransferSettings> transferSettingsProvider =
    Provider<TransferSettings>((ref) => TransferSettings());
