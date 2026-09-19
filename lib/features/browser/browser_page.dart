// 浏览器主壳（单 WebView 多标签）
//
// 结构：SafeArea → 地址栏（顶部固定）→ 内容区（WebView / 极简首页）→ 底部工具栏
// 多标签模型：**只有一个 InAppWebView**，切标签 = 换地址重新 loadUrl；
//   空白标签显示 `about:blank` + 首页覆盖层（WebView 常驻不销毁，切回来能继续用）。
//
// 分工（避免单文件过大）：
//   components/browser_address_bar.dart  两态地址栏（纯展示）
//   components/browser_new_tab_home.dart 极简首页（新标签页）
//   components/browser_speed_dial.dart   固定标签九宫格（首页/管理页共用）
//   components/browser_toolbar.dart      底部工具栏（返回/前进/首页/标签/菜单）
//   components/browser_tab_sheet.dart    多标签抽屉
//   components/browser_menu_sheet.dart   菜单抽屉（5×2 图标网格 + 分页）
//   components/browser_find_bar.dart     页内查找条
//   components/browser_ua_sheet.dart     浏览器标识（UA）选择弹窗
//   pages/*.dart                         设置 / 固定标签管理 / 书签 / 历史 / 规则 / 清理数据
//   services/adblock_*.dart              广告拦截三级规则与订阅抓取
// 本文件只做「状态编排 + WebView 生命周期」，不放 UI 细节。
//
// ⚠️ 广告拦截接的是 `useShouldInterceptRequest` —— 该开关会让**所有**请求过平台通道，
//    开销不可忽视。因此它只在总开关打开时开启，且引擎侧用「域后缀 Set + 分词索引」
//    把单次判定压到常数级（见 services/adblock_engine.dart）。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';
import 'components/browser_address_bar.dart';
import 'components/browser_find_bar.dart';
import 'components/browser_menu_sheet.dart';
import 'components/browser_new_tab_home.dart';
import 'components/browser_sniff_sheet.dart';
import 'components/browser_tab_sheet.dart';
import 'components/browser_toolbar.dart';
import 'models/browser_models.dart';
import 'models/browser_settings.dart';
import 'providers/browser_providers.dart';
import 'services/browser_download_service.dart';

/// 空白标签统一地址（WebView 必须有个地址；用它来表示「当前是新标签页」）
const String kBrowserBlankUrl = 'about:blank';

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key, this.initialUrl});

  /// 外部带地址进入（如从别处的链接跳转），非空则新开一个标签
  final String? initialUrl;

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  InAppWebViewController? _web;
  final TextEditingController _address = TextEditingController();
  final FocusNode _addressFocus = FocusNode();

  bool _bootstrapped = false;
  bool _editing = false;
  double _progress = 1;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  String _pageTitle = '';
  String? _activeTabKey;

  /// DNT 注入去重集合（见 [_shouldOverrideUrlLoading]）
  final Set<String> _dntInjected = <String>{};

  /// 下载服务（WebView 触发 / 嗅探面板都汇入这里落盘）
  late final BrowserDownloadService _downloadService;

  // ——— 页内查找 / 全屏（菜单能力；运行时状态，不落库） ———
  bool _showFindBar = false;
  bool _fullscreen = false;
  final TextEditingController _findQuery = TextEditingController();
  int _findCount = 0;
  int _findActive = 0;
  Timer? _findTimer;

  @override
  void initState() {
    super.initState();
    _addressFocus.addListener(_onFocusChanged);
    _findQuery.addListener(_onFindChanged);
    _downloadService = BrowserDownloadService(ref.read(browserRepositoryProvider));
    // 一次性启动：写默认固定标签 + 恢复/新建标签会话（ref.read 一次性动作用 postFrame 更稳）
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  @override
  void dispose() {
    _addressFocus.removeListener(_onFocusChanged);
    _addressFocus.dispose();
    _address.dispose();
    _findQuery.removeListener(_onFindChanged);
    _findQuery.dispose();
    _findTimer?.cancel();
    // 退出浏览器时还原系统栏（全屏是全局的，不还原会波及别的页面）
    if (_fullscreen) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      );
    }
    super.dispose();
  }

  // ————————————————— 启动 / 标签 —————————————————

  Future<void> _bootstrap() async {
    final repo = ref.read(browserRepositoryProvider);
    await repo.ensureDefaultPinned();
    var tabs = await repo.loadTabs();
    final initial = widget.initialUrl?.trim() ?? '';
    if (initial.isNotEmpty) {
      final opened = await repo.createTab(url: normalizeUrl(initial));
      tabs = [...tabs, opened];
    }
    if (tabs.isEmpty) {
      final first = await repo.createTab();
      tabs = [first];
    }
    if (!mounted) return;
    final active = tabs.last;
    setState(() {
      _bootstrapped = true;
      _activeTabKey = active.key;
      // 打开浏览器一律停在首页（不恢复上次访问的页面）；只有「从外部链接带入地址」时才直接开那个链接
      _currentUrl = initial.isNotEmpty ? (active.url ?? '') : '';
      _progress = 1;
    });
  }

  /// 新建标签（[url] 为空 = 新标签页）
  Future<void> _newTab({String? url}) async {
    _addressFocus.unfocus();
    final repo = ref.read(browserRepositoryProvider);
    final tab = await repo.createTab(url: url);
    if (!mounted) return;
    setState(() {
      _activeTabKey = tab.key;
      _currentUrl = url ?? '';
      _editing = false;
      _progress = 1;
      _pageTitle = '';
    });
    await _load(_blankOr(url));
  }

  /// 切到某个标签
  Future<void> _switchTab(BrowserTab tab) async {
    // 当前已在首页（空白）时，点当前标签也要重新加载它的页面，而不是当成「已在当前标签」直接忽略
    if (tab.key == _activeTabKey && _currentUrl.trim().isNotEmpty) return;
    _addressFocus.unfocus();
    setState(() {
      _activeTabKey = tab.key;
      _currentUrl = tab.url ?? '';
      _editing = false;
      _progress = 1;
      _pageTitle = '';
    });
    await _load(_blankOr(tab.url));
  }

  /// 关闭标签；关的是当前标签时自动切到剩下最后一个，全关光则开一个新标签
  Future<void> _closeTab(String key) async {
    final repo = ref.read(browserRepositoryProvider);
    await repo.closeTab(key);
    if (!mounted) return;
    if (key != _activeTabKey) return;
    final rest = await repo.loadTabs();
    if (!mounted) return;
    if (rest.isEmpty) {
      await _newTab();
    } else {
      await _switchTabForce(rest.last);
    }
  }

  /// 强制切换（[_switchTab] 对「已是当前标签」会早退，关闭后需要强制重载）
  Future<void> _switchTabForce(BrowserTab tab) async {
    setState(() {
      _activeTabKey = tab.key;
      _currentUrl = tab.url ?? '';
      _editing = false;
      _progress = 1;
    });
    await _load(_blankOr(tab.url));
  }

  String _blankOr(String? url) {
    final s = (url ?? '').trim();
    return s.isEmpty ? kBrowserBlankUrl : s;
  }

  // ————————————————— 导航 —————————————————

  BrowserSettings get _settings =>
      ref.read(browserSettingsProvider).value ?? const BrowserSettings();

  /// 地址栏 / 首页搜索提交：网址直接开，关键词按搜索引擎搜
  Future<void> _submitInput(String raw) async {
    final s = _settings;
    final target = resolveInput(
      raw,
      engine: s.engine,
      customTemplate: s.customSearchTemplate,
    );
    if (target.isEmpty) return;
    await _load(target);
  }

  /// 加载地址（唯一的导航入口）
  Future<void> _load(String url) async {
    _addressFocus.unfocus();
    if (!mounted) return;
    setState(() {
      _editing = false;
      _progress = 0.05;
      if (url != kBrowserBlankUrl) _currentUrl = url;
    });
    final key = _activeTabKey;
    if (key != null && url != kBrowserBlankUrl) {
      await ref.read(browserRepositoryProvider).updateTab(key, url: url);
    }
    await _web?.loadUrl(urlRequest: _request(url));
  }

  /// 构造请求（开了「不追踪请求」时带上 DNT 头）
  URLRequest _request(String url) {
    final dnt = _settings.doNotTrack;
    return URLRequest(
      url: WebUri(url),
      headers: dnt ? const {'DNT': '1'} : null,
    );
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final focused = _addressFocus.hasFocus;
    if (focused == _editing) return;
    setState(() => _editing = focused);
    if (focused) {
      // 进入输入态：回填当前地址并全选（对齐 Chrome 点地址栏的行为）
      _address.text = _currentUrl == kBrowserBlankUrl ? '' : _currentUrl;
      _address.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _address.text.length,
      );
    }
  }

  void _exitEditing() {
    _addressFocus.unfocus();
    if (mounted) setState(() => _editing = false);
  }

  // ————————————————— WebView 回调 —————————————————

  void _setProgress(double value) {
    if (!mounted) return;
    final v = value.clamp(0.0, 1.0);
    if ((v - _progress).abs() < 0.01) return;
    setState(() => _progress = v);
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? uri) async {
    if (!mounted) return;
    final url = uri?.toString() ?? '';
    var title = '';
    try {
      title = (await controller.getTitle()) ?? '';
    } catch (_) {
      // 取标题失败不影响任何主流程
    }
    final canBack = await controller.canGoBack();
    final canFwd = await controller.canGoForward();
    if (!mounted) return;
    _dntInjected.clear();
    // 首页（空白标签）视为「浏览器内已无可后退」：回退应直接离开浏览器回到内容 tab，
    // 不能因为 WebView 历史里还残留之前浏览的网页（about:blank 只是压在历史上方的一个条目）
    // 而把回退吃掉、退回到旧网页。
    final isHome = url.isEmpty || url == kBrowserBlankUrl;
    setState(() {
      _progress = 1;
      _canGoBack = isHome ? false : canBack;
      _canGoForward = isHome ? false : canFwd;
      _pageTitle = title;
      if (url.isNotEmpty && url != kBrowserBlankUrl) _currentUrl = url;
    });
    final recordable =
        url.isNotEmpty &&
        url != kBrowserBlankUrl &&
        url.startsWith('http') &&
        !url.startsWith('about:');
    if (!recordable) return;
    final repo = ref.read(browserRepositoryProvider);
    final key = _activeTabKey;
    if (key != null) await repo.updateTab(key, url: url, title: title);
    // 无痕模式不写历史（Cookie/缓存的隔离由 WebView 的 incognito 设置负责）
    if (!_settings.incognito) {
      await repo.recordVisit(url: url, title: title);
    }
  }

  /// 打开新窗口 / 新标签的请求统一在本 WebView 内处理（不做多窗口）
  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    if (action.isForMainFrame != true) return NavigationActionPolicy.ALLOW;
    final s = _settings;
    if (!s.doNotTrack) return NavigationActionPolicy.ALLOW;
    final url = action.request.url?.toString() ?? '';
    if (url.isEmpty) return NavigationActionPolicy.ALLOW;
    // 去重护栏：请求里已带 DNT，或本轮已注入过 → 直接放行（否则会死循环）
    if (action.request.headers?['DNT'] == '1') {
      return NavigationActionPolicy.ALLOW;
    }
    if (_dntInjected.contains(url)) return NavigationActionPolicy.ALLOW;
    if (_dntInjected.length > 200) _dntInjected.clear();
    _dntInjected.add(url);
    await controller.loadUrl(urlRequest: _request(url));
    return NavigationActionPolicy.CANCEL;
  }

  // ————————————————— 菜单 / 分享 / 查找 / 源码 / 全屏 —————————————————

  Future<void> _openMenu() async {
    await showBrowserMenuSheet(
      context,
      currentUrl: _currentUrl,
      handlers: BrowserMenuHandlers(
        onAddBookmark: _addBookmark,
        onShare: _share,
        onFindInPage: _findInPage,
        onViewSource: _viewSource,
        onToggleFullscreen: _toggleFullscreen,
        onSniff: _openSniff,
        onSaveOffline: _saveOffline,
      ),
    );
  }

  Future<void> _share() async {
    final url = _currentUrl;
    if (url.isEmpty || url == kBrowserBlankUrl) return;
    await SharePlus.instance.share(ShareParams(text: url));
  }

  /// 查找输入框内容变化：清空则清高亮；否则 250ms 防抖后触发 findAllAsync
  void _onFindChanged() {
    _findTimer?.cancel();
    final q = _findQuery.text;
    if (q.isEmpty) {
      unawaited(_web?.clearMatches());
      if (mounted) setState(() => _findCount = _findActive = 0);
      return;
    }
    _findTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_web?.findAllAsync(find: q));
    });
  }

  void _findInPage() {
    if (mounted) setState(() => _showFindBar = true);
  }

  /// 命中结果回调（findAllAsync 不返回数量，只能从这里拿）
  void _onFindResult(
    InAppWebViewController controller,
    int active,
    int total,
    bool done,
  ) {
    if (!mounted) return;
    setState(() {
      _findCount = total;
      _findActive = total == 0 ? 0 : active + 1; // 展示用 1-based
    });
  }

  Future<void> _closeFind() async {
    _findQuery.clear();
    _findTimer?.cancel();
    await _web?.clearMatches();
    if (mounted) {
      setState(() {
        _showFindBar = false;
        _findCount = 0;
        _findActive = 0;
      });
    }
  }

  Future<void> _viewSource() async {
    final url = _currentUrl;
    if (url.isEmpty || url == kBrowserBlankUrl) return;
    final html = await _web?.evaluateJavascript(
      source: 'document.documentElement.outerHTML',
    );
    if (!mounted) return;
    final text = html is String ? html : html?.toString() ?? '';
    unawaited(context.push('/browser/view-source', extra: text));
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  // ————————————————— 资源嗅探 / 离线页面 —————————————————

  /// 注入 JS 枚举当前页可下载资源（img / video / audio / a[download]）
  static const String _sniffJs = '''
(function(){
  var out = [];
  function push(kind, els, attr){
    for (var i = 0; i < els.length; i++){
      var el = els[i];
      var u = el.getAttribute(attr) || el.src || el.href;
      if (!u) continue;
      out.push({url: u, kind: kind, tag: el.tagName});
    }
  }
  push('image', document.querySelectorAll('img'), 'src');
  push('video', document.querySelectorAll('video'), 'src');
  push('audio', document.querySelectorAll('audio'), 'src');
  push('link', document.querySelectorAll('a[download]'), 'href');
  return JSON.stringify(out);
})()
''';

  /// 资源嗅探：枚举当前页资源并打开嗅探面板（每行可下载）
  Future<void> _openSniff() async {
    if (_web == null) return;
    final json = await _web!.evaluateJavascript(source: _sniffJs);
    final resources = <BrowserSniffedResource>[];
    if (json is String && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final kind = switch (map['kind']) {
            'video' => BrowserSniffKind.video,
            'audio' => BrowserSniffKind.audio,
            'link' => BrowserSniffKind.link,
            _ => BrowserSniffKind.image,
          };
          final url = (map['url'] ?? '').toString();
          if (url.isNotEmpty) {
            resources.add(
              BrowserSniffedResource(
                url: url,
                kind: kind,
                tagName: (map['tag'] ?? '').toString(),
              ),
            );
          }
        }
      } catch (_) {
        // 解析失败：空列表兜底，面板提示「无资源」
      }
    }
    if (!mounted) return;
    showBrowserSniffSheet(
      context,
      resources: resources,
      onDownload: (url, name) {
        unawaited(
          _downloadService.enqueue(url: url, filename: name),
        );
        showFToast(context: context, title: const Text('已开始下载'));
      },
    );
  }

  /// 离线页面：抓取当前页 HTML 存库，并打开离线列表
  Future<void> _saveOffline() async {
    final url = _currentUrl;
    if (url.isEmpty || url == kBrowserBlankUrl) {
      showFToast(context: context, title: const Text('当前页面无地址'));
      return;
    }
    final html = await _web?.evaluateJavascript(
      source: 'document.documentElement.outerHTML',
    );
    final text = html is String ? html : html?.toString() ?? '';
    await ref.read(browserRepositoryProvider).saveOfflinePage(
      url: url,
      title: _pageTitle,
      html: text,
    );
    if (!mounted) return;
    showFToast(context: context, title: const Text('已保存离线页面'));
    unawaited(context.push('/browser/offline'));
  }

  Future<void> _addBookmark() async {
    final url = _currentUrl;
    if (url.isEmpty || url == kBrowserBlankUrl) return;
    await ref.read(browserRepositoryProvider).addBookmark(
      title: _pageTitle.isEmpty ? hostOf(url) : _pageTitle,
      url: url,
    );
    if (!mounted) return;
    showFToast(context: context, title: const Text('已加入书签'));
  }

  /// 回首页（新标签页）。把当前标签的地址清掉，WebView 退回 `about:blank`，
  /// 首页覆盖层随之显出来（不新开标签 —— 与 Chrome 的「主页」按钮一致）。
  Future<void> _goHome() async {
    _addressFocus.unfocus();
    final key = _activeTabKey;
    if (key != null) {
      await ref.read(browserRepositoryProvider).updateTab(key, url: '');
    }
    if (!mounted) return;
    setState(() {
      _editing = false;
      _currentUrl = '';
      _pageTitle = '';
      _progress = 1;
      _canGoBack = false;
      _canGoForward = false;
    });
    await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(kBrowserBlankUrl)));
  }

  // ————————————————— 广告拦截 —————————————————

  /// 是否拦截某个子资源请求。
  ///
  /// ⚠️ **主文档绝不拦**（`isForMainFrame == true` 直接放行）——
  /// 规则写错时最坏的结果应该是「某个广告没拦住」，而不是「整页白屏」。
  Future<WebResourceResponse?> _shouldInterceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    if (!mounted) return null;
    if (request.isForMainFrame == true) return null;
    // WebResourceRequest.url 在 6.x 是非空类型
    final url = request.url.toString();
    if (url.isEmpty) return null;
    if (!ref.read(adBlockEngineProvider).shouldBlock(url)) return null;
    // 返回空响应体即「拦下不请求」（Android：不再走网络）
    return WebResourceResponse(contentType: 'text/plain', data: Uint8List(0));
  }

  // ————————————————— 新窗口 / 热更设置 —————————————————

  /// 网页里 `target="_blank"` / `window.open` 的链接：
  /// **不交给 WebView 新建窗口**（那会离开我们的多标签模型），而是自己开一个标签，
  /// 按设置决定前台切换还是后台静默打开。
  Future<bool> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final raw = action.request.url?.toString() ?? '';
    final url = raw.trim();
    if (url.isEmpty || url == kBrowserBlankUrl) return false;
    final repo = ref.read(browserRepositoryProvider);
    final tab = await repo.createTab(url: url);
    if (!mounted) return false;
    final foreground =
        _settings.newTabMode == BrowserNewTabMode.foreground;
    if (!foreground) return false; // 后台打开：标签已建好，留在当前页
    setState(() {
      _activeTabKey = tab.key;
      _currentUrl = url;
      _editing = false;
      _progress = 1;
      _pageTitle = '';
    });
    await _load(url);
    return false;
  }

  /// WebView 设置（唯一构造点 —— 首次创建与后续热更都用它，避免两处漂移）
  InAppWebViewSettings _webSettings(BrowserSettings s) {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      useShouldOverrideUrlLoading: true,
      supportZoom: true,
      mediaPlaybackRequiresUserGesture: false,
      domStorageEnabled: true,
      allowFileAccess: true,
      transparentBackground: false,
      verticalScrollBarEnabled: false,
      thirdPartyCookiesEnabled: true,
      incognito: s.incognito,
      cacheEnabled: !s.incognito,
      // 自定义 UA：电脑模式 / 浏览器标识 命中时覆盖（null = 用默认移动 UA）
      userAgent: s.effectiveUserAgent,
      // 无图模式：直接让 WebView 不加载图片（省流量；比借广告引擎拦更干净）
      blockNetworkImage: s.noImage,
      // 深色模式：跟随系统 = AUTO，亮色 = OFF，深色 = ON（Android 10+ 强制深色）
      // ⚠️ 公开名是 `ForceDark`；`ForceDark_` 是生成器的**内部**实现类，未导出，别用。
      forceDark: switch (s.darkMode) {
        BrowserDarkMode.system => ForceDark.AUTO,
        BrowserDarkMode.light => ForceDark.OFF,
        BrowserDarkMode.dark => ForceDark.ON,
      },
      // 网页字号（textZoom 以 100 为基准）
      textZoom: (s.fontScale * 100).round(),
      // 广告拦截：**仅总开关打开时**开启请求拦截（该开关会让所有请求过平台通道）
      useShouldInterceptRequest: s.adBlockEnabled,
      // 多窗口：让 target=_blank 走 onCreateWindow，由我们自己开成标签
      supportMultipleWindows: true,
    );
  }

  /// 把可热更的设置推给已存在的 WebView（深色模式 / 网页字号 / 无图 / UA）。
  ///
  /// 为什么不用重建 WebView：重建会丢掉当前页面的滚动位置与表单状态。
  /// `setSettings` 能原地生效的项就走它；`incognito` 这类必须重建的项仍走 key。
  Future<void> _applyWebSettings(BrowserSettings s) async {
    final controller = _web;
    if (controller == null) return;
    try {
      await controller.setSettings(settings: _webSettings(s));
    } catch (_) {
      // 个别设置在低版本 WebView 上不支持：忽略即可，不影响页面继续使用
    }
  }

  Widget _content(List<BrowserPinnedData> pinned, BrowserSettings settings) {
    final blank = _currentUrl.trim().isEmpty;
    return Stack(
      children: [
        if (_bootstrapped)
          Positioned.fill(
            child: InAppWebView(
              // incognito 变化需要重建 WebView（模式隔离），故写进 key
              key: ValueKey('browser-webview-${settings.incognito}'),
              initialUrlRequest: URLRequest(
                url: WebUri(_blankOr(_currentUrl)),
                headers: settings.doNotTrack ? const {'DNT': '1'} : null,
              ),
              // 与 [_webSettings] 同源：首次创建 / 后续热更走同一套值，避免两处漂移
              initialSettings: _webSettings(settings),
              onWebViewCreated: (controller) => _web = controller,
              onLoadStart: (controller, uri) => _setProgress(0.05),
              onProgressChanged: (controller, value) =>
                  _setProgress(value / 100),
              onLoadStop: _onLoadStop,
              onReceivedError: (controller, request, error) =>
                  _setProgress(1),
              onUpdateVisitedHistory: (controller, uri, isReload) {
                final url = uri?.toString() ?? '';
                if (!mounted) return;
                if (url.isEmpty || url == kBrowserBlankUrl) return;
                setState(() => _currentUrl = url);
              },
              shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
              // 广告拦截：仅在总开关打开时该回调才有意义（settings 里已联动开关）
              shouldInterceptRequest: _shouldInterceptRequest,
              // 网页 target=_blank / window.open → 由我们自己开成标签
              onCreateWindow: _onCreateWindow,
              // 下载请求（点文件链接等）：系统把下载交给我们，落盘到本地
              onDownloadStartRequest: (controller, request) {
                unawaited(
                  _downloadService.enqueue(
                    url: request.url.toString(),
                    filename: request.suggestedFilename,
                    mimeType: request.mimeType,
                    sizeBytes: request.contentLength > 0
                        ? request.contentLength
                        : null,
                  ),
                );
                if (mounted) {
                  showFToast(context: context, title: const Text('已开始下载'));
                }
              },
              // 页内查找命中结果（findAllAsync 不返回数量，只能从这里汇总）
              onFindResultReceived: _onFindResult,
            ),
          ),
        if (!_bootstrapped)
          // forui 的进度环（不依赖 Material 祖先；FScaffold.child 里没有 Material）
          const Center(child: FCircularProgress()),
        // 新标签页：首页盖在 WebView 之上（WebView 常驻不销毁，切回旧标签不丢页面）
        if (_bootstrapped && blank)
          Positioned.fill(
            child: BrowserNewTabHome(
              sites: pinned,
              showPinned: settings.showPinnedOnHome,
              onTapSearch: () => _addressFocus.requestFocus(),
              onOpenSite: (site) {
                final url = (site.url ?? '').trim();
                if (url.isNotEmpty) unawaited(_load(normalizeUrl(url)));
              },
              // 长按首页格子 = 去管理页（替换地址 / 排序 / 移除都在那儿）
              onLongPressSite: (_) => context.push('/browser/pinned'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(browserSettingsProvider).value ?? const BrowserSettings();
    final pinned =
        ref.watch(pinnedSitesProvider).value ?? const <BrowserPinnedData>[];
    final tabs = ref.watch(browserTabsProvider).value ?? const <BrowserTab>[];

    // 子页（书签 / 历史 / 固定标签页）请求导航：消费后**立刻清空**，
    // 否则同一地址在下次 push 时会被再次消费。
    ref.listen<String?>(browserPendingUrlProvider, (previous, next) {
      if (next == null || next.trim().isEmpty) return;
      ref.read(browserPendingUrlProvider.notifier).consume();
      unawaited(_load(next.trim()));
    });

    // 设置热更：深色模式 / 网页字号 / 广告拦截开关 / 无图 / 电脑模式 / UA 能原地生效，
    // 就绝不重建 WebView（重建会丢滚动位置与表单状态）。
    // incognito 做不到，仍走 key 重建；UA 类改动需要重载当前页才能生效。
    ref.listen<AsyncValue<BrowserSettings>>(browserSettingsProvider, (
      previous,
      next,
    ) {
      final before = previous?.value;
      final after = next.value;
      if (before == null || after == null) return;
      final hot = before.darkMode != after.darkMode ||
          before.fontScale != after.fontScale ||
          before.adBlockEnabled != after.adBlockEnabled ||
          before.noImage != after.noImage ||
          before.desktopMode != after.desktopMode ||
          before.uaPreset != after.uaPreset ||
          before.customUa != after.customUa;
      if (!hot) return;
      unawaited(_applyWebSettings(after));
      // UA 类改动：setSettings 的 customUserAgent 只作用于后续请求，
      // 已加载的页面要 reload 才换 UA。
      final uaChanged = before.desktopMode != after.desktopMode ||
          before.uaPreset != after.uaPreset ||
          before.customUa != after.customUa;
      if (uaChanged &&
          _currentUrl.trim().isNotEmpty &&
          _currentUrl != kBrowserBlankUrl) {
        unawaited(_web?.reload());
      }
    });

    return PopScope(
      // 能后退就先把后退交给网页（浏览器通用行为），退无可退才出浏览器
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_web?.goBack() ?? Future<void>.value());
      },
      child: FScaffold(
        childPad: false,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BrowserAddressBar(
                controller: _address,
                focusNode: _addressFocus,
                editing: _editing,
                url: _currentUrl,
                progress: _progress,
                onSubmit: (raw) => unawaited(_submitInput(raw)),
                onCancel: _exitEditing,
              ),
              Expanded(
                child: Stack(
                  children: [
                    _content(pinned, settings),
                    if (_showFindBar)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: FindInPageBar(
                          controller: _findQuery,
                          count: _findCount,
                          active: _findActive,
                          onPrev: () =>
                              unawaited(_web?.findNext(forward: false)),
                          onNext: () =>
                              unawaited(_web?.findNext(forward: true)),
                          onClose: () => unawaited(_closeFind()),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: BrowserToolbar(
                  canGoBack: _canGoBack,
                  canGoForward: _canGoForward,
                  tabCount: tabs.length,
                  onBack: () =>
                      unawaited(_web?.goBack() ?? Future<void>.value()),
                  onForward: () =>
                      unawaited(_web?.goForward() ?? Future<void>.value()),
                  // 中间位 = 回首页。当前已经是新标签页（无地址）时置灰，避免无意义点击。
                  onHome: _currentUrl.trim().isEmpty
                      ? null
                      : () => unawaited(_goHome()),
                  onTabs: () => unawaited(
                    showBrowserTabsSheet(
                      context,
                      activeKey: _activeTabKey,
                      onSwitch: _switchTab,
                      onClose: _closeTab,
                      onNewTab: () => unawaited(_newTab()),
                    ),
                  ),
                  onMenu: () => unawaited(_openMenu()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
