// 笔记编辑页 —— 方案 B「沉浸编辑器」（画布《新建笔记页重设计-3方案》方案 B，2026-09-18）
//
// 结构（白底沉浸、无卡片）：
//   大标题直排（无边框 26/Bold）→ 元信息 chips 行（**仅已选分类/标签，纯展示**，横滑；
//     无已选项时整行不渲染）
//   → hairline 分隔 → 正文区 Expanded（默认纯文本 TextField，随内容滚动）
//   → 头部右侧 Aa 切换 flutter_quill 富文本（工具条出现在正文下方，单行横滑）
//   → 底部固定条：「分类 n」「标签 n」入口 + 保存胶囊。
//
// 数据契约不变：title / categories(JSON 数组) / tags(标签 key 数组) / html。
// 富文本管线（flutter_quill 11）：
//   - 打开默认纯文本；切富文本时若正文未手改，优先用原始 html 经
//     flutter_quill_delta_from_html 转 Delta（保留 PC vue-quill 样式）；
//     解析失败或已手改则按段落纯文本转 Delta（永不崩溃）。
//   - 保存时经 vsc_quill_delta_to_html（Delta→HTML）走 rawHtml 直落 note_book.html，
//     PC 端 vue-quill 直接可渲染；摘要/搜索仍用 Delta 抽取的纯文本。
import 'package:flutter_quill/flutter_quill.dart';
// flutter_quill 主入口不转发 Delta，须显式引 quill_delta.dart（= dart_quill_delta）
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
// ⚠️ forui 也导出一个 mixin Delta（主题 style delta，无构造函数），会顶掉 quill 的 Delta：
// 必须 hide，否则 Delta() 报「找不到构造函数」、且与 HtmlToDelta().convert() 返回型不匹配。
import 'package:forui/forui.dart' hide Delta;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/filter_sheet.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import 'note_tag_chip.dart';

/// 笔记编辑页（noteKey 为空 = 新建）
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteKey});

  final String? noteKey;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _title = TextEditingController();

  /// 纯文本模式正文（切回纯文本时从 Delta 回填）
  final _content = TextEditingController();

  /// 非 null = 富文本模式（flutter_quill 的 Delta 文档）
  QuillController? _quill;

  /// 编辑回显的原始 html（切富文本时的优先转换源，保留 PC 端样式）
  String _sourceHtml = '';

  /// 富文本编辑器的**持久** FocusNode / ScrollController。
  ///
  /// ⚠️ 必须由 State 持有，**不能依赖 `QuillEditor.basic` 在 build 里现造**（2026-09-18 血案）：
  /// `.basic` 每次 build 都新建 `FocusNode()` / `ScrollController()`，页面任何一次重建
  /// 都会换掉节点 → 旧节点失焦 → `openOrCloseConnection()` 关闭输入连接 → 引擎收起软键盘。
  /// 现象就是「点 Aa 后光标不出现、键盘弹一下就没、正文区像没有可输入的地方」。
  /// 实测证据（emulator logcat）：`ImeTracker: onRequestShow → onShown → onRequestHide`。
  final _richFocus = FocusNode(debugLabel: 'noteEditorRich');
  final _richScroll = ScrollController();

  /// 富文本工具条的范围锚点：`onTapOutside` 用它判定「这一下是点在工具条上」。
  /// （工具条在编辑器的 TapRegion 之外，点工具条按钮会走「点空白」那条路 → 会误收键盘）
  final _toolbarKey = GlobalKey();

  final Set<String> _selectedCategories = {}; // 多选分类（写回 JSON 数组文本）
  final Set<String> _selectedTags = {}; // 已选标签 key（note_book.tags 写回值）
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.noteKey != null) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _quill?.dispose();
    // 子树先卸载（Flutter 是 children-first unmount），此处再释放节点是安全的
    _richFocus.dispose();
    _richScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final note = await ref
        .read(noteRepositoryProvider)
        .getNote(widget.noteKey!);
    if (note == null) {
      if (mounted) {
        showFToast(context: context, title: const Text('笔记不存在'));
        context.pop();
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _title.text = note.title == '无标题笔记' ? '' : note.title;
      _content.text = _htmlToText(note.html);
      _sourceHtml = note.html;
      _selectedCategories
        ..clear()
        ..addAll(note.categories);
      _selectedTags
        ..clear()
        ..addAll(note.tags);
      _loaded = true;
    });
  }

  /// 简易 html → 纯文本（段落还原；本应用落库的都是 <p> 结构或 quill 产物）
  static String _htmlToText(String html) {
    return html
        .replaceAll('</p>', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }

  /// 纯文本 → Delta（按行分段；空文本给一个空行，保证 Quill 文档合法）
  Delta _plainTextToDelta(String text) {
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

  /// Delta → HTML（vsc_quill_delta_to_html；<p>/<ul>/<ol> 等结构与 vue-quill 兼容）
  String _deltaToHtml() {
    final converter = QuillDeltaToHtmlConverter(
      _quill!.document.toDelta().toJson().cast<Map<String, dynamic>>(),
    );
    return converter.convert();
  }

  /// 纯文本 ⇄ 富文本切换（头部右侧 Aa）
  void _toggleRich() {
    if (_saving) return;
    if (_quill == null) {
      final plain = _content.text.trim();
      final sourcePlain = _htmlToText(_sourceHtml).trim();
      Delta delta;
      if (_sourceHtml.isNotEmpty && plain == sourcePlain) {
        // 正文未手改：优先用原始 html 转 Delta（保留 PC vue-quill 样式）
        try {
          delta = HtmlToDelta().convert(_sourceHtml);
        } catch (_) {
          // HTML→Delta 解析失败：降级为段落纯文本（experimental 转换的兜底）
          delta = _plainTextToDelta(plain);
        }
      } else {
        delta = _plainTextToDelta(plain);
      }
      setState(() {
        _quill = QuillController(
          // ⚠️ 必须走 fromJson（内部 _transform 会补齐结尾换行，保证文档合法）；
          // fromDelta 不补，HtmlToDelta 产物末尾缺 \n 时 Quill 会插入异常
          document: Document.fromJson(delta.toJson()),
          selection: const TextSelection.collapsed(offset: 0),
        );
      });
      // 切富文本 = 用户显式表达「我要开始写」，立刻聚焦并拉起键盘（Aa 是主动作，
      // 不该再点一次正文）。必须在 build 之后聚焦：本帧里编辑器还没挂载，
      // 直接 requestFocus 会打在未 attach 的节点上（等于没聚焦）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _quill == null) return;
        _richFocus.requestFocus();
      });
    } else {
      // 富文本 → 纯文本：抽取纯文本（样式丢失，toast 明示）
      final plain = _quill!.document.toPlainText();
      // 先主动失焦：让引擎收键盘（否则切回纯文本后 quill 的输入连接还挂着）
      _richFocus.unfocus();
      _quill?.dispose();
      setState(() => _quill = null);
      _content.text = plain;
      showFToast(context: context, title: const Text('已切回纯文本，格式样式不会保存'));
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showFToast(context: context, title: const Text('标题不能为空'));
      return;
    }
    setState(() => _saving = true);
    final rich = _quill != null;
    // 摘要/正文纯文本：富文本模式从 Delta 抽取，纯文本模式直接取输入
    final plain = rich ? _quill!.document.toPlainText() : _content.text;
    try {
      final repo = ref.read(noteRepositoryProvider);
      if (widget.noteKey == null) {
        await repo.createNote(
          title: title,
          content: plain,
          categories: _selectedCategories.toList(),
          tagKeys: _selectedTags.toList(),
          rawHtml: rich ? _deltaToHtml() : null,
        );
      } else {
        await repo.updateNote(
          widget.noteKey!,
          title: title,
          content: plain,
          categories: _selectedCategories.toList(),
          tagKeys: _selectedTags.toList(),
          rawHtml: rich ? _deltaToHtml() : null,
        );
      }
      // 分类来自「已有笔记 distinct」的一次性 FutureProvider——新建分类落库后必须
      // 失效重取，否则 chips 里永远不出现新分类（「新建分类无效」的成因之一）
      ref.invalidate(noteCategoriesProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showFToast(context: context, title: const Text('保存失败，请重试'));
      }
    }
  }

  // ---------- 元信息选择抽屉（底部固定条与 chips 行共用入口） ----------

  /// 底部抽屉输入（小功能新增统一抽屉化，禁用居中弹窗——见 SKILL.md「UI 体系」约定）
  ///
  /// lg 档（内含输入框，80vh 定高）；打开不自动聚焦（红线 #14⑤），
  /// controller 由 [_EditorPromptSheet] 的 State 释放（不跟 await 之后的调用点）。
  Future<String?> _inputSheet({
    required String title,
    String? subtitle,
    required String hint,
    required String confirmLabel,
  }) async {
    final value = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => _EditorPromptSheet(
        title: title,
        subtitle: subtitle,
        hint: hint,
        confirmLabel: confirmLabel,
      ),
    );
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 分类多选抽屉（md 档；草稿态由闭包持有，refresh 驱动重渲）
  Future<void> _pickCategories() async {
    if (_saving) return;
    final existing = ref.read(noteCategoriesProvider).value ?? const <String>[];
    // chips 数据源 = 已选 ∪ 已有分类（新建分类立即可见、编辑回显不丢失）
    final cats = <String>[..._selectedCategories, ...existing];
    final draft = Set<String>.of(_selectedCategories);
    final result = await showFilterSheet<List<String>>(
      context: context,
      title: '选择分类',
      confirmLabel: '确定',
      body: (context, refresh) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              _CategoryChip(
                label: c,
                selected: draft.contains(c),
                onTap: () {
                  draft.contains(c) ? draft.remove(c) : draft.add(c);
                  refresh();
                },
              ),
            _CategoryChip(
              label: '新建分类',
              icon: FLucideIcons.plus,
              selected: false,
              onTap: () async {
                final value = await _inputSheet(
                  title: '新建分类',
                  hint: '输入分类名',
                  confirmLabel: '确定',
                );
                if (value == null || !mounted) return;
                if (!cats.contains(value)) cats.add(value);
                draft.add(value);
                ref.invalidate(noteCategoriesProvider);
                refresh();
              },
            ),
          ],
        );
      },
      // 重置 = 清空草稿（不关闭抽屉、不影响已生效值）
      onReset: (refresh) {
        draft.clear();
        refresh();
      },
      onConfirm: () => draft.toList(),
    );
    if (result == null) return;
    setState(() {
      _selectedCategories
        ..clear()
        ..addAll(result);
    });
  }

  /// 标签多选抽屉（md 档；创建后自动选中，同名去重由仓储保证）
  Future<void> _pickTags() async {
    if (_saving) return;
    final tagDefs = (ref.read(noteTagsProvider).value ?? const <NoteTag>[])
        .where((d) => !d.deleted)
        .toList();
    final draft = Set<String>.of(_selectedTags);
    final result = await showFilterSheet<List<String>>(
      context: context,
      title: '选择标签',
      confirmLabel: '确定',
      body: (context, refresh) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tagDefs)
              NoteTagChip(
                tag: tag,
                selected: draft.contains(tag.key),
                onTap: () {
                  draft.contains(tag.key)
                      ? draft.remove(tag.key)
                      : draft.add(tag.key);
                  refresh();
                },
              ),
            _CategoryChip(
              label: '新建标签',
              icon: FLucideIcons.plus,
              selected: false,
              onTap: () async {
                final value = await _inputSheet(
                  title: '新建标签',
                  subtitle: '颜色随机分配，与桌面端观感一致',
                  hint: '输入标签名',
                  confirmLabel: '创建',
                );
                if (value == null || !mounted) return;
                final tag = await ref
                    .read(noteRepositoryProvider)
                    .createTagDef(value);
                if (tag == null || !mounted) return;
                ref.invalidate(noteTagsProvider);
                tagDefs.add(tag);
                draft.add(tag.key);
                refresh();
              },
            ),
          ],
        );
      },
      // 重置 = 清空草稿（不关闭抽屉、不影响已生效值）
      onReset: (refresh) {
        draft.clear();
        refresh();
      },
      onConfirm: () => draft.toList(),
    );
    if (result == null) return;
    setState(() {
      _selectedTags
        ..clear()
        ..addAll(result);
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final tagDefs = (ref.watch(noteTagsProvider).value ?? const <NoteTag>[])
        .where((d) => !d.deleted)
        .toList();
    // 元信息行只显示「已选中」的分类/标签（添加入口收在底部条）。
    // 一个都没选中时整行 + 上下间距一起收掉，避免新建笔记在标题与正文之间白留死区。
    final selectedTags = [
      for (final d in tagDefs) if (_selectedTags.contains(d.key)) d,
    ];
    final hasMeta = _selectedCategories.isNotEmpty || selectedTags.isNotEmpty;

    return FScaffold(
      // ⚠️ childPad:false：页面边距只由内容区的 pagePadding 提供
      //（scaffold 默认 childPadding 会再叠一层 → 左右 ~26px，与其他页面不一致）
      childPad: false,
      header: FHeader.nested(
        // 标题左对齐（forui 默认 Alignment.centerLeft 会居中）——紧贴返回按钮右侧
        titleAlignment: Alignment.centerLeft,
        title: Text(widget.noteKey == null ? '新建笔记' : '编辑笔记'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          // Aa：纯文本 ⇄ 富文本切换（富文本态以下方工具条是否出现为准）
          // icon 必须传 Widget（FHeaderAction.icon: Widget），不传 size 以跟随头部图标主题
          FHeaderAction(icon: const Icon(FLucideIcons.type), onPress: _toggleRich),
        ],
      ),
      child: widget.noteKey != null && !_loaded
          ? const Center(child: FCircularProgress())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 大标题（无边框直排，沉浸式）
                        // ⚠️ 原生 TextField 必须自带透明 Material 祖先（forui 不提供，红线）
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTokens.pagePadding,
                            12,
                            AppTokens.pagePadding,
                            0,
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: TextField(
                              controller: _title,
                              style: t.typography.body.sm.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: t.colors.foreground,
                              ),
                              cursorColor: t.colors.primary,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: '标题…',
                                hintStyle: t.typography.body.sm.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  color: t.colors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 元信息行：只在有已选分类/标签时渲染（入口在底部条）
                        if (hasMeta) ...[
                          _metaRow(selectedTags),
                          const SizedBox(height: 12),
                        ],
                        // hairline 分隔（沉浸区与元信息的软分界）
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.pagePadding,
                          ),
                          child: Container(
                            height: 1,
                            color: t.colors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 正文区（沉浸：默认纯文本 / Aa 切富文本）
                        Expanded(
                          child: _quill == null
                              ? _plainBody(t)
                              : _richBody(t),
                        ),
                        // 富文本工具条（单行横滑，置于正文与底部条之间）
                        if (_quill != null) _richToolbar(),
                      ],
                    ),
                  ),
                  _bottomBar(t),
                ],
              ),
            ),
    );
  }

  /// 元信息 chips 行（单行横滑，**纯展示**）：已选分类（主色软底）+ 已选标签（标签色软底）
  ///
  /// ⚠️ 不再放「＋分类 / ＋标签」入口（2026-09-18 用户定案）：同一个动作（开抽屉选
  /// 分类/标签）原本在页面上有顶部行与底部条两个入口，属重复；添加入口统一收在底部条。
  /// 本行**只显示已选项**，点任一 chip 仍可打开对应多选抽屉继续增删。
  Widget _metaRow(List<NoteTag> selectedTags) {
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        child: Row(
          spacing: 8,
          children: [
            for (final c in _selectedCategories)
              _CategoryMetaChip(label: c, onTap: _pickCategories),
            for (final tag in selectedTags)
              NoteTagChip(tag: tag, selected: true, onTap: _pickTags),
          ],
        ),
      ),
    );
  }

  /// 纯文本正文（无边框、占满 Expanded、内部滚动；无 Material 祖先须透明补齐）
  Widget _plainBody(FThemeData t) {
    final style = t.typography.body.sm.copyWith(
      fontSize: 15,
      height: 1.7,
      color: t.colors.foreground,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _content,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: style,
          cursorColor: t.colors.primary,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: '记录想法…',
            hintStyle: style.copyWith(color: t.colors.mutedForeground),
          ),
        ),
      ),
    );
  }

  /// 富文本正文（flutter_quill；工具条单独置底，正文区只留文档）
  ///
  /// ⚠️ 同样要补透明 Material：flutter_quill 的默认选择菜单走 Material 的
  /// `AdaptiveTextSelectionToolbar`，长按选区时若无 Material 祖先会抛
  /// 「No Material widget found」。
  Widget _richBody(FThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
      child: Material(
        type: MaterialType.transparency,
        // ⚠️ 用完整构造器（而非 `.basic`）并把 focusNode / scrollController 显式传进来：
        // `.basic` 会在每次 build 里新建这两个对象，页面一重建焦点就丢、键盘被收起。
        child: QuillEditor(
          controller: _quill!,
          focusNode: _richFocus,
          scrollController: _richScroll,
          config: QuillEditorConfig(
            placeholder: '记录想法…',
            padding: EdgeInsets.zero,
            // 编辑器自己撑满 Expanded（QuillRawEditor 内层的 constraints 由它决定，
            // 保持默认 false 时可视输入区只有「内容高度」，空文档≈一行）。
            expands: true,
            autoFocus: false,
            // 点空白收键盘（全 App 约定）：quill 默认实现只在「鼠标/触控笔」且非移动端时
            // 才失焦，移动端 touch 什么都不做 → 这里统一接管，行为与 app.dart 的全局
            // `EditableTextTapOutsideIntent` 覆盖一致（全平台都收）。
            // ⚠️ 例外：**工具条按钮自己不算「空白」**——工具条位于编辑器的 TapRegion 之外，
            // 否则点一次「加粗」就会把键盘和光标一起收掉（2026-09-18 实踩）。
            onTapOutside: (event, node) {
              final box =
                  _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final local = box.globalToLocal(event.position);
                if ((Offset.zero & box.size).contains(local)) return;
              }
              node.unfocus();
            },
            // TODO(样式打磨)：dark 模式下 Quill 默认样式如与主题不符，
            // 用 QuillEditorConfig.customStyles 对齐 context.theme 取色。
          ),
        ),
      ),
    );
  }

  /// 富文本工具条（单行、横滑；只留笔记场景的高频样式）
  Widget _richToolbar() {
    return Padding(
      // 供编辑器的 onTapOutside 判定「点在工具条上」（见 _richBody 里的说明）
      key: _toolbarKey,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        4,
        AppTokens.pagePadding,
        0,
      ),
      // ⚠️ 不要再套横向 SingleChildScrollView（2026-09-18 血案，logcat 实证）：
      // QuillSimpleToolbar 内部是 `QuillToolbarArrowIndicatedButtonList`——含
      // `Expanded` + `CustomScrollView`（**自带箭头横滑，要求父级给出有界宽度**）。
      // 外面再套一层横向滚动会把手改成长度无界 → 内部 CustomScrollView 永远拿不到
      // 有效滚动尺寸 → `_handleScroll`（`Timer.run` 与 `didChangeMetrics` 两处）读
      // `position.minScrollExtent` 抛「Null check operator used on a null value」；
      // 更糟的是该异常会打断 `WidgetsBinding.handleMetricsChanged()` 的 observer 循环
      // （源码里没有 try/catch），键盘 insets 变化时整条链路一起失效。
      // 高度由 QuillSimpleToolbar 自己的 tightFor(height: _toolbarSize) 兜住。
      //
      // ⚠️ 工具条内部按钮用的是 Material 的 `IconButton`（`QuillToolbarIconButton`），
      // 必须补透明 Material 祖先，否则一进富文本就抛「No Material widget found」。
      child: Material(
        type: MaterialType.transparency,
        child: QuillSimpleToolbar(
          controller: _quill!,
          // ⚠️ v11.6 参数命名不统一：加/减按钮无关的旧参数名（showStrikeThrough /
          // showInlineCode / showClearFormat / showQuote…）与带 Button 后缀的
          // （showBoldButton / showItalicButton / showUnderLineButton（大写 L）/
          //  showColorButton / showBackgroundColorButton）混用——**改这里前先 grep
          //  simple_toolbar_config.dart 的构造函数，别按命名规律猜**。
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showDividers: true,
            showFontFamily: false,
            showFontSize: false,
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: true,
            showInlineCode: true,
            showColorButton: true,
            showBackgroundColorButton: true,
            showClearFormat: true,
            showListBullets: true,
            showListNumbers: true,
            showListCheck: true,
            showQuote: true,
            showCodeBlock: false,
            showIndent: false,
            showLink: false,
            showSearchButton: false,
            showUndo: true,
            showRedo: true,
            // 笔记场景不收上下标（二者默认 true，不显式关会白送出两个按钮）
            showSubscript: false,
            showSuperscript: false,
            showAlignmentButtons: false,
            showHeaderStyle: false,
            showDirection: false,
          ),
        ),
      ),
    );
  }

  /// 底部固定条（页面规范：保存/提交按钮固定底部，不随内容滚动）
  /// 左：分类/标签入口（带计数）；右：保存胶囊
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
          _MetaEntryChip(
            icon: FLucideIcons.folder,
            label: '分类 ${_selectedCategories.length}',
            onTap: _pickCategories,
          ),
          const SizedBox(width: 8),
          _MetaEntryChip(
            icon: FLucideIcons.tag,
            label: '标签 ${_selectedTags.length}',
            onTap: _pickTags,
          ),
          const Spacer(),
          GradientButton(
            label: _saving ? '保存中…' : '保存',
            icon: FLucideIcons.check,
            height: 44,
            fullWidth: false,
            onPress: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// 已选分类 chip（元信息行）：主色 12% 软底 + 主色描边 + 主色文字
/// （规格与 NoteTagChip 一致：padding h14/v6 + body.xs + w600，只变色不改尺寸）
class _CategoryMetaChip extends StatelessWidget {
  const _CategoryMetaChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final accent = t.colors.primary;
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: t.typography.body.xs.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 「＋分类 / ＋标签」「分类 n / 标签 n」入口 chip（元信息行与底部条共用）：
/// muted 软底 + 图标 + 文字（muted==border 同色陷阱 → 不描边，只靠软底成形）
class _MetaEntryChip extends StatelessWidget {
  const _MetaEntryChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: t.colors.mutedForeground),
            const SizedBox(width: 5),
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                color: t.colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类 / 新建入口 chip（选择抽屉内复用；选中/强调色跟随外观主题色，随换肤动态变化）
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 非空 = 「新建」入口 chip（描边虚位样式 + plus 图标）
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    // 选中 / 强调色跟随**外观主题色**（随换肤动态变化），不再写死笔记域琥珀
    final accent = t.colors.primary;
    final isAdd = icon != null;
    final bg = selected ? accent : (isAdd ? t.colors.muted : t.colors.card);
    final fg = selected ? Colors.white : (isAdd ? accent : t.colors.foreground);
    return FTappable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent
                : (isAdd ? accent.withValues(alpha: 0.5) : t.colors.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdd) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: t.typography.body.xs.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 轻量输入抽屉本体（lg 档）：controller 由自身 State 释放（红线：controller
/// 生命周期跟 State，不跟 await 之后的调用点）；打开不自动聚焦。
class _EditorPromptSheet extends StatefulWidget {
  const _EditorPromptSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String hint;
  final String confirmLabel;

  @override
  State<_EditorPromptSheet> createState() => _EditorPromptSheetState();
}

class _EditorPromptSheetState extends State<_EditorPromptSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.title,
      // 内含输入框 → lg 80vh 定高（2026-09-13 全局定案）
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: context.theme.typography.body.sm.copyWith(
                fontSize: 12,
                color: context.theme.colors.mutedForeground,
              ),
            ),
          SheetInputBox(controller: _controller, hintText: widget.hint),
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
            label: widget.confirmLabel,
            icon: FLucideIcons.check,
            onPress: () => Navigator.pop(context, _controller.text),
          ),
        ),
      ],
    );
  }
}
