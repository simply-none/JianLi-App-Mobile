// 功能页渐变横幅（PageBanner）—— 首页英雄卡同款视觉语言的子页落地
//
// 页面专属强调色渐变底 + 白色装饰圆 + 半透明图标盘 + 白字标题/统计，
// 取代各功能页「一上来就是白卡列表」的平淡开头；每个功能域一个专属色，
// 与 Hub 分组页入口色对齐（见 hub_pages.dart 的 accentIndex）。
// 取色：渐变走 AppTokens.accentGradient；渐变上的前景固定白色系（装饰色，
// 非主题语义色）；其余排版走 forui token。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'animated_stat.dart';
import 'squircle_box.dart';

/// 功能页渐变横幅：图标 + 标题 + 副标题 + 可选统计行
class PageBanner extends StatelessWidget {
  const PageBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accentIndex = 0,
    this.stats = const [],
    this.margin,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// 页面专属强调色索引（AppTokens.accents，与 Hub 入口色对齐）
  final int accentIndex;

  /// 统计行：(数值, 标签)；纯数值自动数字滚动（AnimatedStat）
  final List<(String, String)> stats;

  /// 外边距（null = 默认：水平随字号缩放的 pagePadding + 上下 12/4）
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(accentIndex);
    return Padding(
      padding:
          margin ??
          EdgeInsets.fromLTRB(
            AppTokens.pagePadding,
            12,
            AppTokens.pagePadding,
            4,
          ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTokens.accentGradient(accent),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          boxShadow: AppTokens.elevation(context, level: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: Stack(
            children: [
              Positioned(right: -28, top: -28, child: _decoCircle(96, 0.12)),
              Positioned(right: 44, bottom: -34, child: _decoCircle(76, 0.10)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // 半透明白图标盘（渐变底上的层次件，与首页英雄卡同语言）
                        SquircleBox(
                          size: 44,
                          radius: 14,
                          color: Colors.white.withValues(alpha: 0.22),
                          alignment: Alignment.center,
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: t.typography.body.lg.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: t.typography.body.sm.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
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
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _stat(context, stats[i].$1, stats[i].$2),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 白色装饰圆（渐变底上的氛围件）
  Widget _decoCircle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  /// 单个统计（居中，同首页英雄卡）；纯数值走数字滚动
  Widget _stat(BuildContext context, String value, String label) {
    final t = context.theme;
    final valueStyle = t.typography.body.lg.copyWith(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    final numeric = double.tryParse(value) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (numeric)
          AnimatedStat(value: double.parse(value), style: valueStyle)
        else
          Text(value, style: valueStyle),
        const SizedBox(height: 2),
        Text(
          label,
          style: t.typography.body.xs.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
