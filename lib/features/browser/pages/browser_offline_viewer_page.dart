// 离线页面查看器（/browser/offline/view/:key）
//
// 把存进 browser_offline_pages 的整页 HTML 喂给一个独立 InAppWebView（loadData），
// 实现「没网也能看刚保存的页」。注意：MVP 只存了 HTML 文本，不含图片/样式等子资源，
// 所以离线页里图片可能加载不出来——这是已知取舍，后续可扩展成把子资源一并抓取打包。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/browser_subpage.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';
import '../../../core/db/app_database.dart';

class BrowserOfflineViewerPage extends ConsumerStatefulWidget {
  const BrowserOfflineViewerPage({super.key, required this.offlineKey});

  final String offlineKey;

  @override
  ConsumerState<BrowserOfflineViewerPage> createState() =>
      _BrowserOfflineViewerPageState();
}

class _BrowserOfflineViewerPageState
    extends ConsumerState<BrowserOfflineViewerPage> {
  BrowserOfflinePage? _row;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final row = await ref
        .read(browserRepositoryProvider)
        .getOfflinePage(widget.offlineKey);
    if (!mounted) return;
    setState(() {
      _row = row;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _row?.title ?? hostOf(_row?.url ?? '');
    final html = _row?.html;
    return BrowserSubPage(
      title: title.isEmpty ? '离线页面' : title,
      child: _loading
          ? const Center(child: FCircularProgress())
          : (html == null || html.isEmpty)
              ? const Center(
                  child: Text('无法读取该离线页面'),
                )
              : InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: html,
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                    baseUrl: WebUri(_row!.url),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    transparentBackground: false,
                  ),
                ),
    );
  }
}
