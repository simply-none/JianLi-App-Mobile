// 浏览器标识（UA）选择弹窗
//
// 菜单「浏览器标识」项复用：列出预设（默认/Chrome/Edge/iPhone/Mac）+ 自定义。
// 选自定义时再弹一个输入框填 UA 串。改动走 [browserSettingsProvider]，WebView 的
// UA 热更 + 重载由主壳的 `ref.listen` 统一处理（见 browser_page.dart）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../models/browser_settings.dart';
import '../providers/browser_providers.dart';

/// 打开浏览器标识选择弹窗（可嵌套在菜单抽屉之上）
Future<void> showBrowserUaSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(browserSettingsProvider).value?.uaPreset ??
      BrowserUaPreset.mobile;
  final picked = await showSheetActionMenu<BrowserUaPreset>(
    context,
    title: '浏览器标识',
    size: SheetSize.sm,
    actions: [
      for (final p in BrowserUaPreset.values)
        SheetAction(
          p,
          p.label,
          icon: p == BrowserUaPreset.mobile
              ? FLucideIcons.globe
              : p == BrowserUaPreset.custom
                  ? FLucideIcons.pencil
                  : FLucideIcons.monitor,
        ),
    ],
  );
  if (picked == null) return;
  if (picked == BrowserUaPreset.custom) {
    final ua = await _promptCustomUa(context, ref);
    if (ua == null) return;
    await ref.read(browserSettingsProvider.notifier).save(
      ref.read(browserSettingsProvider).value?.copyWith(
            uaPreset: BrowserUaPreset.custom,
            customUa: ua,
          ) ??
          const BrowserSettings(),
    );
    return;
  }
  final s = ref.read(browserSettingsProvider).value ?? const BrowserSettings();
  await ref.read(browserSettingsProvider.notifier).save(
    s.copyWith(uaPreset: picked),
  );
  // custom 切回预设时清掉残留的自定义 UA，避免下次选 custom 拿到旧值
  if (current == BrowserUaPreset.custom && picked != BrowserUaPreset.custom) {
    await ref.read(browserSettingsProvider.notifier).save(
      s.copyWith(customUa: ''),
    );
  }
}

/// 自定义 UA 文本输入弹窗（md 档，带输入框）
Future<String?> _promptCustomUa(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(
    text: ref.read(browserSettingsProvider).value?.customUa ?? '',
  );
  final t = context.theme;
  final result = await showFSheet<String?>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightMd,
    builder: (c) => SheetScaffold(
      title: '自定义 UA',
      size: SheetSize.md,
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration.collapsed(
              hintText: '粘贴 User-Agent 串',
              hintStyle: t.typography.body.sm.copyWith(
                fontSize: 14,
                color: t.colors.mutedForeground,
              ),
            ),
            style: t.typography.body.sm.copyWith(fontSize: 14),
          ),
        ),
      ),
      bottomBar: sheetBottomActions(
        c,
        actionLabel: '保存',
        onAction: () => Navigator.pop(c, controller.text.trim()),
      ),
    ),
  );
  controller.dispose();
  return result;
}
