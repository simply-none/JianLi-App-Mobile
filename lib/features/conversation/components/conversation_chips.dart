// 主题对话 —— 共享展示原子（列表页 / 消息页 / 富文本编辑页三处共用）
//
// 抽出来的理由：`ConvTagBadge` 要在「消息气泡」「发送草稿行」「富文本编辑页草稿行」三处
// 保持完全一致；`ConvRefDraftChip` 同理（快速输入栏与富文本编辑页的引用草稿都要）。
// 各自内联一份的话，色值/内边距/圆角任一处调整就会漂移。
import 'package:forui/forui.dart' hide Delta;
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';

/// conversation_tag.color（'#RRGGBB'）→ Color（解析失败回落默认靛紫，与桌面端 TAG_COLORS 首色一致）
Color parseConvTagColor(ConversationTagData tag) {
  return parseConvHexColor(tag.color);
}

/// '#RRGGBB' → Color（解析失败回落默认靛紫）。抽成独立函数供无 tag 实例的场景复用。
Color parseConvHexColor(String? raw) {
  final hex = (raw ?? '').replaceFirst('#', '');
  final v = int.tryParse(hex, radix: 16);
  return v == null ? const Color(0xFF6366F1) : Color(0xFF000000 | v);
}

/// 主题/对话标签彩色徽标（标签色圆点 + 名称）
class ConvTagBadge extends StatelessWidget {
  const ConvTagBadge({super.key, required this.tag, this.radius = 999});

  final ConversationTagData tag;

  /// 圆角（默认胶囊 999；主题列表卡内用 10 对齐 SoftChip 口径）
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final color = parseConvTagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
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
            tag.name ?? '',
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

/// 引用草稿 chip（摘要 + 可点掉）：发送前在输入区/编辑页展示「本次会带上哪些引用」。
///
/// ⚠️ 刻意不做「只读 + 另行 × 图标」的复杂拆解：整块可点即移除，与标签草稿一致口径。
class ConvRefDraftChip extends StatelessWidget {
  const ConvRefDraftChip({
    super.key,
    required this.label,
    required this.onDelete,
  });

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(4);
    return GestureDetector(
      onTap: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTokens.accentSoft(context, accent),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.link, size: 11, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: t.typography.body.xs.copyWith(color: accent),
            ),
            const SizedBox(width: 3),
            Icon(FLucideIcons.x, size: 11, color: accent),
          ],
        ),
      ),
    );
  }
}
