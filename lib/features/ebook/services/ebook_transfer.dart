// 电子书跨端传书 —— 复用同步数据面 47124 的 /ebook/* 三端点（不新开端口）
//
// 端点（两端对称实现，手机端在本文件，PC 端在 electron/main/module/ebookTransfer.ts）：
//   GET  /ebook/list                → {"ok":true,"books":[{"filePath","name","format","title","size","contentHash"}]}
//   GET  /ebook/download?path=<enc> → 原始文件字节（application/octet-stream）
//   POST /ebook/upload?name=&format= → body 为原始字节；接收方落盘并写入书架
//
// 设计要点：
// - 只传 epub/txt；身份键是内容 sha256（content_hash），同名不同内容不会误并。
// - 下载侧先取字节再交给 repository.importBookBytes，复用既有「哈希去重 + 沙盒落盘 + 书架入库」。
// - 路由注册幂等（_registered 守卫），与 transfer_server 同样的注入方式。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_discovery.dart';
import '../../../core/sync/sync_service.dart';
import '../repositories/ebook_repository.dart';

/// 对端书目条目
class RemoteBook {
  const RemoteBook({
    required this.filePath,
    required this.name,
    required this.format,
    this.title,
    this.size,
    this.contentHash,
  });

  final String filePath;
  final String name;
  final String format;
  final String? title;
  final int? size;
  final String? contentHash;

  factory RemoteBook.fromJson(Map<String, dynamic> j) => RemoteBook(
    filePath: (j['filePath'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    format: (j['format'] ?? '').toString(),
    title: j['title']?.toString(),
    size: j['size'] is num ? (j['size'] as num).toInt() : null,
    contentHash: j['contentHash']?.toString(),
  );

  String get display => (title?.isNotEmpty ?? false) ? title! : name;
}

/// 传书服务（同时承担接收端路由与发送端客户端）
class EbookTransferService {
  EbookTransferService(this._repo);

  final EbookRepository _repo;
  bool _registered = false;

  /// 向同步数据面注册 /ebook/* 路由（幂等）
  void registerRoutes() {
    if (_registered) return;
    _registered = true;
    registerRouteHandler(
      (r) => r.method == 'GET' && r.uri.path == '/ebook/list',
      _handleList,
    );
    registerRouteHandler(
      (r) => r.method == 'GET' && r.uri.path == '/ebook/download',
      _handleDownload,
    );
    registerRouteHandler(
      (r) => r.method == 'POST' && r.uri.path == '/ebook/upload',
      _handleUpload,
    );
  }

  // ---- 接收端 ----

  Future<void> _handleList(HttpRequest req) async {
    try {
      final rows = await _repo.db.select(_repo.db.ebookBookshelf).get();
      final books = <Map<String, dynamic>>[];
      for (final r in rows) {
        final f = File(r.filePath);
        if (!f.existsSync()) continue; // 只暴露本机真实有文件的书
        books.add({
          'filePath': r.filePath,
          'name': r.name ?? '',
          'format': r.format ?? '',
          'title': r.title ?? r.name ?? '',
          'size': f.lengthSync(),
          'contentHash': r.contentHash ?? '',
        });
      }
      _json(req, {'ok': true, 'books': books});
    } catch (e) {
      _json(req, {'ok': false, 'error': '$e'}, 500);
    }
  }

  Future<void> _handleDownload(HttpRequest req) async {
    final path = req.uri.queryParameters['path'] ?? '';
    final f = File(path);
    if (path.isEmpty || !f.existsSync()) {
      _json(req, {'ok': false, 'error': '文件不存在'}, 404);
      return;
    }
    try {
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.binary;
      req.response.headers.set('X-File-Name', Uri.encodeComponent(_fileNameOf(path)));
      await req.response.addStream(f.openRead());
      await req.response.close();
    } catch (e) {
      _json(req, {'ok': false, 'error': '$e'}, 500);
    }
  }

  Future<void> _handleUpload(HttpRequest req) async {
    try {
      final name = req.uri.queryParameters['name'] ?? 'book';
      final format = req.uri.queryParameters['format'] ?? '';
      final bytes = await req.fold<BytesBuilder>(
        BytesBuilder(),
        (b, chunk) => b..add(chunk),
      );
      final data = bytes.takeBytes();
      if (data.isEmpty) {
        _json(req, {'ok': false, 'error': '空文件'}, 400);
        return;
      }
      final ext = format == 'epub' ? '.epub' : '.txt';
      final base = name.endsWith(ext) ? name.substring(0, name.length - ext.length) : name;
      final book = await _repo.importBookBytes(
        name: base,
        format: format == 'epub' ? 'epub' : 'txt',
        bytes: data,
      );
      _json(req, {
        'ok': true,
        'title': book?.title ?? base,
        'contentHash': book?.contentHash ?? sha256.convert(data).toString(),
      });
    } catch (e) {
      _json(req, {'ok': false, 'error': '$e'}, 500);
    }
  }

  // ---- 发送端（客户端）----

  /// 拉取对端书目
  Future<List<RemoteBook>> fetchRemoteBooks(PeerDevice peer) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(
        Uri.parse('http://${peer.ip}:${SyncProtocol.dataPort}/ebook/list'),
      );
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['ok'] != true) return const [];
      final list = (json['books'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(RemoteBook.fromJson)
          .where((b) => b.format == 'epub' || b.format == 'txt')
          .toList();
    } catch (_) {
      return const [];
    } finally {
      client.close();
    }
  }

  /// 从对端下载一本书并导入本机书架
  Future<({bool ok, String message})> downloadBook(
    PeerDevice peer,
    RemoteBook book,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
        Uri.parse(
          'http://${peer.ip}:${SyncProtocol.dataPort}/ebook/download'
          '?path=${Uri.encodeComponent(book.filePath)}',
        ),
      );
      final res = await req.close();
      if (res.statusCode != 200) {
        return (ok: false, message: '下载失败（HTTP ${res.statusCode}）');
      }
      final builder = BytesBuilder();
      await res.forEach(builder.add);
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) return (ok: false, message: '下载内容为空');
      final saved = await _repo.importBookBytes(
        name: book.display,
        format: book.format,
        bytes: bytes,
      );
      return (
        ok: saved != null,
        message: saved == null ? '导入失败' : '已导入《${saved.title ?? saved.name}》',
      );
    } catch (e) {
      return (ok: false, message: '下载失败：$e');
    } finally {
      client.close();
    }
  }

  /// 把本机一本书上传到对端
  Future<({bool ok, String message})> uploadBook(
    PeerDevice peer,
    EbookBookshelfData book,
  ) async {
    final f = File(book.filePath);
    if (!f.existsSync()) return (ok: false, message: '本机文件不存在');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final name = '${book.title ?? book.name ?? 'book'}.${book.format == 'epub' ? 'epub' : 'txt'}';
      final req = await client.postUrl(
        Uri.parse(
          'http://${peer.ip}:${SyncProtocol.dataPort}/ebook/upload'
          '?name=${Uri.encodeComponent(name)}'
          '&format=${Uri.encodeComponent(book.format ?? 'epub')}',
        ),
      );
      req.headers.contentType = ContentType.binary;
      req.contentLength = await f.length();
      await req.addStream(f.openRead());
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode != 200) {
        return (ok: false, message: '上传失败（HTTP ${res.statusCode}）');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['ok'] != true) {
        return (ok: false, message: '上传失败：${json['error'] ?? '未知错误'}');
      }
      return (ok: true, message: '已发送到电脑《${book.title ?? book.name}》');
    } catch (e) {
      return (ok: false, message: '上传失败：$e');
    } finally {
      client.close();
    }
  }

  void _json(HttpRequest req, Map<String, dynamic> data, [int status = 200]) {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(data));
    req.response.close();
  }

  String _fileNameOf(String path) =>
      path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;
}

/// 传书服务 provider：创建时即注册 /ebook/* 路由
final Provider<EbookTransferService> ebookTransferProvider =
    Provider<EbookTransferService>((ref) {
      final srv = EbookTransferService(ref.watch(ebookRepositoryProvider));
      srv.registerRoutes();
      return srv;
    });
