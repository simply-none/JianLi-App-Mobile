// 阅读器「笔记与划线」底部抽屉
//
// ⚠️ 关键坑（2026-09-19 实踩，改动前必读）：**抽屉内部必须用 `Consumer` 读流**。
//   `showFSheet` 的 builder 属于 Navigator 的 overlay 子树，它不属于页面 element。
//   若在 builder 里直接用页面 State 的 `ref.watch(...)`，Riverpod 会把依赖注册到
//   **页面 element** 上：provider 之后发出数据时只会让页面 rebuild，而 overlay 里的
//   抽屉内容不会重建 → 抽屉永远停在「首帧」= `AsyncLoading` → **一直转圈**
//   （同理用 `snap.value ?? []` 的抽屉会永远显示空列表，书签抽屉就是这么坏的）。
//   正确做法：抽屉内容自己包一层 `Consumer`，用 overlay 自己的 ref 订阅。
//
// 高度走三档制 lg（80%）+ `resizeToAvoidBottomInset: false`：抽屉内含「编辑笔记」
// 输入框，按全局定案「只要有输入框一律 lg」。
//
// 铅笔按钮（2026-09-23 起）不再自己拼一层「编辑笔记」抽屉，统一改开
// `showAnnotationEditSheet`（样式 / 颜色 / 笔记 / 删除），与「点击划线」入口共用同一组件，
// 避免两份编辑逻辑漂移 —— 见 annotation_edit_sheet.dart 顶部注释。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import 'annotation_edit_sheet.dart';

/// 打开「笔记与划线」抽屉
///
/// - [contentHash]：书的跨端稳定键（批注按它归属）
/// - [onLocate]：点「定位」时由阅读器跳到该 CFI（EPUB / TXT 各自实现）
/// - [onDelete]：点「删除」时由阅读器先撤掉对应覆盖层（下划线 / 高亮分派）再删库
/// - [onSaved]：编辑保存后由阅读器按「旧 type 撤 → 新 type 画」重绘（可空，
///   TXT 等无阅读器覆盖层的场景可不传）
void showAnnotationSheet({
  required BuildContext context,
  required String contentHash,
  required void Function(String cfi) onLocate,
  required Future<void> Function(EbookAnnotationData a) onDelete,
  Future<void> Function(EbookAnnotationData before, String type, String color)?
      onSaved,
}) {
  showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (_) => SheetSurface(
      child: SafeArea(
        child: SizedBox(
          // lg 档必须给承载件定高，否则内容少会 hug 到 ~30%（全局定案）
          height: sheetMaxHeightFull(context, SheetSize.lg),
          child: _AnnotationPanel(
            contentHash: contentHash,
            onLocate: onLocate,
            onDelete: onDelete,
            onSaved: onSaved,
          ),
        ),
      ),
    ),
  );
}

class _AnnotationPanel extends ConsumerStatefulWidget {
  const _AnnotationPanel({
    required this.contentHash,
    required this.onLocate,
    required this.onDelete,
    this.onSaved,
  });

  final String contentHash;
  final void Function(String cfi) onLocate;
  final Future<void> Function(EbookAnnotationData a) onDelete;
  final Future<void> Function(EbookAnnotationData before, String type, String color)?
      onSaved;

  @override
  ConsumerState<_AnnotationPanel> createState() => _AnnotationPanelState();
}

class _AnnotationPanelState extends ConsumerState<_AnnotationPanel> {
  /// 0 = 全部，1 = 划线，2 = 笔记
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Consumer(
      builder: (context, ref, _) {
        final snap = ref.watch(annotationsStreamProvider(widget.contentHash));
        final all = snap.value ?? const <EbookAnnotationData>[];
        final list = [
          for (final a in all)
            if (_match(a)) a,
        ];
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
              child: Text('笔记与划线', style: sheetTitleStyle(context)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
              child: JianliSegmented(
                items: const <(IconData?, String)>[
                  (null, '全部'),
                  (FLucideIcons.highlighter, '划线'),
                  (FLucideIcons.notebookPen, '笔记'),
                ],
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: snap.isLoading && all.isEmpty
                  ? const Center(child: FCircularProgress())
                  : snap.hasError
                      ? Center(child: Text('加载失败：${snap.error}'))
                      : list.isEmpty
                          ? Center(
                              child: Text(
                                _emptyText,
                                style: t.typography.body.sm.copyWith(
                                  color: t.colors.mutedForeground,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.only(bottom: 12),
                              children: [
                                FTileGroup(
                                  divider: FItemDivider.none,
                                  children: [
                                    for (final a in list) _tile(context, a),
                                  ],
                                ),
                              ],
                            ),
            ),
          ],
        );
      },
    );
  }

  String get _emptyText => switch (_tab) {
        1 => '还没有划线',
        2 => '还没有笔记',
        _ => '还没有笔记与划线',
      };

  /// 是否命中当前分类（笔记 = note 类型或带笔记文本，其余都算划线类）
  bool _match(EbookAnnotationData a) {
    final isNote = (a.type ?? '').trim().toLowerCase() == 'note' ||
        (a.note ?? '').trim().isNotEmpty;
    return switch (_tab) {
      1 => !isNote,
      2 => isNote,
      _ => true,
    };
  }

  /// 单条批注（返回类型必须是 [FTile]：FTileGroup.children 要求 FTileMixin）
  FTile _tile(BuildContext context, EbookAnnotationData a) {
    final t = context.theme;
    final quote = (a.annotatedText ?? '').trim();
    final note = (a.note ?? '').trim();
    final isNote = (a.type ?? '').trim().toLowerCase() == 'note';
    final cfi = a.anchor;
    return FTile(
      title: Text(
        quote.isEmpty ? (isNote ? '笔记' : '划线') : quote,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: note.isEmpty
          ? null
          : Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.typography.body.sm.copyWith(
                color: t.colors.mutedForeground,
              ),
            ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (cfi != null && cfi.isNotEmpty)
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () {
                Navigator.pop(context);
                widget.onLocate(cfi);
              },
              child: const Icon(FLucideIcons.crosshair),
            ),
          FButton(
            variant: FButtonVariant.ghost,
            // 铅笔 → 与「点击划线」同一张「编辑标注」面板（样式/颜色/笔记/删除）
            onPress: () => _editAnnotation(context, a),
            child: const Icon(FLucideIcons.pencil),
          ),
          FButton(
            variant: FButtonVariant.destructive,
            onPress: () async {
              await widget.onDelete(a);
            },
            child: const Icon(FLucideIcons.trash2),
          ),
        ],
      ),
    );
  }

  /// 铅笔 → 统一「编辑标注」面板：样式（高亮/下划线）/ 颜色 / 笔记 / 删除
  ///
  /// ⚠️ 与「点击已有划线」入口共用 `AnnotationEditSheet`（单一来源，避免两份编辑逻辑
  ///    漂移）。本入口在外层抽屉之上再叠一层抽屉（flutter_sheet 支持嵌套，父级不 pop）。
  ///    保存后靠注释流（`annotationsStreamProvider`）自动刷新本列表；阅读器侧的覆盖层
  ///    重绘交给 `onSaved`。删除同样走 `onDelete`（先撤覆盖层再删库）。
  /// ⚠️ `onSaved` 可能为空（TXT 等无 JS 覆盖层的场景），`AnnotationEditSheet` 内部
  ///    已用 `onSaved?.call(...)` 容错，不传即可。
  void _editAnnotation(BuildContext context, EbookAnnotationData a) {
    showAnnotationEditSheet(
      context: context,
      annotation: a,
      onDelete: widget.onDelete,
      onSaved: widget.onSaved,
    );
  }
}
