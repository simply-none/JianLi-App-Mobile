// 电子书 - 导出 Markdown 工具（纯函数，不碰数据库，便于复用与单测）
//
// 导出格式：`.md`。结构 = 书架书目清单 + 每本书的「标注与笔记」（有才输出）：
//   # 电子书导出
//   ---
//   ## 书名
//   > 作者 ｜ EPUB ｜ 已读 100%
//   > 分类：国学典籍、历史 ｜ 加入：… ｜ 最后阅读：…
//   ### 标注与笔记（4）
//   - **[强调线]** 原文…
//     > 笔记：…
//
// 标注类型中文标签与「笔记标注」页（book_notes_page.dart `_typeMeta`）同一套口径，
// 划线/笔记的划分口径为仓库唯一判据 `isNoteAnnotation`。
import '../../../core/db/app_database.dart';
import '../repositories/ebook_repository.dart';

/// 标注类型 → 中文标签（与「笔记标注」页 `_typeMeta` 同口径）
String annotationTypeLabel(String? type) {
  switch ((type ?? '').trim()) {
    case 'highlight':
      return '高亮';
    case 'underline':
      return '下划线';
    case 'mark':
      return '横线';
    case 'markStrong':
      return '强调线';
    case 'note':
      return '笔记';
    default:
      return '标注';
  }
}

/// ISO 时间串 → `yyyy-MM-dd HH:mm`（DB 存 ISO；异常/过短时原样返回）
String _shortTime(String? iso) {
  final s = (iso ?? '').trim();
  if (s.isEmpty) return '';
  final t = s.replaceAll('T', ' ');
  return t.length >= 16 ? t.substring(0, 16) : t;
}

/// 单行化：正文里的换行/连续空白压成单个空格（避免撑破 `- **[…] 原文**` 单行格式）
String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// 多本书 → 单个 `.md` 文本。
///
/// [categoryNamesByPath] = 书 filePath → 分类名列表；[annotations] = 全量批注
/// （函数内按 `content_hash` 归到各书，保持传入顺序 = createdAt 升序）；
/// [exportedAt] 导出时间戳（缺省取当前时间）。
String buildBooksMarkdown(
  List<EbookBookshelfData> books, {
  Map<String, List<String>> categoryNamesByPath = const {},
  List<EbookAnnotationData> annotations = const [],
  String? exportedAt,
}) {
  final stamp = exportedAt ?? _timestamp();

  // content_hash -> 该书的批注（保持传入顺序）
  final annoByHash = <String, List<EbookAnnotationData>>{};
  for (final a in annotations) {
    final h = a.contentHash;
    if (h == null || h.isEmpty) continue;
    annoByHash.putIfAbsent(h, () => <EbookAnnotationData>[]).add(a);
  }

  final lines = <String>[
    '# 电子书导出',
    '',
    '导出时间：$stamp ｜ 共 ${books.length} 本',
  ];

  for (final b in books) {
    final title = (b.title ?? b.name ?? '未命名').trim();
    lines.add('');
    lines.add('---');
    lines.add('');
    lines.add('## ${title.isEmpty ? '未命名' : title}');

    // 主信息行：作者 ｜ 格式 ｜ 已读
    final head = <String>[
      if ((b.author ?? '').trim().isNotEmpty) (b.author!).trim(),
      if ((b.format ?? '').trim().isNotEmpty) (b.format!).trim().toUpperCase(),
      '已读 ${((b.percent ?? 0).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
    ];
    lines.add('');
    lines.add('> ${head.join(' ｜ ')}');

    // 次信息行：分类 ｜ 加入 ｜ 最后阅读
    final extra = <String>[];
    final cats = categoryNamesByPath[b.filePath] ?? const <String>[];
    if (cats.isNotEmpty) extra.add('分类：${cats.join('、')}');
    final added = _shortTime(b.addedAt);
    final lastRead = _shortTime(b.lastReadAt);
    if (added.isNotEmpty) extra.add('加入：$added');
    if (lastRead.isNotEmpty) extra.add('最后阅读：$lastRead');
    if (extra.isNotEmpty) {
      lines.add('>');
      lines.add('> ${extra.join(' ｜ ')}');
    }

    // 标注与笔记（该书没有就不输出该节）
    final annos =
        annoByHash[b.contentHash ?? ''] ?? const <EbookAnnotationData>[];
    if (annos.isNotEmpty) {
      lines.add('');
      lines.add('### 标注与笔记（${annos.length}）');
      for (final a in annos) {
        final text = _oneLine(a.annotatedText ?? '');
        final note = (a.note ?? '').trim();
        lines.add('');
        lines.add(
          '- **[${annotationTypeLabel(a.type)}]** ${text.isEmpty ? '（无原文）' : text}',
        );
        if (note.isNotEmpty) {
          // 多行笔记做引用续行，保持 Markdown 结构合法
          lines.add('  > 笔记：${note.replaceAll('\n', '\n  > ')}');
        }
      }
    }
  }

  return '${lines.join('\n').trimRight()}\n';
}

/// 文件名时间戳：yyyyMMdd_HHmmss
String _timestamp() {
  final n = DateTime.now();
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}';
}

/// 单本书的**全部标注与笔记** → 单个 `.md`（书籍「笔记标注」页底部【导出】用）。
///
/// 与 `buildBooksMarkdown` 的差别：这里一本书一段一节，每条标注独立成 `##`，
/// 原文/笔记**保留原始换行**（不做单行压缩），因为每条都独占一节、不存在撑破列表行的问题。
/// [annotations] 应为按 `createdAt` 升序的本书记录（与页面列表同序）。
String buildBookAnnotationsMarkdown(
  List<EbookAnnotationData> annotations, {
  required String title,
  String? exportedAt,
}) {
  final stamp = exportedAt ?? _timestamp();
  final marks = annotations.where((a) => !isNoteAnnotation(a)).length;
  final notes = annotations.length - marks;
  final bookTitle = title.trim().isEmpty ? '笔记标注' : title.trim();

  final lines = <String>[
    '# $bookTitle',
    '',
    '> 共 ${annotations.length} 条 · 划线 $marks · 笔记 $notes',
    '>',
    '> 导出时间：$stamp',
  ];

  if (annotations.isEmpty) {
    lines.add('');
    lines.add('（暂无标注）');
    return '${lines.join('\n').trimRight()}\n';
  }

  for (final a in annotations) {
    final text = (a.annotatedText ?? '').trim();
    final note = (a.note ?? '').trim();
    final time = _shortTime(a.createdAt);
    // 标题：[类型·颜色] 时间（笔记类型不挂颜色，与页面卡片一致）
    final label = annotationTypeLabel(a.type);
    final color = (a.color ?? '').trim();
    final tag = !isNoteAnnotation(a) && color.isNotEmpty
        ? '$label·$color'
        : label;

    lines.add('');
    lines.add('---');
    lines.add('');
    lines.add('## [$tag]${time.isEmpty ? '' : ' $time'}');
    lines.add('');
    lines.add(text.isEmpty ? '（无原文）' : text);
    if (note.isNotEmpty) {
      lines.add('');
      lines.add('> 笔记：${note.replaceAll('\n', '\n> ')}');
    }
  }

  return '${lines.join('\n').trimRight()}\n';
}
