// 订阅规则页（/browser/rules/subscriptions）—— 广告拦截三级之二
//
// 一条订阅 = 一个规则文件 URL。加入后**立即抓取**并缓存原文（离线也能生效），
// 之后可随时手动刷新。抓取走 dart:io HttpClient，零新依赖（见 services/adblock_subscriptions.dart）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/ui_atoms.dart';
import '../components/browser_prompt.dart';
import '../components/browser_site_actions.dart';
import '../components/browser_subpage.dart';
import '../components/settings_tiles.dart';
import '../models/browser_models.dart';
import '../models/browser_settings.dart';
import '../providers/browser_providers.dart';
import '../services/adblock_subscriptions.dart';

/// 订阅条目长按动作
enum _SubAction { refresh, copy, remove }

class BrowserSubscriptionsPage extends ConsumerStatefulWidget {
  const BrowserSubscriptionsPage({super.key});

  @override
  ConsumerState<BrowserSubscriptionsPage> createState() =>
      _BrowserSubscriptionsPageState();
}

class _BrowserSubscriptionsPageState
    extends ConsumerState<BrowserSubscriptionsPage> {
  /// 正在抓取的订阅地址（用于行内菊花与防重复点击）
  String? _busy;

  List<String> get _urls =>
      (ref.read(browserSettingsProvider).value ?? const BrowserSettings())
          .subscriptions;

  Future<void> _saveSubscriptions(List<String> next) async {
    final s =
        ref.read(browserSettingsProvider).value ?? const BrowserSettings();
    await ref
        .read(browserSettingsProvider.notifier)
        .save(s.copyWith(subscriptions: next));
  }

  Future<void> _add() async {
    final input = await showBrowserPrompt(
      context,
      title: '添加订阅',
      hint: 'https://…/easylist.txt',
      confirmLabel: '添加并抓取',
      keyboardType: TextInputType.url,
      helper: '填入 Adblock 语法的规则文件地址。添加后会立即抓取一次并缓存到本机。',
    );
    if (input == null || !mounted) return;
    final url = input.trim();
    final urls = _urls;
    if (urls.contains(url)) {
      showFToast(context: context, title: const Text('该订阅已存在'));
      return;
    }
    await _saveSubscriptions([...urls, url]);
    if (!mounted) return;
    await _refresh(url);
  }

  Future<void> _refresh(String url) async {
    if (_busy != null) return;
    setState(() => _busy = url);
    final result = await ref
        .read(adBlockSubscriptionsProvider.notifier)
        .refresh(url);
    if (!mounted) return;
    setState(() => _busy = null);
    final failed = result.error != null;
    showFToast(
      context: context,
      variant: failed ? FToastVariant.destructive : FToastVariant.primary,
      title: Text(
        failed ? '抓取失败：${result.error}' : '已更新 ${result.ruleCount} 条规则',
      ),
    );
  }

  Future<void> _remove(String url) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除订阅',
      message: '「$url」及其本机缓存将被删除。',
    );
    if (!ok || !mounted) return;
    await _saveSubscriptions(
      _urls.where((e) => e != url).toList(),
    );
    if (!mounted) return;
    await ref.read(adBlockSubscriptionsProvider.notifier).remove(url);
  }

  Future<void> _menu(String url) async {
    final action = await showSheetActionMenu<_SubAction>(
      context,
      title: hostOf(url),
      actions: const [
        SheetAction(_SubAction.refresh, '刷新规则', icon: FLucideIcons.refreshCw),
        SheetAction(_SubAction.copy, '复制地址', icon: FLucideIcons.link),
        SheetAction(
          _SubAction.remove,
          '删除订阅',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _SubAction.refresh:
        await _refresh(url);
      case _SubAction.copy:
        await copyLink(context, url);
      case _SubAction.remove:
        await _remove(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final urls =
        ref.watch(browserSettingsProvider).value?.subscriptions ??
        const <String>[];
    final cache = ref.watch(adBlockSubscriptionsProvider).value ??
        const <String, CachedSubscription>{};
    final engine = ref.watch(adBlockEngineProvider);
    return BrowserSubPage(
      title: '订阅规则',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          4,
          AppTokens.pagePadding,
          AppTokens.pageBottomGapOf(context),
        ),
        children: [
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text(
                  '当前生效 ${engine.ruleCount} 条规则',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                ),
                Text(
                  '订阅的规则文件会与本机内置规则集合并。抓取结果缓存在本机，'
                  '断网时仍按上次缓存生效。',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    height: 1.6,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SettingsGroupLabel('已订阅'),
          if (urls.isEmpty)
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    FLucideIcons.cloudDownload,
                    size: 16,
                    color: t.colors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '还没有订阅。国内站点建议订阅 EasyList China 一类的规则文件，'
                      '体量最大、覆盖面最广。',
                      style: t.typography.body.xs.copyWith(
                        fontSize: 12,
                        height: 1.6,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final url in urls)
              _SubscriptionCard(
                url: url,
                cache: cache[url],
                busy: _busy == url,
                onRefresh: () => _refresh(url),
                onLongPress: () => _menu(url),
              ),
          const SizedBox(height: 16),
          GradientButton(
            label: '添加订阅',
            icon: FLucideIcons.plus,
            onPress: _add,
          ),
        ],
      ),
    );
  }
}

/// 单条订阅卡片
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.url,
    required this.cache,
    required this.busy,
    required this.onRefresh,
    required this.onLongPress,
  });

  final String url;
  final CachedSubscription? cache;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final failed = cache?.error != null;
    final count = cache?.ruleCount ?? 0;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onLongPress: onLongPress,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTokens.accentGradient(
                failed ? t.colors.destructive : AppTokens.accent(3),
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(
              FLucideIcons.shield,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostOf(url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.md.copyWith(
                    fontSize: 15,
                    color: t.colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? '抓取失败：${cache!.error}'
                      : '$count 条 · ${cache?.fetchedLabel ?? '尚未抓取'}',
                  maxLines: 2,
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    height: 1.4,
                    color: failed
                        ? t.colors.destructive
                        : t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: FCircularProgress(),
            )
          else
            GestureDetector(
              onTap: onRefresh,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  FLucideIcons.refreshCw,
                  size: 18,
                  color: t.colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
