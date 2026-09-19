// 资源嗅探面板 —— 枚举当前页面里的可下载资源（img / video / audio / a[download]）
//
// 扫描逻辑在浏览器主壳用 JS 注入完成（见 browser_page._scanResources），本文件只负责
// 把结果列出来，每行带「下载」按钮，点击调用 [onDownload] 汇入 BrowserDownloadService。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/tap_scale.dart';
import '../models/browser_models.dart';

/// 嗅探到的资源类型
enum BrowserSniffKind { image, video, audio, link }

/// 嗅探到的单个资源
class BrowserSniffedResource {
  const BrowserSniffedResource({
    required this.url,
    required this.kind,
    this.tagName,
  });

  final String url;
  final BrowserSniffKind kind;
  final String? tagName;
}

IconData sniffIcon(BrowserSniffKind kind) {
  return switch (kind) {
    BrowserSniffKind.image => FLucideIcons.image,
    BrowserSniffKind.video => FLucideIcons.video,
    BrowserSniffKind.audio => FLucideIcons.music,
    BrowserSniffKind.link => FLucideIcons.file,
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
                resource.tagName ?? resource.kind.name,
                style: t.typography.body.xs.copyWith(
                  fontSize: 11,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        TapScale(
          onTap: onDownload,
          child: Icon(
            FLucideIcons.download,
            size: 20,
            color: t.colors.primary,
          ),
        ),
      ],
    );
  }
}
