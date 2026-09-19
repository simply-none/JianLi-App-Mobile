// 固定标签页九宫格（首页 / 设置页共用组件）
//
// 纯展示 + 回调：只吃 `BrowserPinnedData` 列表，不碰数据层、不读 provider，
// 因此首页（点击打开）与设置页（长按管理）可以用同一份实现，改一处两处同步。
// 槽位规格对齐画布：2 行 × 4 列、单元格 76 宽、磁贴 56×56 r16、
// 占位字 20/SemiBold 品牌色、站点名 11/ mutedForeground。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../models/browser_models.dart';

/// 固定标签九宫格（最多 [kPinnedMaxSlots] 格）
class BrowserSpeedDial extends StatelessWidget {
  const BrowserSpeedDial({
    super.key,
    required this.sites,
    required this.onOpen,
    this.onLongPressSite,
    this.onAdd,
    this.tileSize = 56,
    this.cellWidth = 76,
  });

  /// 固定标签（按槽位排序后的列表）
  final List<BrowserPinnedData> sites;

  /// 单击：打开站点
  final void Function(BrowserPinnedData site) onOpen;

  /// 长按：管理（设置页用；为 null 表示不支持长按）
  final void Function(BrowserPinnedData site)? onLongPressSite;

  /// 空槽位的「+」入口（为 null 则不显示；首页 8 格满时不需要）
  final VoidCallback? onAdd;

  final double tileSize;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (final site in sites) _siteCell(context, site),
      if (onAdd != null && sites.length < kPinnedMaxSlots) _addCell(context),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 4) {
      final end = (i + 4) > cells.length ? cells.length : i + 4;
      final chunk = cells.sublist(i, end);
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 20));
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ...chunk,
            // 不足 4 格时用等宽占位撑住，保证列对齐（不能用 Expanded，
            // 否则最后一行的格子会被拉开、与上一行错位）
            for (var k = chunk.length; k < 4; k++) SizedBox(width: cellWidth),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _siteCell(BuildContext context, BrowserPinnedData site) {
    final t = context.theme;
    final title = (site.title ?? '').trim();
    final brand = parseHexColor(site.color) ?? t.colors.primary;
    final letter =
        (site.letter ?? '').trim().isNotEmpty
            ? site.letter!.trim()
            : letterOfSite(title.isEmpty ? (site.url ?? '') : title);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpen(site),
      onLongPress:
          onLongPressSite == null ? null : () => onLongPressSite!(site),
      child: SizedBox(
        width: cellWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tileSize,
              height: tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.colors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: tileSize * 0.36,
                  fontWeight: FontWeight.w600,
                  color: brand,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.isEmpty ? hostOf(site.url ?? '') : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空槽「+」：同尺寸虚线感磁贴（用 muted 底 + 次级前景，不引入第四种圆角）
  Widget _addCell(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAdd,
      child: SizedBox(
        width: cellWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tileSize,
              height: tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Icon(
                FLucideIcons.plus,
                size: 22,
                color: t.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '加入',
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `#RRGGBB` / `#AARRGGBB` → Color；非法值返回 null（调用方回落主题主色）
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  return value == null ? null : Color(value);
}
