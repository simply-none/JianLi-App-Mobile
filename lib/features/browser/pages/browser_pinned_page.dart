// 固定标签页管理页（/browser/pinned）
//
// 对应设计稿「固定标签页」分组：说明 + 8 格管理网格 + 加入按钮。
// 网格直接复用首页的 [BrowserSpeedDial]（同一份实现，改一处两处同步）。
//
// 规则（用户定案）：默认 8 个；加入第 9 个时**替换最早加入的**（复用它的槽位，
// 九宫格里表现为就地替换）；长按可移除 / 替换 / 前移 / 后移。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
// SheetSize（高度三档）定义在 sheet_surface，不在 sheet_form —— 两个都要导
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../components/browser_prompt.dart';
import '../components/browser_site_actions.dart';
import '../components/browser_speed_dial.dart';
import '../components/browser_subpage.dart';
import '../components/settings_tiles.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';

/// 固定标签长按可执行的动作
enum _PinAction { open, rename, replace, moveLeft, moveRight, remove }

class BrowserPinnedPage extends ConsumerStatefulWidget {
  const BrowserPinnedPage({super.key});

  @override
  ConsumerState<BrowserPinnedPage> createState() => _BrowserPinnedPageState();
}

class _BrowserPinnedPageState extends ConsumerState<BrowserPinnedPage> {
  // ————————————————— 动作 —————————————————

  Future<void> _add() async {
    final result = await _showSiteSheet(
      context,
      title: '加入固定标签页',
      confirmLabel: '加入',
    );
    if (result == null || !mounted) return;
    final replaced = await ref
        .read(browserRepositoryProvider)
        .addPinned(title: result.title, url: result.url);
    if (!mounted) return;
    showFToast(
      context: context,
      title: Text(
        replaced == null ? '已加入固定标签页' : '已加入，替换了「$replaced」',
      ),
    );
  }

  Future<void> _replace(BrowserPinnedData site) async {
    final result = await _showSiteSheet(
      context,
      title: '替换固定标签页',
      initialTitle: site.title ?? '',
      initialUrl: site.url ?? '',
      confirmLabel: '替换',
    );
    if (result == null || !mounted) return;
    await ref
        .read(browserRepositoryProvider)
        .replacePinnedSlot(site.key, title: result.title, url: result.url);
  }

  /// 只改名称、不动地址（用户常只想把「zhihu.com」改成「知乎」）
  Future<void> _renameOnly(BrowserPinnedData site) async {
    final name = await showBrowserPrompt(
      context,
      title: '重命名',
      initial: site.title ?? '',
      hint: '站点名称',
      confirmLabel: '保存',
    );
    if (name == null || !mounted) return;
    final url = (site.url ?? '').trim();
    if (url.isEmpty) return;
    await ref
        .read(browserRepositoryProvider)
        .replacePinnedSlot(site.key, title: name, url: url);
  }

  Future<void> _menu(BrowserPinnedData site) async {
    final action = await showSheetActionMenu<_PinAction>(
      context,
      title: site.title ?? site.url ?? '',
      actions: const [
        SheetAction(_PinAction.open, '打开', icon: FLucideIcons.externalLink),
        SheetAction(_PinAction.rename, '重命名', icon: FLucideIcons.pencil),
        SheetAction(_PinAction.replace, '替换地址', icon: FLucideIcons.link),
        SheetAction(_PinAction.moveLeft, '前移一位', icon: FLucideIcons.chevronLeft),
        SheetAction(
          _PinAction.moveRight,
          '后移一位',
          icon: FLucideIcons.chevronRight,
        ),
        SheetAction(
          _PinAction.remove,
          '移除',
          icon: FLucideIcons.pinOff,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    final repo = ref.read(browserRepositoryProvider);
    switch (action) {
      case _PinAction.open:
        final url = (site.url ?? '').trim();
        if (url.isEmpty) return;
        requestBrowserNavigation(ref, url);
        context.pop();
      case _PinAction.rename:
        await _renameOnly(site);
      case _PinAction.replace:
        await _replace(site);
      case _PinAction.moveLeft:
        await repo.swapPinnedSlot(site.key, -1);
      case _PinAction.moveRight:
        await repo.swapPinnedSlot(site.key, 1);
      case _PinAction.remove:
        await repo.removePinned(site.key);
    }
  }

  // ————————————————— UI —————————————————

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final sites =
        ref.watch(pinnedSitesProvider).value ?? const <BrowserPinnedData>[];
    return BrowserSubPage(
      title: '固定标签页',
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  FLucideIcons.info,
                  size: 16,
                  color: t.colors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '默认 8 个。加入第 9 个时，会替换最早加入的一个（就地替换）。'
                    '长按格子可移除、替换地址或调整顺序；书签与历史记录长按也能加入。',
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      height: 1.6,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BrowserSectionTitle(
            '固定标签页',
            trailing: Text(
              '${sites.length} / $kPinnedMaxSlots',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: BrowserSpeedDial(
              sites: sites,
              onOpen: (site) {
                final url = (site.url ?? '').trim();
                if (url.isEmpty) return;
                requestBrowserNavigation(ref, url);
                context.pop();
              },
              onLongPressSite: _menu,
              onAdd: _add,
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: '加入固定标签页',
            icon: FLucideIcons.plus,
            onPress: _add,
          ),
        ],
      ),
    );
  }
}

/// 「名称 + 地址」双字段抽屉（加入 / 替换共用）。
///
/// 单字段的 [showBrowserPrompt] 不够用：固定标签需要**同时**有站点名和地址，
/// 分两次弹窗体验很差（用户要来回确认两遍）。
Future<({String title, String url})?> _showSiteSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialTitle = '',
  String initialUrl = '',
}) {
  return showFSheet<({String title, String url})>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    // 本抽屉含两个输入框（名称 / 网址）→ 必须 true：让 SheetScaffold 的 sheetMaxHeight
    // 扣掉键盘高、把 md(50%) 抽屉抬到键盘上方，否则底部「网址」输入框被键盘盖住
    // （与 browser_prompt 同一类修复；lg 详情/长表单档才用 false）
    resizeToAvoidBottomInset: true,
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.md,
      body: _SiteForm(
        initialTitle: initialTitle,
        initialUrl: initialUrl,
        confirmLabel: confirmLabel,
      ),
    ),
  );
}

class _SiteForm extends StatefulWidget {
  const _SiteForm({
    required this.initialTitle,
    required this.initialUrl,
    required this.confirmLabel,
  });

  final String initialTitle;
  final String initialUrl;
  final String confirmLabel;

  @override
  State<_SiteForm> createState() => _SiteFormState();
}

class _SiteFormState extends State<_SiteForm> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialTitle,
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _url.text.trim();
    if (raw.isEmpty) return;
    final url = normalizeUrl(raw);
    final name = _title.text.trim();
    Navigator.pop(context, (
      title: name.isEmpty ? hostOf(url) : name,
      url: url,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetFieldLabel('名称'),
        SheetInputBox(controller: _title, hintText: '例如：知乎（留空则用域名）'),
        const SizedBox(height: 16),
        const SheetFieldLabel('网址'),
        SheetInputBox(
          controller: _url,
          hintText: '例如：zhihu.com',
          keyboardType: TextInputType.url,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 18),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.outline,
                onPress: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            Expanded(
              child: GradientButton(
                label: widget.confirmLabel,
                onPress: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
