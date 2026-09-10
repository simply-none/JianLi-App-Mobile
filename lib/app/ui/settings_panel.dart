// 设置面板（左侧滑出弹窗）—— 2026-09 新增
//
// 首页/分组页右上角放齿轮按钮（SettingsButton）打开此面板；面板从左侧滑入，
// 含：外观（5 套主题样式色板 + 浅/暗/跟随系统分段）、数据与同步入口、关于。
// 主题选择实时作用：themeStyleProvider / themeModeProvider 由 app.dart 读取并重渲全树。
// 实现：自定义 PageRouteBuilder（opaque:false + 左侧 SlideTransition），不依赖 forui 弹层，
// 规避与 material_ui 平行 Material 类的潜在冲突。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../providers/theme_providers.dart';
import '../theme/app_theme.dart';
import 'segmented.dart';
import 'squircle_box.dart';

/// 齿轮设置按钮（首页 / 三个分组页 右上角复用）
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.size = 44, this.radius = 14});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SquircleBox(
      size: size,
      radius: radius,
      color: t.colors.mutedForeground.withValues(alpha: 0.12),
      alignment: Alignment.center,
      onTap: () => showSettingsPanel(context),
      haptic: HapticType.light,
      child: Icon(FLucideIcons.settings, color: t.colors.foreground, size: 20),
    );
  }
}

/// 打开左侧设置面板
void showSettingsPanel(BuildContext context) {
  final origin = context;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: AppTokens.base,
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          _SettingsPanel(originContext: origin),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final slide =
            Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: AppTokens.standard),
            );
        return SlideTransition(position: slide, child: child);
      },
    ),
  );
}

/// 设置面板内容（左侧滑入）
class _SettingsPanel extends ConsumerWidget {
  const _SettingsPanel({required this.originContext});

  final BuildContext originContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final styleId = ref.watch(themeStyleProvider).value ?? 'zi';
    final mode = ref.watch(themeModeProvider).value ?? AppThemeMode.system;
    final modeIndex = AppThemeMode.values.indexOf(mode);
    final readingMode =
        ref.watch(readingModeProvider).value ?? ReadingMode.normal;
    final width = MediaQuery.of(context).size.width;

    // 面板铺满全屏高度：背景 Container 直接顶到状态栏与底部。
    // FHeader.nested 自身已含 SafeArea(top)（状态栏安全区），故无需再额外包状态栏高度；
    // 其内部顶部 8px 内边距也已在下方 header 的 style 里归零，标题正好落在状态栏高度处。
    // 列表底部补 Home 指示条安全区（见下方 ListView padding）。
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * 0.82),
          child: Container(
            color: t.colors.background,
            child: Column(
              children: [
                FHeader.nested(
                  title: const Text('设置'),
                  // FHeader.nested 自带 SafeArea(top)；归零其内部顶部内边距，标题正好贴状态栏。
                  style: FHeaderStyleDelta.delta(
                    padding: EdgeInsetsGeometryDelta.value(
                      const EdgeInsets.only(left: AppTokens.pagePadding, right: AppTokens.pagePadding, bottom: 10),
                    ),
                  ),
                  suffixes: [
                    FHeaderAction(
                      icon: Icon(FLucideIcons.x),
                      onPress: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      8,
                      AppTokens.pagePadding,
                      24 + bottomPad,
                    ),
                    children: [
                      const _SectionLabel('外观'),
                      _ThemeStyleRow(
                        selectedId: styleId,
                        onPick: (id) {
                          ref.read(themeStyleProvider.notifier).set(id);
                          haptic(HapticType.light, context);
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('主题模式'),
                      JianliSegmented(
                        items: const [
                          (FLucideIcons.monitor, '系统'),
                          (FLucideIcons.sun, '浅色'),
                          (FLucideIcons.moon, '深色'),
                        ],
                        selected: modeIndex,
                        onSelect: (i) => ref
                            .read(themeModeProvider.notifier)
                            .set(AppThemeMode.values[i]),
                      ),
                      const SizedBox(height: 26),
                      // 阅览模式：正文字号档位（普通/大号），卡片 tag 点击切换
                      const _SectionLabel('阅览模式'),
                      _ReadingModeRow(
                        mode: readingMode,
                        onPick: (m) {
                          ref.read(readingModeProvider.notifier).set(m);
                          haptic(HapticType.light, context);
                        },
                      ),
                      const SizedBox(height: 26),
                      const _SectionLabel('数据与同步'),
                      FTileGroup(
                        divider: FItemDivider.none,
                        children: [
                          FTile(
                            onPress: () {
                              Navigator.of(context).pop();
                              // 面板已 pop，跨异步使用 originContext 前先查 mounted
                              Future.microtask(() {
                                if (!originContext.mounted) return;
                                GoRouter.of(originContext).push('/sync');
                              });
                            },
                            prefix: Icon(
                              FLucideIcons.refreshCw,
                              color: AppTokens.accent(3),
                            ),
                            title: const Text('局域网同步'),
                            subtitle: const Text('在受信局域网内与其他设备互传数据'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const _SectionLabel('关于'),
                      FTileGroup(
                        divider: FItemDivider.none,
                        children: [
                          FTile(
                            prefix: Icon(
                              FLucideIcons.info,
                              color: AppTokens.accent(0),
                            ),
                            title: const Text('渐离App'),
                            subtitle: const Text('效率 · 内容 · 工具 一体工作台'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
          ),
        ),
      ],
    );
  }
}

/// 分区小标题
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: t.typography.body.sm.copyWith(
          color: t.colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 阅览模式卡片选择（普通字体 / 大号字体）——卡片 tag 式点击切换
class _ReadingModeRow extends StatelessWidget {
  const _ReadingModeRow({required this.mode, required this.onPick});

  final ReadingMode mode;
  final ValueChanged<ReadingMode> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, m) in ReadingMode.values.indexed) ...[
          Expanded(
            child: _ModeCard(
              // 图标名必须先在 forui_lucide assets.g.dart 里验证（alphabet 不存在，实踩）
              icon: m == ReadingMode.large
                  ? FLucideIcons.aLargeSmall
                  : FLucideIcons.type,
              label: m == ReadingMode.large ? '大号字体' : '普通字体',
              subtitle:
                  '基准 ${(m == ReadingMode.large ? AppTokens.baseFontSizeLarge : AppTokens.baseFontSizeNormal).toStringAsFixed(0)}px',
              selected: mode == m,
              onTap: () => onPick(m),
            ),
          ),
          if (i < ReadingMode.values.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// 单张模式卡片（选中 = 主色软底 + 主色描边）
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final color = selected ? t.colors.primary : t.colors.mutedForeground;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTokens.fast,
        curve: AppTokens.standard,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.accentSoft(context, t.colors.primary)
              : t.colors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected ? t.colors.primary : t.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: t.typography.body.sm.copyWith(
                color: selected ? t.colors.primary : t.colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: t.typography.body.xs.copyWith(
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5 套主题样式色板
class _ThemeStyleRow extends StatelessWidget {
  const _ThemeStyleRow({required this.selectedId, required this.onPick});

  final String selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: [
        for (final s in AppTheme.styles)
          GestureDetector(
            onTap: () => onPick(s.id),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s.lightPrimary,
                    shape: BoxShape.circle,
                    border: s.id == selectedId
                        ? Border.all(color: t.colors.foreground, width: 3)
                        : null,
                    boxShadow: s.id == selectedId
                        ? AppTokens.elevation(context, level: 2)
                        : null,
                  ),
                  child: s.id == selectedId
                      ? const Icon(
                          FLucideIcons.check,
                          color: Colors.white,
                          size: 22,
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Text(s.name, style: t.typography.body.xs),
              ],
            ),
          ),
      ],
    );
  }
}
