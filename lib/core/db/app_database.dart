// App 数据库（drift）—— 渐离移动端数据层入口
//
// 设计要点（对应 .zcode/skills/jianli-app/references/flutter-port.md）：
// 1. 与桌面端 db.sqlite 同构：表定义逐列对齐（驼峰列用 @Named 锁定），
//    后续局域网同步按主键幂等 upsert。
// 2. 移动端自有库文件存放在应用沙盒 Documents 目录（文件名 db.sqlite）。
// 3. 迁移：首批 22 张表一次性建齐；后续扩表 schemaVersion+1 并写 onUpgrade 迁移。
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // v1→v2：仅新增 file_transfer，drift 的 createAll 用 IF NOT EXISTS，
        // 只会建缺失表，已有的 25 张不动。
        onUpgrade: (m, from, to) async => await m.createAll(),
      );
}

/// 打开沙盒内数据库连接（后台 isolate 执行，避免阻塞 UI）
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = p.join(dir.path, 'db.sqlite');
    return NativeDatabase.createInBackground(File(file));
  });
}
