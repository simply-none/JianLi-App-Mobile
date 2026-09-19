// 浏览器菜单抽屉 —— 5×2 图标网格 + 分页（>10 翻页）
//
// 严格按设计稿 19 项顺序：
//   第 1 页：夜间模式 / 书签 / 历史 / 下载 / 隐身 / 分享 / 添加书签 / 电脑模式 / 资源嗅探 / 设置
//   第 2 页：页内查找 / 离线页面 / 源码 / 全屏 / 无图模式 / 浏览器标识 / 广告拦截 / 标记广告 / 字体大小
//
// 布局（对齐 Ardot 原型 727435166252787）：
//   • 顶部居中拖拽手柄
//   • 每页 2 行 × 5 列图标网格（共 10 项 / 页，>10 走 PageView 横滑翻页）
//   • 第三行页脚：分页圆点居中 + 关机键关闭居最右（对齐图标网格第 5 列）
//   • 弹窗高度走 sm 档（30vh）：这是「操作菜单」类弹窗，规范禁止再用 lg 档
//
// 网格项点击分三类：
//   • 导航类（书签/历史/设置/下载/离线页面）：先 push 子页、再关抽屉
//   • 开关类（夜间/隐身/电脑模式/无图/广告拦截）：改设置、抽屉**不关**，让用户看到高亮翻转
//   • 页面能力类（分享/查找/源码/全屏/添加书签/资源嗅探/离线保存）：关抽屉后调页面回调
//
// ⚠️ 抽屉内容自带 `Consumer`：showFSheet 的 builder 属于 Navigator overlay 子树，
// 页面 ref.watch 的更新不会传进来（技能红线 #28），开关项要当场高亮必须自己订阅设置流。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../models/browser_models.dart';
import '../models/browser_settings.dart';
import '../providers/browser_providers.dart';
import 'browser_ua_sheet.dart';

/// 菜单需要的页面级回调（开关类/导航类在菜单内直接用 ref 处理，不在此列）
class BrowserMenuHandlers {
  const BrowserMenuHandlers({
    required this.onAddBookmark,
    required this.onShare,
    required this.onFindInPage,
    required this.onViewSource,
    required this.onToggleFullscreen,
    required this.onSniff,
    required this.onSaveOffline,
  });

  final Future<void> Function() onAddBookmark;
  final VoidCallback onShare;
  final VoidCallback onFindInPage;
  final VoidCallback onViewSource;
  final VoidCallback onToggleFullscreen;

  /// 资源嗅探：页面用 JS 枚举当前页可下载资源并打开嗅探面板
  final VoidCallback onSniff;

  /// 离线页面：抓取当前页 HTML 存库并打开离线列表
  final Future<void> Function() onSaveOffline;
}

/// 打开浏览器菜单
///
/// ⚠️ 高度用 sm 档（30vh）：操作菜单类弹窗，禁止 lg 档（会撑大半屏）。
Future<void> showBrowserMenuSheet(
  BuildContext context, {
  required String currentUrl,
  required BrowserMenuHandlers handlers,
}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightSm,
    builder: (sheetContext) {
      return SheetSurface(
        child: _BrowserMenuSheetContent(
          sheetContext: sheetContext,
          currentUrl: currentUrl,
          handlers: handlers,
        ),
      );
    },
  );
}

/// 单个网格菜单项
class _MenuAction {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 开关命中时图标 + 文案染主题色
  final bool active;
}

/// 抽屉内容（自带 Consumer 订阅设置流）
class _BrowserMenuSheetContent extends StatelessWidget {
  const _BrowserMenuSheetContent({
    required this.sheetContext,
    required this.currentUrl,
    required this.handlers,
  });

  final BuildContext sheetContext;
  final String currentUrl;
  final BrowserMenuHandlers handlers;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (inner, ref, _) {
        final settings =
            ref.watch(browserSettingsProvider).value ?? const BrowserSettings();
        final actions = _buildActions(ref, settings, inner);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.pagePadding,
            ),
            child: Column(
              children: [
                // 顶部：居中的拖拽手柄（关机键关闭在内容第三行最右，见 _BrowserMenuGrid 底部）
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: inner.theme.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _BrowserMenuGrid(
                  actions: actions,
                  sheetContext: sheetContext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构造 19 个菜单项（顺序严格对应设计稿）
  List<_MenuAction> _buildActions(
    WidgetRef ref,
    BrowserSettings s,
    BuildContext inner,
  ) {
    void close() => Navigator.pop(inner);
    void go(String route) {
      unawaited(inner.push(route));
      close();
    }

    Future<void> save(BrowserSettings next) =>
        ref.read(browserSettingsProvider.notifier).save(next);

    Future<void> toggleNight() async => save(
          s.copyWith(
            darkMode: s.darkMode == BrowserDarkMode.dark
                ? BrowserDarkMode.light
                : BrowserDarkMode.dark,
          ),
        );
    Future<void> toggleIncognito() async =>
        save(s.copyWith(incognito: !s.incognito));
    Future<void> toggleDesktop() async =>
        save(s.copyWith(desktopMode: !s.desktopMode));
    Future<void> toggleNoImage() async =>
        save(s.copyWith(noImage: !s.noImage));
    Future<void> toggleAdBlock() async =>
        save(s.copyWith(adBlockEnabled: !s.adBlockEnabled));

    Future<void> pickFontSize() async {
      final choice = await showSheetActionMenu<double>(
        inner,
        title: '字体大小',
        size: SheetSize.sm,
        actions: [
          for (final f in const [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.5])
            SheetAction(f, '${(f * 100).round()}%'),
        ],
      );
      if (choice != null) await save(s.copyWith(fontScale: choice));
    }

    Future<void> markAd() async {
      final host = hostOf(currentUrl);
      if (host.isEmpty) {
        showFToast(context: inner, title: const Text('当前页面无地址'));
        return;
      }
      final ok = await showSheetConfirm(
        inner,
        title: '标记广告',
        message: '将「$host」加入广告屏蔽（其下资源会被拦截）？',
      );
      if (ok) {
        final rule = '||$host^';
        final rules = s.customRules.contains(rule)
            ? s.customRules
            : [...s.customRules, rule];
        await save(s.copyWith(customRules: rules));
        showFToast(context: inner, title: const Text('已加入广告屏蔽'));
      }
    }

    return <_MenuAction>[
      _MenuAction(
        icon: FLucideIcons.moon,
        label: '夜间模式',
        active: s.darkMode == BrowserDarkMode.dark,
        onTap: () {
          close();
          unawaited(toggleNight());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.bookMarked,
        label: '书签',
        onTap: () => go('/browser/bookmarks'),
      ),
      _MenuAction(
        icon: FLucideIcons.history,
        label: '历史',
        onTap: () => go('/browser/history'),
      ),
      _MenuAction(
        icon: FLucideIcons.download,
        label: '下载',
        onTap: () => go('/browser/downloads'),
      ),
      _MenuAction(
        icon: FLucideIcons.venetianMask,
        label: '隐身',
        active: s.incognito,
        onTap: () {
          close();
          unawaited(toggleIncognito());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.share2,
        label: '分享',
        onTap: () {
          close();
          handlers.onShare();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.bookmarkPlus,
        label: '添加书签',
        onTap: () {
          close();
          unawaited(handlers.onAddBookmark());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.monitor,
        label: '电脑模式',
        active: s.desktopMode,
        onTap: () {
          close();
          unawaited(toggleDesktop());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.radar,
        label: '资源嗅探',
        onTap: () {
          close();
          handlers.onSniff();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.settings,
        label: '设置',
        onTap: () => go('/browser/settings'),
      ),
      _MenuAction(
        icon: FLucideIcons.search,
        label: '页内查找',
        onTap: () {
          close();
          handlers.onFindInPage();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.cloudOff,
        label: '离线页面',
        onTap: () {
          close();
          unawaited(handlers.onSaveOffline());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.code,
        label: '源码',
        onTap: () {
          close();
          handlers.onViewSource();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.maximize,
        label: '全屏',
        onTap: () {
          close();
          handlers.onToggleFullscreen();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.imageOff,
        label: '无图模式',
        active: s.noImage,
        onTap: () {
          close();
          unawaited(toggleNoImage());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.globe,
        label: '浏览器标识',
        active: s.effectiveUserAgent != null,
        onTap: () async {
          await showBrowserUaSheet(inner, ref);
          close();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.shield,
        label: '广告拦截',
        active: s.adBlockEnabled,
        onTap: () {
          close();
          unawaited(toggleAdBlock());
        },
      ),
      _MenuAction(
        icon: FLucideIcons.tag,
        label: '标记广告',
        onTap: () async {
          await markAd();
          close();
        },
      ),
      _MenuAction(
        icon: FLucideIcons.type,
        label: '字体大小',
        onTap: () async {
          await pickFontSize();
          close();
        },
      ),
    ];
  }
}

/// 分页网格（每页 10 项 = 5×2；超过则 PageView 横滑 + 底部小圆点翻页）
///
/// 底部第三行页脚：分页圆点居中 + 关机键关闭居最右（对齐图标网格第 5 列）。
class _BrowserMenuGrid extends StatefulWidget {
  const _BrowserMenuGrid({
    required this.actions,
    required this.sheetContext,
  });

  final List<_MenuAction> actions;

  /// 抽屉上下文（关机键关闭用它 pop）
  final BuildContext sheetContext;

  @override
  State<_BrowserMenuGrid> createState() => _BrowserMenuGridState();
}

class _BrowserMenuGridState extends State<_BrowserMenuGrid> {
  late final PageController _pc;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  List<List<_MenuAction>> get _pages {
    final all = widget.actions;
    final out = <List<_MenuAction>>[];
    for (var i = 0; i < all.length; i += 10) {
      out.add(all.sublist(i, i + 10 > all.length ? all.length : i + 10));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final t = context.theme;
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: pages.length,
            itemBuilder: (c, i) => _gridPage(pages[i], t),
          ),
        ),
        const SizedBox(height: 10),
        // 第三行页脚：分页圆点居中 + 关机键关闭居最右（对齐网格第 5 列）
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
            Expanded(
              child: pages.length > 1
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          GestureDetector(
                            onTap: () => _pc.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? t.colors.primary
                                    : t.colors.border,
                                borderRadius: BorderRadius.circular(3.5),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox(),
            ),
            const Expanded(child: SizedBox()),
            Expanded(
              // 列内居中（而非右贴边）：与第 5 列图标中心严格对齐
              child: Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(widget.sheetContext),
                  child: Icon(
                    FLucideIcons.power,
                    size: 22,
                    color: t.colors.foreground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridPage(List<_MenuAction> items, FThemeData t) {
    final first = items.take(5).toList();
    final rest = items.skip(5).toList();
    return Column(
      children: [
        _row(first, t),
        const SizedBox(height: 16),
        _row(rest, t),
      ],
    );
  }

  /// 一行固定 5 列：不足 5 项补空占位（Expanded 空盒），保证与相邻行列对齐。
  /// ⚠️ 不能直接 `[for (final a in items) Expanded(...)]` —— 4 项会被均分成 4 列、
  /// 每列变宽，与上一行 5 列错位（2026-09-19 真机实踩）。
  Widget _row(List<_MenuAction> items, FThemeData t) {
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: i < items.length ? _cell(items[i], t) : const SizedBox(),
          ),
      ],
    );
  }

  Widget _cell(_MenuAction a, FThemeData t) {
    final color = a.active ? t.colors.primary : t.colors.foreground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: a.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(
              a.label,
              textAlign: TextAlign.center,
              style: t.typography.body.sm.copyWith(
                fontSize: 11,
                color: a.active ? t.colors.primary : t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
