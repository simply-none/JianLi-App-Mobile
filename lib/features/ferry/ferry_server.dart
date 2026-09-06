import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// 隔空互传本地静态服务（QRFerry）
///
/// 机制：把打包内的 assets/qyferry 用本地 http 服务从 [rootBundle] 即时托管到
/// 127.0.0.1 随机端口。127.0.0.1 是安全上下文，WebView 内 getUserMedia 摄像头可被授权；
/// 网页自带扫码识别与解码，本服务只负责把静态文件按 URL 吐出来。
///
/// 路径映射：
/// - 网页里资源引用固定写成 `/assets/...`（与 QRFerry 打包产物一致，PC 端也这样）。
/// - 移动端为了避免 Flutter asset 系统对 `assets/qyferry/assets/` 这种「assets 下嵌套 assets」
///   路径的打包异常（实测嵌套 assets 子目录会进不了 bundle），我们把实际资源目录改名为
///   `assets/qyferry/webassets/`；本服务收到 `/assets/...` 请求时 rewrite 到
///   `assets/qyferry/webassets/...`。
/// - 首页 `/` 与 `/index.html` 仍从 `assets/qyferry/index.html` 读取。
///
/// 单例：多个入口复用同一端口，避免重复绑定。
class FerryServer {
  FerryServer._();
  static final FerryServer instance = FerryServer._();

  HttpServer? _server;
  int? _port;

  static const String _assetRoot = 'assets/qyferry';
  static const String _webAssetDir = '$_assetRoot/webassets';

  static final Map<String, String> _mime = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.svg': 'image/svg+xml',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.ico': 'image/x-icon',
    '.wasm': 'application/wasm',
    '.map': 'application/json',
  };

  /// 起服务并返回首页 URL（已起则直接返回）。
  Future<String> start() async {
    if (_port != null) return 'http://127.0.0.1:$_port/';
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    print('[FerryServer] bound to http://127.0.0.1:$_port/');
    _server!.listen(_onRequest);
    return 'http://127.0.0.1:$_port/';
  }

  /// 将外部请求路径映射到 Flutter asset key。
  ///
  /// - `/` 与 `/index.html` -> `assets/qyferry/index.html`
  /// - `/assets/...` -> `assets/qyferry/webassets/...`
  /// - 其他 -> `assets/qyferry/<path>`
  String _toAssetKey(String urlPath) {
    if (urlPath == '/' || urlPath.isEmpty) return '$_assetRoot/index.html';
    // HTML 现引用 /webassets/...（无 hash）；兼容早期 /assets/... 写法。
    if (urlPath.startsWith('/webassets/')) {
      final suffix = urlPath.substring('/webassets/'.length);
      return '$_webAssetDir/$suffix';
    }
    if (urlPath.startsWith('/assets/')) {
      final suffix = urlPath.substring('/assets/'.length);
      return '$_webAssetDir/$suffix';
    }
    final clean = urlPath.replaceAll(RegExp(r'^/+'), '');
    return '$_assetRoot/$clean';
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      final urlPath = Uri.decodeComponent(req.uri.path);
      final assetKey = _toAssetKey(urlPath);
      print('[FerryServer] request $urlPath -> assetKey=$assetKey');

      late final ByteData data;
      try {
        data = await rootBundle.load(assetKey);
      } catch (e, st) {
        print('[FerryServer] 404 asset not found: $assetKey');
        dev.log('[FerryServer] 404 asset not found: $assetKey',
            error: e, stackTrace: st);
        req.response.statusCode = 404;
        req.response.headers.contentType = ContentType.text;
        req.response.write('not found: $assetKey');
        await req.response.close();
        return;
      }

      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // 关键：扩展名必须按「最终 assetKey」推算，而不是请求 URL 路径。
      // 首页请求是 `/`（无扩展名），若按 urlPath 算会得到空扩展名 →
      // Content-Type=application/octet-stream，WebView 不会把 HTML 当页面渲染 → 白屏。
      // assetKey 末尾是 index.html，按它算才是 text/html; charset=utf-8。
      final ext = assetKey.contains('.')
          ? assetKey.substring(assetKey.lastIndexOf('.')).toLowerCase()
          : '';
      final mime = _mime[ext] ?? 'application/octet-stream';
      req.response.statusCode = 200;
      req.response.contentLength = bytes.length;
      req.response.headers.contentType = ContentType.parse(mime);
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      req.response.headers.set('Cache-Control', 'no-cache');
      req.response.add(bytes);
      await req.response.close();
      print('[FerryServer] served $urlPath (${bytes.length} bytes, $mime)');
    } catch (e, st) {
      print('[FerryServer] failed ${req.uri.path}: $e');
      dev.log('[FerryServer] failed ${req.uri.path}', error: e, stackTrace: st);
      try {
        req.response.statusCode = 500;
        req.response.headers.contentType = ContentType.text;
        req.response.write('server error: $e');
        await req.response.close();
      } catch (_) {}
    }
  }

  /// 关闭服务（一般不需手动调用；单例常驻，App 退出由框架回收）。
  void stop() {
    _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
