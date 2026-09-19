// 浏览器功能域 providers —— 仓库、四块数据流、设置状态
//
// ⚠️ 全部 provider **必须顶层声明**（红线：build 内联构造 = 每次重建都是新 provider，
//    会「订阅→重建→再新建」死循环）。抽屉里读取本文件的流时，抽屉内容要自带 `Consumer`
//    （overlay 子树，页面 ref.watch 不会让抽屉重建，见技能红线 #28）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';
import '../data/browser_repository.dart';
import '../models/browser_settings.dart';
import '../services/adblock_engine.dart';
import '../services/adblock_subscriptions.dart';

/// 浏览器仓库
final Provider<BrowserRepository> browserRepositoryProvider =
    Provider<BrowserRepository>((ref) {
      return BrowserRepository(ref.watch(appDatabaseProvider));
    });

/// 固定标签页（首页九宫格 / 设置页管理网格共用同一份数据）
final StreamProvider<List<BrowserPinnedData>> pinnedSitesProvider =
    StreamProvider<List<BrowserPinnedData>>(
      (ref) => ref.watch(browserRepositoryProvider).watchPinned(),
    );

/// 标签会话（单 WebView 多标签）
final StreamProvider<List<BrowserTab>> browserTabsProvider =
    StreamProvider<List<BrowserTab>>(
      (ref) => ref.watch(browserRepositoryProvider).watchTabs(),
    );

/// 书签（含文件夹，扁平返回，UI 组树）
final StreamProvider<List<BrowserBookmark>> browserBookmarksProvider =
    StreamProvider<List<BrowserBookmark>>(
      (ref) => ref.watch(browserRepositoryProvider).watchBookmarks(),
    );

/// 访问历史
final StreamProvider<List<BrowserHistoryData>> browserHistoryProvider =
    StreamProvider<List<BrowserHistoryData>>(
      (ref) => ref.watch(browserRepositoryProvider).watchHistory(),
    );

/// 下载任务
final StreamProvider<List<BrowserDownload>> browserDownloadsProvider =
    StreamProvider<List<BrowserDownload>>(
      (ref) => ref.watch(browserRepositoryProvider).watchDownloads(),
    );

/// 离线页面
final StreamProvider<List<BrowserOfflinePage>> browserOfflinePagesProvider =
    StreamProvider<List<BrowserOfflinePage>>(
      (ref) => ref.watch(browserRepositoryProvider).watchOfflinePages(),
    );

/// 浏览器设置（读写 basic_info）
final AsyncNotifierProvider<BrowserSettingsNotifier, BrowserSettings>
browserSettingsProvider =
    AsyncNotifierProvider<BrowserSettingsNotifier, BrowserSettings>(
      BrowserSettingsNotifier.new,
    );

/// 设置状态：首次进入异步装载，之后本地立即生效 + 异步落库。
class BrowserSettingsNotifier extends AsyncNotifier<BrowserSettings> {
  @override
  Future<BrowserSettings> build() async {
    final map = await ref.watch(browserRepositoryProvider).readSettings();
    return BrowserSettings.fromMap(map);
  }

  /// 保存整份设置（调用方用 `copyWith` 造新值，本方法只负责落库 + 刷新状态）
  Future<void> save(BrowserSettings next) async {
    state = AsyncData(next); // 先本地生效，UI 不等落库
    await ref.read(browserRepositoryProvider).writeSettings(next.toMap());
  }

  /// 便捷：当前值（未装载完成时返回默认设置，避免调用点空判）
  BrowserSettings get current => state.value ?? const BrowserSettings();
}

/// 跨页导航请求通道。
///
/// 书签 / 历史 / 固定标签页等子页要「打开某个地址」时，把地址写进这里即可 ——
/// 浏览器主壳监听本 provider 并执行导航。为什么不用 `pop(url)` 回传结果：
/// 子页可能被多层推入（浏览器 → 设置 → 固定标签页管理），`pop` 只退一层。
///
/// ⚠️ Riverpod 3 已移除 `StateProvider`（想用需从 `flutter_riverpod/legacy.dart`
/// 单独导入）。这里改用最小 `Notifier` —— 不引入 legacy 依赖，语义也更收口：
/// 只能通过 [BrowserPendingUrlNotifier.request] 写、[BrowserPendingUrlNotifier.consume] 清。
final NotifierProvider<BrowserPendingUrlNotifier, String?>
browserPendingUrlProvider =
    NotifierProvider<BrowserPendingUrlNotifier, String?>(
      BrowserPendingUrlNotifier.new,
    );

/// 一次性导航意图（消费即清空）
class BrowserPendingUrlNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// 子页请求主壳导航到 [url]
  void request(String url) => state = url;

  /// 主壳消费：取走并清空（**不清空会被下次 push 重复消费**）
  void consume() => state = null;
}

/// 广告拦截订阅缓存（订阅 URL → 抓取记录）
final AsyncNotifierProvider<
  AdBlockSubscriptionsNotifier,
  Map<String, CachedSubscription>
>
adBlockSubscriptionsProvider =
    AsyncNotifierProvider<
      AdBlockSubscriptionsNotifier,
      Map<String, CachedSubscription>
    >(AdBlockSubscriptionsNotifier.new);

/// 订阅缓存状态：装载 + 抓取刷新（抓取走 dart:io，不走 UI 线程池以外的依赖）
class AdBlockSubscriptionsNotifier
    extends AsyncNotifier<Map<String, CachedSubscription>> {
  AdBlockSubscriptionStore get _store =>
      AdBlockSubscriptionStore(ref.read(browserRepositoryProvider));

  @override
  Future<Map<String, CachedSubscription>> build() => _store.load();

  /// 抓取一条订阅并刷新状态；返回抓取结果（含错误信息，供 UI 提示）
  Future<CachedSubscription> refresh(String url) async {
    final result = await _store.refresh(url);
    state = AsyncData(await _store.load());
    return result;
  }

  /// 删除一条订阅的缓存
  Future<void> remove(String url) async {
    await _store.remove(url);
    state = AsyncData(await _store.load());
  }

  /// 当前值（未装载完成时返回空表）
  Map<String, CachedSubscription> get current =>
      state.value ?? const <String, CachedSubscription>{};
}

/// 广告拦截引擎（三级规则编译结果）。
///
/// ⚠️ 编译是把上万行规则建成索引，属**一次性重活**（百毫秒级）。这里用签名做记忆化：
/// 设置与订阅缓存都没实质变化时直接复用上一次的引擎，避免任一 provider 微动就重编译。
AdBlockEngine? _engineCache;
String? _engineSignature;

final Provider<AdBlockEngine> adBlockEngineProvider = Provider<AdBlockEngine>((
  ref,
) {
  final s = ref.watch(browserSettingsProvider).value ?? const BrowserSettings();
  final cache =
      ref.watch(adBlockSubscriptionsProvider).value ??
      const <String, CachedSubscription>{};
  if (!s.adBlockEnabled) return AdBlockEngine.none;

  final lines = <String>[];
  var stamp = 0;
  for (final url in s.subscriptions) {
    final hit = cache[url];
    if (hit == null || !hit.hasRules) continue;
    stamp += hit.fetchedAt + hit.ruleCount;
    lines.addAll(hit.rules.split('\n'));
  }
  final signature =
      '${s.staticRulesEnabled}|$stamp|${lines.length}|'
      '${s.customRules.length}|${s.customRules.join('\u0001')}';
  if (_engineSignature == signature && _engineCache != null) {
    return _engineCache!;
  }
  final engine = AdBlockEngine.compile(
    enabled: true,
    staticRulesEnabled: s.staticRulesEnabled,
    subscriptionRules: lines,
    customRules: s.customRules,
  );
  _engineSignature = signature;
  _engineCache = engine;
  return engine;
});
