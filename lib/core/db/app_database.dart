// App 数据库（drift）—— 渐离App移动端数据层入口
//
// 设计要点（对应 .zcode/skills/jianli-app/references/flutter-port.md）：
// 1. 与桌面端 db.sqlite 同构：表定义逐列对齐（驼峰列用 @Named 锁定），
//    后续局域网同步按主键幂等 upsert。
// 2. 库文件位置（2026-09-17 调整，需求#1：重装不丢数据）：默认 `Download/渐离App/db.sqlite`
//    （系统公共 Download 子目录，需「所有文件访问」MANAGE_EXTERNAL_STORAGE，API30+ 才有此要求；
//    该目录不在应用沙盒内，卸载/重装不会被清，文件管理器可直接浏览）。
//    未授权「所有文件访问」或 非 Android → 回退沙盒 `<filesDir>/databases/db.sqlite`
//    （path_provider.getApplicationSupportDirectory() → Android `getFilesDir()`），与旧版一致不丢数据。
//    具体解析与「首启从最新候选源单向拷贝」的迁移逻辑收口在 `db_location.dart`
//    的 [resolveDefaultDatabaseFile]（兼容旧位置 documents/app_flutter → filesDir/databases）。
// 3. 迁移铁律：升级必须「增量、非破坏性」。drift 的 createAll() 生成
//    `CREATE TABLE IF NOT EXISTS`，对「已存在」的表是空操作——绝不重建、绝不清空行。
//    绝不能用 destructiveFallback（drop 全表再重建 = 清空用户数据）。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'db_location.dart';
import 'tables/browser_tables.dart';
import 'tables/conversation_tables.dart';
import 'tables/ebook_tables.dart';
import 'tables/file_transfer.dart';
import 'tables/file_vault_tables.dart';
import 'tables/habit_tables.dart';
import 'tables/note_slip.dart';
import 'tables/note_tables.dart';
import 'tables/pomodoro_tables.dart';
import 'tables/reminder_tables.dart';
import 'tables/screenshot_tables.dart';
import 'tables/todo_tables.dart';
import 'tables/tool_tables.dart';

part 'app_database.g.dart';

/// 渐离App移动端数据库
/// 首批 22 张表 + 工具表 3 张（countdown / qr_history / qr_template），共 25 张；
/// v2 新增 file_transfer（文件互传历史）；
/// v4 新增浏览器 4 张（browser_tabs / browser_pinned / browser_bookmarks / browser_history，移动端专有、不入同步白名单）；
/// v5 新增浏览器 2 张（browser_downloads / browser_offline_pages，下载与离线页面，移动端专有、不入同步白名单）；
/// v6 新增 note_slip（P1-6 小纸条收发记录，双端同构、不入同步白名单）。
@DriftDatabase(
  tables: [
    HabitDef,
    HabitCheckin,
    TodoList,
    TodoTags,
    Reminders,
    NoteBook,
    BasicInfo,
    PomodoroStatus,
    PomodoroMiniConfig,
    Conversation,
    ConversationTheme,
    ConversationTag,
    FileVaultConfig,
    FileVaultFiles,
    EbookBookshelf,
    EbookProgress,
    EbookBookmark,
    EbookAnnotation,
    EbookCategory,
    EbookBookCategory,
    EbookBgImage,
    Screenshots,
    Countdown,
    QrHistory,
    QrTemplate,
    FileTransfer,
    // —— 浏览器（移动端专有，v4 + v5）——
    BrowserTabs,
    BrowserPinned,
    BrowserBookmarks,
    BrowserHistory,
    BrowserDownloads,
    BrowserOfflinePages,
    // —— 小纸条（P1-6，v6）——
    NoteSlip,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 只读打开外部数据库文件（需求#2：导入时按主键合并源库数据用）。
  /// 仅作 SELECT，绝不写盘；源库 schema 与本 App 同源（含 basic_info 表）时使用。
  AppDatabase.forFile(File f)
      : super(LazyDatabase(
          () async => NativeDatabase(f, enableMigrations: false),
        ));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // 铁律：迁移必须「增量、非破坏性」。绝不用 destructiveFallback
          //（drop 全部表再重建 = 清空用户数据）。drift 的 createAll() 生成
          // `CREATE TABLE IF NOT EXISTS`：对「已存在」的表是空操作，不会重建、不会清空任何行；
          // 只对缺失的表执行建表。所以升级永远保留旧数据，所有表都不应被擦除。
          // 后续每扩一张表 / 加一列：schemaVersion+1，并在下面按 from 分支补
          // createTable(ifNotExists) / addColumn，绝不可改用 destructiveFallback。
          if (from < 2) {
            // v1→v2：仅新增 file_transfer（见 @DriftDatabase 注册）；
            // 其余 25 张表 IF NOT EXISTS 跳过，数据原样保留。
            await m.createAll();
          }
          // v2→v3：reminders 表新增 delivery 列（提醒送达方式：通知/闹钟）
          if (from < 3) {
            await m.addColumn(reminders, reminders.delivery);
          }
          // v3→v4：新增浏览器 4 张表（browser_tabs / browser_pinned /
          // browser_bookmarks / browser_history）。createAll 生成的是
          // `CREATE TABLE IF NOT EXISTS`，对已有 28 张表是空操作，数据原样保留。
          if (from < 4) {
            await m.createAll();
          }
          // v4→v5：新增浏览器 2 张表（browser_downloads / browser_offline_pages）。
          // 同样 CREATE TABLE IF NOT EXISTS，不碰旧表、不丢数据。
          if (from < 5) {
            await m.createAll();
          }
          // v5→v6：新增 note_slip（P1-6 小纸条）。同样 CREATE TABLE IF NOT EXISTS，
          // 不碰旧表、不丢数据。
          if (from < 6) {
            await m.createAll();
          }
        },
      );
}

/// 打开数据库连接（后台 isolate 执行，避免阻塞 UI）
///
/// 库文件位置约定（2026-09-17 调整，需求#1：重装不丢数据）：
/// - 默认：系统 `Download/渐离App/db.sqlite`（需「所有文件访问」MANAGE_EXTERNAL_STORAGE，
///   API30+ 才有此要求）。该目录不在应用沙盒内，卸载/重装不会被清，文件管理器可直接浏览。
/// - 回退：未授权「所有文件访问」或 非 Android → 沙盒 `<filesDir>/databases/db.sqlite`
///   （`getApplicationSupportDirectory()` → Android `getFilesDir()`），与旧版行为一致。
/// 具体解析与「首启从最新候选源单向拷贝」的迁移逻辑收口在 `db_location.dart` 的
/// [resolveDefaultDatabaseFile]，这里只调用它拿最终文件。
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await resolveDefaultDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}
