// 待办模块底部抽屉集合（页面操作规范：弹窗一律使用底部抽屉 showFSheet + SheetSurface）
//
// 覆盖 PC 待办的全部交互：状态选择、标签多选+新建、父任务多选、自定义日期时间选择、
// 记录进展（写入主题对话）、显示风格（画布 09）、高级搜索（画布 10）、详情查看（只读）、
// 新增/编辑表单、操作菜单与确认。常规抽屉统一走 _sheetScaffold（顶部标题+关闭、中部滚动、
// 底部按钮），高度按内容自适应（高表单 0.92vh）；画布 09/10 两个弹层改走 _sheetPanel
// （把手 + 白卡 r24 + 内边距 20 + 平铺 gap，逐项对齐画布间距）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/datetime_pickers.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart'
    show SheetFieldLabel, SheetInputBox, showSheetConfirm;
import '../../../app/ui/sheet_surface.dart';
import '../../../core/db/app_database.dart' show TodoTag;
import '../../conversation/repositories/conversation_repository.dart';
import '../models/todo.dart';
import '../models/todo_filter.dart';
import '../models/todo_view_mode.dart';
import '../providers/todo_providers.dart';
import '../repositories/todo_repository.dart'
    show kTodoTagPalette, kTodoPomodoroLinkKey;
import 'todo_chips.dart';

// ===================== 统一抽屉入口（键盘兼容） =====================
//
// ⚠️ 高度三档制（2026-09-12 定）：抽屉高度**只允许三档**——sm 30% / md 50% / lg 80%
// （见 [SheetSize]），由 `_sheetScaffold(size:)` / `_sheetPanel(size:)` 声明。
// 这里把 forui 的 mainAxisMaxRatio 放宽到 0.8，只作为「禁止 100vh」的最后一道保险；
// 真正的高度由档位算，**不要再在调用点写裸比例**。
//
// ⚠️ 键盘与高度（2026-09-12 实测，2026-09-12 下午修订）：
// forui 的 `ShiftedSheet` 用 `dy = max(0, H − 抽屉高 − 键盘高)` 摆放抽屉 ——
// 抽屉高一旦超过「H − 键盘高」，dy 就被夹到 0 停止上移，抽屉**不会抬到键盘上方**，
// 而是被键盘从底下盖住（现象：底部「保存」被键盘压住、点不到）。
// **修订（2026-09-12 下午，全 App 新规）**：「新增/编辑/查看」类抽屉（lg）不再按可用高度算，
// 改为 `屏幕高 × 档位`（见 [sheetMaxHeightFull]）—— 键盘从底部覆盖时抽屉**不收缩、不折叠**，
// 输入框获得焦点会自动滚入可视区，底部按钮在键盘收起后可见。内容区本就是可滚动的，承载溢出。
// 仅 **sm/md**（确认、操作菜单、单选多选、日期时间等小弹层）仍按可用高度算（见 [sheetMaxHeight]），
// 保证内容少、一眼看完时不被键盘盖住。
// 选择逻辑：`size == SheetSize.lg ? sheetMaxHeightFull : sheetMaxHeight`（统一在 _sheetScaffold / _sheetPanel 内）。
Future<T?> _showTodoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showFSheet<T>(
      context: context,
      side: FLayout.btt,
      // 固定档位高度（lg=0.80 不随键盘收缩）：mainAxisMaxRatio=lg 作为「禁止 100vh」保险，
      // resizeToAvoidBottomInset=false 让键盘从底部覆盖抽屉而不是把它挤小/顶满（设计规范 2026-09-12 下午）。
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: builder,
    );

// 弹窗高度三档（`SheetSize`）、高度算法（`sheetMaxHeight` 可用高度 / `sheetMaxHeightFull` 全屏高，
// lg 走后者）与标题样式（`sheetTitleStyle`）统一收口在 `lib/app/ui/sheet_surface.dart`，本文件只消费。

// ===================== 通用抽屉骨架 =====================

Widget _sheetScaffold({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget>? bottomBar,
  required SheetSize size,
}) {
  final t = context.theme;
  // 设计规范 2026-09-12 下午：新增/编辑/查看（lg）走全屏高（不扣键盘，键盘覆盖不折叠）；
  // sm/md（确认/操作菜单/单选多选）仍走可用高度，防被键盘盖住。
  final h = size == SheetSize.lg
      ? sheetMaxHeightFull(context, size)
      : sheetMaxHeight(context, size);
  // 左右内边距 = AppTokens.pagePadding（**与页面正文同一个值**，2026-09-12 收口到 16），
  // 且**只在这里应用一次**。
  // ⚠️ 历史坑（2026-09-12 用户实指「弹窗左右 padding 应该和全局保持一致」）：
  // 键盘型弹窗曾给 SheetSurface 传 `padding: fromLTRB(16,16,16,16)`，而下面标题行 /
  // 滚动区 / 底部条又各写 16 → 左右实际 32，比页面正文多一倍。现在统一由骨架内部提供。
  const hpad = AppTokens.pagePadding;
  return SheetSurface(
    // 定高（不是上限）：档位 = 弹窗规格，同档弹窗高度必然一致（详情/编辑要求对齐）；
    // 内容超出时由中间 Expanded 里的 SingleChildScrollView 滚动，绝不撑高抽屉。
    child: SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部把手（36×4 · 居中 · 距顶 10）
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _sheetHandle(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(hpad, 14, hpad, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: sheetTitleStyle(context),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(FLucideIcons.x, size: 18, color: t.colors.foreground),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(hpad, 14, hpad, 8),
              child: body,
            ),
          ),
          if (bottomBar != null)
            Padding(
              // ⚠️ 键盘弹起时必须把底部操作条顶到键盘上方（2026-09-19 修复「保存按钮点了没反应」）：
              // lg 档走 `sheetMaxHeightFull`（固定 80vh、不扣键盘）+ 调用点
              // `resizeToAvoidBottomInset: false` ⇒ 键盘从底部覆盖抽屉、底部按钮被遮住
              // （先例：habit_page `_habitSheetPanel` / 共享 `SheetScaffold`，同日收口）。
              // sm/md 走 `sheetMaxHeight`（已扣键盘、整抽屉在键盘上方），不重复补偿。
              padding: EdgeInsets.fromLTRB(
                hpad,
                8,
                hpad,
                16 +
                    (size == SheetSize.lg
                        ? MediaQuery.of(context).viewInsets.bottom
                        : 0),
              ),
              child: Row(spacing: 10, children: bottomBar),
            ),
        ],
      ),
    ),
  );
}

/// 选择型 chip（左侧可带色点；选中态显示勾）
Widget _choiceChip(
  BuildContext context, {
  required String label,
  bool selected = false,
  Color? color,
  Widget? leading,
  VoidCallback? onTap,
}) {
  final t = context.theme;
  // 选中/强调默认色 = 待办域专属蓝（2026-09-13 功能色定案）
  final c = color ?? AppTokens.accent(1);
  return FTappable(
    onPress: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.14) : t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: selected ? c : t.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          if (selected) ...[
            Icon(FLucideIcons.check, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: t.typography.body.sm.copyWith(
              color: selected ? c : t.colors.foreground,
            ),
          ),
        ],
      ),
    ),
  );
}

// ===================== 1. 状态选择 =====================

Future<String?> showTodoStatusSheet(
  BuildContext context, {
  String? current,
}) async {
  return _showTodoSheet<String?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '状态',
      size: SheetSize.sm,
      body: StatefulBuilder(
        builder: (c, setInner) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in kTodoStatusOptions)
                _choiceChip(
                  c,
                  label: opt.$2,
                  selected: current == opt.$1,
                  color: statusMetaOf(c, opt.$1).color,
                  onTap: () => Navigator.pop(c, opt.$1),
                ),
            ],
          );
        },
      ),
    ),
  );
}

// ===================== 2. 标签多选 + 新建 =====================

Future<List<String>?> showTodoTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<TodoTagView> tags,
  required List<String> selected,
}) async {
    final draft = List<String>.from(selected);
    final controller = TextEditingController();
    return _showTodoSheet<List<String>?>(
      context: context,
      builder: (c) => _sheetScaffold(
        context: c,
        title: '标签',
        size: SheetSize.lg,
        body: StatefulBuilder(
          builder: (c, setInner) {
            final t = c.theme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // D5：标签管理入口（右上角铅笔，进 lg 管理抽屉；回来后同步草稿并刷新）
                Align(
                  alignment: Alignment.centerRight,
                  child: FTappable(
                    onPress: () async {
                      await showTodoTagManageSheet(c, ref);
                      // 管理抽屉里可能删过标签：把已删 key 从草稿里摘掉，
                      // 并由下方 Consumer 监听标签流自动刷新 chip 列表
                      final live = ref.read(todoTagsProvider).value ??
                          const <TodoTagView>[];
                      draft.removeWhere(
                        (k) => !live.any((tag) => tag.key == k),
                      );
                      setInner(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FLucideIcons.pencil,
                            size: 13,
                            color: t.colors.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '管理标签',
                            style: t.typography.body.xs.copyWith(
                              fontSize: 12,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 新建标签输入行：对齐搜索栏/习惯输入框样式（h40 · r10 · 1px 描边 · 卡色底）
                Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.colors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        type: MaterialType.transparency,
                        child: TextField(
                          controller: controller,
                          style: t.typography.body.sm.copyWith(
                            fontSize: 14,
                            color: t.colors.foreground,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: '新建标签',
                            hintStyle: t.typography.body.sm.copyWith(
                              fontSize: 14,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                          onSubmitted: (_) async {
                            final name = controller.text.trim();
                            if (name.isEmpty) return;
                            final tag = await ref
                                .read(todoRepositoryProvider)
                                .addTag(name);
                            if (!draft.contains(tag.key)) draft.add(tag.key);
                            controller.clear();
                            setInner(() {});
                          },
                        ),
                      ),
                    ),
                    FTappable(
                      onPress: () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        final tag = await ref
                            .read(todoRepositoryProvider)
                            .addTag(name);
                        if (!draft.contains(tag.key)) draft.add(tag.key);
                        controller.clear();
                        setInner(() {});
                      },
                      child: Icon(
                        FLucideIcons.plus,
                        size: 18,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // D5：标签列表用 Consumer 自行订阅标签流（红线 #28：抽屉内容不归页面
              // element 所有，必须用 overlay 自己的 ref）——管理抽屉改/删标签后此处即时刷新。
              // 入参 tags 仅作流尚未出首帧时的兜底快照。
              Consumer(
                builder: (c, tagRef, _) {
                  final liveTags =
                      tagRef.watch(todoTagsProvider).value ?? tags;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in liveTags)
                        _choiceChip(
                          c,
                          label: tag.name,
                          selected: draft.contains(tag.key),
                          color: _parseColor(tag.color),
                          onTap: () {
                            if (draft.contains(tag.key)) {
                              draft.remove(tag.key);
                            } else {
                              draft.add(tag.key);
                            }
                            setInner(() {});
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '完成',
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(c, draft),
          ),
        ),
      ],
    ),
  );
}

// ===================== 2.5 标签管理（D5：重命名 / 改色 / 删除） =====================

/// 标签管理抽屉（lg 定高，骨架与 `_sheetScaffold` 同源）：
/// 标签列表（色点 + 名称 + 编辑 / 删除），行内操作直接改库，
/// 抽屉无需返回值（todoTagsProvider / todoListProvider 流自动刷新各方）。
Future<void> showTodoTagManageSheet(BuildContext context, WidgetRef ref) {
  return _showTodoSheet<void>(
    context: context,
    builder: (c) => const _TodoTagManageSheet(),
  );
}

class _TodoTagManageSheet extends ConsumerWidget {
  const _TodoTagManageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 红线 #28：抽屉内容用自己的 Consumer ref 订阅流，页面层不背依赖
    final tags = ref.watch(todoTagsProvider).value ?? const <TodoTagView>[];
    final todos = ref.watch(todoListProvider).value ?? const <TodoItem>[];
    return _sheetScaffold(
      context: context,
      title: '标签管理',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            '重命名 / 改色即时生效；删除会同时从相关待办上移除该标签。',
            style: context.theme.typography.body.xs.copyWith(
              fontSize: 12,
              color: context.theme.colors.mutedForeground,
            ),
          ),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  '暂无标签，编辑待办或「新建标签」可创建',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ),
            )
          else
            for (final tag in tags)
              _TodoTagManageRow(
                tag: tag,
                // 删除确认文案用：该标签当前被多少条待办引用
                refCount: todos.where((t) => t.tags.contains(tag.key)).length,
              ),
        ],
      ),
    );
  }
}

/// 标签管理行：色点 + 名称 + 编辑 / 删除
class _TodoTagManageRow extends ConsumerWidget {
  const _TodoTagManageRow({required this.tag, required this.refCount});

  final TodoTagView tag;

  /// 引用该标签的待办条数（删除确认文案用）
  final int refCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _parseColor(tag.color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tag.name,
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.colors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (refCount > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$refCount 条',
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
          _rowIcon(context, FLucideIcons.pencil, () => _edit(context)),
          _rowIcon(
            context,
            FLucideIcons.trash2,
            () => _remove(context, ref),
            destructive: true,
          ),
        ],
      ),
    );
  }

  Widget _rowIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: destructive ? t.colors.destructive : t.colors.mutedForeground,
        ),
      ),
    );
  }

  /// 编辑进 md 输入抽屉（名称 + 10 色调色板，同新建标签的调色板）
  Future<void> _edit(BuildContext context) async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      // sm/md 含输入框必须 true（抽屉抬到键盘上方，红线 #9②）
      resizeToAvoidBottomInset: true,
      builder: (c) => _TodoTagEditSheet(tag: tag),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showSheetConfirm(
      context,
      title: '删除标签',
      message: refCount > 0
          ? '确定删除「${tag.name}」？将同时从 $refCount 条待办移除该标签。'
          : '确定删除「${tag.name}」？',
    );
    if (!ok) return;
    await ref.read(todoRepositoryProvider).deleteTag(tag.key);
  }
}

/// 单标签编辑抽屉（md 定高）：名称输入 + 调色板选色。
/// controller 归本 State 持有（_ControllerHost 结论：不能在 await 后 dispose）。
class _TodoTagEditSheet extends ConsumerStatefulWidget {
  const _TodoTagEditSheet({required this.tag});

  final TodoTagView tag;

  @override
  ConsumerState<_TodoTagEditSheet> createState() => _TodoTagEditSheetState();
}

class _TodoTagEditSheetState extends ConsumerState<_TodoTagEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.tag.name,
  );
  late String _color = widget.tag.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return _sheetScaffold(
      context: context,
      title: '编辑标签',
      size: SheetSize.md,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetFieldLabel('名称'),
          SheetInputBox(controller: _name, hintText: '标签名称'),
          const SizedBox(height: 16),
          const SheetFieldLabel('颜色'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in kTodoTagPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _parseColor(hex),
                      border: _color.toLowerCase() == hex.toLowerCase()
                          ? Border.all(
                              color: t.colors.foreground,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            )
                          : null,
                    ),
                    child: _color.toLowerCase() == hex.toLowerCase()
                        ? Icon(
                            FLucideIcons.check,
                            size: 14,
                            color: t.colors.primaryForeground,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: () async {
              final name = _name.text.trim();
              if (name.isEmpty) {
                // 校验失败不静默 return（§1.8）
                showFToast(
                  context: context,
                  variant: FToastVariant.destructive,
                  title: const Text('标签名称不能为空'),
                );
                return;
              }
              // updateTag 只按 key 更新 name/color；TodoTag 的 id 为 drift 行主键，
              // 这里传 0 占位、不参与更新（详见仓库 updateTag 注释）
              await ref.read(todoRepositoryProvider).updateTag(
                    TodoTag(
                      id: 0,
                      key: widget.tag.key,
                      name: name,
                      color: _color,
                    ),
                  );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

// ===================== 3. 父任务多选 =====================

/// 取某 key 的所有后代 key（避免父子环）
Set<String> _descendantKeys(List<TodoItem> all, String key) {
  final result = <String>{};
  final queue = [key];
  while (queue.isNotEmpty) {
    final cur = queue.removeLast();
    for (final it in all.where((t) => t.parentIds.contains(cur))) {
      if (result.add(it.key)) queue.add(it.key);
    }
  }
  return result;
}

Future<List<String>?> showTodoParentSheet(
  BuildContext context, {
  required List<TodoItem> candidates,
  required List<String> selected,
  String? excludeKey,
}) async {
  final draft = List<String>.from(selected);
  // 排除自身及其后代，避免循环父子
  final blocked = excludeKey == null
      ? <String>{}
      : {excludeKey, ..._descendantKeys(candidates, excludeKey)};
  final pool = candidates.where((t) => !blocked.contains(t.key)).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return _showTodoSheet<List<String>?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '父任务',
      size: SheetSize.md,
      body: StatefulBuilder(
        builder: (c, setInner) {
          if (pool.isEmpty) {
            return Text(
              '暂无可关联的父任务',
              style: c.theme.typography.body.sm
                  .copyWith(color: c.theme.colors.mutedForeground),
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final it in pool)
                _choiceChip(
                  c,
                  label: it.title,
                  selected: draft.contains(it.key),
                  onTap: () {
                    if (draft.contains(it.key)) {
                      draft.remove(it.key);
                    } else {
                      draft.add(it.key);
                    }
                    setInner(() {});
                  },
                ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '完成',
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(c, draft),
          ),
        ),
      ],
    ),
  );
}

// ===================== 4. 自定义日期时间选择 =====================

Future<DateTime?> showTodoDateTimeSheet(
  BuildContext context, {
  DateTime? initial,
  bool dateOnly = false,
}) async {
  // 状态需在 StatefulBuilder 之外持有，避免每次 rebuild 被重置
  var selected = initial;
  var display = DateTime(
    (initial ?? DateTime.now()).year,
    (initial ?? DateTime.now()).month,
    1,
  );
  final weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

  return _showTodoSheet<DateTime?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: dateOnly ? '结束日期' : '日期与时间',
      size: SheetSize.md,
      body: StatefulBuilder(
        builder: (c, setInner) {
          Widget buildGrid() {
            final firstWeekday = display.weekday % 7; // 0=周日
            final daysInMonth =
                DateTime(display.year, display.month + 1, 0).day;
            final cells = <Widget>[];
            for (var i = 0; i < firstWeekday; i++) {
              cells.add(const SizedBox.shrink());
            }
            for (var d = 1; d <= daysInMonth; d++) {
              final day = DateTime(display.year, display.month, d);
              final sel = selected != null &&
                  selected!.year == day.year &&
                  selected!.month == day.month &&
                  selected!.day == day.day;
              cells.add(
                FTappable(
                  onPress: () => setInner(() => selected = day),
                  child: Container(
                    alignment: Alignment.center,
                    height: 38,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTokens.accent(1).withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusSm),
                      border: sel
                          ? Border.all(color: AppTokens.accent(1))
                          : null,
                    ),
                    child: Text(
                      '$d',
                      style: c.theme.typography.body.sm.copyWith(
                        color: sel
                            ? AppTokens.accent(1)
                            : c.theme.colors.foreground,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FTappable(
                      onPress: () => setInner(() => display = DateTime(
                          display.year, display.month - 1, 1)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(FLucideIcons.chevronLeft, size: 18),
                      ),
                    ),
                    Text(
                      '${display.year} 年 ${display.month} 月',
                      style: c.theme.typography.body.md
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    FTappable(
                      onPress: () => setInner(() => display = DateTime(
                          display.year, display.month + 1, 1)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(FLucideIcons.chevronRight, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final w in weekLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: c.theme.typography.body.xs.copyWith(
                              color: c.theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.05,
                  children: cells,
                ),
              ],
            );
          }

          final hour = selected?.hour ?? 9;
          final minute = selected?.minute ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildGrid(),
              if (!dateOnly) ...[
                const SizedBox(height: 14),
                // 时刻轮式选择器（forui FTimePicker，24 小时制）——替代时/分步进器
                FTimePicker(
                  hour24: true,
                  control: FTimePickerControl.managed(
                    controller: FTimePickerController(
                      time: FTime(hour, minute),
                    ),
                    onChange: (t) => setInner(
                      () => selected = DateTime(
                        selected?.year ?? DateTime.now().year,
                        selected?.month ?? DateTime.now().month,
                        selected?.day ?? DateTime.now().day,
                        t.hour,
                        t.minute,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (initial != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: FTappable(
                    onPress: () => Navigator.pop(c, null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '清除',
                        style: c.theme.typography.body.sm.copyWith(
                          color: c.theme.colors.destructive,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '确定',
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(c, selected),
          ),
        ),
      ],
    ),
  );
}

// ===================== 5. 记录进展（写入主题对话） =====================

Future<void> showRecordProgressSheet(
  BuildContext context,
  WidgetRef ref,
  TodoItem item,
) async {
  final controller = TextEditingController();
  return _showTodoSheet<void>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '记录进展',
      // 内含多行输入框 → lg 80vh 定高（2026-09-13 全局定案）
      size: SheetSize.lg,
      body: StatefulBuilder(
        builder: (c, setInner) {
          final t = c.theme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '主题：${item.title}',
                style: t.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '将作为一条对话写入该主题，便于日后回看进展',
                style: t.typography.body.sm
                    .copyWith(color: t.colors.mutedForeground),
              ),
              const SizedBox(height: 12),
              FTextField(
                control: FTextFieldControl.managed(controller: controller),
                hint: '本次进展…',
                minLines: 3,
                maxLines: 6,
              ),
            ],
          );
        },
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: () async {
              final content = controller.text.trim();
              if (content.isEmpty) {
                showFToast(
                  context: c,
                  variant: FToastVariant.destructive,
                  title: const Text('进展内容不能为空'),
                );
                return;
              }
              final themeId = await ref
                  .read(conversationRepositoryProvider)
                  .findOrCreateThemeByTitle(item.title);
              await ref
                  .read(conversationRepositoryProvider)
                  .addMessage(themeId: themeId, content: content);
              if (c.mounted) {
                showFToast(
                  context: c,
                  title: const Text('已记录到主题对话'),
                );
                Navigator.pop(c);
              }
            },
          ),
        ),
      ],
    ),
  );
}

// ===================== 6. 显示风格（画布 09） =====================

/// 显示风格三选一（画布「09 待办·设置 显示风格」）。
/// 点击某一项立即返回该风格并关闭 —— 画布文案「切换后立即生效」。
/// D7：同弹层追加「排序」选择（pill chip，与高级搜索同款），点选同样立即生效，
/// 返回 (视图, 排序) 记录由调用方分别持久化。
Future<({TodoViewMode view, TodoSortMode sort})?> showTodoViewModeSheet(
  BuildContext context, {
  required TodoViewMode current,
  required TodoSortMode sort,
}) => _showTodoSheet<({TodoViewMode view, TodoSortMode sort})?>(
  context: context,
  builder: (c) {
    final t = c.theme;
    return _sheetPanel(
      context: c,
      gap: 12,
      children: [
        _sheetHandle(c),
        Text(
          '显示风格',
          style: t.typography.body.lg.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.colors.foreground,
          ),
        ),
        Text(
          '选择待办的展示方式，切换后立即生效',
          style: t.typography.body.xs.copyWith(
            fontSize: 12,
            color: t.colors.mutedForeground,
          ),
        ),
        for (final opt in kTodoViewModeOptions)
          _viewModeOption(
            c,
            mode: opt.$1,
            title: opt.$2,
            desc: opt.$3,
            selected: current == opt.$1,
            onTap: () => Navigator.pop(c, (view: opt.$1, sort: sort)),
          ),
        // D7：排序选择（显示项，同 groupBy 不进条件 chip）
        _groupLabel(c, '排序'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kTodoSortOptions)
              _pill(
                c,
                label: s.$2,
                selected: sort == s.$1,
                onTap: () =>
                    Navigator.pop(c, (view: current, sort: s.$1)),
              ),
          ],
        ),
      ],
    );
  },
);

IconData _viewModeIcon(TodoViewMode m) => switch (m) {
  TodoViewMode.list => FLucideIcons.list,
  TodoViewMode.card => FLucideIcons.grid2x2,
  TodoViewMode.calendar => FLucideIcons.calendarDays,
};

/// 显示风格选项（画布 8:19 / 8:20 / 8:21）：
/// 选中 = 底 主色12% + 描边 主色35% + 图标盘 主色16% + 图标/状态符 主色；
/// 未选中 = 底 #F6F7F9 + 图标盘 #E5E7EB + 图标 #6B7280 + 状态符 #C7CDD6。
/// ⚠️ 画布中标题文字两种状态都是 #1C1C1E（不是主色），不要「顺手」染紫。
Widget _viewModeOption(
  BuildContext c, {
  required TodoViewMode mode,
  required String title,
  required String desc,
  required bool selected,
  required VoidCallback onTap,
}) {
  final t = c.theme;
  final p = AppTokens.accent(1);
  return FTappable(
    onPress: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? p.withValues(alpha: 0.12) : t.colors.muted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? p.withValues(alpha: 0.35) : Colors.transparent,
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // 未选中图标盘（画布 8:20 = #E5E7EB）要**比行底 #F6F7F9 深一档**才看得见；
              // 直接用 `t.colors.border` 会与行底同色（同为 surfaceElevated）→ 盘子消失。
              color: selected ? p.withValues(alpha: 0.16) : _stepUp(c, alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _viewModeIcon(mode),
              size: 16,
              color: selected ? p : t.colors.mutedForeground,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                ),
                Text(
                  desc,
                  style: t.typography.body.xs.copyWith(
                    fontSize: 11,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? FLucideIcons.circleDot : FLucideIcons.circle,
            size: 18,
            color: selected
                ? p
                : t.colors.mutedForeground.withValues(alpha: 0.45),
          ),
        ],
      ),
    ),
  );
}

// ===================== 7. 高级搜索（画布 10） =====================

/// 高级搜索弹层（画布「10 待办·高级搜索弹窗」）。
/// 分组顺序与画布一致：优先级 / 标签 / 到期时间 / 其他 / 分组方式。
/// 状态（进行中/已完成/已取消/全部）由列表页 Tab 栏承担，本弹层不再重复提供。
Future<TodoFilterState?> showTodoFilterSheet(
  BuildContext context, {
  required TodoFilterState current,
  required List<TodoTagView> tags,
}) {
  // TodoFilterState 字段为 final，草稿用本地可变变量承载，确认时再构造新状态
  var draftPriority = current.priority;
  final draftTags = {...current.tagKeys};
  var draftDue = current.dueGroup;
  var draftShowCompleted = current.showCompleted;
  var draftShowTemplates = current.showTemplates;
  var draftGroup = current.groupBy;
  var draftSearch = current.search;

  return _showTodoSheet<TodoFilterState?>(
    context: context,
    // 关键词框的 controller 交给 _ControllerHost 持有，**不能**在本函数里
    // `try { await ... } finally { ctrl.dispose(); }`——见该类注释（点「取消」必崩）。
    builder: (c) => _ControllerHost(
      initialText: current.search,
      builder: (c, kwCtrl) => StatefulBuilder(
        builder: (c, setInner) {
          final t = c.theme;
          return _sheetPanel(
            context: c,
            gap: 14,
            children: [
              _sheetHandle(c),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '高级搜索',
                      style: t.typography.body.lg.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.colors.foreground,
                      ),
                    ),
                  ),
                  FTappable(
                    onPress: () => Navigator.pop(c),
                    child: Text(
                      '取消',
                      style: t.typography.body.sm.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              // 关键词框（画布 8:96，高 44 · r12 · 底 #F6F7F9 · 描边 #E5E7EB）
              // 描边走 _stepUp：底与描边若都取同一个 surfaceElevated，描边等于看不见。
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.colors.muted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stepUp(c, alpha: 0.14)),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(
                      FLucideIcons.search,
                      size: 15,
                      color: t.colors.mutedForeground,
                    ),
                    Expanded(
                      child: TextField(
                        controller: kwCtrl,
                        onChanged: (v) => setInner(() => draftSearch = v),
                        style: t.typography.body.sm.copyWith(
                          fontSize: 14,
                          color: t.colors.foreground,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: '搜索标题或描述',
                          hintStyle: t.typography.body.sm.copyWith(
                            fontSize: 14,
                            color: t.colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        kwCtrl.clear();
                        setInner(() => draftSearch = '');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        FLucideIcons.x,
                        size: 13,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _groupLabel(c, '优先级'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    c,
                    label: '不限',
                    selected: draftPriority == null,
                    onTap: () => setInner(() => draftPriority = null),
                  ),
                  for (final p in kTodoPriorityOptions)
                    _pill(
                      c,
                      label: p.$2,
                      selected: draftPriority == p.$1,
                      color: priorityColor(p.$1),
                      onTap: () => setInner(() => draftPriority = p.$1),
                    ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                _groupLabel(c, '标签'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      _pill(
                        c,
                        label: tag.name,
                        selected: draftTags.contains(tag.key),
                        color: _parseColor(tag.color),
                        onTap: () => setInner(() {
                          if (draftTags.contains(tag.key)) {
                            draftTags.remove(tag.key);
                          } else {
                            draftTags.add(tag.key);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              _groupLabel(c, '到期时间'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    c,
                    label: '不限',
                    selected: draftDue == null,
                    onTap: () => setInner(() => draftDue = null),
                  ),
                  for (final g in kDueRangeOptions)
                    _pill(
                      c,
                      label: kDueRangeLabels[g]!,
                      selected: draftDue == g,
                      onTap: () => setInner(() => draftDue = g),
                    ),
                ],
              ),
              _groupLabel(c, '其他'),
              _switchRow(
                c,
                label: '包含已完成',
                value: draftShowCompleted,
                onChanged: (v) => setInner(() => draftShowCompleted = v),
              ),
              _switchRow(
                c,
                label: '包含重复模板',
                value: draftShowTemplates,
                onChanged: (v) => setInner(() => draftShowTemplates = v),
              ),
              _groupLabel(c, '分组方式'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in TodoGroupBy.values)
                    _pill(
                      c,
                      label: _groupLabelOf(g),
                      selected: draftGroup == g,
                      onTap: () => setInner(() => draftGroup = g),
                    ),
                ],
              ),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: FTappable(
                      onPress: () => setInner(() {
                        draftPriority = null;
                        draftTags.clear();
                        draftDue = null;
                        draftShowCompleted = true;
                        draftShowTemplates = false;
                        draftSearch = '';
                        kwCtrl.clear();
                      }),
                      child: _sheetButton(
                        c,
                        label: '重置',
                        bg: t.colors.muted,
                        fg: t.colors.mutedForeground,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FTappable(
                      onPress: () => Navigator.pop(
                        c,
                        TodoFilterState(
                          search: draftSearch,
                          priority: draftPriority,
                          status: current.status,
                          tagKeys: draftTags,
                          dueGroup: draftDue,
                          showCompleted: draftShowCompleted,
                          showTemplates: draftShowTemplates,
                          groupBy: draftGroup,
                          // D7：排序不归高级搜索管，回传时保留现状不被重置
                          sortBy: current.sortBy,
                        ),
                      ),
                      child: _sheetButton(
                        c,
                        label: '查看结果',
                        bg: t.colors.primary,
                        fg: t.colors.primaryForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// 只负责「创建 + 在正确时机释放」一个 `TextEditingController` 的壳。
///
/// ⚠️ **为什么需要它（2026-09-12 实踩，点「取消」整屏红）**：
/// `showFSheet` / `Navigator.push` 返回的 Future **在 `Navigator.pop()` 那一刻就 complete 了**
/// （`Route.didPop` → `didComplete` → `_popCompleter.complete`，见 flutter/src/widgets/routes.dart），
/// 而抽屉此时还在播退场动画、widget 树仍然活着、里面的 `TextField` 仍然依赖这个 controller。
/// 若在 `await` 之后（例如 `try/finally`）立刻 `dispose()`，就是在「仍被依赖」时把它销毁，
/// 触发框架断言 `'_dependents.isEmpty': is not true`
/// （framework.dart → `InheritedElement.debugDeactivated`）。
///
/// 交给 `State.dispose()` 时机才对：框架在元素 **deactivate 之后** 的 unmount 阶段才调用它，
/// 那时整棵抽屉子树早已拆干净。⚠️ 新增任何「抽屉里用 controller」的地方都照这个壳写，
/// 别再用「await 之后 dispose」的写法。
class _ControllerHost extends StatefulWidget {
  const _ControllerHost({required this.initialText, required this.builder});

  final String initialText;
  final Widget Function(BuildContext context, TextEditingController controller)
  builder;

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, controller);
}

// ===================== 8. 弹层公共件（画布 09/10 共用） =====================

/// 底部弹层外壳：白底 + 顶部 24 圆角 + 20 内边距，子项统一 [gap] 间距。
/// 画布两个弹层的间距都是**平铺 14/12**（把手与标题之间也是），所以这里用扁平
/// Column(spacing:) 而不是分组小标题自带缩进，才能与画布逐像素对上。
Widget _sheetPanel({
  required BuildContext context,
  required double gap,
  required List<Widget> children,
  SheetSize size = SheetSize.lg,
}) {
  // 设计规范 2026-09-12 下午：lg（新增/编辑/查看）固定 80% 全屏高；
  // sm/md（确认/菜单/单选多选）仍当上限、内容少则 hug。
  final maxH = size == SheetSize.lg
      ? sheetMaxHeightFull(context, size)
      : sheetMaxHeight(context, size);
  return SheetSurface(
    color: context.theme.colors.card,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: ConstrainedBox(
      constraints: size == SheetSize.lg
          ? BoxConstraints.tightFor(height: maxH)
          : BoxConstraints(maxHeight: maxH),
      child: Padding(
        // 统一到全局边距（用户规则：弹窗左右 padding 与全局一致；2026-09-12 由 20 收口到 16）
        padding: const EdgeInsets.all(AppTokens.pagePadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: children,
          ),
        ),
      ),
    ),
  );
}

/// 顶部把手（画布 8:16 / 8:92：36×4 · #D9DDE4 · r2 · 居中）
/// 底色走 [_stepUp]：`t.colors.border` 与白卡同系，直接用会淡到看不见。
Widget _sheetHandle(BuildContext c) => Align(
  alignment: Alignment.center,
  child: Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: _stepUp(c),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

/// 分组小标题（画布 8:100 等：12/Bold #6B7280）
Widget _groupLabel(BuildContext c, String text) => Text(
  text,
  style: c.theme.typography.body.xs.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: c.theme.colors.mutedForeground,
  ),
);

/// 胶囊 chip（画布 8:102 等：h30 · r999 · 左右 12 / 上下 7）
/// 胶囊 chip（画布 8:102 等：宽度 hug · 高 30 · r999 · 左右 12 · 文字 13）
///
/// ⚠️ **不要**用 `Container(alignment: Alignment.center)` 做居中（2026-09-12 实踩）：
/// 带 `alignment` 的 Container 会包一层 `Align`，而 `Align` 在拿到「有界 maxWidth」的
/// 松约束时会**撑满整行**——`Wrap` 恰好给子项这种约束，于是每个 chip 都被拉成整行宽，
/// 一行只放得下一个，优先级/标签/到期时间三组全部竖着排（高级搜索弹层就是这么崩观的）。
/// 正确写法：`Row(mainAxisSize: min)`——宽度自适应，高度吃到 Container 的 tight 30
/// 并在交叉轴居中，视觉与画布一致。
Widget _pill(
  BuildContext c, {
  required String label,
  required bool selected,
  Color? color,
  VoidCallback? onTap,
}) {
  final t = c.theme;
  final col = color ?? AppTokens.accent(1);
  return FTappable(
    onPress: onTap,
    child: Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? col.withValues(alpha: 0.14) : t.colors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: t.typography.body.sm.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? col : t.colors.mutedForeground,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 开关行（画布 8:137 / 8:141：#F6F7F9 · r14 · 左右 12 / 上下 10 · 标签 14 + 右侧 44×26 开关）
Widget _switchRow(
  BuildContext c, {
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final t = c.theme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: t.colors.muted,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      spacing: 10,
      children: [
        Expanded(
          child: Text(
            label,
            style: t.typography.body.sm.copyWith(
              fontSize: 14,
              color: t.colors.foreground,
            ),
          ),
        ),
        _CanvasSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

/// 画布规格开关（8:139 开 / 8:143 关）：44×26 · r13 · 内边距 2 · 22Ø 圆形滑块 ·
/// 开 = 主色实底（滑块靠右）/ 关 = 灰轨（滑块靠左）。
/// 不用 forui 的 `FSwitch`：它的尺寸与描边跟画布这枚对不上，塞进 26 高的行里也不齐。
class _CanvasSwitch extends StatelessWidget {
  const _CanvasSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppTokens.fast,
        curve: AppTokens.standard,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? AppTokens.accent(1) : _stepUp(context, alpha: 0.26),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: t.colors.primaryForeground,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// 「抬升面再压一档」的灰（画布 #D9DDE4 把手 / #D8DDE5 开关轨 / #E5E7EB 描边这一档）。
///
/// 本主题把 `muted` 与 `border` 收口成同一个 `surfaceElevated`，画布那几级灰在 token 里
/// 无从直取——若直接用 `t.colors.border`，在**同为抬升面底色**的盒子（关键词框、开关轨）
/// 上会「描边与底同色 = 看不见」，把手贴在白卡上也会淡到几乎不存在。
/// 故按当前主题的次字色叠一层派生：亮色偏灰、暗色偏亮，跟随 9 套外观 + 深浅自动适配。
Color _stepUp(BuildContext c, {double alpha = 0.26}) => Color.alphaBlend(
  c.theme.colors.mutedForeground.withValues(alpha: alpha),
  c.theme.colors.muted,
);

/// 弹层底部按钮（画布 8:156 / 8:158：h46 · r14 · 15/SemiBold）
Widget _sheetButton(
  BuildContext c, {
  required String label,
  required Color bg,
  required Color fg,
}) => Container(
  height: 46,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Text(
    label,
    style: c.theme.typography.body.sm.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: fg,
    ),
  ),
);

/// 分组方式的中文名（弹层 chip 与列表页 chip 共用同一套字面量）
String _groupLabelOf(TodoGroupBy g) => switch (g) {
  TodoGroupBy.none => '不分组',
  TodoGroupBy.status => '按状态',
  TodoGroupBy.due => '按到期',
  TodoGroupBy.parent => '按父任务',
};

// ===================== 9. 新增 / 编辑表单 =====================

class _TodoEditSheet extends StatefulWidget {
  const _TodoEditSheet({
    required this.initial,
    required this.allTodos,
    required this.tags,
    required this.ref,
  });

  final TodoItem initial;
  final List<TodoItem> allTodos;
  final List<TodoTagView> tags;
  final WidgetRef ref;

  @override
  State<_TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<_TodoEditSheet> {
  late final TextEditingController _titleC;
  late final TextEditingController _descC;
  late final TextEditingController _intervalC;
  late String _priority;
  late String _status;
  DateTime? _dueDate;
  bool _reminderOn = false;
  int _remindCount = 1;
  int _remindInterval = 30;
  String _remindUnit = 'minute';
  bool _recurrenceOn = false;
  String _recurrenceRule = 'daily';
  int _recurrenceInterval = 1;
  List<int> _weekdays = const [1];
  DateTime? _recurrenceEnd;

  /// F2 生成方式：'fixed'（到点自动生成，缺省）/ 'on_complete'（完成后生成下一次）
  late String _recurrenceMode;
  late List<String> _parentKeys;
  late List<String> _tagKeys;

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    _titleC = TextEditingController(text: it.title == '（无标题）' ? '' : it.title);
    _descC = TextEditingController(text: it.description);
    _intervalC = TextEditingController(text: '${it.recurrenceInterval}');
    _priority = it.priority;
    _status = it.status ?? (it.completed ? 'completed' : 'not_started');
    _dueDate = parseTodoDateTime(it.dueDate);
    _reminderOn = it.deadlineReminder == 1;
    _remindCount = it.remindCount;
    _remindInterval = it.remindInterval;
    _remindUnit = it.remindIntervalUnit;
    _recurrenceOn = it.isTemplate;
    _recurrenceRule = it.recurrenceRule ?? 'daily';
    _recurrenceInterval = it.recurrenceInterval;
    _weekdays = List<int>.from(it.recurrenceWeekdays);
    _recurrenceEnd = parseTodoDateTime(it.recurrenceEnd);
    // F2：'on_complete' 之外一律回退 fixed（对齐 PC RecurrenceMode 缺省口径）
    _recurrenceMode = it.recurrenceMode == 'on_complete' ? 'on_complete' : 'fixed';
    _parentKeys = List<String>.from(it.parentIds);
    _tagKeys = List<String>.from(it.tags);
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _intervalC.dispose();
    super.dispose();
  }

  void _setState(void Function() fn) => setState(fn);

  /// 周期实例不允许编辑重复规则（build 与 _save 共用）
  bool get allowRecurrence => widget.initial.isRecurrenceInstance != 1;

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: context.theme.typography.body.sm
              .copyWith(color: context.theme.colors.mutedForeground),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.theme;

    return _sheetScaffold(
      context: context,
      title: widget.initial.createTime == null ? '新增待办' : '编辑待办',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题：label + 输入框（与习惯弹窗同构：label/value 同 14，间距 6）
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                '标题',
                style: t.typography.body.sm.copyWith(
                  fontSize: 14,
                  color: t.colors.mutedForeground,
                ),
              ),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.colors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        type: MaterialType.transparency,
                        child: TextField(
                          controller: _titleC,
                          style: t.typography.body.sm.copyWith(
                            fontSize: 14,
                            color: t.colors.foreground,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: '输入标题',
                            hintStyle: t.typography.body.sm.copyWith(
                              fontSize: 14,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 描述（可选）：label + 多行输入框
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                '描述（可选）',
                style: t.typography.body.sm.copyWith(
                  fontSize: 14,
                  color: t.colors.mutedForeground,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: t.colors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.colors.border),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: _descC,
                    maxLines: null,
                    minLines: 2,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: t.colors.foreground,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: '请输入描述',
                      hintStyle: t.typography.body.sm.copyWith(
                        fontSize: 14,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 优先级
          _fieldLabel('优先级'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kTodoPriorityOptions)
                _choiceChip(
                  context,
                  label: p.$2,
                  selected: _priority == p.$1,
                  color: priorityColor(p.$1),
                  onTap: () => _setState(() => _priority = p.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 状态
          _fieldLabel('状态'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in kTodoStatusOptions)
                _choiceChip(
                  context,
                  label: s.$2,
                  selected: _status == s.$1,
                  color: statusMetaOf(context, s.$1).color,
                  onTap: () => _setState(() => _status = s.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 到期时间：点击 → forui 六列滚轮抽屉（年 / 月 / 日 / 时 / 分 / 秒 各一列），
          // 落库格式本就是 'YYYY-MM-DD HH:mm:ss'（含秒），与这里的选择精度一致
          _fieldLabel('到期时间'),
          FTappable(
            onPress: () async {
              final d = await showDateTimeWheelSheet(
                context,
                initial: _dueDate,
                title: '到期时间',
              );
              // 取消（返回 null）保留原值；清空走字段右侧 x 按钮
              if (d != null && mounted) _setState(() => _dueDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Icon(FLucideIcons.calendar, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? '未设置'
                          : _formatDateTime(_dueDate!),
                      style: t.typography.body.md,
                    ),
                  ),
                  if (_dueDate != null)
                    GestureDetector(
                      onTap: () => _setState(() => _dueDate = null),
                      child: Icon(FLucideIcons.x, size: 16, color: t.colors.mutedForeground),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 截止提醒
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(FLucideIcons.bell, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 8),
                  const Text('截止提醒'),
                ],
              ),
              FSwitch(
                value: _reminderOn,
                onChange: (v) => _setState(() => _reminderOn = v),
              ),
            ],
          ),
          if (_reminderOn) ...[
            const SizedBox(height: 10),
            Text('提前 $_remindCount 次 · 间隔 $_remindInterval ${_remindUnit == 'hour' ? '小时' : '分钟'}（移动端于截止时刻提醒一次）',
                style: t.typography.body.xs.copyWith(color: t.colors.mutedForeground)),
          ],
          const SizedBox(height: 16),
          // 重复
          if (allowRecurrence) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(FLucideIcons.repeat, size: 18, color: t.colors.mutedForeground),
                    const SizedBox(width: 8),
                    const Text('重复'),
                  ],
                ),
                FSwitch(
                  value: _recurrenceOn,
                  onChange: (v) => _setState(() => _recurrenceOn = v),
                ),
              ],
            ),
            if (_recurrenceOn) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choiceChip(context, label: '每天', selected: _recurrenceRule == 'daily',
                      onTap: () => _setState(() => _recurrenceRule = 'daily')),
                  _choiceChip(context, label: '每周', selected: _recurrenceRule == 'weekly',
                      onTap: () => _setState(() => _recurrenceRule = 'weekly')),
                  // E4：月 / 年规则（对齐 PC RecurrenceRule 扩展）
                  _choiceChip(context, label: '每月', selected: _recurrenceRule == 'monthly',
                      onTap: () => _setState(() => _recurrenceRule = 'monthly')),
                  _choiceChip(context, label: '每年', selected: _recurrenceRule == 'yearly',
                      onTap: () => _setState(() => _recurrenceRule = 'yearly')),
                ],
              ),
              // E4 hint：月/年命中的锚点口径（与 PC ruleHit 一致）
              if (_recurrenceRule == 'monthly' || _recurrenceRule == 'yearly') ...[
                const SizedBox(height: 8),
                Text(
                  _recurrenceRule == 'monthly'
                      ? '按模板当天「几号」重复（当月无此号则跳过）'
                      : '按模板当天「月-日」重复（2/29 只在闰年命中）',
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('每'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: FTextField(
                      control: FTextFieldControl.managed(
                        controller: _intervalC,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmit: (v) => _setState(() {
                        _recurrenceInterval = int.tryParse(v) ?? 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(switch (_recurrenceRule) {
                    'weekly' => '周',
                    'monthly' => '月',
                    'yearly' => '年',
                    _ => '天',
                  }),
                ],
              ),
              if (_recurrenceRule == 'weekly') ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var w = 0; w < 7; w++)
                      _choiceChip(
                        context,
                        label: ['日', '一', '二', '三', '四', '五', '六'][w],
                        selected: _weekdays.contains(w),
                        onTap: () => _setState(() {
                          if (_weekdays.contains(w)) {
                            _weekdays.remove(w);
                          } else {
                            _weekdays.add(w);
                          }
                          if (_weekdays.isEmpty) _weekdays = [w];
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              FTappable(
                onPress: () async {
                  final d = await showTodoDateTimeSheet(
                    context,
                    initial: _recurrenceEnd,
                    dateOnly: true,
                  );
                  if (mounted) _setState(() => _recurrenceEnd = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.colors.muted,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: t.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(FLucideIcons.calendar, size: 18, color: t.colors.mutedForeground),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _recurrenceEnd == null ? '结束日期（可选）' : _fmtDate(_recurrenceEnd!),
                          style: t.typography.body.md,
                        ),
                      ),
                      if (_recurrenceEnd != null)
                        GestureDetector(
                          onTap: () => _setState(() => _recurrenceEnd = null),
                          child: Icon(FLucideIcons.x, size: 16, color: t.colors.mutedForeground),
                        ),
                    ],
                  ),
                ),
              ),
              // F2 生成方式（仅规则非空时显示；实例行不显示本区，实例禁改区不受影响）
              const SizedBox(height: 12),
              _fieldLabel('生成方式'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choiceChip(
                    context,
                    label: '到点自动生成',
                    selected: _recurrenceMode == 'fixed',
                    onTap: () => _setState(() => _recurrenceMode = 'fixed'),
                  ),
                  _choiceChip(
                    context,
                    label: '完成后生成下一次',
                    selected: _recurrenceMode == 'on_complete',
                    onTap: () =>
                        _setState(() => _recurrenceMode = 'on_complete'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '到点自动生成 = 周期到点自动出现下一期；完成后生成下一次 = 完成当前一期后才生成下一期',
                style: t.typography.body.xs.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          // E3：已专注分钟（>0 时只读展示，参照 PC 详情；编辑不提供入口，由番茄钟累计）
          if (widget.initial.focusedMinutes > 0) ...[
            Row(
              children: [
                Icon(FLucideIcons.timer, size: 16, color: t.colors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  '🍅 已专注 ${widget.initial.focusedMinutes} 分钟',
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // 父任务
          _fieldLabel('父任务'),
          FTappable(
            onPress: () async {
              final res = await showTodoParentSheet(
                context,
                candidates: widget.allTodos,
                selected: _parentKeys,
                excludeKey: widget.initial.key,
              );
              if (res != null && mounted) _setState(() => _parentKeys = res);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Icon(FLucideIcons.userPlus, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _parentKeys.isEmpty
                        ? Text('选择父任务（可选）', style: t.typography.body.md)
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _parentKeys
                                .map((k) => Chip(
                                      label: Text(
                                        widget.allTodos
                                                .firstWhere((e) => e.key == k,
                                                    orElse: () => widget.initial)
                                                .title,
                                        style: t.typography.body.xs,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 标签
          _fieldLabel('标签'),
          FTappable(
            onPress: () async {
              final res = await showTodoTagSheet(
                context,
                widget.ref,
                tags: widget.tags,
                selected: _tagKeys,
              );
              if (res != null && mounted) _setState(() => _tagKeys = res);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.muted,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Icon(FLucideIcons.tag, size: 18, color: t.colors.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tagKeys.isEmpty
                        ? Text('选择标签（可选）', style: t.typography.body.md)
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _tagKeys
                                .map((k) {
                                  final tag = widget.tags
                                      .firstWhere((e) => e.key == k,
                                          orElse: () => const TodoTagView(
                                              key: '', name: '?', color: '#888888'));
                                  return Chip(
                                    label: Text(tag.name,
                                        style: t.typography.body.xs),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  );
                                })
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: [
        Expanded(
          child: GradientButton(
            label: '保存',
            icon: FLucideIcons.check,
            onPress: () => _save(),
          ),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('标题不能为空'),
      );
      return;
    }
    final now = _now();
    final completed = _status == 'completed';
    final item = TodoItem(
      key: widget.initial.key,
      title: title,
      description: _descC.text.trim(),
      completed: completed,
      priority: _priority,
      dueDate: _dueDate == null ? null : _formatDateTime(_dueDate!),
      completedTime: completed
          ? (widget.initial.completed ? widget.initial.completedTime ?? now : now)
          : null,
      tags: _tagKeys,
      status: _status,
      deadlineReminder: _reminderOn ? 1 : 0,
      remindCount: _remindCount,
      remindInterval: _remindInterval,
      remindIntervalUnit: _remindUnit,
      createTime: widget.initial.createTime ?? now,
      updateTime: now,
      sortOrder: widget.initial.sortOrder,
      parentIds: _parentKeys,
      recurrenceRule: (_recurrenceOn && allowRecurrence) ? _recurrenceRule : null,
      recurrenceInterval: _recurrenceInterval,
      recurrenceWeekdays: (_recurrenceOn && _recurrenceRule == 'weekly')
          ? _weekdays
          : const [],
      recurrenceEnd: _recurrenceEnd == null ? null : _fmtDate(_recurrenceEnd!),
      recurrenceId: widget.initial.recurrenceId,
      isRecurrenceInstance: widget.initial.isRecurrenceInstance,
      // E3/E5：软删除标记与专注分钟原样带出（编辑保存不得冲掉既有值）
      deleted: widget.initial.deleted,
      focusedMinutes: widget.initial.focusedMinutes,
      // F2：生成方式随保存链路写入 upsertTodo（仅模板可改；实例/非重复保持原值）
      recurrenceMode: (_recurrenceOn && allowRecurrence)
          ? _recurrenceMode
          : widget.initial.recurrenceMode,
    );
    Navigator.pop(context, item);
  }

  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 打开新增/编辑抽屉，返回保存后的 TodoItem（取消返回 null）
Future<TodoItem?> showTodoEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required TodoItem initial,
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) {
  return _showTodoSheet<TodoItem?>(
    context: context,
    builder: (c) => _TodoEditSheet(
      initial: initial,
      allTodos: allTodos,
      tags: tags,
      ref: ref,
    ),
  );
}

// ===================== 10. 待办详情（只读查看） =====================

/// 详情抽屉的出口动作（查看态本身不写数据，只把「接下来去哪」交回调用方）
enum TodoDetailAction { edit, record }

/// 详情抽屉的返回结果：动作 + 目标条目。
///
/// 为什么要带 item：详情里点父任务 chip 会**再开一层详情**（和 PC 一样可层层往下看），
/// 在里层点「编辑」时结果会逐层上抛，此时要编辑的是里层那一条，不是外层传进去的那条。
class TodoDetailResult {
  const TodoDetailResult(this.action, this.item);

  final TodoDetailAction action;
  final TodoItem item;
}

/// 待办详情（只读）。
///
/// 入口：列表卡片 / 卡片视图 / 日历当天抽屉 —— 单击待办**先看，再决定改不改**，
/// 要修改时点底部「编辑」进表单（PC 列表单击是直接进编辑表单，移动端按交互约定
/// 改为查看优先，避免误触即改）。删除 / 记录进展在列表卡片的 ⋯ 菜单里，本抽屉只
/// 提供「记录进展」和「编辑」两个出口。
///
/// 展示字段对齐 PC TodoDetailDialog 只读态：标题 / 描述 / 优先级 / 截止时间 /
/// 截止提醒 / 重复 / 关联父任务（可点进父任务详情）/ 标签 / 状态 / 完成时间，
/// 另补「子任务进度」「创建时间」（列表卡片上已有这两项，详情里给全）。
Future<TodoDetailResult?> showTodoDetailSheet(
  BuildContext context,
  WidgetRef ref,
  TodoItem item, {
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) {
  return _showTodoSheet<TodoDetailResult>(
    context: context,
    builder: (c) {
      final t = c.theme;
      final status = effectiveStatus(item);
      final meta = statusMetaOf(c, status);
      final done = status == 'completed';
      final tagMap = {for (final tg in tags) tg.key: tg};
      final tagViews = [
        for (final k in item.tags)
          if (tagMap.containsKey(k)) tagMap[k]!,
      ];
      final parents = parentItemsOf(allTodos, item);
      final progress = subtaskProgress(allTodos, item.key);
      final due = formatTodoDue(item.dueDate);
      final recur = formatRecurrence(
        item.recurrenceRule,
        item.recurrenceInterval,
        item.recurrenceWeekdays,
      );
      final remind = item.deadlineReminder == 1
          ? '提前 ${item.remindCount} 次 · 每 ${item.remindInterval} '
                '${item.remindIntervalUnit == 'hour' ? '小时' : '分钟'}'
          : '关闭';

      return _sheetScaffold(
        context: c,
        title: '待办详情',
        size: SheetSize.lg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题：弹窗内条目标题字号（比弹窗标题小 2 号 = 15）
            Text(
              item.title,
              style: t.typography.body.lg.copyWith(
                fontSize: AppTokens.sheetFieldTitleFontSize,
                fontWeight: FontWeight.w700,
                height: 1.35,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? t.colors.mutedForeground : t.colors.foreground,
              ),
            ),
            const SizedBox(height: 10),
            // 状态 / 优先级（+ 重复模板/实例标记）
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _softChip(c, meta.label, meta.color, 0.15),
                _softChip(
                  c,
                  '优先级 ${priorityLabel(item.priority)}',
                  priorityColor(item.priority),
                  0.14,
                ),
                if (item.isTemplate)
                  _softChip(c, '重复模板', AppTokens.accent(1), 0.12),
                if (item.isRecurrenceInstance == 1)
                  _softChip(c, '重复实例', AppTokens.accent(1), 0.12),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.description,
                style: t.typography.body.md.copyWith(
                  fontSize: 14,
                  height: 1.55,
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: t.colors.border),
            const SizedBox(height: 4),
            _detailRow(
              c,
              FLucideIcons.calendarClock,
              '到期时间',
              _detailText(c, due ?? '未设置', primary: due != null),
            ),
            _detailRow(c, FLucideIcons.bell, '截止提醒', _detailText(c, remind)),
            _detailRow(
              c,
              FLucideIcons.repeat,
              '重复',
              _detailText(
                c,
                recur.isEmpty
                    ? '不重复'
                    : (item.recurrenceEnd == null
                          ? recur
                          : '$recur · 至 ${item.recurrenceEnd}'),
              ),
            ),
            _detailRow(
              c,
              FLucideIcons.link,
              '关联父任务',
              parents.isEmpty
                  ? _detailText(c, '无')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in parents)
                          _parentChip(c, ref, p, allTodos: allTodos, tags: tags),
                      ],
                    ),
            ),
            _detailRow(
              c,
              FLucideIcons.tag,
              '标签',
              tagViews.isEmpty
                  ? _detailText(c, '无')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tagViews)
                          _softChip(
                            c,
                            tag.name,
                            _parseColor(tag.color),
                            0.14,
                          ),
                      ],
                    ),
            ),
            if (progress != null)
              _detailRow(
                c,
                FLucideIcons.listChecks,
                '子任务',
                _detailText(c, '已完成 ${progress.done}/${progress.total} 项'),
              ),
            // E3：已专注分钟（>0 时只读行，参照 PC 详情；累计由番茄钟联动完成）
            if (item.focusedMinutes > 0)
              _detailRow(
                c,
                FLucideIcons.timer,
                '已专注',
                _detailText(c, '🍅 ${item.focusedMinutes} 分钟'),
              ),
            _detailRow(
              c,
              FLucideIcons.clock,
              '创建时间',
              _detailText(c, item.createTime ?? '—'),
            ),
            if ((item.completedTime ?? '').isNotEmpty)
              _detailRow(
                c,
                FLucideIcons.check,
                '完成时间',
                _detailText(c, item.completedTime!, primary: true),
              ),
          ],
        ),
        bottomBar: [
          Expanded(
            child: FTappable(
              onPress: () => Navigator.pop(
                c,
                TodoDetailResult(TodoDetailAction.record, item),
              ),
              child: _sheetButton(
                c,
                label: '记录进展',
                bg: t.colors.muted,
                fg: t.colors.foreground,
              ),
            ),
          ),
          Expanded(
            child: GradientButton(
              label: '编辑',
              icon: FLucideIcons.pencil,
              height: 46,
              onPress: () => Navigator.pop(
                c,
                TodoDetailResult(TodoDetailAction.edit, item),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 打开待办详情抽屉，并按出口动作继续（编辑 → 表单；记录进展 → 记录抽屉）。
///
/// 列表卡片 / 卡片视图 / 日历当天抽屉三处入口**共用本函数**，保证单击行为一致、
/// 不出现「某处点开是查看、某处点开是编辑」的漂移。
Future<void> openTodoDetail(
  BuildContext context,
  WidgetRef ref,
  TodoItem item, {
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) async {
  final result = await showTodoDetailSheet(
    context,
    ref,
    item,
    allTodos: allTodos,
    tags: tags,
  );
  if (result == null || !context.mounted) return;
  switch (result.action) {
    case TodoDetailAction.edit:
      final saved = await showTodoEditSheet(
        context,
        ref,
        initial: result.item,
        allTodos: allTodos,
        tags: tags,
      );
      if (saved != null) {
        await ref.read(todoRepositoryProvider).upsertTodo(saved);
      }
    case TodoDetailAction.record:
      await showRecordProgressSheet(context, ref, result.item);
  }
}

/// 父任务 chip：点击进入该父任务的只读详情；在里层产生的动作逐层上抛给最外层入口。
Widget _parentChip(
  BuildContext c,
  WidgetRef ref,
  TodoItem parent, {
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) {
  final t = c.theme;
  return FTappable(
    onPress: () async {
      final r = await showTodoDetailSheet(
        c,
        ref,
        parent,
        allTodos: allTodos,
        tags: tags,
      );
      // 内层抽屉已关闭，此时栈顶是当前这一层 → 原样带出去，交给上层（或页面）处理
      if (r != null && c.mounted) Navigator.pop(c, r);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.accent(1).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FLucideIcons.cornerDownRight, size: 12, color: AppTokens.accent(1)),
          const SizedBox(width: 4),
          Text(
            parent.title,
            style: t.typography.body.xs.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.colors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 详情里的软底 chip（状态 / 优先级 / 标签 / 重复标记；同色底 alpha · r10 · 11/SemiBold）
Widget _softChip(BuildContext c, String label, Color color, double alpha) =>
    Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: c.theme.typography.body.xs.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );

/// 详情信息行：左「图标 + 固定宽标签」，右值自适应（值可能是文本，也可能是 chip 组）
Widget _detailRow(BuildContext c, IconData icon, String label, Widget value) {
  final t = c.theme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: t.colors.mutedForeground),
        const SizedBox(width: 8),
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: t.typography.body.sm.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
            ),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );
}

/// 详情里的文本型值（primary = 主色强调，用于「到期时间」「完成时间」）
Widget _detailText(BuildContext c, String text, {bool primary = false}) {
  final t = c.theme;
  return Text(
    text,
    style: t.typography.body.md.copyWith(
      fontSize: 14,
      height: 1.4,
      fontWeight: primary ? FontWeight.w600 : FontWeight.w400,
      color: primary ? AppTokens.accent(1) : t.colors.foreground,
    ),
  );
}

// ===================== 8. 操作菜单 + 删除确认 =====================

/// 单条待办的操作项
enum TodoAction { edit, record, delete, focusPomodoro, unfocusPomodoro }

/// 操作菜单（底部抽屉）：编辑 / 记录进展 / 番茄钟专注关联（E3）/ 删除。
/// 「番茄钟专注此待办」写 SharedPreferences 键 `todo.pomodoroLink`（值为待办 key，
/// 空串 = 未关联）；UI 态按当前已关联 key 判断显示「专注此待办」还是「取消专注关联」。
Future<void> showTodoActionSheet(
  BuildContext context,
  WidgetRef ref,
  TodoItem item, {
  required List<TodoItem> allTodos,
  required List<TodoTagView> tags,
}) async {
  // E3：先取当前关联态（抽屉内选项随它切换）
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  final linkedKey = prefs.getString(kTodoPomodoroLinkKey) ?? '';
  final isLinked = linkedKey == item.key;
  final action = await _showTodoSheet<TodoAction?>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: '操作',
      size: SheetSize.sm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionRow(
            c,
            label: '编辑',
            icon: FLucideIcons.pencil,
            onTap: () => Navigator.pop(c, TodoAction.edit),
          ),
          _actionRow(
            c,
            label: '记录进展',
            icon: FLucideIcons.bell,
            onTap: () => Navigator.pop(c, TodoAction.record),
          ),
          _actionRow(
            c,
            label: isLinked ? '取消专注关联' : '番茄钟专注此待办',
            icon: FLucideIcons.timer,
            onTap: () => Navigator.pop(
              c,
              isLinked ? TodoAction.unfocusPomodoro : TodoAction.focusPomodoro,
            ),
          ),
          _actionRow(
            c,
            label: '删除',
            icon: FLucideIcons.trash2,
            destructive: true,
            onTap: () => Navigator.pop(c, TodoAction.delete),
          ),
        ],
      ),
    ),
  );
  if (action == null) return;
  final repo = ref.read(todoRepositoryProvider);
  if (!context.mounted) return;
  switch (action) {
    case TodoAction.edit:
      if (!context.mounted) return;
      final edited = await showTodoEditSheet(
        context,
        ref,
        initial: item,
        allTodos: allTodos,
        tags: tags,
      );
      if (edited != null) await repo.upsertTodo(edited);
    case TodoAction.record:
      if (!context.mounted) return;
      await showRecordProgressSheet(context, ref, item);
    case TodoAction.focusPomodoro:
      // E3：写入关联键；专注段完整走完时由番茄钟页累计 focusedMinutes
      await prefs.setString(kTodoPomodoroLinkKey, item.key);
      if (context.mounted) {
        showFToast(
          context: context,
          title: const Text('已关联，专注一轮即为其累计分钟'),
        );
      }
    case TodoAction.unfocusPomodoro:
      await prefs.setString(kTodoPomodoroLinkKey, '');
      if (context.mounted) {
        showFToast(context: context, title: const Text('已取消专注关联'));
      }
    case TodoAction.delete:
      if (!context.mounted) return;
      final ok = await showTodoConfirmSheet(
        context,
        '删除待办',
        '确定删除「${item.title}」及其全部子任务？（可在回收站恢复）',
      );
      if (ok == true) await repo.deleteTodo(item.key);
  }
}

Widget _actionRow(
  BuildContext context, {
  required String label,
  required IconData icon,
  bool destructive = false,
  required VoidCallback onTap,
}) {
  final t = context.theme;
  final color = destructive ? t.colors.destructive : t.colors.foreground;
  return FTappable(
    onPress: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 14),
          Text(label, style: t.typography.body.md.copyWith(color: color)),
        ],
      ),
    ),
  );
}

/// 通用删除/危险确认（底部抽屉，取消/关闭返回 false 或 null，确认返回 true）
Future<bool?> showTodoConfirmSheet(
  BuildContext context,
  String title,
  String message,
) async {
  return _showTodoSheet<bool>(
    context: context,
    builder: (c) => _sheetScaffold(
      context: c,
      title: title,
      size: SheetSize.sm,
      body: Text(
        message,
        style: c.theme.typography.body.md,
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: FButton(
            variant: FButtonVariant.destructive,
            onPress: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ),
      ],
    ),
  );
}

// ===================== 11. 回收站（E5 软删除） =====================

/// 回收站抽屉（lg 定高）：软删除待办列表（标题 + 删除时间 + 恢复 / 彻底删除），
/// 底部「清空回收站」危险确认。数据走 [todoDeletedProvider]，操作调
/// restoreTodo / purgeTodo 后由 drift watch 自动刷新。
Future<void> showTodoRecycleBinSheet(BuildContext context, WidgetRef ref) {
  return _showTodoSheet<void>(
    context: context,
    builder: (c) => const _TodoRecycleBinSheet(),
  );
}

class _TodoRecycleBinSheet extends ConsumerWidget {
  const _TodoRecycleBinSheet();

  /// 清空回收站：逐条彻底删除（含各自子任务此前已随删入站）
  Future<void> _purgeAll(BuildContext context, WidgetRef ref, int count) async {
    final ok = await showTodoConfirmSheet(
      context,
      '清空回收站',
      '确定彻底删除回收站内的 $count 项待办？不可恢复。',
    );
    if (ok != true) return;
    final repo = ref.read(todoRepositoryProvider);
    final items = await repo.watchDeletedTodos().first;
    for (final it in items) {
      await repo.purgeTodo(it.key);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    // 红线 #28：抽屉内容用自己的 Consumer ref 订阅流（不归页面 element 所有）
    final items = ref.watch(todoDeletedProvider).value ?? const <TodoItem>[];
    return _sheetScaffold(
      context: context,
      title: '回收站',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            '删除的待办在此保留 30 天，之后自动彻底删除；恢复后回到待办列表。',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  '回收站是空的',
                  style: t.typography.body.sm.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ),
            )
          else
            for (final item in items) _RecycleRow(item: item),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FTappable(
            onPress:
                items.isEmpty ? null : () => _purgeAll(context, ref, items.length),
            child: _sheetButton(
              context,
              label: items.isEmpty ? '清空回收站' : '清空回收站（${items.length}）',
              bg: t.colors.destructive,
              fg: t.colors.primaryForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// 回收站行：标题 + 删除时间（updateTime）+ 恢复 / 彻底删除（样式对齐标签管理行）
class _RecycleRow extends ConsumerWidget {
  const _RecycleRow({required this.item});

  final TodoItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  item.title,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.colors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '删除于 ${item.updateTime ?? '—'}',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          _rowIcon(context, FLucideIcons.rotateCcw, () async {
            await ref
                .read(todoRepositoryProvider)
                .restoreTodo(item.key);
            if (context.mounted) {
              showFToast(context: context, title: const Text('已恢复到待办列表'));
            }
          }),
          _rowIcon(
            context,
            FLucideIcons.trash2,
            () async {
              final ok = await showSheetConfirm(
                context,
                title: '彻底删除',
                message: '彻底删除「${item.title}」？不可恢复。',
              );
              if (!ok) return;
              await ref.read(todoRepositoryProvider).purgeTodo(item.key);
            },
            destructive: true,
          ),
        ],
      ),
    );
  }

  Widget _rowIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: destructive ? t.colors.destructive : t.colors.mutedForeground,
        ),
      ),
    );
  }
}

// ===================== 工具 =====================

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF8b5cf6);
  try {
    return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) |
        (hex.length == 7 ? 0xFF000000 : 0));
  } catch (_) {
    return const Color(0xFF8b5cf6);
  }
}
