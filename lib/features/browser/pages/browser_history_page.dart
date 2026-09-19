// 历史记录页（/browser/history）—— 按天分组 + 长按操作
//
// 单击 = 在当前标签重新打开；长按 = 操作单（加入固定标签 / 复制链接 / 删除）。
// ⚠️ 与书签页同样用 `pop(url)` 把「要打开什么」交回浏览器主壳，页面自身不认识 WebView。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../components/browser_site_actions.dart';
import '../components/browser_site_tile.dart';
import '../components/browser_subpage.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';

class BrowserHistoryPage extends ConsumerWidget {
  const BrowserHistoryPage({super.key});

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showSheetConfirm(
      context,
      title: '清空历史记录',
      message: '将删除全部访问历史，不可恢复。',
      confirmLabel: '清空',
    );
    if (!ok || !context.mounted) return;
    await ref.read(browserRepositoryProvider).clearHistory();
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    BrowserHistoryData row,
  ) async {
    final url = (row.url ?? '').trim();
    final action = await showBrowserSiteActionMenu(
      context,
      title: row.title ?? hostOf(url),
      url: url,
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case BrowserSiteAction.pin:
        await addSiteToPinned(
          context,
          ref,
          title: row.title ?? hostOf(url),
          url: url,
        );
      case BrowserSiteAction.copy:
        await copyLink(context, url);
      case BrowserSiteAction.delete:
        await ref.read(browserRepositoryProvider).deleteHistoryEntry(row.key);
      case BrowserSiteAction.rename:
        break; // 历史条目不支持重命名（菜单里也不会出现）
    }
  }

  /// 按天分组的标签（今天 / 昨天 / 前天 / M 月 D 日）
  static String dayLabel(int? ms) {
    if (ms == null) return '更早';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    if (d.year == now.year) return '${d.month} 月 ${d.day} 日';
    return '${d.year} 年 ${d.month} 月 ${d.day} 日';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final async = ref.watch(browserHistoryProvider);
    return BrowserSubPage(
      title: '历史记录',
      actions: [
        BrowserHeaderAction(
          icon: FLucideIcons.trash2,
          tooltip: '清空历史',
          onTap: () => _clearAll(context, ref),
        ),
      ],
      child: async.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '读取历史失败：$e',
            style: t.typography.body.sm.copyWith(
              color: t.colors.mutedForeground,
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.history,
              title: '还没有访问记录',
              subtitle: '无痕模式下的访问不会写入历史',
            );
          }
          // 扁平化成「分组头 + 条目」序列（ListView.builder 需要定长可索引）
          final items = <Object>[];
          String? current;
          for (final row in rows) {
            final label = dayLabel(row.visitedAt);
            if (label != current) {
              items.add(label);
              current = label;
            }
            items.add(row);
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              4,
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            itemCount: items.length,
            itemBuilder: (c, i) {
              final item = items[i];
              if (item is String) {
                return Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? 0 : 12,
                    bottom: 8,
                  ),
                  child: Text(
                    item,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                );
              }
              final row = item as BrowserHistoryData;
              final url = (row.url ?? '').trim();
              final count = row.visitCount ?? 1;
              return BrowserSiteCard(
                title: row.title ?? hostOf(url),
                url: url,
                subtitle: displayUrl(url),
                trailing: count > 1 ? '$count 次' : null,
                onTap: () {
                  requestBrowserNavigation(ref, url);
                  context.pop();
                },
                onLongPress: () => _menu(context, ref, row),
              );
            },
          );
        },
      ),
    );
  }
}
