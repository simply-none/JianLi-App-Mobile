// 笔记仓库 —— note_book CRUD + 标签定义（basic_info.note_tags）读写
//
// 标签契约（对齐桌面端 TagSelector.vue / store.ts）：
// - 定义存 basic_info 表 key='note_tags' 行（value=JSON 数组），随同步白名单双端互通；
// - 每条笔记 note_book.tags 存标签 key 的 JSON 数组；
// - 新建标签随机取 PC 同款色板；删除为软删（deleted: true）。
// 移动端编辑为轻量纯文本（html 段落化落库，桌面端 vue-quill 可渲染）；
// flutter_quill 富文本编辑器列入 P2。
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../models/note_item.dart';
import '../models/note_tag.dart';

/// 笔记仓库
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// basic_info 里标签定义的键（桌面端 get-store/set-store 同名键）
  static const _tagDefsKey = 'note_tags';

  // ---------- 笔记 CRUD ----------

  /// 笔记列表流（可按分类过滤，按 updateTime 倒序）
  Stream<List<NoteItem>> watchNotes({String? category}) {
    final query = _db.select(_db.noteBook);
    if (category != null && category.isNotEmpty) {
      query.where((tbl) => tbl.category.equals(category));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]);
    return query.watch().map((rows) => rows.map(NoteItem.fromRow).toList());
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
    final row = await (_db.select(
      _db.noteBook,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row == null ? null : NoteItem.fromRow(row);
  }

  /// 新建笔记（html 由纯文本段落生成，与桌面端 vue-quill 的 <p> 结构兼容）
  Future<String> createNote({
    required String title,
    required String content,
    String? category,
    List<String> tagKeys = const [],
  }) async {
    final key = _uuid.v4();
    final now = _now();
    final html = _textToHtml(content);
    await _db
        .into(_db.noteBook)
        .insert(
          NoteBookCompanion.insert(
            key: key,
            excerpt: Value(_excerptOf(title, content)),
            html: Value(html),
            createTime: Value(now),
            updateTime: Value(now),
            tags: Value(jsonEncode(tagKeys)),
            category: Value(category),
          ),
        );
    return key;
  }

  /// 更新笔记正文/分类/标签
  Future<void> updateNote(
    String key, {
    required String title,
    required String content,
    String? category,
    List<String> tagKeys = const [],
  }) async {
    await (_db.update(_db.noteBook)..where((tbl) => tbl.key.equals(key))).write(
      NoteBookCompanion(
        excerpt: Value(_excerptOf(title, content)),
        html: Value(_textToHtml(content)),
        category: Value(category),
        tags: Value(jsonEncode(tagKeys)),
        updateTime: Value(_now()),
      ),
    );
  }

  /// 删除笔记
  Future<void> deleteNote(String key) =>
      (_db.delete(_db.noteBook)..where((tbl) => tbl.key.equals(key))).go();

  // ---------- 标签定义（basic_info.note_tags） ----------

  /// 标签定义流（basic_info 该行变化即重发，含 PC 同步写入）
  Stream<List<NoteTag>> watchTagDefs() {
    final query = _db.select(_db.basicInfo)
      ..where((tbl) => tbl.key.equals(_tagDefsKey));
    return query.watchSingleOrNull().map((row) => parseNoteTagDefs(row?.value));
  }

  /// 读取标签定义（一次性）
  Future<List<NoteTag>> loadTagDefs() async {
    final row = await _tagDefsRow();
    return parseNoteTagDefs(row?.value);
  }

  /// 新建标签（同名去重直接复用；色板随机取色，与桌面端 TagSelector 同源）。
  /// 返回标签（已存在时返回既有标签）；名称为空返回 null。
  Future<NoteTag?> createTagDef(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final rawList = await _readTagDefsRaw();
    for (final item in rawList) {
      if (item is Map &&
          item['name']?.toString() == trimmed &&
          item['deleted'] != true) {
        return NoteTag.fromJson(Map<String, dynamic>.from(item));
      }
    }
    final color =
        kNoteTagPalette[_uuid.v4().hashCode.abs() % kNoteTagPalette.length];
    final now = _now();
    final tag = NoteTag(key: _uuid.v4(), name: trimmed, color: color);
    rawList.add({
      'key': tag.key,
      'name': tag.name,
      'color': tag.color,
      'createTime': now,
      'updateTime': now,
    });
    await _writeTagDefsRaw(rawList);
    return tag;
  }

  /// 软删标签（deleted: true；笔记上已挂的 key 保留，与桌面端语义一致）
  Future<void> deleteTagDef(String key) async {
    final rawList = await _readTagDefsRaw();
    var touched = false;
    for (final item in rawList) {
      if (item is Map && item['key'] == key) {
        item['deleted'] = true;
        item['updateTime'] = _now();
        touched = true;
      }
    }
    if (touched) await _writeTagDefsRaw(rawList);
  }

  /// 读 note_tags 原始 JSON 数组（异常一律空列表；保留未知字段以便回写不丢数据）
  Future<List<dynamic>> _readTagDefsRaw() async {
    final row = await _tagDefsRow();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
  }

  Future<BasicInfoData?> _tagDefsRow() => (_db.select(
    _db.basicInfo,
  )..where((tbl) => tbl.key.equals(_tagDefsKey))).getSingleOrNull();

  /// 回写标签定义（typed insertOrReplace，正常通知 watch 流；
  /// 与桌面端 set-store 同款整行覆盖语义）
  Future<void> _writeTagDefsRaw(List<dynamic> rawList) async {
    await _db
        .into(_db.basicInfo)
        .insertOnConflictUpdate(
          BasicInfoCompanion.insert(
            key: _tagDefsKey,
            value: Value(jsonEncode(rawList)),
          ),
        );
  }

  // ---------- 内部工具 ----------

  /// 摘要 = 标题 + 正文首行（对齐桌面端 excerpt 用途）
  static String _excerptOf(String title, String content) {
    final firstLine = content
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
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
