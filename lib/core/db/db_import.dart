// 数据库导入（需求#2）：选择本机/桌面导出的 db.sqlite，按主键 upsert 并入默认库。
//
// 语义：非破坏式合并。对默认库每个「数据表」（排除 basic_info 配置表）逐表
// `SELECT * FROM 源` → `INSERT OR REPLACE`（按主键），与局域网同步协议的 upsert 语义一致：
// 源库有、本地也有的行 → 被源覆盖；源库没有、本地有的行 → 保留。
//
// 容错（沿用 sync_service 的踩坑结论）：
// - 源库必须含 basic_info 表才认为是本 App 数据库，否则拒绝，绝不误写；
// - 逐表按本表「实际列」过滤源行字段，兼容双端 schema 差异（源多列/少列都不崩）；
// - 整段包在事务里，任一步失败整体回滚，不留下半截数据；
// - drift 的 customStatement 不会自动通知 watch 流，写完后手动 notifyUpdates 触发列表刷新。
import 'dart:io';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// 导入结果
typedef DbImportResult = ({
  int tables,
  int rows,
  String message,
  bool ok,
});

/// 把 [sourcePath] 指向的数据库文件合并进默认库 [db]。
///
/// [sourcePath] 通常来自 file_picker 选中的 .sqlite/.db/.sqlite3 文件。
Future<DbImportResult> importDatabaseFile(AppDatabase db, String sourcePath) async {
  final src = AppDatabase.forFile(File(sourcePath));
  try {
    // 1) 校验：必须是本 App 同源数据库（含 basic_info 表），否则拒绝
    final valid = await src
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='basic_info'",
        )
        .get();
    if (valid.isEmpty) {
      return (
        tables: 0,
        rows: 0,
        ok: false,
        message: '所选文件不是有效的渐离App数据库，已取消导入。',
      );
    }

    // 2) 源库实际存在的表集合
    final sourceTables = (await src
            .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
            .get())
        .map((r) => r.data['name'] as String)
        .toSet();

    int tables = 0;
    int rows = 0;
    final updated = <String>{};

    // 3) 逐表合并（事务包裹，失败整体回滚）
    await db.transaction(() async {
      for (final tbl in db.allTables) {
        final name = tbl.actualTableName;
        if (name == 'basic_info') continue; // 不动本地配置（2FA vault 路径等）
        if (!sourceTables.contains(name)) continue; // 源缺该表，跳过

        final srcRows = await src.customSelect('SELECT * FROM "$name"').get();
        if (srcRows.isEmpty) continue;

        // 本表实际列（过滤掉源库多余列，兼容 schema 差异）
        final cols = (await db
                .customSelect('PRAGMA table_info("$name")')
                .get())
            .map((r) => r.data['name'] as String)
            .toSet();

        for (final row in srcRows) {
          final data = <String, Object?>{
            for (final e in row.data.entries)
              if (cols.contains(e.key)) e.key: e.value,
          };
          if (data.isEmpty) continue;
          final colSql = data.keys.map((k) => '"$k"').join(', ');
          final placeholders = List.filled(data.length, '?').join(', ');
          await db.customStatement(
            'INSERT OR REPLACE INTO "$name" ($colSql) VALUES ($placeholders)',
            data.values.toList(),
          );
          rows++;
        }
        updated.add(name);
        tables++;
      }
    });

    // 4) customStatement 不通知 watch 流，手动触发刷新（让各列表页即时反映导入数据）
    for (final t in updated) {
      db.notifyUpdates({TableUpdate(t)});
    }

    return (
      tables: tables,
      rows: rows,
      ok: true,
      message: '导入完成：更新 $tables 张表、共 $rows 行数据。',
    );
  } on Object catch (e) {
    return (
      tables: 0,
      rows: 0,
      ok: false,
      message: '导入失败：${e.toString()}',
    );
  } finally {
    await src.close();
  }
}
