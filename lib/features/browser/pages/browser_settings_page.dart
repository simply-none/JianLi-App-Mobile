// 浏览器设置页（/browser/settings）—— 完整设置入口
//
// 分组（与设计稿对齐，另按落地需要补了「书签与历史」一组的入口）：
//   常规 / 外观 / 隐私与安全 / 广告拦截 / 固定标签页 / 书签与历史 / 关于
//
// 分工：本页只做「列设置项 + 写设置」，行样式交给 components/settings_tiles.dart，
// 各子页（固定标签管理 / 规则 / 清除数据 / 书签 / 历史）各自独立成文件。
// ⚠️ 所有写入都走 `browserSettingsProvider.save(copyWith(...))` —— 保存的是**完整快照**，
//    这样把开关改回默认值也不会留下陈旧的库值（见 browser_settings.dart 的说明）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/settings_panel.dart' show kAppVersion;
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../components/browser_prompt.dart';
import '../components/browser_subpage.dart';
import '../components/settings_tiles.dart';
import '../models/browser_models.dart';
import '../models/browser_settings.dart';
import '../providers/browser_providers.dart';
import '../services/adblock_rules.dart';

/// 网页字号档位
const List<(double, String)> _fontScales = [
  (0.8, '80%'),
  (1.0, '100%（推荐）'),
  (1.2, '120%'),
  (1.5, '150%'),
];

class BrowserSettingsPage extends ConsumerWidget {
  const BrowserSettingsPage({super.key});

  // ————————————————— 写入 —————————————————

  static Future<void> _save(WidgetRef ref, BrowserSettings next) {
    return ref.read(browserSettingsProvider.notifier).save(next);
  }

  // ————————————————— 选择器 —————————————————

  Future<void> _pickEngine(
    BuildContext context,
    WidgetRef ref,
    BrowserSettings s,
  ) async {
    final picked = await showSheetActionMenu<BrowserEngine>(
      context,
      title: '搜索引擎',
      // 用户定案（2026-09-19）：50vh（md）。showSheetActionMenu 默认 sm(30vh)，
      // 引擎列表 5 项 + 说明文案在 sm 档偏挤，仅此调用点升 md，不影响其他调用方。
      size: SheetSize.md,
      actions: [
        for (final e in kBrowserEngines)
          SheetAction(e, e.name == '自定义' ? '自定义模板…' : e.name),
      ],
    );
    if (picked == null || !context.mounted) return;
    if (picked.id != 'custom') {
      await _save(ref, s.copyWith(engineId: picked.id));
      return;
    }
    final template = await showBrowserPrompt(
      context,
      title: '自定义搜索引擎',
      initial: s.customSearchTemplate,
      hint: 'https://example.com/search?q=%s',
      confirmLabel: '保存',
      keyboardType: TextInputType.url,
      helper: '用 %s 代表搜索词。例如 https://example.com/search?q=%s',
    );
    if (template == null || !context.mounted) return;
    await _save(
      ref,
      s.copyWith(engineId: 'custom', customSearchTemplate: template),
    );
  }

  Future<void> _pickNewTabMode(
    BuildContext context,
    WidgetRef ref,
    BrowserSettings s,
  ) async {
    final picked = await showSheetActionMenu<BrowserNewTabMode>(
      context,
      title: '新标签页打开方式',
      actions: [
        for (final m in BrowserNewTabMode.values)
          SheetAction(
            m,
            m.label,
            icon: m == BrowserNewTabMode.foreground
                ? FLucideIcons.squareStack
                : FLucideIcons.layers,
          ),
      ],
    );
    if (picked == null) return;
    await _save(ref, s.copyWith(newTabMode: picked));
  }

  Future<void> _pickDarkMode(
    BuildContext context,
    WidgetRef ref,
    BrowserSettings s,
  ) async {
    final picked = await showSheetActionMenu<BrowserDarkMode>(
      context,
      title: '深色模式',
      actions: [
        for (final m in BrowserDarkMode.values)
          SheetAction(m, m.label, icon: switch (m) {
            BrowserDarkMode.system => FLucideIcons.monitor,
            BrowserDarkMode.light => FLucideIcons.sun,
            BrowserDarkMode.dark => FLucideIcons.moon,
          }),
      ],
    );
    if (picked == null) return;
    await _save(ref, s.copyWith(darkMode: picked));
  }

  Future<void> _pickFontScale(
    BuildContext context,
    WidgetRef ref,
    BrowserSettings s,
  ) async {
    final picked = await showSheetActionMenu<double>(
      context,
      title: '网页字号',
      actions: [
        for (final (scale, label) in _fontScales)
          SheetAction(scale, label, icon: FLucideIcons.type),
      ],
    );
    if (picked == null) return;
    await _save(ref, s.copyWith(fontScale: picked));
  }

  // ————————————————— UI —————————————————

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s =
        ref.watch(browserSettingsProvider).value ?? const BrowserSettings();
    final pinned =
        ref.watch(pinnedSitesProvider).value?.length ?? 0;
    final bookmarks = ref.watch(browserBookmarksProvider).value?.length ?? 0;
    final history = ref.watch(browserHistoryProvider).value?.length ?? 0;
    final subs = ref.watch(adBlockSubscriptionsProvider).value;
    final staticCount = kStaticBlockedHosts.length + kStaticBlockedPatterns.length;
    final cachedSubs = subs?.values.where((e) => e.hasRules).length ?? 0;

    void push(String route) => context.push(route);

    return BrowserSubPage(
      title: '浏览器设置',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          4,
          AppTokens.pagePadding,
          AppTokens.pageBottomGapOf(context),
        ),
        children: [
          // —— 常规 ——
          SettingsSection(
            title: '常规',
            children: [
              SettingsNavRow(
                icon: FLucideIcons.search,
                label: '搜索引擎',
                value: s.engine.name,
                onTap: () => _pickEngine(context, ref, s),
              ),
              SettingsSwitchRow(
                icon: FLucideIcons.house,
                label: '首页显示固定标签页',
                hint: '关闭后新标签页只留图标标题与搜索栏',
                value: s.showPinnedOnHome,
                onChange: (v) =>
                    _save(ref, s.copyWith(showPinnedOnHome: v)),
              ),
              SettingsNavRow(
                icon: FLucideIcons.squareStack,
                label: '新标签页打开方式',
                value: s.newTabMode.label,
                hint: s.newTabMode.hint,
                onTap: () => _pickNewTabMode(context, ref, s),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // —— 外观 ——
          SettingsSection(
            title: '外观',
            children: [
              SettingsNavRow(
                icon: FLucideIcons.moon,
                label: '深色模式',
                value: s.darkMode.label,
                hint: '作用于网页内容（Android 10+ 的强制深色）',
                onTap: () => _pickDarkMode(context, ref, s),
              ),
              SettingsNavRow(
                icon: FLucideIcons.aLargeSmall,
                label: '网页字号',
                value: '${(s.fontScale * 100).round()}%',
                onTap: () => _pickFontScale(context, ref, s),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // —— 隐私与安全 ——
          SettingsSection(
            title: '隐私与安全',
            children: [
              SettingsSwitchRow(
                icon: FLucideIcons.venetianMask,
                label: '无痕模式',
                hint: '不写历史、不留 Cookie 与缓存',
                value: s.incognito,
                onChange: (v) => _save(ref, s.copyWith(incognito: v)),
              ),
              SettingsSwitchRow(
                icon: FLucideIcons.globeLock,
                label: '不追踪请求',
                hint: '给所有请求带上 DNT: 1 头',
                value: s.doNotTrack,
                onChange: (v) => _save(ref, s.copyWith(doNotTrack: v)),
              ),
              SettingsSwitchRow(
                icon: FLucideIcons.search,
                label: '媒体嗅探',
                hint: '嗅探页面加载的音视频与流媒体（m3u8/mp4 等）；关闭可省开销',
                value: s.sniffEnabled,
                onChange: (v) => _save(ref, s.copyWith(sniffEnabled: v)),
              ),
              SettingsNavRow(
                icon: FLucideIcons.trash2,
                label: '清除浏览数据',
                hint: '历史 / Cookie / 缓存 / 本地存储',
                onTap: () => push('/browser/clear-data'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // —— 广告拦截（三级规则）——
          SettingsSection(
            title: '广告拦截',
            children: [
              SettingsSwitchRow(
                icon: FLucideIcons.shield,
                label: '广告拦截',
                hint: '总开关；关闭后三级规则一并停用',
                value: s.adBlockEnabled,
                onChange: (v) => _save(ref, s.copyWith(adBlockEnabled: v)),
              ),
              SettingsNavRow(
                icon: FLucideIcons.shieldCheck,
                label: '内置静态规则集',
                value:
                    '$staticCount 条 · ${s.staticRulesEnabled ? '已启用' : '已关闭'}',
                onTap: () => push('/browser/rules/static'),
              ),
              SettingsNavRow(
                icon: FLucideIcons.cloudDownload,
                label: '订阅规则',
                value: s.subscriptions.isEmpty
                    ? '未订阅'
                    : '${s.subscriptions.length} 个订阅 · 已缓存 $cachedSubs',
                onTap: () => push('/browser/rules/subscriptions'),
              ),
              SettingsNavRow(
                icon: FLucideIcons.ban,
                label: '自定义拦截规则',
                value: '${s.customRules.length} 条规则',
                onTap: () => push('/browser/rules/custom'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // —— 固定标签页 ——
          SettingsSection(
            title: '固定标签页',
            children: [
              const SettingsHintRow(
                '默认 8 个。加入第 9 个时，会替换最早加入的一个；长按可移除或替换。',
                icon: FLucideIcons.info,
              ),
              SettingsNavRow(
                icon: FLucideIcons.pin,
                label: '管理固定标签页',
                value: '$pinned / $kPinnedMaxSlots',
                onTap: () => push('/browser/pinned'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // —— 书签与历史 ——
          SettingsSection(
            title: '书签与历史',
            children: [
              SettingsNavRow(
                icon: FLucideIcons.bookMarked,
                label: '书签',
                value: '$bookmarks 项',
                onTap: () => push('/browser/bookmarks'),
              ),
              SettingsNavRow(
                icon: FLucideIcons.history,
                label: '历史记录',
                value: '$history 条',
                onTap: () => push('/browser/history'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // —— 关于 ——
          SettingsSection(
            title: '关于',
            children: [
              SettingsNavRow(
                icon: FLucideIcons.info,
                label: '关于渐离App',
                value: 'v$kAppVersion',
                hint: '功能介绍 · 依赖鸣谢 · 版本信息',
                onTap: () => push('/about'),
              ),
              const SettingsHintRow(
                '浏览器模块使用 Android 系统 WebView 渲染网页，'
                '网页数据只保存在本机，不会上传。',
                icon: FLucideIcons.lock,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
