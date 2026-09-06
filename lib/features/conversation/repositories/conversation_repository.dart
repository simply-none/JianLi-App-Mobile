// 主题对话仓库 —— 对齐桌面端 useThemeConversation 的移动端子集
//
// 字段语义与桌面端 db.ts / types.ts 对齐：
// - conversation_theme：title/tags(JSON 标签 id 数组)/create_time/update_time/remark/parent_id(子主题)
// - conversation：theme_id(字符串化主题 id)/content/is_rich('1'=HTML)/ref_ids(同主题引用 JSON)/
//   cross_refs(跨主题引用 JSON：[{themeId,convId}])/tags/create_time/annotate_time/pinned('1'置顶)/
//   is_deleted('1'软删)
// - conversation_tag：name/color/scope(theme|conversation)/create_time
// 未做（桌面端有、移动端裁剪）：发起引用/跨主题引用、标注、多选、导出 Markdown、标签管理 CRUD、
// 富文本编辑——记 SKILL.md 待办。
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

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

  /// 新建主题（桌面端字段：title/tags/create_time/update_time/remark/parent_id）
  Future<int> createTheme({required String title, String remark = ''}) async {
    final now = _now();
    return _db
        .into(_db.conversationTheme)
        .insert(
          ConversationThemeCompanion.insert(
            title: Value(title),
            tags: const Value('[]'),
            createTime: Value(now),
            updateTime: Value(now),
            remark: Value(remark),
            parentId: const Value(null),
          ),
        );
  }

  /// 更新主题（标题 / 备注，与桌面端 updateTheme 对齐；自动刷新 update_time）
  Future<void> updateTheme(int id, {String? title, String? remark}) async {
    await (_db.update(
      _db.conversationTheme,
    )..where((t) => t.id.equals(id))).write(
      ConversationThemeCompanion(
        updateTime: Value(_now()),
        title: title == null ? const Value.absent() : Value(title),
        remark: remark == null ? const Value.absent() : Value(remark),
      ),
    );
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
  Future<void> addMessage({
    required String themeId,
    required String content,
    List<String> tagIds = const [],
    List<String> refIds = const [],
    List<({int themeId, int convId})> crossRefs = const [],
  }) async {
    final now = _now();
    await _db
        .into(_db.conversation)
        .insert(
          ConversationCompanion.insert(
            themeId: Value(themeId),
            content: Value(content),
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
            isRich: const Value('0'),
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

  /// 更新一条消息的标签（tags JSON 数组，对齐桌面端 updateConversation）
  Future<void> updateMessageTags(int id, List<String> tagIds) {
    return (_db.update(_db.conversation)..where((t) => t.id.equals(id))).write(
      ConversationCompanion(tags: Value(jsonEncode(tagIds))),
    );
  }

  /// 新建对话标签（scope='conversation'；配色对齐桌面端 TAG_COLORS 按顺序取色）
  Future<ConversationTagData> createConversationTag(String name) async {
    const palette = [
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
    final existing = await (_db.select(
      _db.conversationTag,
    )..where((t) => t.scope.equals('conversation'))).get();
    final color = palette[existing.length % palette.length];
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
