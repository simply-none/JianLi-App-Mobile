// 浏览器功能域数据表定义（4 张，均为**移动端专有**）
//
// 桌面端没有浏览器模块，故这 4 张表**不纳入同步白名单**（不动 sync_service 的 kSyncableTables）——
// 标签会话/历史/固定标签都是「本机行为」，跨端同步没有语义。
//
// 设计对齐画布 https://ardot.tencent.com/file/727382358962697 ：
// - browser_tabs   单 WebView 多标签的会话表（只存「地址 + 标题 + 顺序」，
//                  切标签时由唯一 WebView 重新 loadUrl，不做多 WebView 常驻，省内存）。
// - browser_pinned 固定标签页（首页九宫格）。默认 8 个槽位（kPinnedMaxSlots），
//                  超出时**替换 added_at 最早的那一个**（FIFO）→ added_at 是替换判据，勿删。
// - browser_bookmarks 书签，支持文件夹（is_folder='1' 时 url 为空，用 parent_key 组树）。
// - browser_history   访问历史，按 url 去重累计（visit_count），按 visited_at 倒序展示。
import 'package:drift/drift.dart';

/// 打开的标签页会话（表名 `browser_tabs`，行类 `BrowserTab`）
class BrowserTabs extends Table {
  /// 会话内唯一 id（uuid）
  TextColumn get key => text()();

  /// 当前地址；**空 = 新标签页**（显示极简首页）
  TextColumn get url => text().nullable()();

  /// 页面标题（onLoadStop 取回；空则地址栏显示域名）
  TextColumn get title => text().nullable()();

  /// 标签栏顺序（0 起，越小越靠左）
  IntColumn get position => integer().nullable()();

  /// 最后活动时间(ms)，用于「恢复上次会话」排序
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 固定标签页（表名 `browser_pinned`）
class BrowserPinned extends Table {
  TextColumn get key => text()();

  TextColumn get title => text().nullable()();

  TextColumn get url => text().nullable()();

  /// 无 favicon 时的占位字（单字：中文取首字 / 英文取首字母）
  TextColumn get letter => text().nullable()();

  /// 占位字品牌色 `#RRGGBB`（落地换 favicon 后仅作兜底）
  TextColumn get color => text().nullable()();

  /// 九宫格槽位 0..7（替换时复用被替换者的槽位，视觉上「就地替换」）
  IntColumn get position => integer().nullable()();

  /// 加入时间(ms) —— **FIFO 替换的唯一判据**
  IntColumn get addedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 书签（表名 `browser_bookmarks`，支持文件夹层级）
class BrowserBookmarks extends Table {
  TextColumn get key => text()();

  TextColumn get title => text().nullable()();

  /// 文件夹行为空
  TextColumn get url => text().nullable()();

  /// `'1'` = 文件夹；`'0'` / 空 = 普通书签
  TextColumn get isFolder => text().nullable()();

  /// 父文件夹 key；空 = 根级
  TextColumn get parentKey => text().nullable()();

  IntColumn get position => integer().nullable()();

  IntColumn get createdAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 访问历史（表名 `browser_history`；key = `h_<url 的稳定哈希>` → 同一地址去重累计）
class BrowserHistory extends Table {
  TextColumn get key => text()();

  TextColumn get title => text().nullable()();

  TextColumn get url => text().nullable()();

  /// 最近一次访问时间(ms)
  IntColumn get visitedAt => integer().nullable()();

  /// 累计访问次数
  IntColumn get visitCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 下载任务（表名 `browser_downloads`；移动端专有、不入同步白名单）
///
/// 触发来源有两种：① WebView `onDownloadStartRequest`（点文件链接时系统把下载交给我们）；
/// ② 资源嗅探面板对枚举到的 `<img>/<video>/<audio>/<a[download]>` 手动「下载」。
/// 两种都走 [BrowserDownloadService]：先落一条 pending 记录，再用 dart:io HttpClient
/// 抓到 `Download/渐离App/browser_downloads/`（无权限则回退沙盒），结束后改 done/failed。
class BrowserDownloads extends Table {
  TextColumn get key => text()();

  TextColumn get url => text()();

  /// 落盘文件名（优先用服务端 suggestedFilename，否则从地址推）
  TextColumn get filename => text().nullable()();

  /// 服务端回报的 MIME（嗅探下载可能为空）
  TextColumn get mimeType => text().nullable()();

  /// 服务端回报大小；抓取完成后再用文件真实大小回填（字节）
  IntColumn get sizeBytes => integer().nullable()();

  /// 状态：`pending` | `done` | `failed`
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// 本地落盘路径（done 后有值，供 open_filex 打开）
  TextColumn get localPath => text().nullable()();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 离线页面（表名 `browser_offline_pages`；移动端专有、不入同步白名单）
///
/// MVP 存整页 HTML（不含子资源的纯文本快照）：菜单「离线页面」点当前页时抓取
/// `document.documentElement.outerHTML` 存进来，按 url 哈希 upsert 去重（同一地址再次保存即覆盖）。
/// 查看时把 HTML 喂给一个独立 InAppWebView（loadData），实现「没网也能看刚存的页」。
class BrowserOfflinePages extends Table {
  TextColumn get key => text()();

  TextColumn get url => text()();

  TextColumn get title => text().nullable()();

  /// 整页 HTML（可能较大，存 TEXT 列）
  TextColumn get html => text().nullable()();

  /// HTML 字节数（展示用）
  IntColumn get sizeBytes => integer().nullable()();

  IntColumn get savedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
