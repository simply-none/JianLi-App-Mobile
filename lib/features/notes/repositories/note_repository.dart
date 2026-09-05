// 笔记仓库 —— note_book 的只读查询（列表 / 分类 / 详情）
//
// 移动端第一批只做「浏览」；编辑（flutter_quill）与写回列入 P2，
// 届时同步更新 updateTime 并保证双端 upsert 幂等。
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../models/note_item.dart';

/// 笔记仓库
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 笔记列表流（可按分类过滤，按 updateTime 倒序）
  Stream<List<NoteItem>> watchNotes({String? category}) {
    final query = _db.select(_db.noteBook);
    if (category != null && category.isNotEmpty) {
      query.where((tbl) => tbl.category.equals(category));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]);
    return query.watch().map(
          (rows) => rows.map(NoteItem.fromRow).toList(),
        );
  }

  /// 全部分类（distinct，供筛选 chips）
  Future<List<String>> loadCategories() async {
    final query = _db.selectOnly(_db.noteBook)
      ..addColumns([_db.noteBook.category])
      ..groupBy([_db.noteBook.category]);
    final rows = await query.get();
    return rows
        .map((r) => r.read(_db.noteBook.category))
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toList();
  }

  /// 单条笔记详情；不存在返回 null
  Future<NoteItem?> getNote(String key) async {
    final row = await (_db.select(_db.noteBook)..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return row == null ? null : NoteItem.fromRow(row);
  }

  /// 新建笔记（html 由纯文本段落生成，与桌面端 vue-quill 的 <p> 结构兼容）
  Future<String> createNote({
    required String title,
    required String content,
    String? category,
  }) async {
    final key = _uuid.v4();
    final now = _now();
    final html = _textToHtml(content);
    await _db.into(_db.noteBook).insert(NoteBookCompanion.insert(
          key: key,
          excerpt: Value(_excerptOf(title, content)),
          html: Value(html),
          createTime: Value(now),
          updateTime: Value(now),
          tags: const Value('[]'),
          category: Value(category),
        ));
    return key;
  }

  /// 更新笔记正文/分类
  Future<void> updateNote(String key,
      {required String title, required String content, String? category}) async {
    await (_db.update(_db.noteBook)..where((tbl) => tbl.key.equals(key))).write(
      NoteBookCompanion(
        excerpt: Value(_excerptOf(title, content)),
        html: Value(_textToHtml(content)),
        category: Value(category),
        updateTime: Value(_now()),
      ),
    );
  }

  /// 删除笔记
  Future<void> deleteNote(String key) =>
      (_db.delete(_db.noteBook)..where((tbl) => tbl.key.equals(key))).go();

  /// 摘要 = 标题 + 正文首行（对齐桌面端 excerpt 用途）
  static String _excerptOf(String title, String content) {
    final firstLine =
        content.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return firstLine.isEmpty ? title : '$title\n$firstLine';
  }

  /// 纯文本 → HTML 段落（转义 + 换行分段）
  static String _textToHtml(String text) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped
        .split('\n')
        .map((l) => l.trim().isEmpty ? '' : '<p>${l.trim()}</p>')
        .where((l) => l.isNotEmpty)
        .join();
  }

  static String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}
