// 同步日志列表（原子组件）—— 定高上限 + 独立滚动
//
// 背景（2026-09-07）：原先日志是页面 ListView 里的裸 Column，且硬编码 `.take(10)`，
// 条目一多只能整页拖动、超出可视区后很难回溯。现改为「受限高度 + 内层滚动」，
// 与 PC 端 `SyncLog.vue` 的 `max-height: 260px; overflow: auto` 体验对齐；
// 条数上限交由 `SyncLogController`（50 条）控制，UI 层不再截断。
//
// 只负责展示，不含任何业务逻辑；日志内容由 `syncLogProvider` 提供。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/sync/sync_log.dart';

/// 同步日志列表（新 → 旧；超过可视高度后内部滚动）
class SyncLogList extends StatelessWidget {
  const SyncLogList({super.key, required this.logs});

  final List<SyncLogEntry> logs;

  /// 可视区最大高度（对齐 PC 端 SyncLog.vue 的 260px）
  static const double maxHeight = 260;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '暂无同步记录',
          style: t.typography.body.xs.copyWith(
            color: t.colors.mutedForeground,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        // shrinkWrap + maxHeight：条目少时贴合内容，超出后滚动（等价 CSS max-height + overflow auto）
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          final item = logs[i];
          final color = switch (item.level) {
            SyncLogLevel.ok => t.colors.primary,
            SyncLogLevel.error => t.colors.destructive,
            SyncLogLevel.info => t.colors.foreground,
          };
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.time,
                style: t.typography.body.xs.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.msg,
                  style: t.typography.body.xs.copyWith(color: color),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
