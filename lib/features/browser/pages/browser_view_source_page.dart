// 网页源码页（菜单「源码」项）
//
// 由浏览器主壳抓 `document.documentElement.outerHTML` 后经路由 extra 传进来展示。
// 用 SelectableText + 等宽字体，方便长按复制某段。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../components/browser_subpage.dart';

/// 网页源码展示页
class BrowserViewSourcePage extends StatelessWidget {
  const BrowserViewSourcePage({super.key, this.html});

  /// 当前页 HTML（由主壳 evaluateJavascript 抓取，经路由 extra 传入）
  final String? html;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return BrowserSubPage(
      title: '网页源码',
      child: html == null || html!.isEmpty
          ? Center(
              child: Text(
                '暂无源码',
                style: t.typography.body.sm.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.pagePadding),
              child: SelectableText(
                html!,
                style: t.typography.body.sm.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: t.colors.foreground,
                  height: 1.5,
                ),
              ),
            ),
    );
  }
}
