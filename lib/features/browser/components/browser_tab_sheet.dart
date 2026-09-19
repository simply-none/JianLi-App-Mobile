// 多标签抽屉（md 50%）
//
// ⚠️ 抽屉内容自带 `Consumer`：`showFSheet` 的 builder 属于 **Navigator overlay 子树**，
// 用页面的 ref.watch 订阅不会让抽屉重建（会永远停在首帧空列表）——技能红线 #28。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';

/// 打开标签页抽屉
Future<void> showBrowserTabsSheet(
  BuildContext context, {
  required String? activeKey,
  required Future<void> Function(BrowserTab tab) onSwitch,
  required Future<void> Function(String key) onClose,
  required VoidCallback onNewTab,
}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightMd,
    builder: (sheetContext) => SheetSurface(
      child: Consumer(
        builder: (inner, ref, _) {
          final tabs =
              ref.watch(browserTabsProvider).value ?? const <BrowserTab>[];
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.pagePadding,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Center(
                      child: Text(
                        '标签页 · ${tabs.length}',
                        style: sheetTitleStyle(inner),
                      ),
                    ),
                  ),
                  Expanded(
                    child: tabs.isEmpty
                        ? Center(
                            child: Text(
                              '还没有打开的标签',
                              style: inner.theme.typography.body.sm.copyWith(
                                color: inner.theme.colors.mutedForeground,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tabs.length,
                            itemBuilder: (itemContext, index) {
                              final tab = tabs[index];
                              return _TabRow(
                                tab: tab,
                                active: tab.key == activeKey,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  onSwitch(tab);
                                },
                                onClose: () => onClose(tab.key),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  _NewTabButton(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onNewTab();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// 单条标签
class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final url = (tab.url ?? '').trim();
    final title =
        (tab.title ?? '').trim().isNotEmpty
            ? tab.title!.trim()
            : (url.isEmpty ? kBlankTabTitle : displayUrl(url));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.colors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(
              color: active ? t.colors.primary : t.colors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.colors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  FLucideIcons.globe,
                  size: 18,
                  color: t.colors.mutedForeground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.body.sm.copyWith(
                        fontSize: 14,
                        color: active ? t.colors.primary : t.colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      url.isEmpty ? '新标签页' : displayUrl(url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.body.xs.copyWith(
                        fontSize: 11.5,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      FLucideIcons.x,
                      size: 18,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部「新建标签页」
class _NewTabButton extends StatelessWidget {
  const _NewTabButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.colors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.plus, size: 18, color: t.colors.primary),
            const SizedBox(width: 8),
            Text(
              '新建标签页',
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                color: t.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
