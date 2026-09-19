// 浏览器下载服务 —— 把文件真正抓到磁盘（WebView 的 onDownloadStartRequest /
// 资源嗅探面板的「下载」都汇入这里）
//
// 不引新依赖：用 dart:io 的 HttpClient 直连抓取，落盘到
//   - 已授权「所有文件访问」：系统 Download/渐离App/browser_downloads/
//   - 否则 / 非 Android：沙盒 <supportDir>/渐离App/browser_downloads/
// 抓取期间 DB 里先落一条 pending 记录；完成改 done + 本地路径 + 大小，
// 失败改 failed（UI 据此展示状态，不阻塞页面）。
//
// ⚠️ MVP：抓取在主 isolate 同步 pipe，大文件会短暂占 UI 线程。后续若要后台断点续传，
// 可把这段抽到 isolate（仓库层 BrowserDownloadService 已隔离，改造成本低）。
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/public_downloads.dart'
    show hasPublicDownloadsAccess;
import '../data/browser_repository.dart';

/// 下载落盘基准子目录（挂在「Download/渐离App」或沙盒下）
const String _kDownloadSubDir = 'browser_downloads';

/// 浏览器下载服务
class BrowserDownloadService {
  BrowserDownloadService(this._repo);

  final BrowserRepository _repo;

  /// 解析落盘目录（首次调用即创建）
  Future<Directory> _resolveDir() async {
    if (Platform.isAndroid && await hasPublicDownloadsAccess()) {
      final dir = Directory(
        '/storage/emulated/0/Download/渐离App/$_kDownloadSubDir',
      );
      await dir.create(recursive: true);
      return dir;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, '渐离App', _kDownloadSubDir));
    await dir.create(recursive: true);
    return dir;
  }

  /// 入队一个下载：先落 pending 记录，再用 HttpClient 抓到磁盘，结束改状态。
  ///
  /// [filename] 为 null 时从 url 推断；[sizeBytes] 由调用方预填（服务端回报），
  /// 抓取完成后再用文件真实大小覆盖。
  Future<void> enqueue({
    required String url,
    String? filename,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final key = await _repo.addDownload(
      url: url,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
    try {
      final dir = await _resolveDir();
      final baseName = _safeName(filename ?? _nameFromUrl(url));
      final target = await _uniqueFile(File(p.join(dir.path, baseName)));
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      final sink = target.openWrite();
      await resp.pipe(sink);
      await sink.close();
      client.close(force: true);
      final len = await target.length();
      await _repo.updateDownload(
        key,
        status: 'done',
        localPath: target.path,
        sizeBytes: len,
        completedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // 抓取失败（网络/权限/磁盘）不影响页面；记录失败态供 UI 提示
      await _repo.updateDownload(key, status: 'failed');
    }
  }

  /// 重名则加 (1)(2)... 序号，避免覆盖旧文件
  Future<File> _uniqueFile(File f) async {
    if (!await f.exists()) return f;
    var i = 1;
    final base = p.basenameWithoutExtension(f.path);
    final ext = p.extension(f.path);
    File candidate;
    do {
      candidate = File(p.join(f.parent.path, '$base($i)$ext'));
      i++;
    } while (await candidate.exists());
    return candidate;
  }

  String _nameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final seg = uri?.pathSegments.where((e) => e.isNotEmpty).lastOrNull;
    if (seg != null && seg.contains('.')) return seg;
    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _safeName(String name) {
    var s = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (s.isEmpty) s = 'download';
    if (s.length > 120) s = s.substring(0, 120);
    return s;
  }
}
