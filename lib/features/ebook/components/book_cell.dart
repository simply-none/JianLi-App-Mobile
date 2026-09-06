// 书架单本书格（原子组件）—— 渐变封面 + 标题 + 进度条
//
// 按标题 hash 取专属强调色（同一本书颜色稳定）；长按删除入口由调用方定义
// （删除确认遵循页面规范：showFDialog 二次确认）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';

/// 书架单本书格
class BookCell extends StatelessWidget {
  const BookCell({
    super.key,
    required this.book,
    required this.onOpen,
    required this.onRemove,
  });

  final EbookBookshelfData book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 按标题取专属强调色（同一本书颜色稳定）
    final idx =
        (book.title ?? book.name ?? '').hashCode.abs() %
        AppTokens.accents.length;
    final accent = AppTokens.accent(idx);
    final percent = (book.percent ?? 0).clamp(0.0, 1.0);
    return FTappable(
      onPress: onOpen,
      onLongPress: onRemove,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTokens.accentGradient(accent),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FLucideIcons.bookOpenText,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    book.title ?? book.name ?? '未命名',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: t.typography.body.sm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已读 ${percent.toStringAsFixed(0)}%',
                    style: t.typography.body.xs.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: percent),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
