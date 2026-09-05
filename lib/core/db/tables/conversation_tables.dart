// 主题对话模块数据表定义（conversation / conversation_theme / conversation_tag）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// 这三张表桌面端业务列恰好全为下划线/单词风格（theme_id / create_time / is_deleted…），
// drift 默认转换即对齐；旧层遗留列（name/value/created_at）原样保留。
// LLM 后端（自建 API / 本地模型）未定稿前，移动端先做「只读浏览」。
import 'package:drift/drift.dart';

/// 对话消息表 conversation（自增 id，业务关联键为 theme_id）
class Conversation extends Table {
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列（桌面端即下划线风格，drift 默认对齐） ----
  /// 所属主题 id（conversation_theme.id 的字符串形式）
    TextColumn get themeId => text().named('theme_id').nullable()();

  /// 消息内容
  TextColumn get content => text().nullable()();

  /// 标签 JSON 数组
  TextColumn get tags => text().nullable()();

    TextColumn get createTime => text().named('create_time').nullable()();

  /// 标注时间
    TextColumn get annotateTime => text().named('annotate_time').nullable()();

  /// 是否置顶：'1'/'0'
  TextColumn get pinned => text().nullable()();

  /// 软删除标记：'1'/'0'
    TextColumn get isDeleted => text().named('is_deleted').nullable()();

  /// 引用的消息 id JSON
    TextColumn get refIds => text().named('ref_ids').nullable()();

  /// 是否富文本：'1'/'0'
    TextColumn get isRich => text().named('is_rich').nullable()();

  /// 桌面端遗留的截断列名（真实列就叫 is_），原样保留
    TextColumn get is_ => text().named('is_').nullable()();

  /// 交叉引用 JSON
    TextColumn get crossRefs => text().named('cross_refs').nullable()();

  /// 扩展键
    TextColumn get extKey => text().named('ext_key').nullable()();
}

/// 对话主题表 conversation_theme（主题/人格）
class ConversationTheme extends Table {
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  TextColumn get title => text().nullable()();
  TextColumn get tags => text().nullable()();

    TextColumn get createTime => text().named('create_time').nullable()();

    TextColumn get updateTime => text().named('update_time').nullable()();

  TextColumn get remark => text().nullable()();

  /// 父主题 id（主题树）
    TextColumn get parentId => text().named('parent_id').nullable()();
}

/// 对话标签表 conversation_tag（scope 区分 theme/message 作用域）
class ConversationTag extends Table {
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  TextColumn get color => text().nullable()();
  TextColumn get scope => text().nullable()();

    TextColumn get createTime => text().named('create_time').nullable()();
}
