// 浏览器功能域仓库 —— drift 读写唯一入口（UI 不直接碰 AppDatabase）
//
// 四块数据 + 一块设置：
//   pinned    固定标签页（槽位制 + FIFO 替换，见 addPinned）
//   tabs      标签会话（单 WebView 多标签，只存地址/标题/顺序）
//   bookmarks 书签（支持文件夹层级）
//   history   历史（按 url 稳定哈希去重累计）
//   设置       读写 basic_info（键定义见 models/browser_settings.dart）
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../models/browser_models.dart';
import '../models/browser_settings.dart';

/// 浏览器仓库
class BrowserRepository {
  BrowserRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  // ————————————————— 固定标签页 —————————————————

  /// 固定标签页流（按槽位升序；空槽不占位，由 UI 自行补「+」）
  Stream<List<BrowserPinnedData>> watchPinned() {
    return (_db.select(
      _db.browserPinned,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();
  }

  /// 首次进入浏览器时写入默认 8 个站点（**只在表为空时执行**，不覆盖用户编辑）
  Future<void> ensureDefaultPinned() async {
    // 固定标签最多 8 行，直接全查比 count() 更省心（也避免 count API 差异）
    final existing = await _db.select(_db.browserPinned).get();
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((b) {
      for (var i = 0; i < kDefaultPinnedSites.length; i++) {
        final site = kDefaultPinnedSites[i];
        b.insert(
          _db.browserPinned,
          BrowserPinnedCompanion.insert(
            key: _uuid.v4(),
            title: Value(site.title),
            url: Value(site.url),
            letter: Value(site.letter),
            color: Value(site.color),
            position: Value(i),
            addedAt: Value(now + i),
          ),
        );
      }
    });
  }

  /// 加入固定标签页（**FIFO**：满 8 个时替换 added_at 最早的一个）。
  ///
  /// 替换时**复用被替换者的槽位**，九宫格里表现为「就地替换」而不是末尾插入。
  /// 返回被替换的站点标题（null = 未发生替换），供 UI 提示。
  Future<String?> addPinned({
    required String title,
    required String url,
    String? letter,
    String? color,
  }) async {
    final rows =
        await (_db.select(_db.browserPinned)
              ..orderBy([(t) => OrderingTerm.asc(t.addedAt)]))
            .get();
    final now = DateTime.now().millisecondsSinceEpoch;
    int slot;
    String? replacedTitle;
    if (rows.length >= kPinnedMaxSlots) {
      final oldest = rows.first;
      replacedTitle = oldest.title;
      slot = oldest.position ?? 0;
      await (_db.delete(
        _db.browserPinned,
      )..where((t) => t.key.equals(oldest.key))).go();
    } else {
      final used = rows.map((e) => e.position ?? -1).toSet();
      slot = 0;
      while (used.contains(slot) && slot < kPinnedMaxSlots) {
        slot++;
      }
    }
    await _db
        .into(_db.browserPinned)
        .insert(
          BrowserPinnedCompanion.insert(
            key: _uuid.v4(),
            title: Value(title),
            url: Value(url),
            letter: Value(letter ?? letterOfSite(title)),
            color: Value(color),
            position: Value(slot),
            addedAt: Value(now),
          ),
        );
    return replacedTitle;
  }

  /// 就地替换某个槽位（设置页「替换」/ 长按菜单用）；槽位与 addedAt 保持全新。
  Future<void> replacePinnedSlot(
    String key, {
    required String title,
    required String url,
    String? letter,
    String? color,
  }) async {
    await (_db.update(
      _db.browserPinned,
    )..where((t) => t.key.equals(key))).write(
      BrowserPinnedCompanion(
        title: Value(title),
        url: Value(url),
        letter: Value(letter ?? letterOfSite(title)),
        color: Value(color),
        addedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 移除固定标签页（槽位随之空出，下一次 addPinned 会补进来）
  Future<void> removePinned(String key) async {
    await (_db.delete(_db.browserPinned)..where((t) => t.key.equals(key))).go();
  }

  /// 交换两个槽位（设置页长按拖拽排序的轻量实现：左/右移一格）
  Future<void> swapPinnedSlot(String key, int delta) async {
    final rows =
        await (_db.select(_db.browserPinned)
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final index = rows.indexWhere((e) => e.key == key);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= rows.length) return;
    final a = rows[index];
    final b = rows[target];
    await _db.transaction(() async {
      await (_db.update(_db.browserPinned)..where((t) => t.key.equals(a.key)))
          .write(BrowserPinnedCompanion(position: Value(b.position ?? 0)));
      await (_db.update(_db.browserPinned)..where((t) => t.key.equals(b.key)))
          .write(BrowserPinnedCompanion(position: Value(a.position ?? 0)));
    });
  }

  // ————————————————— 标签会话 —————————————————

  /// 标签流（按 position 升序）
  Stream<List<BrowserTab>> watchTabs() {
    return (_db.select(_db.browserTabs)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  /// 一次性读取标签（启动时用；之后跟随 [watchTabs] 流）
  Future<List<BrowserTab>> loadTabs() {
    return (_db.select(_db.browserTabs)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  /// 新建标签（[url] 为空 = 新标签页，显示极简首页）
  Future<BrowserTab> createTab({String? url}) async {
    final rows = await _db.select(_db.browserTabs).get();
    final maxPos = rows.isEmpty
        ? -1
        : rows
              .map((e) => e.position ?? 0)
              .reduce((a, b) => a > b ? a : b);
    final key = _uuid.v4();
    await _db
        .into(_db.browserTabs)
        .insert(
          BrowserTabsCompanion.insert(
            key: key,
            url: Value(url),
            position: Value(maxPos + 1),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    return (await (_db.select(
      _db.browserTabs,
    )..where((t) => t.key.equals(key))).getSingle());
  }

  /// 更新标签的地址 / 标题（页面加载完成时回写）
  Future<void> updateTab(String key, {String? url, String? title}) async {
    await (_db.update(_db.browserTabs)..where((t) => t.key.equals(key))).write(
      BrowserTabsCompanion(
        url: url == null ? const Value.absent() : Value(url),
        title: title == null ? const Value.absent() : Value(title),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 关闭标签
  Future<void> closeTab(String key) async {
    await (_db.delete(_db.browserTabs)..where((t) => t.key.equals(key))).go();
  }

  /// 清空全部标签（「关闭全部」/ 退出时用）
  Future<void> clearTabs() async {
    await _db.delete(_db.browserTabs).go();
  }

  // ————————————————— 书签 —————————————————

  /// 全部书签与文件夹（单表扁平返回，树形结构由 UI 组装；文件夹排在前面）
  Stream<List<BrowserBookmark>> watchBookmarks() {
    return (_db.select(_db.browserBookmarks)..orderBy([
          (t) => OrderingTerm.desc(t.isFolder),
          (t) => OrderingTerm.asc(t.position),
        ]))
        .watch();
  }

  /// 加书签（[parentKey] 为空 = 根级）
  Future<void> addBookmark({
    String? title,
    required String url,
    String? parentKey,
  }) async {
    await _insertBookmarkRow(
      title: (title == null || title.trim().isEmpty) ? url : title,
      url: url,
      isFolder: false,
      parentKey: parentKey,
    );
  }

  /// 新建文件夹
  Future<void> addBookmarkFolder(String title, {String? parentKey}) async {
    await _insertBookmarkRow(
      title: title.trim().isEmpty ? '新建文件夹' : title,
      url: null,
      isFolder: true,
      parentKey: parentKey,
    );
  }

  Future<void> _insertBookmarkRow({
    required String title,
    required String? url,
    required bool isFolder,
    String? parentKey,
  }) async {
    final siblings =
        await (_db.select(_db.browserBookmarks)..where(
              (t) => parentKey == null
                  ? t.parentKey.isNull()
                  : t.parentKey.equals(parentKey),
            ))
            .get();
    final maxPos = siblings.isEmpty
        ? -1
        : siblings
              .map((e) => e.position ?? 0)
              .reduce((a, b) => a > b ? a : b);
    await _db
        .into(_db.browserBookmarks)
        .insert(
          BrowserBookmarksCompanion.insert(
            key: _uuid.v4(),
            title: Value(title),
            url: Value(url),
            isFolder: Value(isFolder ? '1' : '0'),
            parentKey: Value(parentKey),
            position: Value(maxPos + 1),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  /// 重命名书签 / 文件夹
  Future<void> renameBookmark(String key, String title) async {
    await (_db.update(
      _db.browserBookmarks,
    )..where((t) => t.key.equals(key))).write(
      BrowserBookmarksCompanion(title: Value(title.trim())),
    );
  }

  /// 删除书签 / 文件夹（**文件夹递归删子项**）
  Future<void> deleteBookmark(String key) async {
    final all = await _db.select(_db.browserBookmarks).get();
    final doomed = <String>{key};
    var grew = true;
    while (grew) {
      grew = false;
      for (final row in all) {
        final parent = row.parentKey;
        if (parent != null && doomed.contains(parent) && doomed.add(row.key)) {
          grew = true;
        }
      }
    }
    await (_db.delete(
      _db.browserBookmarks,
    )..where((t) => t.key.isIn(doomed))).go();
  }

  // ————————————————— 历史 —————————————————

  /// 历史流（最近访问倒序，[limit] 防大库卡顿）
  Stream<List<BrowserHistoryData>> watchHistory({int limit = 500}) {
    return (_db.select(_db.browserHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.visitedAt)])
          ..limit(limit))
        .watch();
  }

  /// 记一次访问：同一 url 去重累计次数（无痕模式由调用方决定不调用本方法）
  Future<void> recordVisit({String? title, required String url}) async {
    if (url.trim().isEmpty) return;
    final key = urlKeyOf(url);
    final existing =
        await (_db.select(_db.browserHistory)..where((t) => t.key.equals(key)))
            .getSingleOrNull();
    await _db
        .into(_db.browserHistory)
        .insertOnConflictUpdate(
          BrowserHistoryCompanion.insert(
            key: key,
            url: Value(url),
            title: Value(
              (title == null || title.trim().isEmpty)
                  ? (existing?.title ?? hostOf(url))
                  : title,
            ),
            visitedAt: Value(DateTime.now().millisecondsSinceEpoch),
            visitCount: Value((existing?.visitCount ?? 0) + 1),
          ),
        );
  }

  /// 删一条历史
  Future<void> deleteHistoryEntry(String key) async {
    await (_db.delete(_db.browserHistory)..where((t) => t.key.equals(key))).go();
  }

  /// 清空历史
  Future<void> clearHistory() async {
    await _db.delete(_db.browserHistory).go();
  }

  /// 只清 [sinceMs] 之前的历史（毫秒时间戳；「最近 7 天」这类时间范围清理用）
  Future<void> clearHistoryBefore(int sinceMs) async {
    await (_db.delete(
      _db.browserHistory,
    )..where((t) => t.visitedAt.isSmallerThanValue(sinceMs))).go();
  }

  /// 清空全部书签与文件夹（「清除浏览数据」里勾了书签时用）
  Future<void> clearBookmarks() async {
    await _db.delete(_db.browserBookmarks).go();
  }

  // ————————————————— 下载 —————————————————

  /// 下载任务流（最近创建倒序）
  Stream<List<BrowserDownload>> watchDownloads() {
    return (_db.select(_db.browserDownloads)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// 新建一条下载任务（状态 = pending），返回主键
  Future<String> addDownload({
    required String url,
    String? filename,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final key = _uuid.v4();
    await _db.into(_db.browserDownloads).insert(
          BrowserDownloadsCompanion.insert(
            key: key,
            url: url,
            filename: Value(filename),
            mimeType: Value(mimeType),
            sizeBytes: Value(sizeBytes),
            status: const Value('pending'),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    return key;
  }

  /// 更新下载任务状态 / 落盘路径 / 大小
  Future<void> updateDownload(
    String key, {
    String? status,
    String? localPath,
    int? sizeBytes,
    int? completedAt,
  }) async {
    await (_db.update(_db.browserDownloads)
          ..where((t) => t.key.equals(key)))
        .write(
      BrowserDownloadsCompanion(
        status: status == null ? const Value.absent() : Value(status),
        localPath: localPath == null ? const Value.absent() : Value(localPath),
        sizeBytes: sizeBytes == null ? const Value.absent() : Value(sizeBytes),
        completedAt:
            completedAt == null ? const Value.absent() : Value(completedAt),
      ),
    );
  }

  /// 删除一条下载记录（落盘文件由调用方按 [localPath] 另删）
  Future<void> deleteDownload(String key) async {
    await (_db.delete(_db.browserDownloads)
          ..where((t) => t.key.equals(key)))
        .go();
  }

  /// 清空全部下载记录
  Future<void> clearDownloads() async {
    await _db.delete(_db.browserDownloads).go();
  }

  // ————————————————— 离线页面 —————————————————

  /// 离线页面流（最近保存倒序）
  Stream<List<BrowserOfflinePage>> watchOfflinePages() {
    return (_db.select(_db.browserOfflinePages)
          ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]))
        .watch();
  }

  /// 保存离线页面（按 url 哈希 upsert：同一地址重复保存 = 覆盖更新）。
  /// [html] 为整页 HTML 快照（可能较大）。
  Future<void> saveOfflinePage({
    required String url,
    String? title,
    String? html,
  }) async {
    final key = urlKeyOf(url);
    final existing = await (_db.select(_db.browserOfflinePages)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    final companion = BrowserOfflinePagesCompanion.insert(
      key: key,
      url: url,
      title: Value((title == null || title.trim().isEmpty)
          ? (existing?.title ?? hostOf(url))
          : title),
      html: Value(html),
      sizeBytes: Value(html == null ? 0 : html.length),
      savedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    if (existing == null) {
      await _db.into(_db.browserOfflinePages).insert(companion);
    } else {
      await (_db.update(_db.browserOfflinePages)
            ..where((t) => t.key.equals(key)))
          .write(
        BrowserOfflinePagesCompanion(
          url: Value(url),
          title: Value((title == null || title.trim().isEmpty)
              ? (existing.title ?? hostOf(url))
              : title),
          html: Value(html),
          sizeBytes: Value(html == null ? 0 : html.length),
          savedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    }
  }

  /// 取单条离线页面（查看器用）
  Future<BrowserOfflinePage?> getOfflinePage(String key) {
    return (_db.select(_db.browserOfflinePages)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
  }

  /// 删除一条离线页面
  Future<void> deleteOfflinePage(String key) async {
    await (_db.delete(_db.browserOfflinePages)
          ..where((t) => t.key.equals(key)))
        .go();
  }

  /// 清空全部离线页面
  Future<void> clearOfflinePages() async {
    await _db.delete(_db.browserOfflinePages).go();
  }

  // ————————————————— 设置（basic_info） —————————————————

  /// 一次读取全部浏览器配置键（未写入的键返回 null，模型侧用默认值兜底）
  Future<Map<String, String?>> readSettings() async {
    final rows = await (_db.select(
      _db.basicInfo,
    )..where((t) => t.key.isIn(BrowserKeys.all))).get();
    final map = <String, String?>{for (final k in BrowserKeys.all) k: null};
    for (final row in rows) {
      map[row.key] = row.value;
    }
    return map;
  }

  /// 写入若干配置键（幂等 upsert）
  Future<void> writeSettings(Map<String, String> values) async {
    for (final entry in values.entries) {
      await _db
          .into(_db.basicInfo)
          .insertOnConflictUpdate(
            BasicInfoCompanion.insert(
              key: entry.key,
              value: Value(entry.value),
            ),
          );
    }
  }

  /// 按需读取**单个**原始配置值。
  ///
  /// 给「体积大 / 低频」的键用（如广告拦截的订阅原文缓存）——它们不能进
  /// [BrowserKeys.all]，否则每次进浏览器都要白读几 MB。
  Future<String?> readRawSetting(String key) async {
    final row = await (_db.select(
      _db.basicInfo,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// 写入**单个**原始配置值（幂等 upsert；[value] 为空串也照写）
  Future<void> writeRawSetting(String key, String value) async {
    await _db
        .into(_db.basicInfo)
        .insertOnConflictUpdate(
          BasicInfoCompanion.insert(key: key, value: Value(value)),
        );
  }
}
