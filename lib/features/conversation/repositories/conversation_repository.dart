// 主题对话仓库 —— 只读浏览（themes / messages）
//
// LLM 后端未定稿前移动端仅做「浏览」；字段语义与桌面端 db.ts 对齐：
// conversation.is_deleted='1' 过滤软删除，theme_id 为字符串化的主题 id。
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

/// 主题对话仓库
class ConversationRepository {
  ConversationRepository(this._db);

  final AppDatabase _db;

  /// 主题列表流（update_time 倒序）
  Stream<List<ConversationThemeData>> watchThemes() {
    return (_db.select(
      _db.conversationTheme,
    )..orderBy([(t) => OrderingTerm.desc(t.updateTime)])).watch();
  }

  /// 某主题下的消息流（过滤软删除，时间正序）
  Stream<List<ConversationData>> watchMessages(String themeId) {
    return (_db.select(_db.conversation)
          ..where((t) => t.themeId.equals(themeId) & t.isDeleted.equals('0'))
          ..orderBy([(t) => OrderingTerm.asc(t.createTime)]))
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

  /// 追加一条消息（记录型对话；themeId 与桌面端一致为字符串化 id）
  Future<void> addMessage({
    required String themeId,
    required String content,
  }) async {
    await _db
        .into(_db.conversation)
        .insert(
          ConversationCompanion.insert(
            themeId: Value(themeId),
            content: Value(content),
            tags: const Value('[]'),
            createTime: Value(_now()),
            pinned: const Value('0'),
            isDeleted: const Value('0'),
            refIds: const Value('[]'),
            isRich: const Value('0'),
          ),
        );
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

/// 消息流 provider（family：themeId）
final messagesProvider = StreamProvider.family<List<ConversationData>, String>(
  (ref, themeId) =>
      ref.watch(conversationRepositoryProvider).watchMessages(themeId),
);
