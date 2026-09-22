// 阅读器页
//
// EPUB：flutter_epub_viewer（epub.js 引擎）—— 原生滑动翻页、文本选区高亮 / 下划线、
//       任意位置书签、笔记、全文搜索、主题 / 字号 / 行距；锚点走 epub CFI
//       （与 PC 端 epubjs 同构，跨端批注零成本互通）。
//       沉浸阅读：隐藏系统状态栏、阅读全程保持屏幕常亮、顶栏做浮层（点正文中间浮出）；
//       翻页模式下点左右边界（各 25%）翻页，左右热区以外才切换顶栏。
// TXT ：沿用 epubx + flutter_widget_from_html 的章节滚动渲染（旧路径保持不变）。
//
// 进度 / 书签 / 批注落库锚点统一为 epub CFI（ebook_progress.cfi、ebook_bookmark.cfi、
// ebook_annotation.anchor 三列早已是 CFI 就绪，旧 `chapter:<i>` 占位仅 TXT 路径保留）。
import 'dart:async';
import 'dart:io';

import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:forui/forui.dart';
import 'package:flutter/services.dart'
    show SystemChrome, SystemUiMode, SystemUiOverlay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../../../core/device/screen_awake.dart';
import '../providers/ebook_providers.dart';
import '../providers/reader_settings.dart';
import '../repositories/ebook_repository.dart';
import '../services/epub_service.dart';
import 'annotation_sheet.dart';
import 'reader_settings_sheet.dart';

/// 强制字体的选择器（放过 pre / code，保住等宽语义）
const String _kFontSelector =
    'p, div, li, td, th, blockquote, dd, dt, figcaption, h1, h2, h3, h4, h5, h6';

/// 强制文字色继承的选择器（书内联 `color` 一律让位给主题正文色）
const String _kColorSelector = 'p, div, span, li, td, th, a, em, strong, b, i, '
    'u, small, sub, sup, blockquote, dd, dt, figcaption, section, article, '
    'address, h1, h2, h3, h4, h5, h6';

/// 强制字号 / 行距的选择器（正文块级 + 行内，**不含 h1-h6**）。
///
/// ⚠️ **为何不能只挂在 `body`**：epub 书的正文几乎都在 `<p>/<div>/<span>` 里，书自带
///   CSS 通常给这些元素**声明了各自的 `font-size`**，会覆盖从 `body` 继承的值（就像
///   `font-family` 早已用 `_kFontSelector` 直接打到元素上才生效，只挂 `body` 的中文正文
///   不跟着变）。故字号 / 行距必须同样直接注入正文元素。
/// ⚠️ **故意排除标题**：h1-h6 在书里一般有独立 `font-size`，强制覆盖会把标题层级压平，
///   故交回书自带样式，仅正文响应滑块。
const String _kSizeSelector = 'p, div, span, li, td, th, a, em, strong, b, i, '
    'u, small, sub, sup, blockquote, dd, dt, figcaption, section, article, '
    'address';

/// 点击翻页的左右热区宽度（占阅读区宽度的比例）
///
/// 翻页模式下：`x < 0.25` → 上一页、`x > 0.75` → 下一页，
/// **中间 50% 才是「点击浮出顶栏」的区域**（阅读器惯例，也是用户定案）。
/// 滚动模式**不启用**热区（连续滚动本身就是导航方式），任何位置点击都切换顶栏。
const double _kTapTurnZone = 0.25;

/// 阅读器页（路由参数：书籍沙盒路径；可选 initialChapter = 笔记页「跳到该章」用；
/// 可选 initialCfi = 笔记页「跳到位置」用，epubcfi 串）
class EpubReaderPage extends ConsumerStatefulWidget {
  const EpubReaderPage({
    super.key,
    required this.filePath,
    this.initialChapter,
    this.initialCfi,
  });

  final String filePath;

  /// 指定起始章节索引（笔记页「跳到该章」传入）— 仅 TXT 路径使用
  final int? initialChapter;

  /// 指定起始 CFI 位置（笔记页「跳到位置」传入）— 仅 EPUB 路径使用
  final String? initialCfi;

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  bool get _isTxt => widget.filePath.toLowerCase().endsWith('.txt');

  // ---- 公共 ----
  String? _contentHash;
  String _format = 'epub';
  String? _title;
  // 仅 EPUB 路径使用，实例稳定（key 变更重建的是 EpubViewer 而非控制器）
  late final EpubController _epubController = EpubController();

  // ---- TXT 状态 ----
  ParsedBook? _book;
  int _chapter = 0;
  bool _loadingTxt = true;
  String? _error;

  // ---- EPUB 状态 ----
  bool _loadingEpub = true;
  // epub.js 渲染就绪（onEpubLoaded 后置 true）——未就绪时样式热更新必须排队等它
  bool _epubReady = false;
  String? _savedCfi;
  String? _currentCfi;
  double _currentPercent = 0;
  List<EpubChapter> _chapters = [];
  (String, String)? _lastSelection; // (cfi, text)
  Timer? _saveTimer;

  // ---- 沉浸阅读：顶栏默认隐藏，点正文才浮出（阅读器惯例）----
  bool _chromeVisible = false;
  Timer? _chromeTimer;
  DateTime? _tapDownAt;
  double _tapDownX = 0;
  double _tapDownY = 0;

  /// 上一次「点击」被处置的时刻（翻页 / 切换顶栏共用同一个去重窗口）
  DateTime? _lastTapHandledAt;

  @override
  void initState() {
    super.initState();
    // 阅读界面不展示系统状态栏（沉浸阅读）：只藏状态栏、保留底部手势条，
    // 顶栏浮层与正文才能一直顶到屏幕上缘。
    // ⚠️ SystemChrome 是全局的，退出必须在 dispose 还原（同浏览器页规矩）。
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.bottom],
      ),
    );
    // 阅读时屏幕常亮（用户会长时间不触屏）：离页在 dispose 释放。
    // 走 core/device/screen_awake.dart 的共享守卫（引用计数），避免与文件互传 #19 保活互相误关。
    unawaited(acquireScreenAwake());
    _init();
  }

  /// 阅读设置变更分派：样式类 → 热更新；结构类 → 重建 EpubViewer
  ///
  /// ⚠️ **Riverpod 铁律：`ref.listen` 只能在 `build()` 里调**（框架断言
  ///    `debugDoingBuild`，放 `initState` 直接抛
  ///    `ref.listen can only be used within the build method of a ConsumerWidget`）。
  ///    每次 build 重复调用是安全的：Riverpod 会在重建时**替换**上一个监听，不会累积。
  void _listenSettings() {
    ref.listen(readerSettingsProvider, (prev, next) {
      if (prev == null) return;
      // 翻页方式 / 分栏 / 方向无法热切换（epub.js 需重新 renderTo）→ 整重建，
      // 位置靠 _currentCfi 续接
      if (prev.structureFingerprint != next.structureFingerprint) {
        _epubReady = false;
        if (mounted) setState(() => _loadingEpub = true);
        return;
      }
      if (prev.styleFingerprint != next.styleFingerprint) {
        _applyStyle(next);
      }
    });
  }

  /// 样式热更新：只推 CSS / 字号给已加载的 epub.js，不重载整本书
  Future<void> _applyStyle(ReaderSettings s) async {
    if (!_epubReady) return;
    try {
      await _epubController.updateTheme(theme: _epubTheme(s));
    } catch (_) {
      // 忽略：webview 未就绪 / 书已卸载
    }
    try {
      await _epubController.setFontSize(fontSize: s.fontSize);
    } catch (_) {}
  }

  Future<void> _init() async {
    try {
      final repo = ref.read(ebookRepositoryProvider);
      final row = await repo.findBookByPath(widget.filePath);
      if (row != null) {
        _contentHash = row.contentHash;
        _format = row.format ?? (_isTxt ? 'txt' : 'epub');
        _title = row.title;
        final progress = await repo.getProgress(row);
        final cfi = progress?.cfi ?? '';
        if (cfi.startsWith('epubcfi')) _savedCfi = cfi;
      }
      if (widget.initialCfi != null && widget.initialCfi!.startsWith('epubcfi')) {
        _savedCfi = widget.initialCfi;
      }
    } catch (_) {
      // 忽略：无 content_hash 时各项功能降级为不落库
    }
    if (_isTxt) _loadTxt(); // TXT 异步解析（fire-and-forget）
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _chromeTimer?.cancel();
    // 还原系统栏：SystemChrome 是全局的，不还原会波及别的页面
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    // 释放屏幕常亮（引用计数；只在没人再持有且进页前本就是关的时候才真关）
    unawaited(releaseScreenAwake());
    super.dispose();
  }

  // ===========================================================================
  // 构建分发
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    // ⚠️ 必须在这里注册，不能搬进 initState（见 _listenSettings 注释）
    _listenSettings();
    return _isTxt ? _buildTxt() : _buildEpub();
  }

  // ===========================================================================
  // EPUB（flutter_epub_viewer）
  // ===========================================================================

  /// 主题映射（对齐 PC 端 themePresets：day #fff/#333、night #1a1a1a/#ccc、eye #c7edcc/#2c3e50）
  EpubTheme _epubTheme(ReaderSettings s) => EpubTheme.custom(
        backgroundDecoration: BoxDecoration(color: resolveReaderBg(s)),
        foregroundColor: resolveReaderText(s),
        customCss: _readerCss(s),
      );

  /// 注入 epub iframe 的强制样式
  ///
  /// ⚠️ **为什么必须走 customCss 而不是 `backgroundDecoration`**：
  ///    `EpubTheme.backgroundDecoration` 在 `flutter_epub_viewer` 里**根本没有下发到
  ///    JS**（`epub_viewer.dart` 的 loadBook 写死 `'backgroundColor': null`），它只用于
  ///    给 Flutter 侧的 Container 上色。所以「护眼主题只有顶部非阅读区变色、正文还是
  ///    白底」——必须把底色 / 文字色塞进 customCss，由 epub.js `themes.register`
  ///    注入到 iframe 内部。
  ///
  /// ⚠️ **为什么每个值都带 `!important`**：书自带 CSS 常有 `body{background:#fff}`、
  ///    `span{color:#000}`，不带 !important 一律被书压过（夜间模式直接黑底黑字）。
  ///    epub.js 自身也这么干（dist 8385 行 `"100%" + "!important"`）。
  ///
  /// ⚠️ **为什么「关掉」的效果也要显式注入中性值**：epub.js `addStylesheetRules`
  ///    是往同一个 `<style id="epubjs-inserted-css-user-theme">` 里**追加**规则
  ///    （`insertRule`），不清除旧规则。省略某个键 = 上一次的值永久残留。
  ///    故 text-indent 关闭要写 `0`、字体用具体族名而不是省略。
  Map<String, dynamic> _readerCss(ReaderSettings s) {
    final bg = colorToHex(resolveReaderBg(s));
    final fg = colorToHex(resolveReaderText(s));
    final family = readerFontFamily(s.font);
    final indent = readerTextIndent(s.indent);
    return {
      // html 兜底：iframe 视口整体染色（body 有 padding 时四周边缘也能覆盖）
      'html': {
        'background-color': '$bg !important',
        'background-image': 'none !important',
        'color': '$fg !important',
      },
      'body': {
        'background-color': '$bg !important',
        'background-image': 'none !important',
        'color': '$fg !important',
        'font-family': '$family !important',
        'font-size': '${s.fontSize.round()}px !important',
        'line-height': '${s.lineHeight.toStringAsFixed(2)} !important',
        'padding': '${readerBodyPadding(s.margin)} !important',
        'text-align': '${readerTextAlign(s.align)} !important',
        'text-indent': '$indent !important',
        'max-width': '100% !important',
      },
      // 字体：只压正文块级元素，放过 pre / code（等宽语义）
      _kFontSelector: {'font-family': '$family !important'},
      // 字号 / 行距：必须直接打到正文元素（见 _kSizeSelector 注释），只挂 body
      // 会被书自带 p/div 的 font-size 覆盖 → 中文正文不随滑块变。
      _kSizeSelector: {
        'font-size': '${s.fontSize.round()}px !important',
        'line-height': '${s.lineHeight.toStringAsFixed(2)} !important',
      },
      // 文字色：书内联的 `color` 一律继承 body，否则夜间模式出现黑底黑字
      _kColorSelector: {'color': 'inherit !important'},
      'p': {
        'margin': '${readerParagraphMargin(s.spacing)} !important',
        'text-indent': '$indent !important',
      },
      'img': {'max-width': '100% !important', 'height': 'auto !important'},
    };
  }

  Color _toColor(String? name) {
    switch ((name ?? 'yellow').toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'pink':
        return Colors.pink;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'red':
        return Colors.red;
      default:
        return Colors.yellow;
    }
  }

  Widget _buildEpub() {
    final settings = ref.watch(readerSettingsProvider);
    return FScaffold(
      // 全屏阅读：关闭 childPad，正文自控边距。
      // ⚠️ 顶栏不走 FScaffold.header —— 沉浸阅读要求「正常情况下隐藏、点正文才浮出」，
      //    故顶栏改为叠在正文之上的覆盖层（见 _buildReaderChrome）。
      childPad: false,
      child: ColoredBox(
        color: resolveReaderBg(settings),
        child: Stack(
          children: [
            // 顶栏已改为浮层 → 正文自己避开系统栏（状态栏 / 手势条），
            // 否则文字会顶到状态栏下面（真机实踩）。
            SafeArea(
              child: EpubViewer(
                // 只有「结构」变化才重建（位置靠 _currentCfi 续接）；
                // 主题 / 字号 / 行距 / 排版一律走 _applyStyle 热更新，不重载整本书。
                key: ValueKey('reader:${settings.structureFingerprint}'),
                epubSource: EpubSource.fromFile(File(widget.filePath)),
                epubController: _epubController,
                initialCfi: _currentCfi ?? _savedCfi,
                displaySettings: EpubDisplaySettings(
                  fontSize: settings.fontSize.round(),
                  flow: settings.flow == ReaderFlow.scrolled
                      ? EpubFlow.scrolled
                      : EpubFlow.paginated,
                  // 分栏设置已移除（阅读设置优化），固定为「自动」
                  spread: EpubSpread.auto,
                  defaultDirection: settings.direction == ReaderDirection.rtl
                      ? EpubDefaultDirection.rtl
                      : EpubDefaultDirection.ltr,
                  // ⚠️ snap 一个值管两件事，必须跟「翻页方式」联动：
                  //   ① JS 侧横滑吸附翻页（仅 iOS / 桌面生效——Android 走
                  //      useCustomSwipe 后 JS 里恒为 false）；
                  //   ② **WebView 的 `disableVerticalScroll`**：插件
                  //      `epub_viewer.dart` 把 `displaySettings.snap` 直传给
                  //      `EpubPlatformViewConfig.disableVerticalScroll`，而
                  //      flutter_inappwebview 的 onTouchListener 在该项为 true 时
                  //      会把**触摸的 Y 坐标钉死在按下位置**
                  //      （`event.setLocation(event.getX(), m_downY)`）⇒ 纵向滚动
                  //      整条失效。这正是「选了『滚动』翻页方式却滚不动、只能横滑」
                  //      的根因。故滚动模式必须传 false。
                  snap: settings.flow == ReaderFlow.paginated,
                  useSnapAnimationAndroid: false,
                  theme: _epubTheme(settings),
                  allowScriptedContent: false,
                ),
                selectionContextMenu: EpubContextMenu(
                  hideDefaultSystemItems: true,
                  items: [
                    EpubContextMenuItem(
                      id: 1,
                      title: '划线',
                      action: () => _addHighlightFromSelection('yellow', 'highlight'),
                    ),
                    EpubContextMenuItem(
                      id: 2,
                      title: '下划线',
                      action: () => _addUnderlineFromSelection(),
                    ),
                    EpubContextMenuItem(
                      id: 3,
                      title: '笔记',
                      action: () => _showNoteInput(),
                    ),
                  ],
                ),
                onChaptersLoaded: (chaps) => setState(() => _chapters = chaps),
                onEpubLoaded: () async {
                  _epubReady = true;
                  if (mounted) setState(() => _loadingEpub = false);
                  // 首帧样式 + 异步恢复的自定义设置（provider 从 SharedPreferences
                  // 恢复可能晚于首帧）都在这里补一次
                  await _applyStyle(ref.read(readerSettingsProvider));
                  await _reapplyHighlights();
                },
                onRelocated: (loc) {
                  _currentCfi = loc.startCfi;
                  _currentPercent = loc.progress * 100;
                  _scheduleSaveProgress();
                },
                onTextSelected: (sel) {
                  if (sel.selectionCfi.isNotEmpty) {
                    _lastSelection = (sel.selectionCfi, sel.selectedText);
                  }
                },
                onAnnotationClicked: (cfi, _) => _showAnnotationSheet(cfi),
                // JS 侧选区塌陷（selectionCleared）时同步清掉待命选区
                onDeselection: () => _lastSelection = null,
                // 点击分派：左右边界翻页、其余位置切换顶栏；滑动翻页 / 长按选词
                // 都不算「点击」（见 _onViewerTouchUp）
                onTouchDown: _onViewerTouchDown,
                onTouchUp: _onViewerTouchUp,
              ),
            ),
            if (_loadingEpub)
              Container(
                color: resolveReaderBg(settings),
                child: const Center(child: FCircularProgress()),
              ),
            _buildReaderChrome(),
          ],
        ),
      ),
    );
  }

  /// 沉浸顶栏：平时透明 + 上移出屏 + 不吃点击；点亮后浮出，5 秒无操作自动收起
  ///
  /// ⚠️ `SafeArea` 只包「内容」不包「底色」：顶栏底色要铺到状态栏后面，否则
  /// 浮出时状态栏区域会露出一条与顶栏不同色的窄条。
  Widget _buildReaderChrome() {
    final t = context.theme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: AnimatedSlide(
            offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 180),
            child: Container(
              decoration: BoxDecoration(
                color: t.colors.background,
                border: Border(
                  bottom: BorderSide(color: t.colors.border, width: 0.5),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: FHeader.nested(
                  title: Text(_title ?? '阅读'),
                  prefixes: [
                    FHeaderAction.back(onPress: () => context.pop()),
                  ],
                  suffixes: [
                    FHeaderAction(
                      icon: const Icon(FLucideIcons.list),
                      onPress: _chapters.isEmpty ? null : _showToc,
                    ),
                    FHeaderAction(
                      icon: const Icon(FLucideIcons.bookmark),
                      onPress: _contentHash == null ? null : _showBookmarks,
                    ),
                    FHeaderAction(
                      icon: const Icon(FLucideIcons.highlighter),
                      onPress: _contentHash == null ? null : _showAnnotations,
                    ),
                    FHeaderAction(
                      icon: const Icon(FLucideIcons.search),
                      onPress: _showSearch,
                    ),
                    FHeaderAction(
                      icon: const Icon(FLucideIcons.settings),
                      onPress: _showSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onViewerTouchDown(double x, double y) {
    _tapDownX = x;
    _tapDownY = y;
    _tapDownAt = DateTime.now();
  }

  void _onViewerTouchUp(double x, double y) {
    final down = _tapDownAt;
    if (down == null) return;
    _tapDownAt = null;
    // 长按（选词）/ 横滑翻页都不是「点击」，既不翻页也不切换顶栏
    if (DateTime.now().difference(down).inMilliseconds > 400) return;
    if ((x - _tapDownX).abs() > 0.03 || (y - _tapDownY).abs() > 0.03) return;
    // ⚠️ 选区工具栏待命时，点击空白 = 清选区收工具栏，不翻页也不切顶栏。
    // 插件在选区期间会注入 touch-action CSS 屏蔽滑动并劫持 next/prev/display，
    // 唯一解除路径是 DOM 选区塌陷触发 selectionCleared —— 但 WebView + 原生浮动
    // 菜单组合下点空白常常不塌陷，导致菜单卡死、无法翻页。这里主动调插件公开的
    // clearSelection()（removeAllRanges + 清状态标记 + 发 selectionCleared）兜底。
    // 长按选词松手（>400ms）/ 拖选区手柄（有位移）都被上面的过滤排除，不会误清；
    // 点「划线/下划线/笔记」是原生浮层点击，不走 iframe touchend，同样不受影响。
    if (_lastSelection != null) {
      _lastSelection = null;
      try {
        _epubController.clearSelection();
      } catch (_) {
        // webview 未就绪 / 已卸载时忽略
      }
      return;
    }
    // epub.js 在 iframe 内与父文档各发一次 touchend，做去重避免「一次点击翻两页 /
    // 点了又立刻收起」
    final last = _lastTapHandledAt;
    if (last != null &&
        DateTime.now().difference(last).inMilliseconds < 400) {
      return;
    }
    _lastTapHandledAt = DateTime.now();
    // 翻页模式：左右边界点击翻页（热区各 25%），中间区域点击切换顶栏。
    // 滚动模式不做左右热区：连续滚动本身就是导航方式，处处点击都切换顶栏。
    if (ref.read(readerSettingsProvider).flow == ReaderFlow.paginated) {
      if (x < _kTapTurnZone) {
        _turnPage(-1);
        return;
      }
      if (x > 1 - _kTapTurnZone) {
        _turnPage(1);
        return;
      }
    }
    _toggleChrome();
  }

  /// 点击左右热区翻页（仅翻页模式）
  ///
  /// 走插件公开的 `next() / prev()`（= JS 侧 `rendition.next/prev`），与横滑翻页
  /// 同一条通路，位置变化照常经 `onRelocated` 回传并落库（CFI 续接不受影响）。
  void _turnPage(int direction) {
    if (!_epubReady) return;
    try {
      if (direction > 0) {
        _epubController.next();
      } else {
        _epubController.prev();
      }
    } catch (_) {
      // webview 未就绪 / 已卸载时忽略（checkEpubLoaded 会抛）
    }
  }

  void _toggleChrome() {
    if (!mounted) return;
    setState(() => _chromeVisible = !_chromeVisible);
    _chromeTimer?.cancel();
    if (_chromeVisible) {
      _chromeTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _chromeVisible = false);
      });
    }
  }

  void _scheduleSaveProgress() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_contentHash == null || _currentCfi == null) return;
      try {
        await ref.read(ebookRepositoryProvider).saveProgressCfi(
          _contentHash!,
          widget.filePath,
          _format,
          _currentCfi!,
          _currentPercent,
        );
      } catch (_) {}
    });
  }

  /// 启动 / 主题切换重建后，从库里把已存的高亮 / 下划线重绘到阅读器
  Future<void> _reapplyHighlights() async {
    final hash = _contentHash;
    if (hash == null) return;
    try {
      final list = await ref.read(ebookRepositoryProvider).getAnnotations(hash);
      for (final a in list) {
        final cfi = a.anchor;
        if (cfi == null || !cfi.startsWith('epubcfi')) continue;
        try {
          if ((a.type ?? '').trim() == 'underline') {
            await _epubController.addUnderline(cfi: cfi);
          } else {
            await _epubController.addHighlight(
              cfi: cfi,
              color: _toColor(a.color),
            );
          }
        } catch (_) {
          // 个别失效 CFI 跳过，不阻断其余
        }
      }
    } catch (_) {}
  }

  Future<void> _addHighlightFromSelection(String colorName, String type) async {
    final sel = _lastSelection;
    if (sel == null || _contentHash == null) return;
    try {
      await _epubController.addHighlight(cfi: sel.$1, color: _toColor(colorName));
      await ref.read(ebookRepositoryProvider).addAnnotation(
        filePath: widget.filePath,
        contentHash: _contentHash!,
        format: _format,
        anchor: sel.$1,
        annotatedText: sel.$2,
        note: null,
        color: colorName,
        type: type,
      );
      if (mounted) showFToast(context: context, title: const Text('已添加划线'));
      // 清掉残留选区：插件选区期间屏蔽滑动，必须塌陷选区才恢复翻页
      _lastSelection = null;
      try {
        await _epubController.clearSelection();
      } catch (_) {}
    } catch (e) {
      if (mounted) showFToast(context: context, title: Text('添加失败：$e'));
    }
  }

  Future<void> _addUnderlineFromSelection() async {
    final sel = _lastSelection;
    if (sel == null || _contentHash == null) return;
    try {
      await _epubController.addUnderline(cfi: sel.$1);
      await ref.read(ebookRepositoryProvider).addAnnotation(
        filePath: widget.filePath,
        contentHash: _contentHash!,
        format: _format,
        anchor: sel.$1,
        annotatedText: sel.$2,
        note: null,
        color: '',
        type: 'underline',
      );
      if (mounted) showFToast(context: context, title: const Text('已添加下划线'));
      // 清掉残留选区：插件选区期间屏蔽滑动，必须塌陷选区才恢复翻页
      _lastSelection = null;
      try {
        await _epubController.clearSelection();
      } catch (_) {}
    } catch (e) {
      if (mounted) showFToast(context: context, title: Text('添加失败：$e'));
    }
  }

  void _showNoteInput() {
    final sel = _lastSelection;
    if (sel == null || _contentHash == null) return;
    var note = '';
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 含笔记输入框 → lg 80vh 定高、键盘覆盖不折叠（全局定案）
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (c, setSt) => Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    8,
                  ),
                  child: Text('写笔记', style: c.theme.typography.body.lg),
                ),
                Padding(
                  padding: EdgeInsets.all(AppTokens.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: c.theme.colors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(sel.$2, style: c.theme.typography.body.md),
                      ),
                      const SizedBox(height: 12),
                      FTextField(
                        label: const Text('笔记内容'),
                        control: FTextFieldControl.managed(
                          onChange: (v) => setSt(() => note = v.text),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 8,
                        children: [
                          FButton(
                            variant: FButtonVariant.outline,
                            onPress: () => Navigator.pop(c),
                            child: const Text('取消'),
                          ),
                          FButton(
                            onPress: () async {
                              Navigator.pop(c);
                              try {
                                await _epubController.addHighlight(
                                  cfi: sel.$1,
                                  color: Colors.yellow,
                                );
                                await ref
                                    .read(ebookRepositoryProvider)
                                    .addAnnotation(
                                  filePath: widget.filePath,
                                  contentHash: _contentHash!,
                                  format: _format,
                                  anchor: sel.$1,
                                  annotatedText: sel.$2,
                                  note: note.trim().isEmpty ? null : note.trim(),
                                  color: 'yellow',
                                  type: 'note',
                                );
                                if (mounted) {
                                  showFToast(
                                    context: context,
                                    title: const Text('已添加笔记'),
                                  );
                                }
                                // 清掉残留选区：插件选区期间屏蔽滑动，
                                // 必须塌陷选区才恢复翻页
                                _lastSelection = null;
                                try {
                                  await _epubController.clearSelection();
                                } catch (_) {}
                              } catch (e) {
                                if (mounted) {
                                  showFToast(
                                    context: context,
                                    title: Text('添加失败：$e'),
                                  );
                                }
                              }
                            },
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToc() {
    if (_chapters.isEmpty) return;
    // 展平层级目录（最多两级），子项缩进展示
    final flat = _flattenToc(_chapters);
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  12,
                  AppTokens.pagePadding,
                  8,
                ),
                child: Text('目录', style: sheetTitleStyle(c)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    FTileGroup(
                      divider: FItemDivider.none,
                      children: [
                        for (var i = 0; i < flat.length; i++)
                          FTile(
                            title: Padding(
                              padding: EdgeInsets.only(
                                left: flat[i].$2 * 16.0,
                              ),
                              child: Text(
                                _tocTitle(flat[i].$1, i),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onPress: () {
                              Navigator.pop(c);
                              _epubController.display(cfi: flat[i].$1.href);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 目录标题兜底
  ///
  /// ⚠️ 真机 Android 15 实测：epub.js 的 `navigation.toc[].label` 在部分 EPUB /
  /// WebView 版本上解析为空串（`title` 随之为空），但 `href` 始终有效 —— 表现为
  /// 「目录每行都是空标题却都能跳转」。故这里逐级兜底：label → href 推导 → 「第 N 章」。
  String _tocTitle(EpubChapter c, int index) {
    final t = c.title.trim();
    if (t.isNotEmpty) return t;
    final fromHref = _titleFromHref(c.href);
    if (fromHref != null) return fromHref;
    return '第 ${index + 1} 章';
  }

  /// 从 href 反推可读标题：`OEBPS/chap01.html#a` → `chap01`
  String? _titleFromHref(String href) {
    var s = href.split('#').first.split('/').last;
    final dot = s.lastIndexOf('.');
    if (dot > 0) s = s.substring(0, dot);
    try {
      s = Uri.decodeComponent(s);
    } catch (_) {
      // 非合法百分号编码时原样使用
    }
    s = s.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return s.isEmpty ? null : s;
  }

  /// 展平目录层级（返回 `(章节, 缩进层级)`，最多两层）
  List<(EpubChapter, int)> _flattenToc(
    List<EpubChapter> chapters, [
    int depth = 0,
  ]) {
    final out = <(EpubChapter, int)>[];
    for (final c in chapters) {
      out.add((c, depth));
      if (depth < 1 && c.subitems.isNotEmpty) {
        out.addAll(_flattenToc(c.subitems, depth + 1));
      }
    }
    return out;
  }

  /// 书签抽屉
  ///
  /// ⚠️ 抽屉内读流必须自带 Consumer：用页面 State 的 ref 在 sheet builder 里
  /// watch 会永远停在首帧（空列表），详见 annotation_sheet.dart 顶部注释。
  void _showBookmarks() {
    final hash = _contentHash;
    if (hash == null) return;
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: Consumer(
            builder: (c, ref, _) {
              final snap = ref.watch(bookmarksStreamProvider(hash));
              final list = snap.value ?? const <EbookBookmarkData>[];
              final hasCurrent =
                  _currentCfi != null && list.any((b) => b.cfi == _currentCfi);
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text('书签', style: sheetTitleStyle(c)),
                  ),
                  Expanded(
                    child: snap.isLoading && list.isEmpty
                        ? const Center(child: FCircularProgress())
                        : snap.hasError
                            ? Center(child: Text('加载失败：${snap.error}'))
                            : list.isEmpty
                                ? const Center(child: Text('还没有书签'))
                                : ListView(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    children: [
                                      FTileGroup(
                                        divider: FItemDivider.none,
                                        children: [
                                          for (final b in list)
                                            FTile(
                                              title: Text(
                                                b.label ?? '书签',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: b.percent != null
                                                  ? Text('${b.percent}%')
                                                  : null,
                                              suffix: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                spacing: 4,
                                                children: [
                                                  if (b.cfi != null)
                                                    FButton(
                                                      variant:
                                                          FButtonVariant.ghost,
                                                      onPress: () {
                                                        Navigator.pop(c);
                                                        _epubController.display(
                                                          cfi: b.cfi!,
                                                        );
                                                      },
                                                      child: const Icon(
                                                        FLucideIcons.crosshair,
                                                      ),
                                                    ),
                                                  FButton(
                                                    variant: FButtonVariant
                                                        .destructive,
                                                    onPress: () async {
                                                      await ref
                                                          .read(
                                                            ebookRepositoryProvider,
                                                          )
                                                          .removeBookmark(b.id);
                                                    },
                                                    child: const Icon(
                                                      FLucideIcons.trash2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTokens.pagePadding),
                    child: FButton(
                      onPress: () async {
                        if (_currentCfi == null) return;
                        if (hasCurrent) {
                          final existing = list.firstWhere(
                            (b) => b.cfi == _currentCfi,
                          );
                          await ref
                              .read(ebookRepositoryProvider)
                              .removeBookmark(existing.id);
                          if (mounted) {
                            showFToast(
                              context: context,
                              title: const Text('已取消书签'),
                            );
                          }
                        } else {
                          await ref
                              .read(ebookRepositoryProvider)
                              .addBookmarkCfi(
                            filePath: widget.filePath,
                            contentHash: hash,
                            format: _format,
                            cfi: _currentCfi!,
                            percent: _currentPercent,
                          );
                          if (mounted) {
                            showFToast(
                              context: context,
                              title: const Text('已加入书签'),
                            );
                          }
                        }
                      },
                      child: Text(hasCurrent ? '取消当前页书签' : '书签当前页'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 顶部「划线」入口 —— 底部抽屉展示本书的笔记与划线（见 annotation_sheet.dart）
  ///
  /// ⚠️ 抽屉内部自行用 Consumer 订阅流：在 sheet builder 里直接用页面 State 的
  /// ref.watch 会永远停在首帧（一直转圈），详见 annotation_sheet.dart 顶部注释。
  void _showAnnotations() {
    final hash = _contentHash;
    if (hash == null) return;
    showAnnotationSheet(
      context: context,
      contentHash: hash,
      onLocate: (cfi) {
        try {
          _epubController.display(cfi: cfi);
        } catch (_) {
          // 阅读器未就绪时忽略，下次再点即可
        }
      },
      onDelete: (a) async {
        final cfi = a.anchor;
        if (cfi != null && cfi.startsWith('epubcfi')) {
          try {
            await _epubController.removeHighlight(cfi: cfi);
          } catch (_) {}
        }
        await ref.read(ebookRepositoryProvider).removeAnnotation(a.id);
      },
    );
  }

  void _showAnnotationSheet(String cfi) {
    final hash = _contentHash;
    if (hash == null) return;
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightMd,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppTokens.pagePadding),
            // ⚠️ 抽屉内读流必须自带 Consumer（否则永远停在首帧空列表）
            child: Consumer(
              builder: (c, ref, _) {
                final list =
                    ref.watch(annotationsStreamProvider(hash)).value ??
                        const <EbookAnnotationData>[];
                final a = list.where((x) => x.anchor == cfi).firstOrNull;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('标注', style: sheetTitleStyle(c)),
                    const SizedBox(height: 8),
                    if (a != null) ...[
                    if ((a.annotatedText ?? '').isNotEmpty)
                      Text(a.annotatedText!, style: c.theme.typography.body.md),
                    if ((a.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(a.note!, style: c.theme.typography.body.sm),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: FButton(
                            variant: FButtonVariant.outline,
                            onPress: () async {
                              if (a.anchor != null) {
                                try {
                                  await _epubController.removeHighlight(
                                    cfi: a.anchor!,
                                  );
                                } catch (_) {}
                              }
                              await ref
                                  .read(ebookRepositoryProvider)
                                  .removeAnnotation(a.id);
                              if (c.mounted) Navigator.pop(c);
                            },
                            child: const Text('删除'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Text('该标注已不存在'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showSearch() {
    var query = '';
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (c, setSt) => Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    8,
                  ),
                  child: Text('搜索', style: c.theme.typography.body.lg),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
                  child: FTextField(
                    label: const Text('关键词'),
                    control: FTextFieldControl.managed(
                      onChange: (v) => setSt(() => query = v.text.trim()),
                    ),
                  ),
                ),
                Expanded(
                  child: query.isEmpty
                      ? const Center(child: Text('输入关键词检索'))
                      : FutureBuilder<List<EpubSearchResult>>(
                          future: _epubController.search(query: query),
                          builder: (c, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(child: FCircularProgress());
                            }
                            final res = snap.data ?? const <EpubSearchResult>[];
                            if (res.isEmpty) {
                              return const Center(child: Text('无匹配结果'));
                            }
                            return ListView(
                              padding: const EdgeInsets.only(bottom: 12),
                              children: [
                                FTileGroup(
                                  divider: FItemDivider.none,
                                  children: [
                                    for (final r in res)
                                      FTile(
                                        title: Text(
                                          r.excerpt,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onPress: () {
                                          Navigator.pop(c);
                                          _epubController.display(cfi: r.cfi);
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 阅读设置抽屉（EPUB：含翻页方式 / 分栏 / 阅读方向）
  ///
  /// 抽屉内部自带 Consumer 订阅 provider 并写入；本页通过 initState 里的
  /// `ref.listen` 分派：样式类 → `_applyStyle` 热更新，结构类 → 重建 EpubViewer。
  void _showSettings() =>
      showReaderSettingsSheet(context, showStructure: true);

  // ===========================================================================
  // TXT（epubx + flutter_widget_from_html，保持旧逻辑）
  // ===========================================================================

  Future<void> _loadTxt() async {
    try {
      final book = await parseBook(widget.filePath);
      if (!mounted) return;
      setState(() {
        _book = book;
        _loadingTxt = false;
      });
      final repo = ref.read(ebookRepositoryProvider);
      final row = await repo.findBookByPath(widget.filePath);
      var restored = 0;
      if (row != null) {
        final progress = await repo.getProgress(row);
        final cfi = progress?.cfi ?? '';
        restored = cfi.startsWith('chapter:')
            ? int.tryParse(cfi.substring(8)) ?? 0
            : 0;
      }
      final target = widget.initialChapter ?? restored;
      if (mounted && target > 0 && book.chapters.length > target) {
        setState(() => _chapter = target);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '解析失败：$e';
        _loadingTxt = false;
      });
    }
  }

  Future<void> _goChapter(int index) async {
    final book = _book;
    if (book == null || index < 0 || index >= book.chapters.length) return;
    setState(() => _chapter = index);
    try {
      final repo = ref.read(ebookRepositoryProvider);
      final row = await repo.findBookByPath(widget.filePath);
      if (row != null) {
        final percent = book.chapters.isEmpty
            ? 0.0
            : (index + 1) / book.chapters.length * 100;
        await repo.saveProgress(row, index, percent);
      }
    } catch (_) {}
  }

  bool _isBookmarked(List<EbookBookmarkData>? list) =>
      list?.any((b) => b.cfi == 'chapter:$_chapter') ?? false;

  Future<void> _toggleCurrentBookmark() async {
    final hash = _contentHash;
    final book = _book;
    if (hash == null || book == null) return;
    final repo = ref.read(ebookRepositoryProvider);
    final existing = await repo.findBookmark(hash, _chapter);
    if (existing != null) {
      await repo.removeBookmark(existing.id);
      if (mounted) showFToast(context: context, title: const Text('已取消书签'));
      return;
    }
    final percent = book.chapters.isEmpty
        ? 0.0
        : (_chapter + 1) / book.chapters.length * 100;
    await repo.addBookmark(
      filePath: widget.filePath,
      contentHash: hash,
      format: _format,
      chapterIndex: _chapter,
      label: book.chapters[_chapter].title,
      percent: percent,
    );
    if (mounted) showFToast(context: context, title: const Text('已加入书签'));
  }

  Widget _buildTxt() {
    final book = _book;
    final t = context.theme;
    final settings = ref.watch(readerSettingsProvider);
    final bg = resolveReaderBg(settings);
    final text = resolveReaderText(settings);
    final html = book == null
        ? ''
        : _chapter < book.chapters.length
        ? _renderHtml(book.chapters[_chapter].html, settings)
        : '';
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(book?.title ?? _title ?? '阅读'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.bookmark),
            onPress: book == null ? null : () => _showBookmarkList(),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.highlighter),
            onPress: book == null ? null : () => _showAnnotationsTxt(),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.list),
            onPress: book == null ? null : () => _showChaptersTxt(book),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.settings),
            onPress: book == null ? null : () => _showSettingsTxt(),
          ),
        ],
      ),
      child: ColoredBox(
        color: bg,
        child: _loadingTxt && _book == null
            ? const Center(child: FCircularProgress())
            : _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: text)))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppTokens.pagePadding),
                      child: HtmlWidget(
                        html,
                        textStyle: TextStyle(
                          color: text,
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          fontFamily: readerFontFamily(settings.font),
                        ),
                      ),
                    ),
                  ),
                  const FDivider(),
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: _chapter > 0
                              ? () => _goChapter(_chapter - 1)
                              : null,
                          child: const Text('上一章'),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_chapter + 1}/${book!.chapters.length}',
                              style: t.typography.body.sm.copyWith(
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: _chapter < book.chapters.length - 1
                              ? () => _goChapter(_chapter + 1)
                              : null,
                          child: const Text('下一章'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 非默认配色下剥离 epub 内联 color/background，避免白字白底
  ///
  /// 触发条件跟着「实际配色」走：只要主题不是日间、或用户自定义了背景 / 文字色，
  /// 书内联的 `color` / `background` 一律剥掉（自定义色是新增项，不能只看主题）。
  String _renderHtml(String html, ReaderSettings s) {
    final themed = s.theme != ReaderTheme.day ||
        s.bgColor.isNotEmpty ||
        s.textColor.isNotEmpty;
    if (!themed) return html;
    return html.replaceAllMapped(
      RegExp(r'style="([^"]*)"', caseSensitive: false),
      (m) {
        final inner = m[1]!
            .replaceAllMapped(
              RegExp(
                r'(?:^|;)\s*(?:color|background|background-color|background-image)\s*:[^;]*;?',
                caseSensitive: false,
              ),
              (_) => '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return inner.isEmpty ? '' : 'style="$inner"';
      },
    );
  }

  /// 书签抽屉（TXT 路径）
  ///
  /// ⚠️ 抽屉内读流必须自带 Consumer，否则永远停在首帧空列表。
  void _showBookmarkList() {
    final hash = _contentHash;
    if (hash == null) return;
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: Consumer(
            builder: (c, ref, _) {
              final snap = ref.watch(bookmarksStreamProvider(hash));
              final list = snap.value ?? const <EbookBookmarkData>[];
              final current = _isBookmarked(list);
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text('书签', style: sheetTitleStyle(c)),
                  ),
                  Expanded(
                    child: snap.isLoading && list.isEmpty
                        ? const Center(child: FCircularProgress())
                        : snap.hasError
                            ? Center(child: Text('加载失败：${snap.error}'))
                            : list.isEmpty
                                ? const Center(child: Text('还没有书签'))
                                : ListView(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    children: [
                                      FTileGroup(
                                        divider: FItemDivider.none,
                                        children: [
                                          for (final b in list)
                                            FTile(
                                              title: Text(
                                                b.label ?? '未命名章节',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: b.percent != null
                                                  ? Text('${b.percent}%')
                                                  : null,
                                              suffix: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                spacing: 4,
                                                children: [
                                                  FButton(
                                                    variant:
                                                        FButtonVariant.ghost,
                                                    onPress: () async {
                                                      Navigator.pop(c);
                                                      final idx = int.tryParse(
                                                            (b.cfi ?? '')
                                                                    .startsWith(
                                                                      'chapter:',
                                                                    )
                                                                ? (b.cfi ?? '')
                                                                    .substring(
                                                                      8,
                                                                    )
                                                                : '',
                                                          ) ??
                                                          _chapter;
                                                      await _goChapter(idx);
                                                    },
                                                    child: const Icon(
                                                      FLucideIcons.crosshair,
                                                    ),
                                                  ),
                                                  FButton(
                                                    variant: FButtonVariant
                                                        .destructive,
                                                    onPress: () async {
                                                      await ref
                                                          .read(
                                                            ebookRepositoryProvider,
                                                          )
                                                          .removeBookmark(b.id);
                                                    },
                                                    child: const Icon(
                                                      FLucideIcons.trash2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTokens.pagePadding),
                    child: FButton(
                      onPress: () => _toggleCurrentBookmark(),
                      child: Text(current ? '取消收藏本章' : '收藏当前章'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAnnotationsTxt() {
    final hash = _contentHash;
    if (hash == null) return;
    var adding = false;
    var type = 'markStrong';
    var note = '';
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSt) => Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    8,
                  ),
                  child: Text('批注', style: context.theme.typography.body.lg),
                ),
                Expanded(
                  // ⚠️ 抽屉内读流必须自带 Consumer：直接用页面 State 的 ref 会
                  // 永远停在首帧（一直转圈 / 空列表）
                  child: Consumer(
                    builder: (context, ref, _) => ref
                      .watch(annotationsStreamProvider(hash))
                      .when(
                    loading: () => const Center(child: FCircularProgress()),
                    error: (e, _) => Center(child: Text('加载失败：$e')),
                    data: (list) {
                      if (list.isEmpty && !adding) {
                        return const Center(child: Text('还没有批注'));
                      }
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          if (adding) ...[
                            Padding(
                              padding: EdgeInsets.all(AppTokens.pagePadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '类型',
                                    style: context.theme.typography.body.sm,
                                  ),
                                  const SizedBox(height: 8),
                                  JianliSegmented(
                                    items: const [
                                      (FLucideIcons.highlighter, '划线'),
                                      (FLucideIcons.notebookPen, '笔记'),
                                    ],
                                    selected: type == 'markStrong' ? 0 : 1,
                                    onSelect: (i) => setSt(
                                      () => type = i == 0 ? 'markStrong' : 'note',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FTextField(
                                    label: const Text('笔记内容（可选）'),
                                    control: FTextFieldControl.managed(
                                      onChange: (v) =>
                                          setSt(() => note = v.text),
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    spacing: 8,
                                    children: [
                                      FButton(
                                        variant: FButtonVariant.outline,
                                        onPress: () {
                                          note = '';
                                          setSt(() => adding = false);
                                        },
                                        child: const Text('取消'),
                                      ),
                                      FButton(
                                        onPress: () async {
                                          await ref
                                              .read(ebookRepositoryProvider)
                                              .addAnnotation(
                                            filePath: widget.filePath,
                                            contentHash: hash,
                                            format: _format,
                                            anchor: 'chapter:$_chapter',
                                            annotatedText:
                                                _book!.chapters[_chapter].title,
                                            note: note.trim().isEmpty
                                                ? null
                                                : note.trim(),
                                            color: type == 'markStrong'
                                                ? 'yellow'
                                                : '',
                                            type: type,
                                          );
                                          note = '';
                                          setSt(() => adding = false);
                                        },
                                        child: const Text('保存'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          FTileGroup(
                            divider: FItemDivider.none,
                            children: [
                              for (final a in list)
                                FTile(
                                  title: Text(
                                    a.annotatedText ??
                                        (a.type == 'note' ? '笔记' : '划线'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: a.note != null && a.note!.isNotEmpty
                                      ? Text(
                                          a.note!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  suffix: Row(
                                    spacing: 8,
                                    children: [
                                      if (a.type == 'markStrong')
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: a.color == 'yellow'
                                                ? Colors.yellow
                                                : Colors.grey,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                        ),
                                      FButton(
                                        variant: FButtonVariant.destructive,
                                        onPress: () async {
                                          await ref
                                              .read(ebookRepositoryProvider)
                                              .removeAnnotation(a.id);
                                        },
                                        child: const Icon(FLucideIcons.trash2),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(AppTokens.pagePadding),
                  child: FButton(
                    onPress: () => setSt(() => adding = !adding),
                    child: Text(adding ? '收起' : '添加批注（本章）'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChaptersTxt(ParsedBook book) {
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      // 目录可能很长，挂 lg 档并定高（三档制：禁止裸比例 / null）
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  0,
                  AppTokens.pagePadding,
                  8,
                ),
                child: Text('目录', style: context.theme.typography.body.lg),
              ),
              FTileGroup(
                divider: FItemDivider.none,
                children: [
                  for (var i = 0; i < book.chapters.length; i++)
                    FTile(
                      title: Text(
                        book.chapters[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: i == _chapter,
                      onPress: () {
                        Navigator.pop(context);
                        _goChapter(i);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 阅读设置抽屉（TXT：无翻页方式 / 分栏 / 阅读方向）
  void _showSettingsTxt() =>
      showReaderSettingsSheet(context, showStructure: false);
}
