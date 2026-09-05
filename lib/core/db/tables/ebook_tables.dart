// 电子书阅读器数据表定义（ebook_* 共 7 张）
//
// 与桌面端 db.sqlite 逐列对齐（来源：test-scripts/db_first_batch_dump.txt）。
// ⚠️ 桌面端以「文件绝对路径 file_path」做关联键；移动端把 epub 放进沙盒后路径必然不同，
//    必须用 content_hash 做稳定映射（flutter-port.md 第 3 节红线），不依赖 file_path。
import 'package:drift/drift.dart';

/// 书架表 ebook_bookshelf（file_path TEXT PRIMARY KEY）
class EbookBookshelf extends Table {
  /// 桌面端文件绝对路径（主键；移动端同步后需以 content_hash 重映射）
    TextColumn get filePath => text().named('file_path')();

  TextColumn get name => text().nullable()();
  TextColumn get format => text().nullable()();

  /// 阅读进度百分比（桌面端 REAL）
  RealColumn get percent => real().nullable()();

    TextColumn get lastReadAt => text().named('last_read_at').nullable()();

    TextColumn get addedAt => text().named('added_at').nullable()();

  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();

  /// 封面（data URL 或路径）
  TextColumn get cover => text().nullable()();

  /// 文件内容哈希（跨端稳定映射键）
    TextColumn get contentHash => text().named('content_hash').nullable()();

  /// 旧层遗留可空整型列
  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {filePath};
}

/// 阅读进度表 ebook_progress（file_path TEXT PRIMARY KEY）
class EbookProgress extends Table {
    TextColumn get filePath => text().named('file_path')();

  TextColumn get format => text().nullable()();

  /// epub CFI 定位串
  TextColumn get cfi => text().nullable()();

  /// 阅读进度百分比（桌面端 REAL）
  RealColumn get percent => real().nullable()();

    TextColumn get updatedAt => text().named('updated_at').nullable()();

    TextColumn get contentHash => text().named('content_hash').nullable()();

  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {filePath};
}

/// 书签表 ebook_bookmark
class EbookBookmark extends Table {
  IntColumn get id => integer().autoIncrement()();

    TextColumn get filePath => text().named('file_path').nullable()();

  TextColumn get format => text().nullable()();
  TextColumn get cfi => text().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get percent => text().nullable()();

    TextColumn get createdAt => text().named('created_at').nullable()();

    TextColumn get contentHash => text().named('content_hash').nullable()();
}

/// 划线/批注表 ebook_annotation（type 区分样式，color 为标注色）
class EbookAnnotation extends Table {
  IntColumn get id => integer().autoIncrement()();

    TextColumn get filePath => text().named('file_path').nullable()();

  TextColumn get format => text().nullable()();

  /// 定位锚点（epub CFI / pdf 坐标串）
  TextColumn get anchor => text().nullable()();

  /// 选中原文
  /// ⚠️ getter 不能叫 text（与 drift Table.text() 构造方法冲突），
  ///    改名 annotatedText 并用 named('text') 锁定桌面列名。
  TextColumn get annotatedText => text().named('text').nullable()();

  /// 批注内容
  TextColumn get note => text().nullable()();

  /// 标注颜色（桌面端默认 'yellow'）
  TextColumn get color => text().nullable()();

    TextColumn get createdAt => text().named('created_at').nullable()();

    TextColumn get updatedAt => text().named('updated_at').nullable()();

  /// 类型，如 markStrong
  TextColumn get type => text().nullable()();

    TextColumn get contentHash => text().named('content_hash').nullable()();
}

/// 书籍分类表 ebook_category（name UNIQUE）
class EbookCategory extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

    TextColumn get createdAt => text().named('created_at').nullable()();

  TextColumn get color => text().nullable()();
}

/// 书-分类关联表 ebook_book_category（复合主键 book_path + category_id）
class EbookBookCategory extends Table {
    TextColumn get bookPath => text().named('book_path')();

    IntColumn get categoryId => integer().named('category_id')();

  /// 旧层遗留可空整型列
  IntColumn get id => integer().nullable()();

  @override
  Set<Column> get primaryKey => {bookPath, categoryId};
}

/// 阅读背景图表 ebook_bg_image（image_path UNIQUE，data_url 存图）
class EbookBgImage extends Table {
  IntColumn get id => integer().autoIncrement()();

    TextColumn get imagePath => text().named('image_path').unique()();

    TextColumn get dataUrl => text().named('data_url').nullable()();

    TextColumn get createdAt => text().named('created_at').nullable()();
}
