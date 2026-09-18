// HTML ⇄ 纯文本 工具（对齐桌面端 src/views/themeConversation/composables/richText.ts）
//
// 背景：主题对话（conversation）的 `content` 一律以「字符串」存储，兼容两种情况：
//   1) 纯文本（无标签）—— 底部快速输入栏录入，或桌面折叠态输入框录入；
//   2) HTML（来自富文本编辑器）—— 移动端富文本编辑页 / 桌面端 vue-quill 录入。
// `conversation.is_rich`（'0'/'1'）显式标记内容类型，该列同时驱动展示与编辑：
//   - 展示：'1' → HtmlWidget（HTML 渲染）；'0' → Text（纯文本原样显示）
//   - 编辑：'1' → 富文本编辑器（HTML→Delta 做种子）；'0' → 纯文本输入框
//
// ⚠️⚠️ 归一化判据必须与桌面端【逐字对齐】。反例代价不可逆：
//   若把「其实不含任何格式」的内容写成 is_rich='1'，PC 端气泡会因为要给 v-html
//   做转义保护而走 `escapeHtml` → 用户看到的是整串 `<p>…</p>` 源码，且已是脏数据。
//   故 [isRichContent] 的「剥掉结构性 <p>/<br> 后是否还残留标签」判定、
//   [stripTags] 的「块级结尾→换行」映射与实体解码顺序，均照抄 PC 实现，**不要优化**。
//
// 与 PC richText.ts 的**有意差异**（移动端不需要，不要盲目补）：
//   - `escapeHtml` / `toQuillContent`：PC 给的是「纯文本也要喂给 vue-quill 的 `v-html`」
//     场景，必须转义 + 包 <p>。移动端纯文本走 `Text()` 渲染、进编辑器走原生 Delta，
//     全程不经 HTML → 无此需求。若将来移动端也要把纯文本塞进 HtmlWidget，再补。
//   - `snippetOf`：① 空内容占位——PC 硬编码 `'(空对话)'`，移动端返回 `''`（调用点需要
//     自行区分「空」与「有内容」，见 [isBlankContent]）；② 去标签策略——PC 无条件
//     `stripTags`，移动端多一个 `html:` 开关按 `is_rich` 决定（详见该函数注释）。
//
// 本文件是移动端 HTML/纯文本互转的**唯一**入口（2026-09-18 收口）：此前
// `conversation_page` 内联了两份等价正则（`_snippetOf` / `_RefPickItem._snippet`）。
// ⚠️ 仍有未迁移的旧内联副本，都属**语义不同**的另一件事、不要顺手合并：
//   - `note_editor_page._htmlToText`：笔记「编辑回显」，不折叠内部空行
//   - `epub_reader_page._stripTags`：电子书正文清洗，口径独立

/// `<[a-z!][\s\S]*>` —— 对齐 PC `isHtml` 的正则
final RegExp _kHtmlTag = RegExp(r'<[a-z!][\s\S]*>', caseSensitive: false);

/// 结构性标签（只换行、不带格式）—— 对齐 PC `isRichContent` 的第一步
final RegExp _kStructural = RegExp(r'<\/?(p|br)\b[^>]*>', caseSensitive: false);

final RegExp _kWs = RegExp(r'\s+');
final RegExp _kNbsp = RegExp('&nbsp;', caseSensitive: false);

/// 粗略判断字符串是否含 HTML 标签。
///
/// 与 PC `isHtml` 同源，但**不参与 is_rich 判定**——它只用来做「脏数据守卫」：
/// 例如某行 is_rich='1' 但 content 里根本没有标签（历史/同步来的异常行）时，
/// 富文本编辑页应退化为纯文本种子，而不是把裸文本丢给 HTML 解析器。
bool isHtml(String? s) {
  if (s == null || s.isEmpty) return false;
  return _kHtmlTag.hasMatch(s);
}

/// 判断一段 HTML 是否为「富文本」（**含实际格式**），用于写入时决定 `is_rich`。
///
/// 仅由 `<p>`/`<br>` 包裹的纯文本视为非富文本；含 b/i/u/a/ul/ol/blockquote/h1-3
/// 等格式标签才视为富文本。算法与 PC `isRichContent` 逐字一致。
bool isRichContent(String? html) {
  if (html == null || html.isEmpty) return false;
  final stripped = html
      .replaceAll(_kStructural, '') // 去掉结构性 p / br
      .replaceAll(_kNbsp, '')
      .replaceAll(_kWs, '');
  return stripped.contains('<') || stripped.contains('>');
}

/// 去掉 HTML 标签并解码实体，得到纯文本。
///
/// 用途：判空、列表/摘要预览、以及**写入归一化时的纯文本分支**。
/// ⚠️ 实体解码顺序与 PC 一致（`&amp;` → `&lt;` → `&gt;`），不要调整。
String stripTags(String? html) {
  if (html == null || html.isEmpty) return '';
  return html
      // 块级结尾 → 换行
      .replaceAll(
        RegExp(r'<\/(p|div|li|h[1-6]|blockquote|pre)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(_kNbsp, ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

/// 「单行纯文本」：`html: true` 时先去标签；随后折叠所有空白为单空格并 trim（**不截断**）。
///
/// 供两类调用方使用：① [snippetOf] 的截断前形态；② 关键词搜索索引（需要整段可比对文本）。
String plainLineOf(String? text, {bool html = false}) {
  final base = html ? stripTags(text) : (text ?? '');
  return base.replaceAll(_kWs, ' ').trim();
}

/// 摘要：去标签 + 折叠空白 + 截断，供列表 / 抽屉预览使用。
///
/// [html] = 内容是否为 HTML（调用方按 `is_rich == '1'` 传）。**默认 false（按纯文本处理）**。
///
/// ⚠️ 与 PC 的差异（**有意，且更正确**）：PC `snippetOf` 无条件 `stripTags`，于是纯文本
/// 里写的 `<重要>` 会被预览吃掉（而同一段文字在气泡里是原样显示的）——预览与正文口径不一致。
/// 移动端改为「按 is_rich 决定要不要去标签」，让预览与气泡的渲染分支严格对齐。
/// 写入归一化（[normalizeContent]）仍无条件 `stripTags`，不受此参数影响。
String snippetOf(String? text, {int max = 60, bool html = false}) {
  final t = plainLineOf(text, html: html);
  if (t.isEmpty) return '';
  return t.length > max ? '${t.substring(0, max)}…' : t;
}

/// 判空：去标签后是否还有实体内容（对齐 PC `isEmpty = !stripTags(content).trim()`）。
bool isBlankContent(String? raw) => stripTags(raw).trim().isEmpty;

// ---------------------------------------------------------------------------
// 写入归一化（唯一入口，对齐 PC createConversation / updateConversation 的内容分支）
// ---------------------------------------------------------------------------

/// 一次写入归一化的结果：该存什么 content、is_rich 该写什么。
class NormalizedContent {
  const NormalizedContent({required this.content, required this.isRich});

  /// 实际落库的 content：含格式 → 原样 HTML；否则 → 去标签后的纯文本
  final String content;

  /// 是否富文本（落库为 '1' / '0'，见 [isRichFlag]）
  final bool isRich;

  /// drift 写入用：'1' / '0'
  String get isRichFlag => isRich ? '1' : '0';
}

/// 把「任意来源的 content（纯文本 或 HTML）」归一化为落库形态。
///
/// **写入侧的唯一判据**：调用方不需要自己判断内容类型，直接把手上的字符串丢进来。
/// 纯文本走 [stripTags] 是安全的（无标签可去，顺带把连续空行折成一行、裁掉首尾空白），
/// 这一点与 PC 完全一致——PC 对 `payload.content` 一律先跑 `isRichContent` + `stripTags`，
/// 不区分来源，故两端对同一条内容会得出同一个 is_rich。
NormalizedContent normalizeContent(String? raw) {
  final rich = isRichContent(raw);
  return NormalizedContent(
    content: rich ? (raw ?? '') : stripTags(raw),
    isRich: rich,
  );
}
