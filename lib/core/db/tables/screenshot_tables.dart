// 截图记录数据表定义（screenshots）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// ⚠️ 移动端无法系统级监听截图（隐私限制），功能重设计为：相册导入（image_picker）/
//    系统分享收纳；图片拷入沙盒后 path 重写为沙盒路径。
import 'package:drift/drift.dart';

/// 截图记录表 screenshots（自增 id）
class Screenshots extends Table {
  IntColumn get id => integer().autoIncrement()();

  // ---- 旧层遗留列 ----
  TextColumn get name => text().nullable()();
  TextColumn get value => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  // ---- 业务列 ----
  /// 图片路径（桌面端为系统路径；移动端为沙盒内路径）
  TextColumn get path => text().nullable()();

  /// 动作，如 save
  TextColumn get action => text().nullable()();
  TextColumn get width => text().nullable()();
  TextColumn get height => text().nullable()();

  /// 贴纸处理状态
    TextColumn get stickerStatus => text().named('sticker_status').nullable()();
}
