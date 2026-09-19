// 下载列表页（/browser/downloads）—— 展示 WebView 触发与嗅探发起的下载任务
//
// 点已完成项 = open_filex 打开本地文件；长按 = 删除（记录 + 落盘文件一并删）。
// ⚠️ 抓取在 BrowserDownloadService 里异步进行，DB 状态变更会经
// browserDownloadsProvider 流自动刷新本页，无需手动 pull。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../components/browser_site_tile.dart';
import '../components/browser_subpage.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';

class BrowserDownloadsPage extends ConsumerWidget {
  const BrowserDownloadsPage({super.key});

  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showSheetConfirm(
      context,
      title: '清空下载记录',
      message: '将删除全部下载记录（已下载的文件不会被自动删除）。',
      confirmLabel: '清空',
    );
    if (ok && context.mounted) {
      await ref.read(browserRepositoryProvider).clearDownloads();
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref,
      BrowserDownload row) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除下载',
      message: '删除该记录${row.localPath != null ? '及已下载的文件' : ''}？',
      confirmLabel: '删除',
    );
    if (!ok || !context.mounted) return;
    if (row.localPath != null) {
      try {
        await File(row.localPath!).delete();
      } catch (_) {
        // 文件已不在，继续删记录
      }
    }
    await ref.read(browserRepositoryProvider).deleteDownload(row.key);
  }

  Future<void> _open(BrowserDownload row) async {
    if (row.localPath == null) return;
    await OpenFilex.open(row.localPath!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final async = ref.watch(browserDownloadsProvider);
    return BrowserSubPage(
      title: '下载',
      actions: [
        BrowserHeaderAction(
          icon: FLucideIcons.trash2,
          tooltip: '清空记录',
          onTap: () => _clearAll(context, ref),
        ),
      ],
      child: async.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '读取下载失败：$e',
            style: t.typography.body.sm.copyWith(
              color: t.colors.mutedForeground,
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: FLucideIcons.download,
              title: '还没有下载',
              subtitle: '点文件链接或「资源嗅探」发起下载',
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
              final name = row.filename ?? hostOf(row.url);
              final size = formatSize(row.sizeBytes);
              final status = switch (row.status) {
                'done' => '已完成',
                'failed' => '失败',
                _ => '下载中',
              };
              return BrowserSiteCard(
                title: name,
                url: displayUrl(row.url),
                subtitle: [status, if (size.isNotEmpty) size]
                    .join(' · '),
                trailing: row.status == 'pending' ? '下载中…' : null,
                onTap: row.status == 'done' ? () => _open(row) : null,
                onLongPress: () => _delete(context, ref, row),
              );
            },
          );
        },
      ),
    );
  }
}
