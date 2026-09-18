// 笔记仓库 —— note_book CRUD + 标签定义（basic_info.note_tags）读写
//
// 标签契约（对齐桌面端 TagSelector.vue / store.ts）：
// - 定义存 basic_info 表 key='note_tags' 行（value=JSON 数组），随同步白名单双端互通；
// - 每条笔记 note_book.tags 存标签 key 的 JSON 数组；
// - 新建标签随机取 PC 同款色板；删除为软删（deleted: true）。
// 移动端编辑：默认纯文本（html 段落化落库）；编辑页支持切 flutter_quill 富文本
// （Delta→HTML 经 vsc_quill_delta_to_html 走 rawHtml 直落，2026-09-18 方案 B 落地）。
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

  /// 笔记列表流（可按多分类过滤——任一命中即列出，按 updateTime 倒序）。
  /// ⚠️ category 列存 JSON 数组文本（多选分类），用 `"名称"` 全匹配子串定位；
  /// LIKE 通配符做基础转义（分类名含 % _ 的极端场景不保证，注释在案）。
  Stream<List<NoteItem>> watchNotes({List<String> categories = const []}) {
    final query = _db.select(_db.noteBook);
    if (categories.isNotEmpty) {
      Expression<bool> cond = _categoryLike(categories.first);
      for (final c in categories.skip(1)) {
        cond = cond | _categoryLike(c);
      }
      query.where((tbl) => cond);
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.updateTime)]);
    return query.watch().map((rows) => rows.map(NoteItem.fromRow).toList());
  }

  Expression<bool> _categoryLike(String category) {
    final escaped = category
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return _db.noteBook.category.like('%"$escaped"%');
  }

  /// 全部分类（从各行 category 列解析 JSON 数组后取并集，供筛选 chips）
  Future<List<String>> loadCategories() async {
    final rows = await _db.select(_db.noteBook).get();
    final cats = <String>[];
    for (final row in rows) {
      for (final c in parseNoteCategories(row.category)) {
        if (!cats.contains(c)) cats.add(c);
      }
    }
    return cats;
  }

  /// 单条笔记详情；不存在返回 null
  Future<NoteItem?> getNote(String key) async {
    final row = await (_db.select(
      _db.noteBook,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row == null ? null : NoteItem.fromRow(row);
  }

  /// 新建笔记（默认由纯文本段落生成 <p> 结构 html，与桌面端 vue-quill 兼容；
  /// [rawHtml] 非空时直接落库（富文本模式 Delta→HTML 的产物，不再段落化）；
  /// categories 多选分类，落库为 JSON 数组文本，空列表存 NULL）
  Future<String> createNote({
    required String title,
    required String content,
    List<String> categories = const [],
    List<String> tagKeys = const [],
    String? rawHtml,
  }) async {
    final key = _uuid.v4();
    final now = _now();
    final html = rawHtml ?? _textToHtml(content);
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
            category: Value(
              categories.isEmpty ? null : jsonEncode(categories),
            ),
          ),
        );
    return key;
  }

  /// 更新笔记正文/分类/标签（[rawHtml] 语义同 [createNote]）
  Future<void> updateNote(
    String key, {
    required String title,
    required String content,
    List<String> categories = const [],
    List<String> tagKeys = const [],
    String? rawHtml,
  }) async {
    await (_db.update(_db.noteBook)..where((tbl) => tbl.key.equals(key))).write(
      NoteBookCompanion(
        excerpt: Value(_excerptOf(title, content)),
        html: Value(rawHtml ?? _textToHtml(content)),
        category: Value(
          categories.isEmpty ? null : jsonEncode(categories),
        ),
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

  /// 重命名标签（对齐 PC TagSelector：与其它活跃标签重名时返回 false 不写入）
  Future<bool> renameTagDef(String key, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final rawList = await _readTagDefsRaw();
    for (final item in rawList) {
      if (item is Map &&
          item['key'] != key &&
          item['name']?.toString() == trimmed &&
          item['deleted'] != true) {
        return false;
      }
    }
    return _patchTagDef(key, (item) {
      item['name'] = trimmed;
      item['updateTime'] = _now();
    });
  }

  /// 改标签颜色（'#RRGGBB'，色板 = [kNoteTagPalette]，与 PC TagSelector 同源）
  Future<void> updateTagColor(String key, String color) => _patchTagDef(key, (
    item,
  ) {
    item['color'] = color;
    item['updateTime'] = _now();
  });

  /// 按 key 打补丁并回写 basic_info.note_tags（命中返回 true）
  Future<bool> _patchTagDef(
    String key,
    void Function(Map<dynamic, dynamic> item) patch,
  ) async {
    final rawList = await _readTagDefsRaw();
    var touched = false;
    for (final item in rawList) {
      if (item is Map && item['key'] == key) {
        patch(item);
        touched = true;
      }
    }
    if (touched) await _writeTagDefsRaw(rawList);
    return touched;
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
