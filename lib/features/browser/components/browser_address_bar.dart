// 浏览器顶部地址栏（常态 / 输入态两态）
//
// 两态规格对齐画布「1·地址栏输入态」：
//   常态   = 卡片底 + 发丝线描边 + r22 + h44，左侧锁/地球图标 + 当前域名，
//            下方 2px 加载进度条（progress 在 0~1 之间才出现）。
//   输入态 = **淡紫底 `#FAF9FF` + 1px `#DED7FB` 描边**（用底色表达激活，不用粗边框）
//            + 淡紫 18px 放大镜 + 14px 文字 + 紫色光标 + 清空 ✕ + 行尾独立「取消」。
//
// 状态（editing / controller / focusNode）由页面持有：地址栏是纯展示组件，
// 这样「首页搜索栏点击 → 地址栏进入输入态」只需页面改一个 flag。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../models/browser_models.dart';

class BrowserAddressBar extends StatelessWidget {
  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.editing,
    required this.url,
    required this.progress,
    required this.onSubmit,
    required this.onCancel,
    this.onClear,
    this.onActivate,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// true = 用户在输入（药丸变淡紫底 + 显示取消）
  final bool editing;

  /// 当前页面地址（空 = 新标签页）
  final String url;

  /// 加载进度 0~1（1 = 完成，不显示进度条）
  final double progress;

  /// 回车提交原始输入（解析交给页面）
  final ValueChanged<String> onSubmit;

  /// 点「取消」：退出输入态并还原为当前地址
  final VoidCallback onCancel;

  /// 点 ✕：清空输入（保留输入态）
  final VoidCallback? onClear;

  /// 非输入态点药丸 → 进入输入态（由页面持有：直接翻 editing 状态，
  /// 避免「requestFocus 一个未挂载的节点」而永远进不了输入态）。
  /// 为 null 时退回 `focusNode.requestFocus` 兜底。
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = t.colors.primary;
    // 输入态配色（对齐画布）：淡紫底 + 更浅的紫描边
    final editingFill = Color.alphaBlend(
      accent.withValues(alpha: 0.04),
      t.colors.card,
    );
    final editingBorder = Color.alphaBlend(
      accent.withValues(alpha: 0.22),
      t.colors.card,
    );
    return Container(
      color: t.colors.background,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        6,
        AppTokens.pagePadding,
        8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // 非输入态点一下即进入输入态（对齐 Chrome：点地址栏开始输入）
                  // ⚠️ 必须走 onActivate（页面直接翻 editing），不能只 requestFocus——
                  // 非输入态时 TextField 未挂载，requestFocus 作用于未挂载的节点会失效。
                  onTap: editing ? null : (onActivate ?? focusNode.requestFocus),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    decoration: BoxDecoration(
                      color: editing ? editingFill : t.colors.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: editing ? editingBorder : t.colors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          editing
                              ? FLucideIcons.search
                              : FLucideIcons.lock,
                          size: editing ? 18 : 15,
                          color: editing
                              ? accent.withValues(alpha: 0.72)
                              : t.colors.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: editing
                              ? _AddressInput(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onSubmit: onSubmit,
                                )
                              : Text(
                                  url.trim().isEmpty
                                      ? '搜索或输入网址'
                                      : displayUrl(url),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.typography.body.sm.copyWith(
                                    fontSize: 14,
                                    color: url.trim().isEmpty
                                        ? t.colors.mutedForeground
                                        : t.colors.foreground,
                                  ),
                                ),
                        ),
                        if (editing)
                          _ClearButton(
                            onTap: () {
                              controller.clear();
                              onClear?.call();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (editing) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCancel,
                  child: Text(
                    '取消',
                    style: t.typography.body.md.copyWith(
                      fontSize: 15,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // 加载进度：只在加载中出现，2px，不占位（用 Visibility 保高度稳定）
          SizedBox(
            height: 3,
            child: (progress > 0 && progress < 1)
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.02, 1.0),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// 输入态文本域。
///
/// ⚠️ `InputBorder.none` 是**允许的例外**：外层药丸自带描边与底色，
/// 若再让 TextField 画默认描边会出现「双框」（技能红线 #14 ①）。
/// ⚠️ 原生 TextField 必须有 `Material` 祖先（本行外层包了 transparent Material）。
class _AddressInput extends StatelessWidget {
  const _AddressInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        // ⚠️ 进输入态时本 TextField 是「刚挂载」的（非输入态是纯 Text），
        // 用 autofocus 在挂载瞬间抢焦点；页面侧也会显式 requestFocus 兜底。
        autofocus: true,
        onSubmitted: onSubmit,
        textInputAction: TextInputAction.go,
        keyboardType: TextInputType.url,
        autocorrect: false,
        enableSuggestions: false,
        style: t.typography.body.sm.copyWith(
          fontSize: 14,
          color: t.colors.foreground,
        ),
        cursorColor: t.colors.primary,
        cursorWidth: 2,
        cursorHeight: 16,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          isDense: true,
        ),
      ),
    );
  }
}

/// 清空按钮（✕）
class _ClearButton extends StatelessWidget {
  const _ClearButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 44,
        child: Center(
          child: Icon(
            FLucideIcons.x,
            size: 16,
            color: t.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
