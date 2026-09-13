// 分段 Tab 栏（列表页通用原子）—— 从待办页 todo_page.dart 原样抽出
//
// 规格（画布 08 / 5:424）：
//   容器   左右 16 / 上下 4 · muted 底 · r11 · 高 34 · 内边距 3 · 段间距 3
//   选中段 白卡底 · r8 · 13/w600 + foreground；未选中 透明底 · 13/w400 + mutedForeground
//
// ⚠️ 这是「状态 / 模式范围」切换，不是筛选 —— 它随滚动移出（**不吸顶**），
//    吸顶锚点是上方的搜索行（见 pinned_search_row.dart 文件头）。
// ⚠️ `crossAxisAlignment: stretch` 必须保留：选中白底要填满 34-3-3=28 的内轨，
//    Row 默认 center 只会让白底药丸有文字高（`fill_container` 不会自动发生，雷区 #11）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 分段 Tab 栏（泛型：tab 值由调用方定义，如状态枚举 / 模式字符串）
class ScopeTabBar<T> extends StatelessWidget {
  const ScopeTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 4),
  });

  /// tab 清单（值 + 标签）
  final List<(T, String)> tabs;

  /// 当前选中值
  final T selected;

  /// 点选回调（点同一个值也会回调，由调用方自行判等）
  final ValueChanged<T> onSelect;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: padding,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          spacing: 3,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tab in tabs)
              Expanded(
                child: FTappable(
                  onPress: () => onSelect(tab.$1),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == tab.$1
                          ? t.colors.card
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab.$2,
                      style: t.typography.body.xs.copyWith(
                        fontSize: 13,
                        fontWeight: selected == tab.$1
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected == tab.$1
                            ? t.colors.foreground
                            : t.colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
