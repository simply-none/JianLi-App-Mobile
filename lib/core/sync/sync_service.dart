// 同步数据传输 —— HTTP 收发 + 按主键幂等 upsert（P3 同步的数据面）
//
// 协议：
//   GET  /ping  → 设备信息 JSON
//   POST /sync  → body: {"table": "...", "rows": [{col: val}, ...]}
// 幂等写：INSERT OR REPLACE（表必须声明主键）；仅允许白名单表。
// 安全 TODO(P3)：传输层加会话密钥（当前明文 JSON，仅限受信局域网）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import 'sync_discovery.dart';

/// 可同步表白名单（主题对话三表为 INTEGER 自增 id 主键，2026-09-05 加入——
/// INSERT OR REPLACE 按 id 幂等，桌面端 tablePk 同步适配）
const List<String> kSyncableTables = [
  'habit_def',
  'habit_checkin',
  'todo_list',
  'todo_tags',
  'note_book',
  'basic_info',
  'countdown',
  'qr_history',
  'qr_template',
  'conversation_theme',
  'conversation',
  'conversation_tag',
];

/// 同步服务
class SyncService {
  SyncService(this._db);

  final AppDatabase _db;
  HttpServer? _server;

  /// 启动接收端（HTTP 数据面）；name/id 为空时回退本机信息
  Future<void> startServer({String name = '', String id = ''}) async {
    if (_server != null) return;
    // 回退逻辑收敛为局部变量（原 _serverName/_serverId 未声明，属既有编译错误）
    final resolvedName = name.isEmpty ? localDeviceName : name;
    final resolvedId = id.isEmpty ? localDeviceId : id;
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      SyncProtocol.dataPort,
    );
    _server!.listen((request) async {
      if (request.uri.path == '/ping') {
        _json(request, {
          'name': resolvedName,
          'id': resolvedId,
          'platform': localPlatform,
        });
        return;
      }
      // 拉取端点：对端主动拉本机数据（与 PC 端 syncModule.ts 的 /export 对称）
      if (request.uri.path == '/export' && request.method == 'GET') {
        final table = request.uri.queryParameters['table'];
        if (table == null || !kSyncableTables.contains(table)) {
          _json(request, {'ok': false, 'error': 'table 不在白名单'}, 400);
          return;
        }
        try {
          final rows = await exportTable(table);
          _json(request, {'ok': true, 'table': table, 'rows': rows});
        } catch (e) {
          _json(request, {'ok': false, 'error': '$e'}, 500);
        }
        return;
      }
      if (request.uri.path == '/sync' && request.method == 'POST') {
        try {
          final body = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(body) as Map<String, dynamic>;
          final table = payload['table'] as String?;
          final rows = (payload['rows'] as List?) ?? const [];
          if (table == null || !kSyncableTables.contains(table)) {
            _json(request, {'ok': false, 'error': 'table 不在白名单'}, 400);
            return;
          }
          var written = 0;
          for (final row in rows.whereType<Map<String, dynamic>>()) {
            await _upsertRow(table, row);
            written++;
          }
          _json(request, {'ok': true, 'written': written});
        } catch (e) {
          _json(request, {'ok': false, 'error': '$e'}, 500);
        }
        return;
      }
      request.response.statusCode = 404;
      await request.response.close();
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

  /// 幂等写入一行（INSERT OR REPLACE，按 map 的键拼列）
  /// 各表实际列名缓存（PRAGMA table_info 结果，避免逐行查询）
  final Map<String, Set<String>> _tableColumns = {};

  /// 取本机某表的实际列名集合（带缓存）
  Future<Set<String>> _columnsOf(String table) async {
    final cached = _tableColumns[table];
    if (cached != null) return cached;
    final info = await _db.customSelect('PRAGMA table_info("$table")').get();
    final cols = info.map((r) => r.data['name'] as String).toSet();
    _tableColumns[table] = cols;
    return cols;
  }

  /// 幂等写入一行（INSERT OR REPLACE，按 map 的键拼列）
  /// 关键容错：桌面端表带旧 SQL 层遗留列（id/name/value/created_at 等），
  /// 移动端表未必有；写入前按本表实际列过滤，保证双端 schema 有差异时也能同步。
  Future<void> _upsertRow(String table, Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final valid = await _columnsOf(table);
    final cols = row.keys.where(valid.contains).toList();
    if (cols.isEmpty) return;
    final colSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final values = cols.map((c) {
      return row[c]?.toString();
    }).toList();
    await _db.customStatement(
      'INSERT OR REPLACE INTO "$table" ($colSql) VALUES ($placeholders)',
      values,
    );
  }

  /// 导出某表全部行为同步载荷
  Future<List<Map<String, dynamic>>> exportTable(String table) async {
    if (!kSyncableTables.contains(table)) return const [];
    final rows = await _db.customSelect('SELECT * FROM "$table"').get();
    return rows.map((r) => r.data).toList();
  }

  /// 向对端推送一张表
  Future<({bool ok, String message})> sendTable(
    PeerDevice peer,
    String table,
  ) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final rows = await exportTable(table);
      final req = await client.postUrl(
        Uri.parse('http://${peer.ip}:${SyncProtocol.dataPort}/sync'),
      );
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({'table': table, 'rows': rows})));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (
        ok: res.statusCode == 200 && json['ok'] == true,
        message: json['ok'] == true
            ? '已同步 $table：${json['written']} 行'
            : '${json['error']}',
      );
    } catch (e) {
      return (ok: false, message: '发送失败：$e');
    }
  }

  /// 从对端拉取一张表（GET /export?table=x → 幂等 upsert 入本机库）
  Future<({bool ok, String message})> fetchTable(
    PeerDevice peer,
    String table,
  ) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(
        Uri.parse(
          'http://${peer.ip}:${SyncProtocol.dataPort}/export?table=$table',
        ),
      );
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (res.statusCode != 200 || json['ok'] != true) {
        return (ok: false, message: '拉取 $table 失败：${json['error']}');
      }
      final rows = ((json['rows'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>();
      var written = 0;
      for (final row in rows) {
        await _upsertRow(table, row);
        written++;
      }
      return (ok: true, message: '已拉取 $table：$written 行');
    } catch (e) {
      return (ok: false, message: '拉取失败：$e');
    }
  }
}

/// 同步服务 provider
final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(appDatabaseProvider)),
);
