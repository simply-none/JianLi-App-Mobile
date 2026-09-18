// 主题对话「富文本编辑」页 —— 沉浸式（画布《新建笔记页重设计-3方案》方案 B 的同构形态）
//
// 为什么是独立页而不是底部抽屉（2026-09-18 定案）：
//   富文本编辑器需要「编辑区 + 工具条 + 软键盘」三者同时在屏。底部抽屉按红线 #9 的 lg 档
//   必须 `resizeToAvoidBottomInset: false` 且不扣键盘 → 键盘会盖住抽屉下半屏，工具条只能
//   挪到抽屉顶部，可见编辑区被压到约 35vh。独立页则随键盘自然收缩，工具条常驻键盘上方，
//   与笔记编辑页方案 B 完全同构（含红线 #24 的三条 quill 键盘/焦点铁律）。
//
// 职责边界（刻意收紧）：**只负责内容**。
//   - 标签 / 引用草稿从快速输入栏带进来（可点掉），发送时一并写入；选择入口仍留在快速输入栏。
//     理由：快速输入栏是「一次发送会话」的持有者，两处各放一套选择器会让草稿状态分裂。
//   - 编辑已有对话时只改内容（对齐 PC ConversationEditDialog）：标签改走长按菜单「标签」项，
//     与移动端既有分工一致，不在这里捎带。
//
// 数据契约（对齐 PC ChatInput / ConversationEditDialog）：
//   提交的是**富文本 HTML**（Delta → vsc_quill_delta_to_html），由仓库侧
//   `normalizeContent` 判定「是否含实际格式」再决定 `is_rich` 落 '1' 还是 '0'
//   —— 即「用户在富文本里只打了纯文字」会自动降级为纯文本，不留半脏行。
import 'package:flutter_quill/flutter_quill.dart';
// flutter_quill 主入口不转发 Delta，须显式引（= dart_quill_delta）
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
// ⚠️ forui 也导出 mixin Delta，必须 hide（详见 SKILL.md 红线 #23①）
import 'package:forui/forui.dart' hide Delta;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../core/db/app_database.dart';
import '../../../core/text/rich_text.dart';
import '../repositories/conversation_repository.dart';
import 'conversation_chips.dart';

/// 主题对话富文本编辑页
///
/// [messageId] 为空 = 新建；非空 = 编辑该条对话的内容。
class ConversationComposePage extends ConsumerStatefulWidget {
  const ConversationComposePage({
    super.key,
    required this.themeId,
    this.messageId,
    this.initialTagIds = const <String>{},
    this.initialRefIds = const <int>{},
  });

  final String themeId;

  /// 非 null = 编辑已有对话（只改内容，见文件头「职责边界」）
  final int? messageId;

  /// 从快速输入栏带过来的标签草稿（发送时一并写入）
  final Set<String> initialTagIds;

  /// 从快速输入栏带过来的引用草稿（消息 id；发送时按归属拆 ref_ids / cross_refs）
  final Set<int> initialRefIds;

  @override
  ConsumerState<ConversationComposePage> createState() =>
      _ConversationComposePageState();
}

class _ConversationComposePageState
    extends ConsumerState<ConversationComposePage> {
  /// 富文本文档控制器（非 null = 已就绪；编辑态等待回显期间为 null）
  QuillController? _quill;

  /// 富文本编辑器的**持久** FocusNode / ScrollController。
  ///
  /// ⚠️ 必须由 State 持有，**不能依赖 `QuillEditor.basic` 在 build 里现造**（红线 #24①）：
  /// `.basic` 每次 build 都新建这两个对象，而**键盘 inset 变化本身就会触发重建**
  /// → 节点被换掉 → 旧节点失焦 → 引擎收起键盘（「键盘弹一下就没了」）。
  final _richFocus = FocusNode(debugLabel: 'convComposeRich');
  final _richScroll = ScrollController();

  /// 工具条范围锚点：`onTapOutside` 用它豁免「点在工具条上」（红线 #24③）
  final _toolbarKey = GlobalKey();

  /// 本次发送要附带的标签 / 引用（从快速输入栏带入，可点掉）
  final Set<String> _tagIds = {};
  final Set<int> _refIds = {};

  bool _saving = false;

  bool get _isEdit => widget.messageId != null;

  @override
  void initState() {
    super.initState();
    _tagIds.addAll(widget.initialTagIds);
    _refIds.addAll(widget.initialRefIds);
    if (_isEdit) {
      _loadForEdit();
    } else {
      _quill = _controllerOf(_plainDelta(''), focus: true);
    }
  }

  @override
  void dispose() {
    _quill?.dispose();
    // 子树先卸载（Flutter children-first），此处再释放节点是安全的
    _richFocus.dispose();
    _richScroll.dispose();
    super.dispose();
  }

  // ---------- 文档构造 ----------

  /// 纯文本 → Delta（按行分段；空文本给一个空行，保证 Quill 文档合法）
  static Delta _plainDelta(String text) {
    final delta = Delta();
    final lines = text.split('\n');
    if (lines.length == 1 && lines.first.trim().isEmpty) {
      delta.insert('\n');
      return delta;
    }
    for (final line in lines) {
      delta.insert('$line\n');
    }
    return delta;
  }

  /// Delta → 控制器。
  ///
  /// ⚠️ 必须走 `Document.fromJson(delta.toJson())` 而不是 `Document.fromDelta`：
  /// `fromJson` 内部的 `_transform` 会补齐结尾换行，而 `HtmlToDelta` 的产物末尾常缺 `\n`，
  /// 不补会让文档非法（红线 #23④）。[focus] = 本帧挂载后是否立刻聚焦拉起键盘。
  QuillController _controllerOf(Delta delta, {required bool focus}) {
    final c = QuillController(
      document: Document.fromJson(delta.toJson()),
      selection: const TextSelection.collapsed(offset: 0),
    );
    if (focus) {
      // 用户点 Aa 就是「我要开始写」，直接聚焦拉起键盘；但必须等本帧编辑器挂载完，
      // 否则 requestFocus 打在未 attach 的节点上等于没聚焦。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _richFocus.requestFocus();
      });
    }
    return c;
  }

  /// 编辑态：回显已有内容
  ///
  /// 按 `is_rich` 决定种子来源（对齐 PC `ConversationEditDialog.isRichEdit`）：
  ///   - '1' 且内容确实是 HTML → `HtmlToDelta`（保留 PC vue-quill 的格式）
  ///   - 否则（含 `is_rich='1'` 但内容无标签的脏数据）→ 按纯文本段落构造
  Future<void> _loadForEdit() async {
    final msg = await ref
        .read(conversationRepositoryProvider)
        .getMessage(widget.messageId!);
    if (!mounted) return;
    if (msg == null) {
      showFToast(context: context, title: const Text('这条对话已不存在'));
      context.pop();
      return;
    }
    final raw = msg.content ?? '';
    final asRich = msg.isRich == '1' && isHtml(raw);
    Delta delta;
    if (asRich) {
      try {
        delta = HtmlToDelta().convert(raw);
      } catch (_) {
        // HTML→Delta 解析失败：降级为纯文本段落（experimental 转换的兜底，永不崩）
        delta = _plainDelta(stripTags(raw));
      }
    } else {
      delta = _plainDelta(raw);
    }
    setState(() => _quill = _controllerOf(delta, focus: true));
  }

  /// Delta → HTML（vsc_quill_delta_to_html：`p` / `ul` / `ol` / `h1-3` / `blockquote` /
  /// `pre` 等结构与 PC vue-quill 输出同源，PC 气泡 CSS 已覆盖这批标签）
  String _deltaToHtml() {
    final converter = QuillDeltaToHtmlConverter(
      _quill!.document.toDelta().toJson().cast<Map<String, dynamic>>(),
    );
    return converter.convert();
  }

  // ---------- 提交 ----------

  Future<void> _submit() async {
    if (_saving) return;
    final html = _deltaToHtml();
    // 判空走 stripTags（对齐 PC isEmpty）：纯文字也算有内容，只是会被归一化为纯文本
    if (isBlankContent(html)) {
      showFToast(context: context, title: const Text('内容不能为空'));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(conversationRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateMessageContent(widget.messageId!, html);
      } else {
        // 引用草稿按归属分类：同主题 → ref_ids；跨主题 → cross_refs（对齐桌面端语义）
        final all =
            ref.read(allConversationsProvider).value ??
            const <ConversationData>[];
        final byId = {for (final c in all) c.id: c};
        final sameRefs = <String>[];
        final crossRefs = <({int themeId, int convId})>[];
        for (final id in _refIds) {
          final m = byId[id];
          if (m == null) continue;
          if (m.themeId == widget.themeId) {
            sameRefs.add('$id');
          } else {
            crossRefs.add((
              themeId: int.tryParse(m.themeId ?? '') ?? 0,
              convId: id,
            ));
          }
        }
        await repo.addMessage(
          themeId: widget.themeId,
          content: html,
          tagIds: _tagIds.toList(),
          refIds: sameRefs,
          crossRefs: crossRefs,
        );
      }
      // 新建成功回传 true：调用方（消息页）据此清空自己的标签/引用草稿。
      // 编辑态回传空值 —— 用户快速输入栏里可能还攒着草稿，不该被编辑动作清掉。
      if (mounted) context.pop<bool>(_isEdit ? null : true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showFToast(context: context, title: const Text('保存失败，请重试'));
      }
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 主题名（用于「写入《xxx》」上下文行）。不用 `firstOrNull`（需 package:collection）
    String? title;
    for (final th
        in ref.watch(conversationThemesProvider).value ??
            const <ConversationThemeData>[]) {
      if (th.id.toString() == widget.themeId) {
        title = th.title;
        break;
      }
    }
    return FScaffold(
      // ⚠️ childPad:false：页面边距只由内容区提供（否则会再叠一层，与其他页面不一致）
      childPad: false,
      header: FHeader.nested(
        // 标题左对齐（forui 默认居中），紧贴返回按钮右侧
        titleAlignment: Alignment.centerLeft,
        title: Text(_isEdit ? '编辑对话' : '记录对话'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: _quill == null
          ? const Center(child: FCircularProgress())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  // 主题上下文：明确「这条记录写到哪个主题里」
                  if ((title ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        10,
                        AppTokens.pagePadding,
                        0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            FLucideIcons.folder,
                            size: 12,
                            color: t.colors.mutedForeground,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '写入《$title》',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.typography.body.xs.copyWith(
                                fontSize: 12,
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 本次发送附带的标签 / 引用（仅新建态；编辑态只改内容，见文件头职责边界）
                  if (!_isEdit && (_tagIds.isNotEmpty || _refIds.isNotEmpty))
                    _attachRow(),
                  const SizedBox(height: 10),
                  Expanded(child: _richBody(t)),
                  _richToolbar(),
                  _bottomBar(t),
                ],
              ),
            ),
    );
  }

  /// 已带标签 / 引用草稿行（单行横滑，点掉即移除）
  Widget _attachRow() {
    final tagDefs =
        ref.watch(conversationTagsProvider).value ??
        const <ConversationTagData>[];
    final tagById = {for (final d in tagDefs) d.id.toString(): d};
    final all =
        ref.watch(allConversationsProvider).value ??
        const <ConversationData>[];
    final msgById = {for (final c in all) c.id: c};

    return SizedBox(
      height: 26,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.pagePadding,
        ),
        child: Row(
          children: [
            for (final id in _tagIds)
              if (tagById[id] != null) ...[
                GestureDetector(
                  onTap: () => setState(() => _tagIds.remove(id)),
                  child: ConvTagBadge(tag: tagById[id]!),
                ),
                const SizedBox(width: 6),
              ],
            for (final id in _refIds)
              if (msgById[id] != null) ...[
                ConvRefDraftChip(
                  label: _refLabel(msgById[id]!),
                  onDelete: () => setState(() => _refIds.remove(id)),
                ),
                const SizedBox(width: 6),
              ],
          ],
        ),
      ),
    );
  }

  /// 引用草稿 chip 的短摘要（与消息页 `_short(snippetOf(...), 12)` 同口径）
  static String _refLabel(ConversationData m) {
    final s = snippetOf(m.content, html: m.isRich == '1', max: 12);
    return s.isEmpty ? '（无文本）' : s;
  }

  /// 富文本正文
  ///
  /// ⚠️ 透明 `Material` 不能省：flutter_quill 的长按选区菜单走 Material 的
  /// `AdaptiveTextSelectionToolbar`，forui 的 `FScaffold` 不提供 Material 祖先。
  Widget _richBody(FThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
      child: Material(
        type: MaterialType.transparency,
        // ⚠️ 用完整构造器（而非 `.basic`）并显式传入持久的 focusNode / scrollController
        child: QuillEditor(
          controller: _quill!,
          focusNode: _richFocus,
          scrollController: _richScroll,
          config: QuillEditorConfig(
            placeholder: '记录此刻的思考波动…',
            padding: EdgeInsets.zero,
            // 编辑器撑满 Expanded：默认 false 时可视输入区只有内容高度，空文档≈一行，
            // 观感上像「没有可输入的地方」（红线 #24⑤）
            expands: true,
            autoFocus: false, // 聚焦由 post-frame requestFocus 接管
            // 点空白收键盘，但**豁免工具条**（工具条在编辑器的 TapRegion 之外，
            // 不豁免就是「点一次加粗，键盘和光标一起没了」——红线 #24③）
            onTapOutside: (event, node) {
              final box =
                  _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(event.position);
                if ((Offset.zero & box.size).contains(local)) return;
              }
              node.unfocus();
            },
          ),
        ),
      ),
    );
  }

  /// 富文本工具条：**1:1 对齐 PC `ChatInput.vue` 的飞书式精简配置**
  ///
  /// PC = bold / italic / underline / strike | blockquote / code-block |
  ///      ordered / bullet list | link | header 1·2·3
  /// 移动端 quill 默认会白送颜色 / 高亮 / 行内码 / 缩进 / 对齐 / 上下标 / 待办清单 /
  /// 查找 / 字号 / 字体 / 行高 / 清除格式 —— 全部显式关掉，否则工具条既长又会产生
  /// **PC 端气泡 CSS 没有对应样式**的标签（渲染出来是裸样式）。
  /// ⚠️ 参数名不成规律，改这里前先 grep `simple_toolbar_config.dart` 构造函数（红线 #23②）。
  ///
  /// 有意保留的两个 PC 没有的按钮：[showUndo]/[showRedo] —— 桌面有 Ctrl+Z，手机没有，
  /// 撤销按钮是移动端唯一的撤销途径。它们不产生新格式，不影响双端互通。
  Widget _richToolbar() {
    return Padding(
      // 供编辑器 onTapOutside 判定「点在工具条上」
      key: _toolbarKey,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        4,
        AppTokens.pagePadding,
        0,
      ),
      // ⚠️ 不要再套横向 SingleChildScrollView（红线 #24②：宽度无界会让 quill 内部
      // CustomScrollView 拿不到滚动尺寸 → 空断言 → 打断键盘 inset 的 observer 链）
      child: Material(
        type: MaterialType.transparency,
        child: QuillSimpleToolbar(
          controller: _quill!,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showDividers: true,
            // —— 与 PC 对齐的十项 ——
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true, // ⚠️ 大写 L
            showStrikeThrough: true,
            showQuote: true, // blockquote
            showCodeBlock: true,
            showListNumbers: true,
            showListBullets: true,
            showLink: true,
            showHeaderStyle: true, // 标题 1/2/3
            // —— 仅移动端保留（无 Ctrl+Z）——
            showUndo: true,
            showRedo: true,
            // —— PC 没有 / 会产生无样式标签，全部关闭 ——
            showFontFamily: false,
            showFontSize: false,
            showSmallButton: false,
            showLineHeightButton: false,
            showInlineCode: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showClearFormat: false,
            showListCheck: false,
            showIndent: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showAlignmentButtons: false,
            showDirection: false,
          ),
        ),
      ),
    );
  }

  /// 底部固定条（页面规范：提交按钮固定底部，不随内容滚动）
  Widget _bottomBar(FThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        8,
        AppTokens.pagePadding,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEdit
                  ? '改回纯文字会自动降级为纯文本'
                  : '只打纯文字时会自动存为纯文本',
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                color: t.colors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GradientButton(
            label: _saving
                ? (_isEdit ? '保存中…' : '发送中…')
                : (_isEdit ? '保存' : '发送'),
            icon: _isEdit ? FLucideIcons.check : FLucideIcons.send,
            height: 44,
            fullWidth: false,
            onPress: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
