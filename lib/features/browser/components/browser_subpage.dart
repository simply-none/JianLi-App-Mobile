// 浏览器子页统一骨架（书签 / 历史 / 设置 / 规则 / 清理 共用）
//
// 仿项目既有全屏页（data_management_page）的头部样式：chevronLeft 22 + 标题 18/w700。
// 抽出来的理由：Phase 2 一次加了 6 个浏览器子页，头部若各写一遍必然漂移。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/tap_scale.dart';

/// 浏览器子页骨架：返回 + 标题（+ 右侧动作）+ 内容
class BrowserSubPage extends StatelessWidget {
  const BrowserSubPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;

  /// 页面主体（一般传 ListView，左右边距请自行用 [EdgeInsets] 处理）
  final Widget child;

  /// 右上角动作按钮（图标按钮，建议 ≤2 个）
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  12,
                  AppTokens.pagePadding,
                  12,
                ),
                child: Row(
                  children: [
                    TapScale(
                      onTap: () => context.pop(),
                      child: Icon(
                        FLucideIcons.chevronLeft,
                        size: 22,
                        color: t.colors.foreground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.typography.body.lg.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: t.colors.foreground,
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头部图标动作按钮（BrowserSubPage.actions 用）
class BrowserHeaderAction extends StatelessWidget {
  const BrowserHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final button = Padding(
      padding: const EdgeInsets.only(left: 14),
      child: TapScale(
        onTap: onTap,
        child: Icon(icon, size: 20, color: t.colors.foreground),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
