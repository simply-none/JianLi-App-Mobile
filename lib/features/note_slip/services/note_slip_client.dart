// P1-6 小纸条 —— 发送端（HTTP 客户端）
//
// 复用局域网 47124 数据面（与同步 / 文件互传 / 遥控 PC 同端口，不新开端口）。
// 协议（双端对称，桌面端 noteSlip.ts 同端点）：
//   POST /slip/push  body {id, from:{name,platform}, kind, content, ts}
//   GET  /slip/ping  → {ok:true, role:'mobile'|'pc', support:true}
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';
import '../../../core/sync/device_nickname.dart';
import '../../../core/sync/sync_discovery.dart';
import '../models/note_slip.dart';
import '../repositories/note_slip_repository.dart';

/// 发送结果
class SlipSendResult {
  const SlipSendResult({required this.ok, this.error, this.unsupported = false});

  final bool ok;

  /// 失败原因（成功为 null）
  final String? error;

  /// 对端不支持小纸条（老版本 PC / 其它设备）：提示升级而非「网络失败」
  final bool unsupported;
}

/// 小纸条发送端
class NoteSlipClient {
  NoteSlipClient(this._db);

  final AppDatabase _db;

  late final NoteSlipRepository _repo = NoteSlipRepository(_db);

  static const String _targetsKey = 'slip_targets';
  static const String _lastPeerKey = 'slip_last_peer';

  // ---------- 目标设备（basic_info 持久化） ----------

  /// 已保存的发送目标（最近使用的排最前）
  Future<List<SlipTarget>> loadTargets() async {
    final row = await (_db.select(_db.basicInfo)
          ..where((t) => t.key.equals(_targetsKey)))
        .getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SlipTarget.fromJson(e as Map<String, dynamic>))
          .where((t) => t.ip.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveTargets(List<SlipTarget> targets) async {
    await _db.into(_db.basicInfo).insertOnConflictUpdate(
          BasicInfoCompanion.insert(
            key: _targetsKey,
            value: Value(jsonEncode([for (final t in targets) t.toJson()])),
          ),
        );
  }

  /// 记住一个目标（排到最前，最多 8 个），并设为「最近目标」
  Future<void> rememberTarget(SlipTarget target) async {
    final next = [
      target,
      ...(await loadTargets()).where((t) => t.ip != target.ip),
    ].take(8).toList();
    await _saveTargets(next);
    await _db.into(_db.basicInfo).insertOnConflictUpdate(
          BasicInfoCompanion.insert(key: _lastPeerKey, value: Value(target.ip)),
        );
  }

  /// 最近一次发送目标的 IP（无则 null）
  Future<String?> lastPeerIp() async {
    final row = await (_db.select(_db.basicInfo)
          ..where((t) => t.key.equals(_lastPeerKey)))
        .getSingleOrNull();
    final ip = row?.value?.trim();
    return (ip == null || ip.isEmpty) ? null : ip;
  }

  // ---------- HTTP ----------

  /// 探测对端是否支持小纸条（GET /slip/ping）
  Future<bool> ping(String ip) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('http://$ip:47124/slip/ping'))
          .timeout(const Duration(seconds: 6));
      final res = await req.close().timeout(const Duration(seconds: 6));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200 || body.isEmpty) return false;
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['ok'] == true && json['support'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 推送一条小纸条（成功即写本地 out 记录）
  Future<SlipSendResult> send({
    required String ip,
    required String content,
    String? peerName,
  }) async {
    final text = content.trim();
    if (text.isEmpty) {
      return const SlipSendResult(ok: false, error: '内容为空');
    }
    if (text.length > kSlipMaxChars) {
      return const SlipSendResult(ok: false, error: '内容过长（上限 8000 字）');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .postUrl(Uri.parse('http://$ip:47124/slip/push'))
          .timeout(const Duration(seconds: 6));
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'id': id,
          'from': {'name': localBroadcastName, 'platform': localPlatform},
          'kind': slipKindOf(text),
          'content': text,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) {
        // 对端没有 /slip/push 路由 = 老版本 → 明确提示「不支持」
        return const SlipSendResult(
          ok: false,
          unsupported: true,
          error: '对端不支持小纸条（请更新到最新版）',
        );
      }
      final json = body.isEmpty
          ? <String, dynamic>{'ok': res.statusCode == 200}
          : (jsonDecode(body) as Map<String, dynamic>).cast<String, dynamic>();
      if (res.statusCode != 200 || json['ok'] != true) {
        return SlipSendResult(
          ok: false,
          error: json['error'] as String? ?? '发送失败（${res.statusCode}）',
        );
      }
      await _repo.insertOutgoing(
        key: id,
        content: text,
        peerName: peerName ?? ip,
        peerIp: ip,
      );
      await rememberTarget(SlipTarget(ip: ip, name: peerName ?? ip));
      return const SlipSendResult(ok: true);
    } catch (e) {
      return SlipSendResult(ok: false, error: '发送失败：$e');
    } finally {
      client?.close();
    }
  }
}

/// 发送目标（PC 或另一台手机）
class SlipTarget {
  const SlipTarget({required this.ip, required this.name});

  final String ip;
  final String name;

  Map<String, dynamic> toJson() => {'ip': ip, 'name': name};

  factory SlipTarget.fromJson(Map<String, dynamic> j) => SlipTarget(
        ip: j['ip'] as String? ?? '',
        name: j['name'] as String? ?? '',
      );
}
