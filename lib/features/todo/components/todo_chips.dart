// 待办状态 / 标签 chip —— 列表卡片与卡片网格共用同一套渲染，
// 避免两侧各写一份后口径漂移（画布「07 待办·列表」与「卡片视图」字段必须一致）。
//
// 配色口径（与画布一致，主题自适应、不硬编码中性色）：
//   状态 chip  色底 15% · r10 · 内边距 4 · 11/SemiBold
//   标签 chip  各自色底 14% · r10 · 内边距 4 · 11/SemiBold
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// 状态 chip（未开始/进行中/阻塞/已完成/已取消/重新开始）
class TodoStatusChip extends StatelessWidget {
  const TodoStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: context.theme.typography.body.xs.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
}

/// 标签 chip（带标签名，配色走标签自身颜色）
class TodoTagChip extends StatelessWidget {
  const TodoTagChip({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          name,
          style: context.theme.typography.body.xs.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
}

/// 标签 hex → Color（缺省/异常回退紫色）
Color parseTodoTagColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF8b5cf6);
  try {
    return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) |
        (hex.length == 7 ? 0xFF000000 : 0));
  } catch (_) {
    return const Color(0xFF8b5cf6);
  }
}
