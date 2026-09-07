// 同步数据传输 —— HTTP 收发 + 按主键幂等 upsert（P3 同步的数据面）
//
// 协议：
//   GET  /ping  → 设备信息 JSON
//   POST /sync  → body: {"table": "...", "rows": [{col: val}, ...]}
// 幂等写：INSERT OR REPLACE（表必须声明主键）；仅允许白名单表。
// 安全 TODO(P3)：传输层加会话密钥（当前明文 JSON，仅限受信局域网）。
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import 'device_nickname.dart';
import 'sync_discovery.dart';
import 'sync_log.dart';

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

/// 可插拔路由（文件互传等模块向同步数据面注入自定义端点，复用 47124 不新开端口）
typedef _RouteMatcher = bool Function(HttpRequest request);
typedef _RouteHandler = Future<void> Function(HttpRequest request);

final List<(_RouteMatcher, _RouteHandler)> _extraRoutes = [];

/// 注册一个自定义路由处理器。
/// 每个请求先依次匹配 `_extraRoutes`，命中即交由 handler 处理（handler 自行关闭 response）。
/// 内置 /ping /export /sync 分支保持不变；文件互传的 /file/* 由 transfer_server 注册。
void registerRouteHandler(_RouteMatcher matcher, _RouteHandler handler) {
  _extraRoutes.add((matcher, handler));
}

/// 同步服务
class SyncService {
  SyncService(this._db, this._log);

  final AppDatabase _db;

  /// 同步日志（被动端事件也写入，使两端看到相同日志；见 sync_log.dart 说明）
  final SyncLogController _log;
  HttpServer? _server;

  /// 启动接收端（HTTP 数据面）；name/id 为空时回退本机信息
  Future<void> startServer({String name = '', String id = ''}) async {
    if (_server != null) return;
    // 回退逻辑收敛为局部变量（原 _serverName/_serverId 未声明，属既有编译错误）
    final resolvedName = name.isEmpty ? localBroadcastName : name;
    final resolvedId = id.isEmpty ? localDeviceId : id;
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      SyncProtocol.dataPort,
    );
    _server!.listen((request) async {
      // 先走可插拔路由（文件互传 /file/* 等）
      for (final (matcher, handler) in _extraRoutes) {
        if (matcher(request)) {
          await handler(request);
          return;
        }
      }
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
          // 被动端：对端来拉，动作是「拉取」，与对端 fetchTable 里那条字面相同
          _log.log('拉取 $table：${rows.length} 行', level: SyncLogLevel.ok);
          _json(request, {'ok': true, 'table': table, 'rows': rows});
        } catch (e) {
          _log.log('拉取 $table 失败：$e', level: SyncLogLevel.error);
          _json(request, {'ok': false, 'error': '$e'}, 500);
        }
        return;
      }
      if (request.uri.path == '/sync' && request.method == 'POST') {
        // 提前在 try 外声明：Dart 的 catch 子句是独立作用域，
        // 访问不到 try 块内的局部变量（日志要在 catch 里带上表名，故提到外层）
        String? table;
        try {
          final body = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(body) as Map<String, dynamic>;
          table = payload['table'] as String?;
          final rows = (payload['rows'] as List?) ?? const [];
          if (table == null || !kSyncableTables.contains(table)) {
            _json(request, {'ok': false, 'error': 'table 不在白名单'}, 400);
            return;
          }
          var written = 0;
          for (final row in rows.whereType<Map<String, dynamic>>()) {
            if (await _upsertRow(table, row)) written++;
          }
          // 原始 SQL 写入不会自动通知 drift 的 watch 流，整表写完后手动触发刷新，
          // 否则列表页停留在写入前的旧快照（「拉取/推送成功但界面空白」的根因）。
          _db.notifyUpdates({TableUpdate(table)});
          // 被动端：对端来推，动作是「推送」，与对端 sendTable 里那条字面相同
          _log.log('推送 $table：$written 行', level: SyncLogLevel.ok);
          _json(request, {'ok': true, 'written': written});
        } catch (e) {
          _log.log(
            '推送 ${table ?? '未知表'} 失败：$e',
            level: SyncLogLevel.error,
          );
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
  /// 返回值：是否真正写入了至少一列（cols 为空则不写，便于上层准确计数）。
  ///
  /// ⚠️ 坑（2026-09-07 定位）：这里走原始 SQL `customStatement`，而 drift 的
  /// `customStatement` **不会自动通知 watch 流**（drift 源码 connection_user.dart
  /// 已明注）。若只写不通知，列表页的 `.watch()` 会一直停留在拉取前的空快照，
  /// 表现为「拉取日志显示已写入 N 行，但界面列表空空」。**整表写完后调用方必须
  /// `_db.notifyUpdates({TableUpdate(table)})` 手动触发刷新**（见 fetchTable / POST /sync）。
  Future<bool> _upsertRow(String table, Map<String, dynamic> row) async {
    if (row.isEmpty) return false;
    final valid = await _columnsOf(table);
    final cols = row.keys.where(valid.contains).toList();
    if (cols.isEmpty) return false;
    final colSql = cols.map((c) => '"$c"').join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final values = cols.map((c) {
      return row[c]?.toString();
    }).toList();
    await _db.customStatement(
      'INSERT OR REPLACE INTO "$table" ($colSql) VALUES ($placeholders)',
      values,
    );
    return true;
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
      final ok = res.statusCode == 200 && json['ok'] == true;
      // 主动端推送：行数取「对端实际写入数」，与对端 POST /sync 分支那条字面相同
      if (ok) {
        _log.log('推送 $table：${json['written']} 行', level: SyncLogLevel.ok);
      } else {
        _log.log(
          '推送 $table 失败：${json['error']}',
          level: SyncLogLevel.error,
        );
      }
      return (
        ok: ok,
        message: json['ok'] == true
            ? '已同步 $table：${json['written']} 行'
            : '${json['error']}',
      );
    } catch (e) {
      _log.log('推送 $table 失败：$e', level: SyncLogLevel.error);
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
        if (await _upsertRow(table, row)) written++;
      }
      // 同 POST /sync 分支：原始 SQL 写后手动通知 watch 流刷新
      _db.notifyUpdates({TableUpdate(table)});
      // 主动端拉取：与对端 GET /export 分支那条字面相同
      _log.log('拉取 $table：$written 行', level: SyncLogLevel.ok);
      return (ok: true, message: '已拉取 $table：$written 行');
    } catch (e) {
      _log.log('拉取 $table 失败：$e', level: SyncLogLevel.error);
      return (ok: false, message: '拉取失败：$e');
    }
  }
}

/// 同步服务 provider
final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(appDatabaseProvider),
    ref.read(syncLogProvider.notifier),
  ),
);
