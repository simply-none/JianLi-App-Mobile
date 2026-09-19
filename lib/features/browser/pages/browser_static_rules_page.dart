// 内置静态规则集页（/browser/rules/static）—— 广告拦截三级之一
//
// 只读展示 + 一个开关。规则集本身是**打包进 App 的常量**（services/adblock_rules.dart），
// 页面不做任何编辑 —— 想加规则请用「自定义拦截规则」，想扩量请用「订阅规则」。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/ui_atoms.dart';
import '../components/browser_subpage.dart';
import '../components/settings_tiles.dart';
import '../models/browser_settings.dart';
import '../providers/browser_providers.dart';
import '../services/adblock_rules.dart';

class BrowserStaticRulesPage extends ConsumerWidget {
  const BrowserStaticRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    final s =
        ref.watch(browserSettingsProvider).value ?? const BrowserSettings();
    final total = kStaticBlockedHosts.length + kStaticBlockedPatterns.length;
    return BrowserSubPage(
      title: '内置静态规则集',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          4,
          AppTokens.pagePadding,
          AppTokens.pageBottomGapOf(context),
        ),
        children: [
          SettingsSection(
            title: '状态',
            children: [
              SettingsSwitchRow(
                label: '启用内置规则集',
                hint: '随 App 一起打包，离线可用；关闭后订阅与自定义规则不受影响',
                value: s.staticRulesEnabled,
                onChange: (v) => ref
                    .read(browserSettingsProvider.notifier)
                    .save(s.copyWith(staticRulesEnabled: v)),
              ),
              SettingsHintRow(
                '当前共 $total 条：域锚定 ${kStaticBlockedHosts.length} 条 · '
                '路径 ${kStaticBlockedPatterns.length} 条。',
                icon: FLucideIcons.info,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SettingsGroupLabel('规则内容（只读）'),
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              [
                for (final h in kStaticBlockedHosts) '||$h^',
                for (final p in kStaticBlockedPatterns) p,
              ].join('\n'),
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.7,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: Text(
              '这是种子集：覆盖中英文常见的广告 / 统计 / 追踪域，体积小、命中快。'
              '完整 EasyList（数万条）体积过大不适合硬编码，请到「订阅规则」里订阅，'
              '两条路径会合并生效。',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                height: 1.6,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
