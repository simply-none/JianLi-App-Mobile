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
import 'ui_atoms.dart';

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
        final slide = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: AppTokens.standard));
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
    final width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * 0.82),
            child: Container(
              color: t.colors.background,
              child: Column(
                children: [
                  FHeader.nested(
                    title: const Text('设置'),
                    suffixes: [
                      FHeaderAction(
                        icon: Icon(FLucideIcons.x),
                        onPress: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                          onSelect: (i) =>
                              ref.read(themeModeProvider.notifier).set(AppThemeMode.values[i]),
                        ),
                        const SizedBox(height: 26),
                        const _SectionLabel('数据与同步'),
                        AppCard(
                          margin: EdgeInsets.zero,
                          child: FTile(
                            onPress: () {
                              Navigator.of(context).pop();
                              Future.microtask(
                                () => GoRouter.of(originContext).push('/sync'),
                              );
                            },
                            prefix:
                                Icon(FLucideIcons.refreshCw, color: AppTokens.accent(3)),
                            title: const Text('局域网同步'),
                            subtitle: const Text('在受信局域网内与其他设备互传数据'),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const _SectionLabel('关于'),
                        AppCard(
                          margin: EdgeInsets.zero,
                          child: FTile(
                            prefix: Icon(FLucideIcons.info, color: AppTokens.accent(0)),
                            title: const Text('渐离 Jianli'),
                            subtitle: const Text('效率 · 内容 · 工具 一体工作台'),
                          ),
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
      ),
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
                      ? const Icon(FLucideIcons.check, color: Colors.white, size: 22)
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
