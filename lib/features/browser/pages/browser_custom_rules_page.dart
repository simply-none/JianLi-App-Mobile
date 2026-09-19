// 自定义拦截规则页（/browser/rules/custom）—— 广告拦截三级之三
//
// 用户手写的 Adblock 语法行，逐条生效（解析规则见 services/adblock_rules.dart 文件头）。
// 这里只做「增 / 删 / 看」，不做语法校验器的花活 —— 无效行会被解析器静默丢弃，
// 页面上用「当前生效条数」给出反馈即可。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/ui_atoms.dart';
import '../components/browser_prompt.dart';
import '../components/browser_site_actions.dart';
import '../components/browser_subpage.dart';
import '../components/settings_tiles.dart';
import '../models/browser_settings.dart';
import '../providers/browser_providers.dart';

/// 规则条目长按动作
enum _RuleAction { copy, remove }

/// 语法速查（页面顶部展示）
const String _syntaxHelp =
    '||example.com^   命中该域及其所有子域\n'
    '|https://a.com/x  命中以该串开头的地址\n'
    '/banner/ad/        命中地址里包含该串的请求\n'
    '@@||example.com^   例外：该域一律放行（优先级最高）\n'
    '! 开头             注释，不生效';

class BrowserCustomRulesPage extends ConsumerStatefulWidget {
  const BrowserCustomRulesPage({super.key});

  @override
  ConsumerState<BrowserCustomRulesPage> createState() =>
      _BrowserCustomRulesPageState();
}

class _BrowserCustomRulesPageState
    extends ConsumerState<BrowserCustomRulesPage> {
  List<String> get _rules =>
      (ref.read(browserSettingsProvider).value ?? const BrowserSettings())
          .customRules;

  Future<void> _save(List<String> next) async {
    final s =
        ref.read(browserSettingsProvider).value ?? const BrowserSettings();
    await ref
        .read(browserSettingsProvider.notifier)
        .save(s.copyWith(customRules: next));
  }

  Future<void> _add() async {
    final input = await showBrowserPrompt(
      context,
      title: '添加拦截规则',
      hint: '||ads.example.com^',
      confirmLabel: '添加',
      helper: '一行一条。支持 ||域^ / |前缀 / 子串 / @@例外 / !注释。',
    );
    if (input == null || !mounted) return;
    final rule = input.trim();
    final rules = _rules;
    if (rules.contains(rule)) {
      showFToast(context: context, title: const Text('该规则已存在'));
      return;
    }
    await _save([...rules, rule]);
    if (!mounted) return;
    showFToast(context: context, title: const Text('已添加规则'));
  }

  Future<void> _remove(String rule) async {
    await _save(_rules.where((e) => e != rule).toList());
    if (!mounted) return;
    showFToast(context: context, title: const Text('已删除规则'));
  }

  Future<void> _menu(String rule) async {
    final action = await showSheetActionMenu<_RuleAction>(
      context,
      title: rule,
      actions: const [
        SheetAction(_RuleAction.copy, '复制规则', icon: FLucideIcons.link),
        SheetAction(
          _RuleAction.remove,
          '删除',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _RuleAction.copy:
        await copyLink(context, rule);
      case _RuleAction.remove:
        await _remove(rule);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final rules = ref.watch(browserSettingsProvider).value?.customRules ??
        const <String>[];
    final engine = ref.watch(adBlockEngineProvider);
    return BrowserSubPage(
      title: '自定义拦截规则',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          4,
          AppTokens.pagePadding,
          AppTokens.pageBottomGapOf(context),
        ),
        children: [
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  '当前生效 ${engine.ruleCount} 条规则（含内置与订阅）',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                ),
                SelectableText(
                  _syntaxHelp,
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    height: 1.8,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsGroupLabel('我的规则（${rules.length} 条）'),
          if (rules.isEmpty)
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(14),
              child: Text(
                '还没有自定义规则。内置规则集会兜住常见广告，这里用于补漏：'
                '遇到漏拦的站点，加一条 ||它的广告域名^ 即可。',
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  height: 1.6,
                  color: t.colors.mutedForeground,
                ),
              ),
            )
          else
            for (final rule in rules)
              AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                onLongPress: () => _menu(rule),
                child: Row(
                  children: [
                    Icon(
                      FLucideIcons.ban,
                      size: 16,
                      color: t.colors.mutedForeground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rule,
                        style: t.typography.body.xs.copyWith(
                          fontSize: 13,
                          height: 1.5,
                          color: t.colors.foreground,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _remove(rule),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          FLucideIcons.trash2,
                          size: 16,
                          color: t.colors.destructive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          GradientButton(
            label: '添加规则',
            icon: FLucideIcons.plus,
            onPress: _add,
          ),
        ],
      ),
    );
  }
}
