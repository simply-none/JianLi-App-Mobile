// App 数据库（drift）—— 渐离移动端数据层入口
//
// 设计要点（对应 .zcode/skills/jianli-app/references/flutter-port.md）：
// 1. 与桌面端 db.sqlite 同构：表定义逐列对齐（驼峰列用 @Named 锁定），
//    后续局域网同步按主键幂等 upsert。
// 2. 库文件位置（2026-09-07 调整）：`<filesDir>/databases/db.sqlite`
//    （path_provider.getApplicationSupportDirectory() → Android `getFilesDir()`，
//    对应 Auto Backup 的 `file` 备份域，默认覆盖 → 重装后云备份可恢复，用户数据不丢）。
//    （本工程 path_provider 锁 2.1.6，无 `getDatabasesPath()`，故用 filesDir/databases 等价落位。）
//    旧版本曾放在 `app_flutter/db.sqlite`（getApplicationDocumentsDirectory() 的返回，
//    即 Context.getDir('flutter') 目录；沙盒、重装即焚、且不在默认备份域内），
//    首次启动做一次单向拷贝到新位置（见 _openConnection），老用户升级不丢数据。
// 3. 迁移铁律：升级必须「增量、非破坏性」。drift 的 createAll() 生成
//    `CREATE TABLE IF NOT EXISTS`，对「已存在」的表是空操作——绝不重建、绝不清空行。
//    绝不能用 destructiveFallback（drop 全表再重建 = 清空用户数据）。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/conversation_tables.dart';
import 'tables/ebook_tables.dart';
import 'tables/file_transfer.dart';
import 'tables/file_vault_tables.dart';
import 'tables/habit_tables.dart';
import 'tables/note_tables.dart';
import 'tables/pomodoro_tables.dart';
import 'tables/reminder_tables.dart';
import 'tables/screenshot_tables.dart';
import 'tables/todo_tables.dart';
import 'tables/tool_tables.dart';

part 'app_database.g.dart';

/// 渐离移动端数据库
/// 首批 22 张表 + 工具表 3 张（countdown / qr_history / qr_template），共 25 张；
/// v2 新增 file_transfer（文件互传历史）。
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 只读打开桌面端导出的 db.sqlite 做数据校验/迁移演练时使用（测试入口，暂不暴露 UI）
  // AppDatabase.forFile(File f) : super(LazyDatabase(() async => NativeDatabase(f, readOnly: true)));

  @override
  int get schemaVersion => 3;

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
        },
      );
}

/// 打开数据库连接（后台 isolate 执行，避免阻塞 UI）
///
/// 库文件位置约定（2026-09-07 调整）：
/// - 新版本：`<filesDir>/databases/db.sqlite`（`getApplicationSupportDirectory()` →
///   Android `getFilesDir()`，对应 Auto Backup 的 `file` 备份域，默认覆盖 → 重装后云备份可恢复，用户数据不丢）。
///   （本工程 path_provider 锁 2.1.6，无 `getDatabasesPath()`，故用 filesDir/databases 等价落位。）
/// - 旧版本（≤ 本次调整前）把库放在 `app_flutter/db.sqlite`（getApplicationDocumentsDirectory()
///   的返回，即 Context.getDir('flutter') 目录），首次启动做一次单向拷贝到新位置
///   （旧文件保留，拷贝失败也不破坏原数据），保证老用户升级不丢数据。
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 新位置：<filesDir>/databases/db.sqlite（file 备份域，Auto Backup 覆盖）
    final supportDir = await getApplicationSupportDirectory();
    final newDir = Directory(p.join(supportDir.path, 'databases'));
    final newFile = File(p.join(newDir.path, 'db.sqlite'));
    if (!await newFile.exists()) {
      final oldDir = await getApplicationDocumentsDirectory();
      final oldFile = File(p.join(oldDir.path, 'db.sqlite'));
      if (await oldFile.exists()) {
        await newDir.create(recursive: true);
        await oldFile.copy(newFile.path);
      }
    }
    return NativeDatabase.createInBackground(newFile);
  });
}
