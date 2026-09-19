// 阅读设置抽屉（EPUB / TXT 共用）
//
// 覆盖项：主题预设 8 档 / 自定义背景色 / 自定义文字色 / 字号（滑块）/ 行距（滑块）/
//        字体 / 页边距（滑块）/ 段间距（滑块）/ 首行缩进 / 对齐（EPUB + TXT）
//        + 翻页方式 / 阅读方向（仅 EPUB）。
//
// ⚠️ 坑 1：**抽屉内必须用 Consumer 自读 provider**。`showFSheet` 的 builder 属于
//   Navigator 的 overlay 子树，不属于页面 element；若在 builder 里直接用页面 State 的
//   `ref.watch(...)`，依赖会注册到**页面 element** 上 → provider 更新只重建页面，
//   抽屉不重建 → 开关「点了没反应」。详见 `annotation_sheet.dart` 顶部说明。
//
// ⚠️ 坑 2：**chip 选中态只改颜色、不得改尺寸**（全局定案）。字重恒定 w500
//   （w500→w600 会让中文字面度量变大 → 高度跳变）、padding 恒定、不加对勾；
//   描边宽度两侧一致，只换描边色与底色。
//
// ⚠️ 坑 3：本抽屉只写 provider，**不碰阅读器**。样式类变更由阅读页监听
//   `styleFingerprint` 走热更新（updateTheme），结构类变更走重建（见 epub_reader_page）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_surface.dart';
import '../providers/reader_settings.dart';

/// 打开阅读设置抽屉
///
/// - [showStructure]：是否显示「翻页方式 / 阅读方向」（只有 EPUB 支持）
void showReaderSettingsSheet(
  BuildContext context, {
  required bool showStructure,
}) {
  showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightMd,
    resizeToAvoidBottomInset: false,
    builder: (_) => SheetSurface(
      child: SafeArea(
        child: SizedBox(
          // md 档必须定高，否则内容少会 hug 到 ~30%
          height: sheetMaxHeight(context, SheetSize.md),
          child: _ReaderSettingsPanel(showStructure: showStructure),
        ),
      ),
    ),
  );
}

class _ReaderSettingsPanel extends ConsumerWidget {
  const _ReaderSettingsPanel({required this.showStructure});

  final bool showStructure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final s = ref.watch(readerSettingsProvider);
    final n = ref.read(readerSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.pagePadding,
            12,
            AppTokens.pagePadding,
            8,
          ),
          child: Text('阅读设置', style: sheetTitleStyle(context)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.pagePadding,
              4,
              AppTokens.pagePadding,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- 主题 ----
                _label(context, '主题'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final th in ReaderTheme.values)
                        _ThemeCard(
                          theme: th,
                          selected: s.theme == th,
                          onTap: () => n.setTheme(th),
                        ),
                    ],
                  ),
                ),

                // ---- 背景色 ----
                const SizedBox(height: 16),
                _label(context, '背景色'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      _FollowChip(
                        label: '跟随主题',
                        bg: readerBg(s.theme),
                        fg: readerText(s.theme),
                        selected: s.bgColor.isEmpty,
                        onTap: () => n.setBgColor(''),
                      ),
                      for (final hex in kReaderBgPool)
                        _Swatch(
                          color: hexToColor(hex),
                          selected:
                              s.bgColor.toLowerCase() == hex.toLowerCase(),
                          onTap: () => n.setBgColor(hex),
                        ),
                    ],
                  ),
                ),

                // ---- 文字色 ----
                const SizedBox(height: 16),
                _label(context, '文字色'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      _FollowChip(
                        label: '跟随主题',
                        bg: readerBg(s.theme),
                        fg: readerText(s.theme),
                        selected: s.textColor.isEmpty,
                        onTap: () => n.setTextColor(''),
                      ),
                      for (final hex in kReaderTextPool)
                        _Swatch(
                          color: hexToColor(hex),
                          selected:
                              s.textColor.toLowerCase() == hex.toLowerCase(),
                          onTap: () => n.setTextColor(hex),
                        ),
                    ],
                  ),
                ),

                // ---- 字号 / 行距 ----
                const SizedBox(height: 16),
                _SliderRow(
                  label: '字号',
                  realValue: s.fontSize,
                  min: kReaderFontSizeMin,
                  max: kReaderFontSizeMax,
                  displayText: '${s.fontSize.toInt()}',
                  onChanged: n.setFontSize,
                ),
                const SizedBox(height: 14),
                _SliderRow(
                  label: '行距',
                  realValue: s.lineHeight,
                  min: kReaderLineHeightMin,
                  max: kReaderLineHeightMax,
                  displayText: s.lineHeight.toStringAsFixed(1),
                  onChanged: n.setLineHeight,
                ),

                // ---- 字体 ----
                const SizedBox(height: 16),
                _label(context, '字体'),
                const SizedBox(height: 8),
                _chipRow(
                  context,
                  labels: [
                    for (final f in ReaderFont.values) kReaderFontLabels[f]!,
                  ],
                  selected: s.font.index,
                  onSelect: (i) => n.setFont(ReaderFont.values[i]),
                ),

                // ---- 页边距 ----
                const SizedBox(height: 16),
                _SliderRow(
                  label: '页边距',
                  realValue: s.margin,
                  min: kReaderMarginMin,
                  max: kReaderMarginMax,
                  displayText: '${s.margin.round()} px',
                  onChanged: n.setMargin,
                ),

                // ---- 段间距 ----
                const SizedBox(height: 16),
                _SliderRow(
                  label: '段间距',
                  realValue: s.spacing,
                  min: kReaderSpacingMin,
                  max: kReaderSpacingMax,
                  displayText: '${s.spacing.toStringAsFixed(1)} 行',
                  onChanged: n.setSpacing,
                ),

                // ---- 首行缩进 ----
                const SizedBox(height: 16),
                _label(context, '首行缩进'),
                const SizedBox(height: 8),
                _chipRow(
                  context,
                  labels: [
                    for (final v in ReaderIndent.values) kReaderIndentLabels[v]!,
                  ],
                  selected: s.indent.index,
                  onSelect: (i) => n.setIndent(ReaderIndent.values[i]),
                ),

                // ---- 对齐 ----
                const SizedBox(height: 16),
                _label(context, '对齐'),
                const SizedBox(height: 8),
                _chipRow(
                  context,
                  labels: [
                    for (final v in ReaderAlign.values) kReaderAlignLabels[v]!,
                  ],
                  selected: s.align.index,
                  onSelect: (i) => n.setAlign(ReaderAlign.values[i]),
                ),

                if (showStructure) ...[
                  // ---- 翻页方式 ----
                  const SizedBox(height: 16),
                  _label(context, '翻页方式'),
                  const SizedBox(height: 8),
                  _chipRow(
                    context,
                    labels: [
                      for (final v in ReaderFlow.values) kReaderFlowLabels[v]!,
                    ],
                    selected: s.flow.index,
                    onSelect: (i) => n.setFlow(ReaderFlow.values[i]),
                  ),

                  // ---- 阅读方向 ----
                  const SizedBox(height: 16),
                  _label(context, '阅读方向'),
                  const SizedBox(height: 8),
                  _chipRow(
                    context,
                    labels: [
                      for (final v in ReaderDirection.values)
                        kReaderDirectionLabels[v]!,
                    ],
                    selected: s.direction.index,
                    onSelect: (i) => n.setDirection(ReaderDirection.values[i]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '翻页方式 / 阅读方向变更会重新载入当前页，位置自动续接',
                    style: t.typography.body.xs.copyWith(
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],

                // ---- 恢复默认 ----
                const SizedBox(height: 18),
                Center(
                  child: FButton(
                    variant: FButtonVariant.outline,
                    onPress: () => n.reset(),
                    child: const Text('恢复默认'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: context.theme.typography.body.sm.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      );

  Widget _chipRow(
    BuildContext context, {
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onSelect,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            _Chip(
              label: labels[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
        ],
      );
}

/// 滑块行（字号 / 行距 / 页边距 / 段间距）
///
/// ⚠️ forui `FSlider` 的 [FSliderValue] 是**百分比（0~1）**，故本组件以真实数值
///   [realValue] + [min]/[max] 计算百分比，回调 [onChanged] 时再换算回真实数值。
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.realValue,
    required this.min,
    required this.max,
    required this.displayText,
    required this.onChanged,
  });

  final String label;
  final double realValue;
  final double min;
  final double max;
  final String displayText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final span = max - min;
    final pct = span <= 0 ? 0.0 : ((realValue - min) / span).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: t.typography.body.sm),
            const Spacer(),
            Text(
              displayText,
              style: t.typography.body.sm.copyWith(
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FSlider(
          control: FSliderControl.liftedContinuous(
            value: FSliderValue(max: pct),
            onChange: (v) => onChanged(min + v.max * span),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 子组件
// =============================================================================

/// 主题色卡（用真实 bg / fg 预览，所见即所得）
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: readerBg(theme),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          // 选中态只换颜色：描边宽度两侧恒为 1.5，不含尺寸变化
          border: Border.all(
            color: selected ? t.colors.primary : t.colors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          kReaderThemeLabels[theme]!,
          style: TextStyle(
            color: readerText(theme),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 纯色圆角块（背景 / 文字色板）
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(
            color: selected ? t.colors.primary : t.colors.border,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// 「跟随主题」块（用当前预设配色预览）
class _FollowChip extends StatelessWidget {
  const _FollowChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(
            color: selected ? t.colors.primary : t.colors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 文字 chip
///
/// ⚠️ 选中态只改颜色：字重恒定 w500、padding 恒定、不加对勾、描边宽度恒定。
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? t.colors.primary.withValues(alpha: 0.14)
              : t.colors.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(
            color: selected ? t.colors.primary : t.colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: t.typography.body.sm.copyWith(
            color: selected ? t.colors.primary : t.colors.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
