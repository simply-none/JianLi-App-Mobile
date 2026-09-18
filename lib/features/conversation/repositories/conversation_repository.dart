// 主题对话仓库 —— 对齐桌面端 useThemeConversation 的移动端子集
//
// 字段语义与桌面端 db.ts / types.ts 对齐：
// - conversation_theme：title/tags(JSON 标签 id 数组)/create_time/update_time/remark/parent_id(子主题)
// - conversation：theme_id(字符串化主题 id)/content/is_rich('1'=HTML)/ref_ids(同主题引用 JSON)/
//   cross_refs(跨主题引用 JSON：[{themeId,convId}])/tags/create_time/annotate_time/pinned('1'置顶)/
//   is_deleted('1'软删)
// - conversation_tag：name/color/scope(theme|conversation)/create_time
// 2026-09-13 起：引用/跨主题引用、导出 Markdown、标签管理 CRUD（updateTag/deleteTag）均已落地；
// 2026-09-18 起：**富文本写入与编辑**已落地（`addMessage` / `updateMessageContent` 走
//   `core/text/rich_text.dart` 的 `normalizeContent` 归一化，判据与桌面端逐字对齐）；
// 未做（桌面端有、移动端裁剪）：子主题发起、多选批量、情绪预设、LLM 回复——记 SKILL.md 待办。
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/text/rich_text.dart';

/// 引用关系条目（跨主题/反向链接时附带来源主题名）
class ConvRefItem {
  const ConvRefItem(this.msg, this.themeTitle);

  final ConversationData msg;
  final String? themeTitle;
}

/// 某条消息的引用关系（正向 = 它引用的；反向 = 引用它的，含跨主题来源）
class ConvRefLinks {
  const ConvRefLinks({
    required this.outgoing,
    required this.cross,
    required this.backlinks,
  });

  /// 正向链接：ref_ids 指向的同主题消息
  final List<ConversationData> outgoing;

  /// 跨主题引用：cross_refs 指向的消息（附来源主题名）
  final List<ConvRefItem> cross;

  /// 反向链接：引用了本条的消息（含同主题与跨主题来源）
  final List<ConvRefItem> backlinks;
}

/// 主题对话仓库
class ConversationRepository {
  ConversationRepository(this._db);

  final AppDatabase _db;

  /// 标签配色轮转（对齐桌面端 TAG_COLORS 顺序取色，createConversationTag /
  /// createThemeTag / 改色共用同一色板）
  static const List<String> kTagPalette = [
    '#6366f1',
    '#ec4899',
    '#f59e0b',
    '#10b981',
    '#3b82f6',
    '#8b5cf6',
    '#ef4444',
    '#14b8a6',
    '#f97316',
    '#06b6d4',
  ];

  /// 主题列表流（update_time 倒序，与桌面端 loadThemes 一致）
  Stream<List<ConversationThemeData>> watchThemes() {
    return (_db.select(
      _db.conversationTheme,
    )..orderBy([(t) => OrderingTerm.desc(t.updateTime)])).watch();
  }

  /// 各主题对话数流（角标）：theme_id(字符串化) → 条数
  /// 计数口径与桌面端 loadThemeCounts 一致（不做 is_deleted 过滤，NULL 免疫）
  Stream<Map<String, int>> watchThemeCounts() {
    return _db
        .customSelect(
          'SELECT theme_id, COUNT(*) AS cnt FROM conversation GROUP BY theme_id',
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows)
              if (r.data['theme_id'] != null)
                '${r.data['theme_id']}': (r.data['cnt'] as int? ?? 0),
          },
        );
  }

  /// 标签定义流（conversation_tag，id 正序，与桌面端 loadTags 一致）
  Stream<List<ConversationTagData>> watchTags() {
    return (_db.select(
      _db.conversationTag,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  /// 全量消息流（气泡引用计数 / 反向链接扫描用；conversation 数据量小）
  Stream<List<ConversationData>> watchAllConversations() {
    return _db.select(_db.conversation).watch();
  }

  /// 某主题下的消息流：置顶在前，其余按创建时间正序；
  /// 软删除过滤对 NULL 免疫（老数据该列可能为空）
  Stream<List<ConversationData>> watchMessages(String themeId) {
    return (_db.select(_db.conversation)
          ..where(
            (t) =>
                t.themeId.equals(themeId) &
                (t.isDeleted.isNull() | t.isDeleted.equals('0')),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.asc(t.createTime),
          ]))
        .watch();
  }

  /// 新建主题（桌面端字段：title/tags(JSON 标签 id 数组)/create_time/update_time/remark/parent_id）
  /// tagIds：主题标签 id 数组（scope='theme'），与桌面端 createTheme 对齐。
  Future<int> createTheme({
    required String title,
    String remark = '',
    List<String> tagIds = const [],
  }) async {
    final now = _now();
    return _db
        .into(_db.conversationTheme)
        .insert(
          ConversationThemeCompanion.insert(
            title: Value(title),
            tags: Value(jsonEncode(tagIds)),
            createTime: Value(now),
            updateTime: Value(now),
            remark: Value(remark),
            parentId: const Value(null),
          ),
        );
  }

  /// 更新主题（标题 / 备注 / 标签，与桌面端 updateTheme 对齐；自动刷新 update_time）
  /// tagIds：不传则不动标签列；传空数组表示清空标签。
  Future<void> updateTheme(
    int id, {
    String? title,
    String? remark,
    List<String>? tagIds,
  }) async {
    await (_db.update(
      _db.conversationTheme,
    )..where((t) => t.id.equals(id))).write(
      ConversationThemeCompanion(
        updateTime: Value(_now()),
        title: title == null ? const Value.absent() : Value(title),
        remark: remark == null ? const Value.absent() : Value(remark),
        tags: tagIds == null
            ? const Value.absent()
            : Value(jsonEncode(tagIds)),
      ),
    );
  }

  /// 按标题查找或创建主题（对齐 PC RecordProgressDialog「按标题写入主题对话」）。
  /// 返回主题 id 字符串化；不存在则新建并返回其 id。
  Future<String> findOrCreateThemeByTitle(String title, {String remark = ''}) async {
    final existing = await (_db.select(_db.conversationTheme)
          ..where((t) => t.title.equals(title)))
        .get();
    if (existing.isNotEmpty) return existing.first.id.toString();
    final id = await createTheme(title: title, remark: remark);
    return id.toString();
  }

  /// 删除主题（对齐桌面端 deleteTheme：存在子主题时抛错；级联删除其下全部对话）
  Future<void> deleteTheme(int id) async {
    final children = await (_db.select(
      _db.conversationTheme,
    )..where((t) => t.parentId.equals(id.toString()))).get();
    if (children.isNotEmpty) {
      throw Exception('该主题下存在子主题，请先删除其下全部子主题后再删除');
    }
    await (_db.delete(
      _db.conversation,
    )..where((t) => t.themeId.equals(id.toString()))).go();
    await (_db.delete(
      _db.conversationTheme,
    )..where((t) => t.id.equals(id))).go();
  }

  /// 追加一条消息（记录型对话；themeId 与桌面端一致为字符串化 id；tagIds 写入 tags JSON；
  /// refIds = 同主题引用的消息 id；crossRefs = 跨主题引用 [{themeId, convId}]，均与桌面端同构）
  ///
  /// [content] 可以是纯文本或富文本 HTML —— **调用方不需要自己判断类型**：
  /// 由 [normalizeContent] 统一归一化（对齐桌面端 `createConversation`）——含实际格式
  /// 则原样存 HTML + `is_rich='1'`，否则去掉标签存纯文本 + `is_rich='0'`。
  /// ⚠️ 判据必须与 PC 逐字一致，否则会出现「一端按富文本渲染、另一端把源码显示出来」。
  Future<void> addMessage({
    required String themeId,
    required String content,
    List<String> tagIds = const [],
    List<String> refIds = const [],
    List<({int themeId, int convId})> crossRefs = const [],
  }) async {
    final now = _now();
    // 内容归一化：落库 content 与 is_rich 由同一处判定（唯一入口，勿在调用点各判一次）
    final normalized = normalizeContent(content);
    await _db
        .into(_db.conversation)
        .insert(
          ConversationCompanion.insert(
            themeId: Value(themeId),
            content: Value(normalized.content),
            tags: Value(jsonEncode(tagIds)),
            createTime: Value(now),
            pinned: const Value('0'),
            isDeleted: const Value('0'),
            refIds: Value(jsonEncode(refIds)),
            crossRefs: Value(
              jsonEncode([
                for (final x in crossRefs)
                  {'themeId': x.themeId, 'convId': x.convId},
              ]),
            ),
            isRich: Value(normalized.isRichFlag),
          ),
        );
    // 同步刷新主题的更新时间（与桌面端 createConversation 行为一致）
    final themeIdInt = int.tryParse(themeId);
    if (themeIdInt != null) {
      await (_db.update(_db.conversationTheme)
            ..where((t) => t.id.equals(themeIdInt)))
          .write(ConversationThemeCompanion(updateTime: Value(now)));
    }
  }

  /// 更新一条消息的**内容**（对齐桌面端 `updateConversation` 的 content 分支）。
  ///
  /// 归一化规则与 [addMessage] 完全一致，并**同步改写 `is_rich`** —— 所以「把一条
  /// 富文本改回纯文本」会正确地降级为 `is_rich='0'`，不会留下「标记是富文本、
  /// 内容却是纯文本」的半脏行。
  ///
  /// ⚠️ 与桌面端一致：**不**刷新主题的 `update_time`（PC 只在新建 / 改主题元信息时刷，
  /// 改对话内容不刷）。若要顺带改标签请用 [updateMessageTags]，别在这里捎带。
  Future<void> updateMessageContent(int id, String content) {
    final normalized = normalizeContent(content);
    return (_db.update(_db.conversation)..where((t) => t.id.equals(id))).write(
      ConversationCompanion(
        content: Value(normalized.content),
        isRich: Value(normalized.isRichFlag),
      ),
    );
  }

  /// 取单条消息（富文本编辑页进入编辑态时按 id 回显；已软删的返回 null）
  Future<ConversationData?> getMessage(int id) async {
    final rows = await (_db.select(
      _db.conversation,
    )..where((t) => t.id.equals(id))).get();
    if (rows.isEmpty) return null;
    final m = rows.first;
    return m.isDeleted == '1' ? null : m;
  }

  /// 更新一条消息的标签（tags JSON 数组，对齐桌面端 updateConversation）
  Future<void> updateMessageTags(int id, List<String> tagIds) {
    return (_db.update(_db.conversation)..where((t) => t.id.equals(id))).write(
      ConversationCompanion(tags: Value(jsonEncode(tagIds))),
    );
  }

  /// 新建对话标签（scope='conversation'；配色对齐桌面端 TAG_COLORS 按顺序取色）
  Future<ConversationTagData> createConversationTag(String name) async {
    final existing = await (_db.select(
      _db.conversationTag,
    )..where((t) => t.scope.equals('conversation'))).get();
    final color = kTagPalette[existing.length % kTagPalette.length];
    final id = await _db
        .into(_db.conversationTag)
        .insert(
          ConversationTagCompanion.insert(
            name: Value(name),
            color: Value(color),
            scope: const Value('conversation'),
            createTime: Value(_now()),
          ),
        );
    return ConversationTagData(
      id: id,
      name: name,
      color: color,
      scope: 'conversation',
      createTime: _now(),
    );
  }

  /// 新建主题标签（scope='theme'；配色对齐桌面端 TAG_COLORS 按顺序取色）
  /// 与 createConversationTag 平行，仅 scope 不同；创建后自动选中由调用方处理。
  Future<ConversationTagData> createThemeTag(String name) async {
    final existing = await (_db.select(
      _db.conversationTag,
    )..where((t) => t.scope.equals('theme'))).get();
    final color = kTagPalette[existing.length % kTagPalette.length];
    final id = await _db
        .into(_db.conversationTag)
        .insert(
          ConversationTagCompanion.insert(
            name: Value(name),
            color: Value(color),
            scope: const Value('theme'),
            createTime: Value(_now()),
          ),
        );
    return ConversationTagData(
      id: id,
      name: name,
      color: color,
      scope: 'theme',
      createTime: _now(),
    );
  }

  /// 更新标签（重命名 / 改色，对齐桌面端 updateTag；引用处无需回写——
  /// 主题/消息 tags 存 id，名称与颜色实时解析）
  Future<void> updateTag(int id, {String? name, String? color}) async {
    await (_db.update(
      _db.conversationTag,
    )..where((t) => t.id.equals(id))).write(
      ConversationTagCompanion(
        name: name == null ? const Value.absent() : Value(name),
        color: color == null ? const Value.absent() : Value(color),
      ),
    );
  }

  /// 删除标签（对齐桌面端 deleteTag 语义：删行 + 自动从主题/对话 tags 字段移除该 id）
  Future<void> deleteTag(int id) async {
    final idStr = '$id';
    await (_db.delete(
      _db.conversationTag,
    )..where((t) => t.id.equals(id))).go();
    final themes = await _db.select(_db.conversationTheme).get();
    for (final th in themes) {
      final ids = _strArr(th.tags);
      if (ids.contains(idStr)) {
        await (_db.update(
          _db.conversationTheme,
        )..where((t) => t.id.equals(th.id))).write(
          ConversationThemeCompanion(
            tags: Value(
              jsonEncode(ids.where((e) => e != idStr).toList()),
            ),
          ),
        );
      }
    }
    final msgs = await _db.select(_db.conversation).get();
    for (final m in msgs) {
      final ids = _strArr(m.tags);
      if (ids.contains(idStr)) {
        await (_db.update(
          _db.conversation,
        )..where((t) => t.id.equals(m.id))).write(
          ConversationCompanion(
            tags: Value(jsonEncode(ids.where((e) => e != idStr).toList())),
          ),
        );
      }
    }
  }

  /// 取某主题下的全部对话（排除软删，按 create_time 升序）——导出 Markdown 用，
  /// 口径与桌面端 getConversationsByTheme 一致。
  Future<List<ConversationData>> getMessagesByTheme(String themeId) async {
    return (_db.select(_db.conversation)
          ..where(
            (t) =>
                t.themeId.equals(themeId) &
                (t.isDeleted.isNull() | t.isDeleted.equals('0')),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createTime)]))
        .get();
  }

  /// 软删除一条消息（对齐桌面端追溯语义：is_deleted='1'，行保留）
  Future<void> softDeleteMessage(int id) {
    return (_db.update(_db.conversation)..where((t) => t.id.equals(id))).write(
      ConversationCompanion(isDeleted: const Value('1')),
    );
  }

  /// 置顶 / 取消置顶（pinned '1'/'0'，与桌面端同列）
  Future<void> togglePin(ConversationData msg) {
    return (_db.update(
      _db.conversation,
    )..where((t) => t.id.equals(msg.id))).write(
      ConversationCompanion(pinned: Value(msg.pinned == '1' ? '0' : '1')),
    );
  }

  /// 计算一条消息的引用关系（正向 / 跨主题 / 反向），供长按菜单与链接抽屉。
  /// 实现取全表在 Dart 内扫描（conversation 数据量小；JSON 含在文本列，SQL LIKE 易误配）。
  Future<ConvRefLinks> loadRefLinks(ConversationData msg) async {
    final all = await _db.select(_db.conversation).get();
    final byId = {for (final c in all) c.id: c};
    final themeTitles = {
      for (final th in await _db.select(_db.conversationTheme).get())
        th.id: th.title,
    };

    // 正向：ref_ids 指向的同主题消息
    final outgoing = <ConversationData>[
      for (final idStr in _strArr(msg.refIds))
        if (int.tryParse(idStr) case final id? when byId[id] != null) byId[id]!,
    ];

    // 跨主题引用：cross_refs [{themeId, convId}]
    final cross = <ConvRefItem>[
      for (final ref in _crossArr(msg.crossRefs))
        if (byId[ref.convId] != null)
          ConvRefItem(byId[ref.convId]!, themeTitles[ref.themeId]),
    ];

    // 反向：其它消息的 ref_ids / cross_refs 指向本条
    final backlinks = <ConvRefItem>[];
    for (final c in all) {
      if (c.id == msg.id) continue;
      final sameTheme = _strArr(c.refIds).contains('${msg.id}');
      final crossHit = _crossArr(c.crossRefs).any((x) => x.convId == msg.id);
      if (sameTheme || crossHit) {
        backlinks.add(
          ConvRefItem(c, themeTitles[int.tryParse(c.themeId ?? '')]),
        );
      }
    }
    return ConvRefLinks(outgoing: outgoing, cross: cross, backlinks: backlinks);
  }

  /// 解析 JSON 字符串数组（异常返回空）
  static List<String> _strArr(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return [
        if (v is List)
          for (final e in v) e.toString(),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 解析跨主题引用 JSON（[{themeId, convId}]，异常返回空）
  static List<({int themeId, int convId})> _crossArr(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return [
        if (v is List)
          for (final e in v)
            if (e is Map)
              (
                themeId: int.tryParse('${e['themeId']}') ?? 0,
                convId: int.tryParse('${e['convId']}') ?? 0,
              ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}

/// 仓库 provider
final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>(
      (ref) => ConversationRepository(ref.watch(appDatabaseProvider)),
    );

/// 主题流 provider
final StreamProvider<List<ConversationThemeData>> conversationThemesProvider =
    StreamProvider<List<ConversationThemeData>>(
      (ref) => ref.watch(conversationRepositoryProvider).watchThemes(),
    );

/// 各主题对话数 provider（角标）
final StreamProvider<Map<String, int>> themeCountsProvider =
    StreamProvider<Map<String, int>>(
      (ref) => ref.watch(conversationRepositoryProvider).watchThemeCounts(),
    );

/// 标签定义流 provider（conversation_tag）
final StreamProvider<List<ConversationTagData>> conversationTagsProvider =
    StreamProvider<List<ConversationTagData>>(
      (ref) => ref.watch(conversationRepositoryProvider).watchTags(),
    );

/// 消息流 provider（family：themeId）
final messagesProvider = StreamProvider.family<List<ConversationData>, String>(
  (ref, themeId) =>
      ref.watch(conversationRepositoryProvider).watchMessages(themeId),
);

/// 全量消息流 provider（气泡引用计数 / 反向链接扫描用）
final StreamProvider<List<ConversationData>> allConversationsProvider =
    StreamProvider<List<ConversationData>>(
      (ref) =>
          ref.watch(conversationRepositoryProvider).watchAllConversations(),
    );
