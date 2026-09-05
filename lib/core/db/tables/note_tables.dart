// 笔记模块数据表定义（note_book）+ 全局键值表（basic_info）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// ⚠️ 桌面端驼峰列名必须 named() 锁定（详见 habit_tables.dart 顶部说明）。
// note_book.html 为 vue-quill 产出的富文本 HTML，移动端阅读用 flutter_widget_from_html 渲染，
// 编辑器（flutter_quill）列入 P2。
// basic_info 是桌面端全局键值配置（含 twoFactorVaultPath / passwordVaultPath / appLockVault /
// note_tags 等关键键），是加密 PoC（vault 路径寻址）的关键表。
import 'package:drift/drift.dart';

/// 可归类笔记表 note_book（key TEXT PRIMARY KEY，类型未声明的文本主键）
class NoteBook extends Table {
  /// 业务主键（UUID）
  TextColumn get key => text()();

  /// 摘要（列表展示用）
  TextColumn get excerpt => text().nullable()();

  /// 富文本 HTML（vue-quill 产出）
  TextColumn get html => text().nullable()();

  TextColumn get createTime => text().named('createTime').nullable()();

  TextColumn get updateTime => text().named('updateTime').nullable()();

  TextColumn get mdText => text().named('mdText').nullable()();

  TextColumn get tags => text().nullable()();

  TextColumn get whereStr => text().named('whereStr').nullable()();

  TextColumn get content => text().nullable()();

  /// 分类
  TextColumn get category => text().nullable()();

  /// 旧层遗留可空整型列
  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 全局键值配置表 basic_info（key PRIMARY KEY）
/// 桌面端把 vault 文件路径 / 应用锁哨兵 / 笔记标签配置等全放这里。
class BasicInfo extends Table {
  /// 配置键（如 twoFactorVaultPath / appLockVault / note_tags / closeWorkTime）
  TextColumn get key => text()();

  /// 配置值（vault 相关键的 value 为路径或哨兵 JSON）
  TextColumn get value => text().nullable()();

  TextColumn get whereStr => text().named('whereStr').nullable()();

  TextColumn get orderByDesc => text().named('orderByDesc').nullable()();

  TextColumn get orderBy => text().named('orderBy').nullable()();

  /// 旧层遗留可空整型列
  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
