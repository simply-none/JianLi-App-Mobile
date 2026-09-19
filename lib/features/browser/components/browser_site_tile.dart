// 站点条目 / 文件夹条目（书签页与历史页共用）
//
// 规格对齐项目「列表卡族」约定：AppCard(margin:仅底部 8、padding:0、elevation 默认)
// + 图标盘固定 40 / r13 / 图标 20。
//
// 没有真实 favicon 资源，用「域名首字 + 由 URL 稳定推导的域色」做身份标识
// —— 同一站点在书签页、历史页、长按菜单里颜色一致，看起来仍是「同一个东西」。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';

/// 卡片外壳（站点行）：AppCard + [BrowserSiteRow]
class BrowserSiteCard extends StatelessWidget {
  const BrowserSiteCard({
    super.key,
    required this.title,
    required this.url,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final String title;

  /// 用于推导图标盘颜色与首字
  final String url;

  /// 副标题（不传则用 `displayUrl(url)`）
  final String? subtitle;

  /// 尾部备注（如历史页的「12 次」）
  final String? trailing;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      onTap: onTap,
      onLongPress: onLongPress,
      child: BrowserSiteRow(
        title: title,
        url: url,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}

/// 站点行本体（纯展示，不带点击 —— 点击交给外层 AppCard，避免双 TapScale）
class BrowserSiteRow extends StatelessWidget {
  const BrowserSiteRow({
    super.key,
    required this.title,
    required this.url,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String url;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = accentOfSite(url);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTokens.accentGradient(accent),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              letterOfTitle(title, url),
              style: t.typography.body.md.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.md.copyWith(
                    fontSize: 15,
                    color: t.colors.foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 文件夹卡片（书签页专用）：文件夹图标盘 + 名称 + 「N 项」 + 右箭头
class BrowserFolderCard extends StatelessWidget {
  const BrowserFolderCard({
    super.key,
    required this.title,
    required this.childCount,
    this.onTap,
    this.onLongPress,
  });

  final String title;

  /// 直接子项数量（展示用）
  final int childCount;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTokens.accentGradient(AppTokens.accent(0)),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: const Icon(
                FLucideIcons.folder,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.md.copyWith(
                  fontSize: 15,
                  color: t.colors.foreground,
                ),
              ),
            ),
            Text(
              '$childCount 项',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              FLucideIcons.chevronRight,
              size: 18,
              color: t.colors.mutedForeground.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 由 URL 稳定推导域色（同一站点跨页面同色）
Color accentOfSite(String url) {
  var hash = 0;
  for (final c in url.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return AppTokens.accent(hash % 8);
}

/// 首字：优先取标题首字（中文站名更好认），无标题时取域名首字母
String letterOfTitle(String title, String url) {
  final t = title.trim();
  if (t.isNotEmpty) return String.fromCharCode(t.runes.first).toUpperCase();
  final s = url.trim();
  if (s.isEmpty) return '·';
  return String.fromCharCode(s.runes.first).toUpperCase();
}
