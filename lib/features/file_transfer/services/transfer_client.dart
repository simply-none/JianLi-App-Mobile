// 文件互传 · 发送端（客户端）—— 批量：offer → 逐文件流式 data(字节计数) → end
//
// 复用 SyncService 的 HttpClient + 47124 数据面（与 sendTable 同款先例）。
// 逐文件串行，全程流式（req.addStream(file.openRead())），不 base64 不落内存；
// 发送端按字节回调节流进度（~100ms）；批次可中途取消，剩余文件标记 canceled。
//
// 已实现的增强（2026-09-06 之后）：
//   #13 断点续传：offer 响应带回各文件 resumeFrom；data 带 from= 并从偏移读流
//   #14 会话加密（默认关）：offer 协商 AES-256-CTR 会话密钥，data 流加密后发送
//   #17 并发守卫：同一时刻仅一个发送批次（_activeSendTid）
//   #19 后台保活：发送全程 Wakelock，避免手机息屏中断
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as crypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart' as mime_pkg;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/sync/device_nickname.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_discovery.dart';
import '../models/transfer_models.dart';
import '../models/transfer_utils.dart';
import '../repositories/transfer_repository.dart';
import '../services/transfer_server.dart';

/// 发送端服务
class TransferClient {
  TransferClient(this._db, this._settings);

  final AppDatabase _db;
  final TransferSettings _settings;
  late final TransferRepository _repo = TransferRepository(_db);

  bool _canceled = false;
  String? _activeSendTid; // #17 并发守卫

  /// 取消当前批次（检查点在文件间隙，v1 不在单文件流中途打断）
  void cancel() => _canceled = true;

  /// 重置取消标记（开始新批次前调用）
  void reset() => _canceled = false;

  Future<({bool ok, String message})> sendBatch({
    required PeerDevice peer,
    required List<File> files,
    required void Function(TransferProgress) onProgress,
  }) async {
    if (files.isEmpty) return (ok: false, message: '未选择文件');
    reset();
    final tid = const Uuid().v4();
    // #17 并发守卫：同一时刻仅一个发送批次
    if (_activeSendTid != null) {
      return (ok: false, message: '已有发送任务进行中');
    }
    _activeSendTid = tid;

    // #19 后台保活：发送全程持锁，息屏不中断（部分平台不支持则忽略）
    var wakelockOn = false;
    try {
      await WakelockPlus.enable();
      wakelockOn = true;
    } catch (_) {
      wakelockOn = false;
    }

    try {
      // 1) offer（携带可选的加密会话协商）
      final encEnabled = _settings.enc;
      List<int>? encKey;
      List<int>? encIv;
      if (encEnabled) {
        // #14 密钥由接收端随机数源生成（cryptography 密码学安全），base64 经 enc 字段发出
        final aesCtr = crypt.AesCtr.with256bits(
          macAlgorithm: crypt.MacAlgorithm.empty,
        );
        final sk = await aesCtr.newSecretKey();
        encKey = await sk.extractBytes(); // 32 字节
        encIv = aesCtr.newNonce(); // 16 字节
      }

      final offerFiles = <Map<String, dynamic>>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        offerFiles.add({
          'fid': '${i + 1}',
          'name': p.basename(f.path),
          'size': f.lengthSync(),
          'mime': _mime(f.path),
        });
      }
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final offerReq = await client.postUrl(
        Uri.parse('http://${peer.ip}:${SyncProtocol.dataPort}/file/offer'),
      );
      offerReq.headers.contentType = ContentType.json;
      offerReq.add(utf8.encode(jsonEncode({
        'tid': tid,
        'from': {
          'name': localBroadcastName,
          'id': localDeviceId,
          'platform': localPlatform,
        },
        'files': offerFiles,
        // #14 加密协商：仅当本端开启且密钥已生成时携带 enc 字段
        if (encEnabled && encKey != null && encIv != null)
          'enc': encodeEncSession(encKey, encIv),
      })));
      final offerRes = await offerReq.close();
      final offerBody = await utf8.decoder.bind(offerRes).join();
      final offerJson = jsonDecode(offerBody) as Map<String, dynamic>;
      if (offerJson['ok'] != true) {
        client.close();
        return (
          ok: false,
          message: '对方拒绝接收：${offerJson['reason'] ?? '未知原因'}',
        );
      }
      // 接收端在 offer 响应里回传了设备名，用它对端名填发送历史（不再空白）
      final peerName =
          (offerJson['me'] is Map ? (offerJson['me']['name'] as String?) : null) ??
          peer.name;
      // #14 是否真正走加密：本端开启 ∧ 密钥就绪 ∧ 对端确认 enc:true
      final useEnc =
          encEnabled && encKey != null && encIv != null && offerJson['enc'] == true;
      // #13 续传映射：fid → resumeFrom（加密时不续传，恒为 0）
      final accepted = (offerJson['accepted'] as List? ?? [])
          .whereType<Map<String, dynamic>>();
      final resumeMap = <String, int>{
        for (final a in accepted)
          (a['fid'] as String? ?? ''):
              (useEnc ? 0 : (a['resumeFrom'] as num? ?? 0).toInt()),
      };

      // 2) 逐文件 data → end
      for (var i = 0; i < files.length; i++) {
        if (_canceled) {
          // 剩余文件标记 canceled
          for (var j = i; j < files.length; j++) {
            final rf = files[j];
            await _repo.add(
              tid: tid,
              fid: '${j + 1}',
              direction: 'send',
              peerName: peerName,
              peerIp: peer.ip,
              fileName: p.basename(rf.path),
              size: rf.lengthSync(),
              mime: _mime(rf.path),
              path: rf.path,
              status: 'canceled',
            );
          }
          client.close();
          return (ok: true, message: '已取消，剩余 ${files.length - i} 个标记取消');
        }

        final file = files[i];
        final fid = '${i + 1}';
        final name = p.basename(file.path);
        final size = file.lengthSync();
        final resumeFrom = resumeMap[fid] ?? 0;

        // data：流式写出（明文按字节计数；加密时再包一层 AES-CTR 密文流）
        final dataReq = await client.postUrl(
          Uri.parse(
            'http://${peer.ip}:${SyncProtocol.dataPort}/file/data'
            '?tid=$tid&fid=$fid&from=$resumeFrom',
          ),
        );
        Stream<List<int>> streamToSend = countingStream(
          file.openRead(resumeFrom),
          (total) {
            onProgress(
              TransferProgress(
                tid: tid,
                fid: fid,
                name: name,
                total: size,
                sent: total,
                phase: 'data',
              ),
            );
          },
          initial: resumeFrom,
        );
        if (useEnc) {
          final aesCtr = crypt.AesCtr.with256bits(
            macAlgorithm: crypt.MacAlgorithm.empty,
          );
          final sk = await aesCtr.newSecretKeyFromBytes(encKey!);
          // encryptStream 直接返回密文流（首个位置参数为明文流）；CTR 无 MAC 用 onMac 收 empty
          streamToSend = aesCtr.encryptStream(
            streamToSend,
            secretKey: sk,
            nonce: encIv!,
            onMac: (_) {},
          );
        }
        await dataReq.addStream(streamToSend);
        final dataRes = await dataReq.close();
        await utf8.decoder.bind(dataRes).join(); // 消费响应体

        // 计算文件 sha256（流式，明文，不整文件入内存），随 /file/end 带给接收端校验。
        // 注意 Hash.bind 返回的是 Stream<Digest> 而非 Future，必须 .first 消费流取结果，
        // 直接 await 拿到的是流对象，toString 后作为 hash 发出会导致对端恒报 hash mismatch。
        final hash =
            (await crypto.sha256.bind(file.openRead()).first).toString();

        // end：收尾 + 写历史（携带 hash）
        final endReq = await client.postUrl(
          Uri.parse(
            'http://${peer.ip}:${SyncProtocol.dataPort}/file/end?tid=$tid&fid=$fid',
          ),
        );
        endReq.headers.contentType = ContentType.json;
        endReq.add(utf8.encode(jsonEncode({'hash': hash})));
        final endRes = await endReq.close();
        final endBody = await utf8.decoder.bind(endRes).join();
        final endJson = jsonDecode(endBody) as Map<String, dynamic>;
        final ok = endJson['ok'] == true;
        final err = ok ? null : (endJson['error'] as String? ?? 'peer rejected');
        await _repo.add(
          tid: tid,
          fid: fid,
          direction: 'send',
          peerName: peerName,
          peerIp: peer.ip,
          fileName: name,
          size: size,
          mime: _mime(file.path),
          path: file.path,
          status: ok ? 'done' : 'failed',
          error: err,
        );
        onProgress(
          TransferProgress(
            tid: tid,
            fid: fid,
            name: name,
            total: size,
            sent: size,
            phase: ok ? 'done' : 'failed',
          ),
        );
      }
      client.close();
      return (ok: true, message: '已发送 ${files.length} 个文件');
    } catch (e) {
      return (ok: false, message: '发送失败：$e');
    } finally {
      _activeSendTid = null;
      if (wakelockOn) {
        try {
          await WakelockPlus.disable();
        } catch (_) {
          // 忽略释放失败
        }
      }
    }
  }

  String? _mime(String path) => mime_pkg.lookupMimeType(path);
}

/// 发送端服务 provider
final Provider<TransferClient> transferClientProvider =
    Provider<TransferClient>(
      (ref) => TransferClient(
        ref.watch(appDatabaseProvider),
        ref.watch(transferSettingsProvider),
      ),
    );
