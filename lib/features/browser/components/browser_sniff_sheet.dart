// 资源嗅探面板 —— 展示实时累计的媒体资源（流媒体 / 视频 / 音频 / 图片 / 链接）
//
// 采集逻辑：网络层观察 + JS hook 喂给 BrowserSniffer（见 services/browser_sniffer.dart），
// 打开面板时页面侧再把静态 DOM 扫描结果合并进来。本文件只负责展示：
//   - 流媒体（m3u8/mpd）条目尾按钮 = 复制链接（内置合成下载是独立工程）
//   - 其余条目尾按钮 = 下载（汇入 BrowserDownloadService）
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/tap_scale.dart';
import '../models/browser_models.dart';
import '../services/browser_sniffer.dart';

IconData sniffIcon(BrowserSniffKind kind) {
  return switch (kind) {
    BrowserSniffKind.stream => FLucideIcons.play,
    BrowserSniffKind.video => FLucideIcons.video,
    BrowserSniffKind.audio => FLucideIcons.music,
    BrowserSniffKind.image => FLucideIcons.image,
    BrowserSniffKind.link => FLucideIcons.file,
  };
}

/// 类型展示名
String sniffKindLabel(BrowserSniffedResource r) {
  return switch (r.kind) {
    BrowserSniffKind.stream => '流媒体',
    _ => r.tagName ?? r.kind.name,
  };
}

/// 打开资源嗅探面板
void showBrowserSniffSheet(
  BuildContext context, {
  required List<BrowserSniffedResource> resources,
  required void Function(String url, String? filename) onDownload,
}) {
  showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightMd,
    builder: (sheetContext) => SheetSurface(
      child: _BrowserSniffSheetContent(
        resources: resources,
        onDownload: onDownload,
      ),
    ),
  );
}

class _BrowserSniffSheetContent extends StatelessWidget {
  const _BrowserSniffSheetContent({
    required this.resources,
    required this.onDownload,
  });

  final List<BrowserSniffedResource> resources;
  final void Function(String url, String? filename) onDownload;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePadding,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '资源嗅探（${resources.length}）',
                style: t.typography.body.lg.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: resources.isEmpty
                  ? Center(
                      child: Text(
                        '当前页面没有可下载的资源',
                        style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: resources.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final r = resources[i];
                        return _SniffRow(
                          resource: r,
                          onDownload: () => onDownload(r.url, null),
                        );
                      },
                    ),
            ),
            if (resources.any((r) => r.kind == BrowserSniffKind.stream)) ...[
              const SizedBox(height: 6),
              Text(
                '流媒体（m3u8/mpd）为清单链接：点右侧按钮复制，'
                '可用支持 HLS 的播放器/下载器处理',
                style: t.typography.body.xs.copyWith(
                  fontSize: 11,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SniffRow extends StatelessWidget {
  const _SniffRow({required this.resource, required this.onDownload});

  final BrowserSniffedResource resource;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Row(
      children: [
        Icon(sniffIcon(resource.kind), size: 20, color: t.colors.foreground),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayUrl(resource.url),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.sm.copyWith(fontSize: 13),
              ),
              Text(
                sniffKindLabel(resource),
                style: t.typography.body.xs.copyWith(
                  fontSize: 11,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        TapScale(
          onTap: resource.kind == BrowserSniffKind.stream
              ? () async {
                  await Clipboard.setData(ClipboardData(text: resource.url));
                  if (!context.mounted) return;
                  showFToast(
                    context: context,
                    title: const Text('流媒体链接已复制'),
                  );
                }
              : onDownload,
          child: Icon(
            resource.kind == BrowserSniffKind.stream
                ? FLucideIcons.copy
                : FLucideIcons.download,
            size: 20,
            color: t.colors.primary,
          ),
        ),
      ],
    );
  }
}
