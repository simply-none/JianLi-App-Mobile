import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui/page_banner.dart';
import 'ferry_server.dart';

/// 隔空互传页（webview_flutter 测试版）：本地 WebView 加载 QRFerry。
///
/// 前一版用 flutter_inappwebview，在 Android 模拟器出现「WebView 空白、连 loadStart/
/// loadStop 都不触发」的异常。本版改用官方 webview_flutter（4.x）：
///   - WebViewController.setJavaScriptMode(unrestricted) 开启 JS
///   - setOnPlatformPermissionRequest 授权摄像头（getUserMedia）
///   - setNavigationDelegate 的 onPageStarted/onPageFinished/onProgress/
///     onWebResourceError 全部打到 dev.log（[FerryPage] 前缀）
/// 页面保持「只一个占满内容区的 WebView」，诊断全走 logcat。确认新插件能正常渲染后，
/// 再恢复完整版 UI（PageBanner / 资产面板 / 自检卡片 / 加载进度）。
class FerryPage extends ConsumerStatefulWidget {
  const FerryPage({super.key});

  @override
  ConsumerState<FerryPage> createState() => _FerryPageState();
}

class _FerryPageState extends ConsumerState<FerryPage> {
  final FerryServer _server = FerryServer.instance;
  final GlobalKey _webViewKey = GlobalKey();
  WebViewController? _controller;
  String? _url;
  bool _starting = true;
  String? _error;

  // 诊断工具：资产自检 + 资产结构透视，结果打进 dev.log（logcat）。
  String? _assetCheck;
  List<String> _qyferryAssets = [];
  final List<String> _debug = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _addDebug(String s) {
    dev.log('[FerryPage] $s');
    if (!mounted) return;
    setState(() => _debug.add(s));
  }

  Future<void> _init() async {
    try {
      final status = await Permission.camera.request();
      dev.log('[FerryPage] camera permission=$status');
    } catch (e, st) {
      dev.log('[FerryPage] camera permission error', error: e, stackTrace: st);
    }
    try {
      final url = await _server.start();
      dev.log('[FerryPage] server url=$url');
      if (!mounted) return;

      // 用 webview_flutter 创建控制器并加载本地 QRFerry 站。
      // 注意：webview_flutter 4.14 把权限回调改为构造函数入参 onPermissionRequest
      // （旧版的 setOnPlatformPermissionRequest 链式方法已移除）。
      final controller = WebViewController(
        onPermissionRequest: (request) {
          dev.log('[FerryPage] platformPermissionRequest: ${request.types}');
          request.grant();
        },
      )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) => dev.log('[FerryPage] pageStarted: $url'),
            onPageFinished: (url) => dev.log('[FerryPage] pageFinished: $url'),
            onProgress: (progress) {
              dev.log('[FerryPage] progress: $progress');
              if (progress >= 100) {
                // webview_flutter 的 progress 可靠，100 即加载完成。
                dev.log('[FerryPage] load complete (progress=100)');
              }
            },
            onWebResourceError: (error) => dev.log(
              '[FerryPage] webResourceError: ${error.description} url=${error.url} type=${error.errorType}',
            ),
          ),
        );
      controller.loadRequest(Uri.parse(url));

      setState(() {
        _url = url;
        _starting = false;
        _controller = controller;
      });

      // 重新启用资产诊断（logcat 可见，不渲染额外 UI）。
      _selfCheckAssets(url);
      _dumpAssets();
    } catch (e, st) {
      dev.log('[FerryPage] start server error', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = '启动本地服务失败：$e';
        _starting = false;
      });
    }
  }

  /// 关键自检：拉取首页 HTML，提取它引用的 CSS 路径，再直接用 rootBundle 验证该资源
  /// 是否真的随应用打包。
  Future<void> _selfCheckAssets(String baseUrl) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(baseUrl));
      final resp = await req.close();
      final html = await resp.transform(utf8.decoder).join();
      // 现网 HTML 引用 /webassets/*.css（无 hash）；也兼容早期 /assets/*.css 写法。
      final m = RegExp(r'href="(/webassets/[^"]+\.css)"').firstMatch(html) ??
          RegExp(r'href="(/assets/[^"]+\.css)"').firstMatch(html);
      if (m == null) {
        setState(() => _assetCheck = '⚠️ 首页未找到 CSS 引用（HTML 结构异常）');
        dev.log('[FerryPage] assetCheck: 首页未找到 CSS 引用');
        return;
      }
      final cssPath = m.group(1)!; // /webassets/index.css 或 /assets/index-xxx.css
      // 移动端资源统一放在 assets/qyferry/webassets/ 下，直接取末尾文件名拼 asset key。
      final fileName = cssPath.split('/').where((s) => s.isNotEmpty).last;
      final assetKey = 'assets/qyferry/webassets/$fileName';
      try {
        await rootBundle.load(assetKey);
        setState(() => _assetCheck = '✅ CSS 资源已打包进 bundle');
        dev.log('[FerryPage] assetCheck: ✅ $assetKey');
      } catch (e) {
        setState(() => _assetCheck =
            '❌ CSS 资源未打包进 bundle：$assetKey\n→ 这是旧构建导致，请重新 flutter clean 构建');
        dev.log('[FerryPage] assetCheck: ❌ $assetKey');
      }
    } catch (e) {
      _addDebug('asset self-check failed: $e');
    }
  }

  /// 资产结构透视：枚举 bundle 内所有 qyferry 资源路径打印到 logcat，
  /// 一眼可见 webassets/ 子目录是否真的打进了 bundle（这正是隔空互传能否工作的关键）。
  Future<void> _dumpAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final qyferry = manifest
          .listAssets()
          .where((k) => k.contains('qyferry'))
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() => _qyferryAssets = qyferry);
      _addDebug('bundle 内 qyferry 资源共 ${qyferry.length} 项');
      for (final k in qyferry) _addDebug('  $k');
      _addDebug(qyferry.any((k) => k.contains('/webassets/'))
          ? '✅ 含 webassets/ 子目录'
          : '❌ 不含 webassets/ 子目录');
    } catch (e, st) {
      _addDebug('asset dump failed: $e');
      dev.log('[FerryPage] asset dump failed', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 隔离测试版：去掉所有装饰，页面只剩一个占满内容区的 WebView。
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('隔空互传'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_starting) {
      return const Center(child: FCircularProgress());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: context.theme.typography.body.sm
                .copyWith(color: context.theme.colors.destructive),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_controller == null) {
      return const Center(child: Text('WebView 初始化失败'));
    }
    // 只一个占满内容区的 WebView；所有生命周期回调打到 dev.log，看 logcat 判断。
    return WebViewWidget(
      key: _webViewKey,
      controller: _controller!,
    );
  }

  @override
  void dispose() {
    // 本地服务为单例常驻，其他入口可复用，不在此关闭。
    super.dispose();
  }
}
