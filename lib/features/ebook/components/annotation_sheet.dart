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
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';

/// 打开「笔记与划线」抽屉
///
/// - [contentHash]：书的跨端稳定键（批注按它归属）
/// - [onLocate]：点「定位」时由阅读器跳到该 CFI（EPUB / TXT 各自实现）
/// - [onDelete]：点「删除」时由阅读器先撤掉高亮再删库
void showAnnotationSheet({
  required BuildContext context,
  required String contentHash,
  required void Function(String cfi) onLocate,
  required Future<void> Function(EbookAnnotationData a) onDelete,
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
  });

  final String contentHash;
  final void Function(String cfi) onLocate;
  final Future<void> Function(EbookAnnotationData a) onDelete;

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
            onPress: () => _editNote(context, a),
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

  /// 编辑笔记（lg 抽屉 + 输入框；保存只改 note，不重绘高亮）
  void _editNote(BuildContext context, EbookAnnotationData a) {
    var text = a.note ?? '';
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetSurface(
        child: SafeArea(
          child: SizedBox(
            height: sheetMaxHeightFull(c, SheetSize.lg),
            child: StatefulBuilder(
              builder: (c, setSt) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text('编辑笔记', style: sheetTitleStyle(c)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTokens.pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: c.theme.colors.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            (a.annotatedText ?? '').trim().isEmpty
                                ? '（无引用文本）'
                                : a.annotatedText!,
                            style: c.theme.typography.body.md,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FTextField(
                          label: const Text('笔记内容'),
                          control: FTextFieldControl.managed(
                            onChange: (v) => setSt(() => text = v.text),
                          ),
                          maxLines: null,
                          minLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 底部按钮固定贴底，不随内容滚动
                  // ⚠️ 键盘弹起时必须把按钮顶到键盘上方（lg 固定 80vh 不扣键盘，
                  // 键盘覆盖抽屉；先例 habit_page `_habitSheetPanel` / SheetScaffold）
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      AppTokens.pagePadding,
                      AppTokens.pagePadding,
                      AppTokens.pagePadding +
                          MediaQuery.of(c).viewInsets.bottom,
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: FButton(
                            variant: FButtonVariant.outline,
                            onPress: () => Navigator.pop(c),
                            child: const Text('取消'),
                          ),
                        ),
                        Expanded(
                          child: FButton(
                            onPress: () async {
                              final trimmed = text.trim();
                              await ref
                                  .read(ebookRepositoryProvider)
                                  .updateAnnotationNote(
                                    a.id,
                                    trimmed.isEmpty ? null : trimmed,
                                  );
                              if (c.mounted) Navigator.pop(c);
                            },
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
