// 习惯导出抽屉（lg = 80vh 定高）—— 排版自上而下：
//   ① 标题 + 关闭
//   ② 搜索栏（**此处无高级搜索** → 不渲染筛选按钮）
//   ③ 可勾选的滚动列表（每条习惯：勾选圆点 + 名称 + 频次/生效/提醒）
//   ④ 底部固定三个按钮【导出选中】【导出筛选】【导出所有】
//
// 导出为 .md（正文见 utils/export_habits_markdown.dart）；直接落盘 `Download/渐离App导出/`
// （未授权回退沙盒）+ 顶部提示（见 app/ui/file_export.dart）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/file_export.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/pinned_search_row.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../models/habit.dart';
import '../providers/habit_providers.dart';
import '../utils/export_habits_markdown.dart';

/// 打开「导出习惯」抽屉（lg 80vh 定高、键盘覆盖不折叠 —— 三档制红线 #9）
Future<void> showHabitExportSheet(BuildContext context) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _HabitExportSheet(),
  );
}

class _HabitExportSheet extends ConsumerStatefulWidget {
  const _HabitExportSheet();

  @override
  ConsumerState<_HabitExportSheet> createState() => _HabitExportSheetState();
}

class _HabitExportSheetState extends ConsumerState<_HabitExportSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  /// 已勾选的习惯 key
  final Set<String> _selectedKeys = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 关键词过滤：名称 / 频次 / 提醒时间（习惯无分类标签，仅关键词匹配）
  List<HabitItem> _filtered(List<HabitItem> habits) {
    final kw = _keyword.trim().toLowerCase();
    if (kw.isEmpty) return habits;
    return habits.where((h) {
      final hay = '${h.name} ${h.freqLabel} ${h.reminderTimes.join(' ')}'
          .toLowerCase();
      return hay.contains(kw);
    }).toList();
  }

  /// 导出：`selectedOnly` ? 勾选项 : [pool] 全部（[pool] = 筛选结果或全部习惯）
  Future<void> _export(
    List<HabitItem> pool, {
    required bool selectedOnly,
  }) async {
    final chosen = selectedOnly
        ? [for (final h in pool) if (_selectedKeys.contains(h.key)) h]
        : pool;
    if (chosen.isEmpty) {
      showFToast(context: context, title: const Text('没有可导出的习惯'));
      return;
    }
    // 一次性取全量打卡记录并按 habitKey 分组（导出时才查，避免常驻监听）
    final all = await ref.read(habitRepositoryProvider).loadAllCheckins();
    final byKey = <String, List<HabitCheckinData>>{};
    for (final r in all) {
      byKey.putIfAbsent(r.habitKey ?? '', () => []).add(r);
    }
    final md = buildHabitsMarkdown(chosen, byKey);
    if (!mounted) return;
    await exportTextToDownloadDir(
      context: context,
      text: md,
      filename: '习惯打卡导出_${_fileStamp()}.md',
    );
    if (mounted) Navigator.pop(context);
  }

  static String _fileStamp() {
    final n = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitListProvider).value ?? const <HabitItem>[];
    final filtered = _filtered(habits);
    final t = context.theme;

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
            // ① 标题 + 关闭（17/Bold + 裸 X）
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
                    child: Text('导出习惯', style: sheetTitleStyle(context)),
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
            // ② 搜索栏（无高级搜索 → onFilter 不传，右侧筛选按钮整钮不渲染）
            PinnedSearchRow(
              controller: _searchController,
              hintText: '搜索要导出的习惯…',
              onChanged: (v) => setState(() => _keyword = v),
            ),
            // ③ 可勾选的滚动列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        habits.isEmpty ? '暂无启用的习惯' : '没有匹配的习惯',
                        style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        4,
                        AppTokens.pagePadding,
                        8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final h = filtered[i];
                        return _HabitExportRow(
                          habit: h,
                          selected: _selectedKeys.contains(h.key),
                          onTap: () => setState(() {
                            _selectedKeys.contains(h.key)
                                ? _selectedKeys.remove(h.key)
                                : _selectedKeys.add(h.key);
                          }),
                        );
                      },
                    ),
            ),
            // ④ 底部固定：导出选中 / 导出筛选 / 导出所有（三键一行）
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.pagePadding,
                8,
                AppTokens.pagePadding,
                16,
              ),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: GradientButton(
                      label: '导出选中',
                      onPress: () => _export(filtered, selectedOnly: true),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => _export(filtered, selectedOnly: false),
                      child: const Text('导出筛选'),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => _export(habits, selectedOnly: false),
                      child: const Text('导出所有'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条习惯勾选行（勾选圆点 + 名称 + 频次/生效/提醒）
class _HabitExportRow extends StatelessWidget {
  const _HabitExportRow({
    required this.habit,
    required this.selected,
    required this.onTap,
  });

  final HabitItem habit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final meta = [
      habit.freqLabel,
      habitWeekLabel(habit.weekDays),
      if (habit.reminderTimes.isNotEmpty) habit.reminderTimes.join('、'),
    ].join(' ｜ ');

    return FTappable(
      onPress: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.accentSoft(context, AppTokens.accent(2))
              : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected
                ? AppTokens.accent(2).withValues(alpha: 0.4)
                : t.colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTokens.accent(2) : t.colors.background,
                border: Border.all(
                  color: selected
                      ? AppTokens.accent(2)
                      : t.colors.mutedForeground,
                ),
              ),
              child: selected
                  ? const Icon(FLucideIcons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: t.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: t.colors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
