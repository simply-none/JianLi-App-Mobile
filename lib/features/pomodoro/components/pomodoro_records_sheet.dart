// 番茄钟记录抽屉（lg = 80vh 定高）—— 从 pomodoro_page 头部「记录」图标打开。
//
// 排版自上而下：
//   ① 把手 + 标题「番茄钟记录」+ 裸 X
//   ② 统计行（专注 N ｜ 休息 N ｜ 共 M，muted 小字）
//   ③ 可滚动周期列表（每个**完成的阶段**一条：类型 SoftChip + 时间；专注=番茄红 / 休息=绿）
//   ④ 底部固定【导出】按钮 → 导出 .md 到 `Download/渐离App导出/`
//
// 数据源 = `pomodoro_status` 流水（`watchRecords` 实时流；导出走一次性 `loadRecords`）。
// 替代旧的独立记录页（`/pomodoro/records` 死路由已删）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/ui/file_export.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/soft_chip.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/pomodoro_records_repository.dart';
import '../utils/export_pomodoro_markdown.dart';

/// 打开「番茄钟记录」抽屉（lg 80vh 定高，键盘覆盖不折叠 —— 三档制红线 #9）
Future<void> showPomodoroRecordsSheet(BuildContext context) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _PomodoroRecordsSheet(),
  );
}

class _PomodoroRecordsSheet extends ConsumerStatefulWidget {
  const _PomodoroRecordsSheet();

  @override
  ConsumerState<_PomodoroRecordsSheet> createState() =>
      _PomodoroRecordsSheetState();
}

class _PomodoroRecordsSheetState extends ConsumerState<_PomodoroRecordsSheet> {
  bool _exporting = false;

  /// 导出全部流水为 `.md`（一次性取全量，不依赖当前列表窗口）
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final all = await ref.read(appDatabaseProvider).loadRecords();
      if (!mounted) return;
      if (all.isEmpty) {
        showFToast(context: context, title: const Text('暂无记录可导出'));
        return;
      }
      await exportTextToDownloadDir(
        context: context,
        text: buildPomodoroMarkdown(all),
        filename: '番茄钟记录_${_fileStamp()}.md',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static String _fileStamp() {
    final n = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final db = ref.watch(appDatabaseProvider);

    return SheetSurface(
      child: SizedBox(
        height: sheetMaxHeightFull(context, SheetSize.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: SheetHandle(),
            ),
            // ① 标题 + 关闭
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.pagePadding,
                14,
                AppTokens.pagePadding,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('番茄钟记录', style: sheetTitleStyle(context)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        FLucideIcons.x,
                        size: 18,
                        color: t.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ② 统计行 + ③ 列表（共用同一份流水快照）
            Expanded(
              child: StreamBuilder<List<PomodoroStatusData>>(
                stream: db.watchRecords(limit: 500),
                builder: (context, snap) {
                  final records = snap.data ?? const <PomodoroStatusData>[];
                  final work = records.where((r) => r.value == 'work').length;
                  final rest = records.where((r) => r.value == 'rest').length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.pagePadding,
                          10,
                          AppTokens.pagePadding,
                          0,
                        ),
                        child: Text(
                          '专注 $work ｜ 休息 $rest ｜ 共 ${records.length} 条',
                          style: t.typography.body.xs.copyWith(
                            color: t.colors.mutedForeground,
                          ),
                        ),
                      ),
                      Expanded(
                        child: records.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无记录\n完成一个阶段后会自动写入',
                                  textAlign: TextAlign.center,
                                  style: t.typography.body.sm.copyWith(
                                    color: t.colors.mutedForeground,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTokens.pagePadding,
                                  10,
                                  AppTokens.pagePadding,
                                  8,
                                ),
                                itemCount: records.length,
                                itemBuilder: (c, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RecordTile(record: records[i]),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ④ 底部固定导出（永不随内容滚动，§1.8）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.pagePadding,
                8,
                AppTokens.pagePadding,
                16,
              ),
              child: GradientButton(
                label: _exporting ? '导出中…' : '导出',
                icon: FLucideIcons.download,
                onPress: _exporting ? null : _export,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条流水行（待办 tile 同款：r16 卡 + 类型 SoftChip + 时间；work/rest 图标盘语义色）
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final PomodoroStatusData record;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final isWork = record.value == 'work';
    // 类型语义色与番茄钟页同口径：专注=番茄红 / 休息=绿
    final typeColor = isWork
        ? AppTokens.accent(6)
        : record.value == 'rest'
        ? AppTokens.accent(2)
        : t.colors.mutedForeground;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      elevation: 1,
      child: Row(
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(typeColor),
            alignment: Alignment.center,
            child: Icon(
              isWork ? FLucideIcons.briefcase : FLucideIcons.coffee,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: Text(
                        pomodoroRecordLabel(record),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.typography.body.sm.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SoftChip(label: isWork ? '专注' : '休息', color: typeColor),
                  ],
                ),
                if (record.createTime?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.createTime ?? '',
                    style: t.typography.body.xs.copyWith(
                      fontSize: 11,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
