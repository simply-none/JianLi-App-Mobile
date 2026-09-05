// 笔记标签 chip —— 列表 / 详情 / 编辑页共用的彩色小标签
//
// 视觉对齐桌面端：色点 + 名称；选中态 = 标签色 16% 软底 + 彩色文字 + 对勾
// （桌面端筛选 chips 同款 color+'20' 底、color 文字）。圆角 pill、可点。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../models/note_tag.dart';

/// 笔记标签 chip
///
/// 尺寸与分类 chip 统一（页面规范：同一容器内所有筛选/选项 chip 同规格）：
/// padding h14/v7 + body.sm 文字 + 色点；选中态 = 标签色 16% 软底 + 彩色文字 + 对勾。
class NoteTagChip extends StatelessWidget {
  const NoteTagChip({
    super.key,
    required this.tag,
    this.selected = false,
    this.onTap,
  });

  final NoteTag tag;

  /// 选中态（编辑页多选 / 列表筛选）
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final color = tag.colorValue;
    final fg = selected ? color : t.colors.foreground;
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : t.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              tag.name,
              style: t.typography.body.sm.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(FLucideIcons.check, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// 只读小号标签 chip（笔记卡 / 详情页展示用，无按压态）
class NoteTagBadge extends StatelessWidget {
  const NoteTagBadge({super.key, required this.tag});

  final NoteTag tag;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final color = tag.colorValue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            tag.name,
            style: t.typography.body.xs.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
