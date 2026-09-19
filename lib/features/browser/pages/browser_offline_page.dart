// 离线页面列表（/browser/offline）—— 展示已保存可离线阅读的整页 HTML
//
// 点列表项 = 打开离线查看器（/browser/offline/view/:key，把存好的 HTML 喂给一个独立
// InAppWebView）；长按 = 删除。保存动作在菜单「离线页面」里触发（抓取当前页 HTML 落库）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/ui_atoms.dart';
import '../components/browser_site_tile.dart';
import '../components/browser_subpage.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';
import '../../../core/db/app_database.dart';

class BrowserOfflineListPage extends ConsumerWidget {
  const BrowserOfflineListPage({super.key});

  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String dayLabel(int? ms) {
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天 ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return '昨天';
    if (d.year == now.year) return '${d.month} 月 ${d.day} 日';
    return '${d.year} 年 ${d.month} 月 ${d.day} 日';
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showSheetConfirm(
      context,
      title: '清空离线页面',
      message: '将删除全部已保存的离线页面，不可恢复。',
      confirmLabel: '清空',
    );
    if (ok && context.mounted) {
      await ref.read(browserRepositoryProvider).clearOfflinePages();
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref,
      BrowserOfflinePage row) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除离线页面',
      message: '删除「${row.title ?? hostOf(row.url)}」的离线副本？',
      confirmLabel: '删除',
    );
    if (ok && context.mounted) {
      await ref.read(browserRepositoryProvider).deleteOfflinePage(row.key);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final async = ref.watch(browserOfflinePagesProvider);
    return BrowserSubPage(
      title: '离线页面',
      actions: [
        BrowserHeaderAction(
          icon: FLucideIcons.trash2,
          tooltip: '清空',
          onTap: () => _clearAll(context, ref),
        ),
      ],
      child: async.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '读取离线页面失败：$e',
            style: t.typography.body.sm.copyWith(
              color: t.colors.mutedForeground,
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.cloudOff,
              title: '还没有离线页面',
              subtitle: '在菜单点「离线页面」保存当前页',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              4,
              AppTokens.pagePadding,
              AppTokens.pageBottomGapOf(context),
            ),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final row = rows[i];
              final size = formatSize(row.sizeBytes);
              return BrowserSiteCard(
                title: row.title ?? hostOf(row.url),
                url: displayUrl(row.url),
                subtitle: [dayLabel(row.savedAt), if (size.isNotEmpty) size]
                    .join(' · '),
                onTap: () => context.push('/browser/offline/view/${row.key}'),
                onLongPress: () => _delete(context, ref, row),
              );
            },
          );
        },
      ),
    );
  }
}
