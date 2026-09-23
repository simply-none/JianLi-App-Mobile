// 阅读器「标注编辑」抽屉（样式 / 颜色 / 笔记 / 删除）
//
// 两个入口复用同一个组件，避免两份编辑逻辑漂移：
//   ① 阅读器里**点击已有划线** → `epub_reader_page._showAnnotationSheet`（按 CFI 查出
//      记录后直接渲染本组件）；
//   ② 「笔记与划线」抽屉（`annotation_sheet.dart`）的铅笔按钮 → `showAnnotationEditSheet`
//      （从抽屉内再开一层抽屉，参数与父级同款，嵌套抽屉是既有先例、可安全嵌套）。
//
// ⚠️ 三条不变式：
//   1. **锚点（CFI）不参与编辑** —— 保存只改 `note / color / type` 三列 + updatedAt，
//      位置不丢；需要重绘的场景（颜色 / 类型变了）由调用方按「旧 type 撤 → 新 type 画」
//      自行处理（见 `onSaved`）。
//   2. **样式与分类是两件事**：`type` 里 `underline` = 下划线覆盖层，其余（含历史
//      `note`）都走高亮覆盖层。所以「样式」只在高亮 / 下划线之间切；原本是 `note`
//      的记录在切回高亮时**保留 `note`**，否则会被 `isNoteAnnotation` 判成「划线」，
//      书架卡片与笔记页的统计口径跟着漂。
//   3. 抽屉内含输入框 → **必须 lg 80vh 定高 + `resizeToAvoidBottomInset: false`**
//      （底部按钮的键盘避让由 `SheetScaffold` 内部补偿，见 sheet_form.dart）。
//
// ⚠️ 收尾顺序（2026-09-23 用户实报「点 2 次保存才关弹窗」，勿改回）：
//   **「关抽屉」只允许依赖「写库成功」这一件事**。旧写法把 `Navigator.pop` 排在
//   `await onSaved`（WebView 覆盖层重绘）之后 —— 重绘走 JS 桥，慢/抛/挂都会让 pop
//   永远到不了；而 `catch` 只复位 `_busy`、不关窗 ⇒ 第一次点击「保存成功但抽屉不关」，
//   第二次点击命中 `unchanged` 分支才立即 pop ⇒ 用户看到「要点两次」。
//   正解：写库 `await`（失败留在抽屉里报错）→ **立刻 pop** → 重绘 fire-and-forget。
//   （交互红线「禁止 fire-and-forget 后立刻 pop」针对的是**写库**，此处写库已 await。）
import 'dart:async';

import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_form.dart';
// `SheetSize` 定义在 sheet_surface.dart（sheet_form.dart 只 import 不 export，Dart 无隐式转出）
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart';
import '../repositories/ebook_repository.dart';
import '../utils/annotation_style.dart';

/// 打开「标注编辑」抽屉（自带把手 / 标题 / 关闭 / 滚动区 / 底部三按钮）
Future<void> showAnnotationEditSheet({
  required BuildContext context,
  required EbookAnnotationData annotation,
  required Future<void> Function(EbookAnnotationData a) onDelete,
  Future<void> Function(EbookAnnotationData before, String type, String color)?
      onSaved,
}) async {
  await showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (_) => AnnotationEditSheet(
      annotation: annotation,
      onDelete: onDelete,
      onSaved: onSaved,
    ),
  );
}

/// 标注编辑抽屉主体（可直接放进 `showFSheet` 的 builder —— 内部自带上层容器）
class AnnotationEditSheet extends ConsumerStatefulWidget {
  const AnnotationEditSheet({
    super.key,
    required this.annotation,
    required this.onDelete,
    this.onSaved,
  });

  final EbookAnnotationData annotation;

  /// 删除回调：阅读器侧 = 撤掉 SVG + 删库；其它入口 = 只删库
  final Future<void> Function(EbookAnnotationData a) onDelete;

  /// 保存成功回调：传「改之前那条」与新的 `type / color`，供阅读器按旧类型撤、按新类型画
  final Future<void> Function(EbookAnnotationData before, String type, String color)?
      onSaved;

  @override
  ConsumerState<AnnotationEditSheet> createState() => _AnnotationEditSheetState();
}

class _AnnotationEditSheetState extends ConsumerState<AnnotationEditSheet> {
  late final TextEditingController _note =
      TextEditingController(text: widget.annotation.note ?? '');

  /// 是否下划线样式（其余含历史 `note` 都走高亮覆盖层）
  late bool _underline = isUnderlineType(widget.annotation.type);

  /// 原本是不是「笔记」分类（切回高亮时保留 `note`，见文件头不变式 ②）
  late final bool _wasNote = isNoteType(widget.annotation.type);

  /// 当前色名（空串 / 未知一律归一到色板内的默认色）
  late String _color = normalizeAnnotationColor(widget.annotation.color);

  /// 保存 / 删除进行中（防重复点击）
  bool _busy = false;

  /// 已经发出过 pop（守卫「只弹一层」：退出动画期间再点不会把外层抽屉也弹掉）
  bool _closing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final quote = (widget.annotation.annotatedText ?? '').trim();
    return SheetScaffold(
      title: '编辑标注',
      // 内含笔记输入框 → lg 80vh 定高（全局定案）
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 引用原文（左主色竖线，与「编辑笔记」既有形态一致）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: t.colors.primary, width: 3),
              ),
            ),
            child: Text(
              quote.isEmpty ? '（无引用文本）' : quote,
              style: t.typography.body.md,
            ),
          ),
          const SizedBox(height: 16),
          const SheetFieldLabel('样式'),
          JianliSegmented(
            items: const <(IconData?, String)>[
              (FLucideIcons.highlighter, '高亮'),
              (FLucideIcons.underline, '下划线'),
            ],
            selected: _underline ? 1 : 0,
            onSelect: (i) => setState(() => _underline = i == 1),
          ),
          const SizedBox(height: 16),
          const SheetFieldLabel('颜色'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in kAnnotationColors) _swatch(t, c.$1),
            ],
          ),
          const SizedBox(height: 16),
          const SheetFieldLabel('笔记'),
          SheetMultilineBox(
            controller: _note,
            hintText: '写点想法…（可选，留空表示纯划线）',
            minLines: 3,
          ),
        ],
      ),
      // 底部按钮区：删除（危险）| 取消 | 保存 并列（2026-09-13 用户定案）
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.destructive,
            prefix: const Icon(FLucideIcons.trash2, size: 16),
            onPress: _busy ? null : _delete,
            child: const Text('删除'),
          ),
        ),
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: _busy ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: _busy ? null : _save,
          ),
        ),
      ],
    );
  }

  /// 色板色块（36 圆点 + 选中外描边 + 白勾，与标签改色同款规格）
  Widget _swatch(FThemeData t, String name) {
    final selected = name == _color;
    return GestureDetector(
      onTap: () => setState(() => _color = name),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: annotationColorOf(name),
          border: selected
              ? Border.all(
                  color: t.colors.foreground,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
        ),
        child: selected
            ? const Icon(FLucideIcons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final before = widget.annotation;
    final note = _note.text.trim();
    // 样式（下划线 / 高亮）与分类（note）解耦，见文件头不变式 ②
    final type = _underline ? 'underline' : (_wasNote ? 'note' : 'highlight');
    final color = _color;

    // 点「保存」= 结束输入：主动收键盘。别把「收键盘」留成这次点击的副作用——
    // 键盘收起会让 `SheetScaffold` 的 bottomBar（下边距 = 键盘等高补偿）瞬移一个键盘高。
    FocusManager.instance.primaryFocus?.unfocus();

    // 无改动直接关掉，避免产生一条无意义的 updatedAt 变更
    final unchanged = note == (before.note ?? '').trim() &&
        type == (before.type ?? '').trim() &&
        color == normalizeAnnotationColor(before.color);
    if (unchanged) {
      _popSheet();
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(ebookRepositoryProvider).updateAnnotation(
            before.id,
            note: note.isEmpty ? null : note,
            color: color,
            type: type,
          );
    } catch (e) {
      // 只有「写库」失败才留在抽屉里报错（防连点 + 失败不静默，交互红线）
      if (mounted) {
        setState(() => _busy = false);
        showFToast(context: context, title: Text('保存失败：$e'));
      }
      return;
    }
    // 写库已成 → **立刻关抽屉**（pop 的唯一前置依赖就是这次写库）。
    // 覆盖层重绘是 WebView 侧的视觉副作用，放到关窗之后 fire-and-forget：
    // 它慢 / 抛 / 挂都不该让用户看到「点了保存不关、得再点一次」——见本文件头 ⚠️。
    _popSheet();
    unawaited(_redrawSafely(before, type, color));
  }

  /// 关掉本抽屉（自带 mounted / 可弹栈 / **只弹一次** 守卫）
  ///
  /// ⚠️ 必须收口：本抽屉可能是「笔记与划线」抽屉之上叠的第二层，多弹一层会把
  ///    外层列表抽屉一起关掉（退出动画期间连点「保存」就能触发）；context 已失效
  ///    时同样要静默返回。
  void _popSheet() {
    if (_closing || !mounted) return;
    final nav = Navigator.of(context);
    if (!nav.canPop()) return;
    _closing = true;
    nav.pop();
  }

  /// 关窗之后的覆盖层重绘：失败一律吞掉（视觉副作用，不该冒泡成未处理的异步错误）
  Future<void> _redrawSafely(
    EbookAnnotationData before,
    String type,
    String color,
  ) async {
    try {
      await widget.onSaved?.call(before, type, color);
    } catch (_) {
      // 忽略：重绘失败不影响已落库的数据，下次打开阅读器/重排时会自动重绘
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showSheetConfirm(
      context,
      title: '删除标注',
      message: '确定删除该标注？',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      // 撤覆盖层 + 删库由调用方一并完成（见 onDelete 契约）
      await widget.onDelete(widget.annotation);
      _popSheet();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showFToast(context: context, title: Text('删除失败：$e'));
      }
    }
  }
}
