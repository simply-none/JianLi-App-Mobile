// P3-3 遥控 PC —— 服务层（HTTP 命令 + 配对 token 持久化）
//
// 通信：复用局域网数据面 47124（与同步/互传同端口），PC 端 /remote/* 路由见
// electron/main/module/remoteControl.ts。配对 token 存本机 basic_info（键
// remote_token_<ip>），已配对设备清单存 remote_targets（JSON 数组）——零新表，
// 不进同步白名单（纯本机偏好）。
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../core/db/app_database.dart' show AppDatabase, BasicInfoCompanion;

/// 已保存的遥控目标
class RemoteTarget {
  const RemoteTarget({required this.ip, required this.name});

  final String ip;
  final String name;

  Map<String, dynamic> toJson() => {'ip': ip, 'name': name};

  factory RemoteTarget.fromJson(Map<String, dynamic> j) => RemoteTarget(
        ip: j['ip'] as String? ?? '',
        name: j['name'] as String? ?? '',
      );
}

/// 命令执行结果
class RemoteResult {
  const RemoteResult({required this.ok, this.error, this.unpaired = false});

  final bool ok;
  final String? error;

  /// 403 = token 失效，需重新配对
  final bool unpaired;
}

class RemoteService {
  RemoteService(this._db);

  final AppDatabase _db;

  static const _tokenKeyPrefix = 'remote_token_';
  static const _targetsKey = 'remote_targets';

  // ---------- 偏好存取 ----------

  Future<String?> loadToken(String ip) async {
    final row = await (_db.select(_db.basicInfo)
          ..where((t) => t.key.equals('$_tokenKeyPrefix$ip')))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> saveToken(String ip, String token) async {
    await _db.into(_db.basicInfo).insertOnConflictUpdate(
          BasicInfoCompanion.insert(
            key: '$_tokenKeyPrefix$ip',
            value: Value(token),
          ),
        );
  }

  Future<void> clearToken(String ip) async {
    await (_db.delete(_db.basicInfo)
          ..where((t) => t.key.equals('$_tokenKeyPrefix$ip')))
        .go();
  }

  Future<List<RemoteTarget>> loadTargets() async {
    final row = await (_db.select(_db.basicInfo)
          ..where((t) => t.key.equals(_targetsKey)))
        .getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RemoteTarget.fromJson(e as Map<String, dynamic>))
          .where((t) => t.ip.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTargets(List<RemoteTarget> targets) async {
    await _db.into(_db.basicInfo).insertOnConflictUpdate(
          BasicInfoCompanion.insert(
            key: _targetsKey,
            value: Value(jsonEncode(
              [for (final t in targets) t.toJson()],
            )),
          ),
        );
  }

  // ---------- HTTP ----------

  Future<Map<String, dynamic>> _get(String ip, String path) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('http://$ip:47124$path'))
          .timeout(const Duration(seconds: 6));
      final res = await req.close().timeout(const Duration(seconds: 6));
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (body.isEmpty) return {'ok': res.statusCode == 200};
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'ok': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> _post(
    String ip,
    String path, {
    Map<String, dynamic> body = const {},
    String? token,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .postUrl(Uri.parse('http://$ip:47124$path'))
          .timeout(const Duration(seconds: 6));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('x-remote-token', token);
      req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 8));
      final text = await res.transform(utf8.decoder).join();
      final out = text.isEmpty
          ? <String, dynamic>{'ok': res.statusCode == 200}
          : (jsonDecode(text) as Map<String, dynamic>).cast<String, dynamic>();
      out['_status'] = res.statusCode;
      return out;
    } catch (e) {
      return {'ok': false, 'error': '$e', '_status': 0};
    } finally {
      client?.close();
    }
  }

  /// 探测：目标是否为可遥控的渐离 PC
  Future<bool> ping(String ip) async {
    final r = await _get(ip, '/remote/ping');
    return r['ok'] == true && r['role'] == 'pc';
  }

  /// 第一步：请求 PC 弹出配对码（码只显示在 PC 屏幕上，不经过网络回传）
  Future<RemoteResult> requestPair(String ip) async {
    final r = await _post(ip, '/remote/pair');
    return RemoteResult(ok: r['ok'] == true, error: r['error'] as String?);
  }

  /// 第二步：提交 4 位码换取 token（手机持久化，之后每条命令带上）
  Future<RemoteResult> confirmPair(String ip, String code) async {
    final r = await _post(ip, '/remote/pair/confirm', body: {'code': code});
    if (r['ok'] == true && r['token'] is String) {
      await saveToken(ip, r['token'] as String);
      return const RemoteResult(ok: true);
    }
    return RemoteResult(ok: false, error: r['error'] as String? ?? '配对失败');
  }

  /// 执行白名单命令。403 → unpaired=true（调用方清 token 引导重新配对）。
  /// [arg] 仅供带参命令使用：`clipboard-text` = 要写入 PC 剪贴板的文本、
  /// `open-url` = 要让 PC 打开的链接；其余命令忽略。
  Future<RemoteResult> sendCmd(String ip, String cmd, {String? arg}) async {
    final token = await loadToken(ip);
    if (token == null) {
      return const RemoteResult(ok: false, unpaired: true, error: '尚未配对');
    }
    final r = await _post(
      ip,
      '/remote/cmd',
      body: {'cmd': cmd, 'arg': ?arg},
      token: token,
    );
    if (r['_status'] == 403) {
      await clearToken(ip);
      return RemoteResult(
        ok: false,
        unpaired: true,
        error: r['error'] as String? ?? '配对已失效',
      );
    }
    return RemoteResult(ok: r['ok'] == true, error: r['error'] as String?);
  }
}

/// 服务实例（数据库单例派生，无独立生命周期）
// 页内直接 ref.read(appDatabaseProvider) 构造即可，不单独注册 provider。
