// 广告拦截 · 订阅规则（三级之二）：抓取 + 本地缓存
//
// 设计取舍：
//   · **不引入 http 依赖** —— 用 `dart:io` 的 [HttpClient]（零新依赖，Android 上可用）。
//   · 抓回来的**规则原文**缓存进 `basic_info`，离线也能生效；页面里只暴露「刷新」动作。
//   · 缓存键 `browser_adblock_subs_cache` **刻意不放进 [BrowserKeys.all]**：
//     订阅原文动辄数 MB，一旦混进 `readSettings()` 的一次性读取，设置页会读爆。
//
// 存储结构（JSON）：
//   { "<订阅URL>": { "at": <抓取时间ms>, "cnt": <有效条数>, "rules": "<规则原文>" } }
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/browser_repository.dart';
import '../models/browser_settings.dart';
import 'adblock_rules.dart';

/// 抓取订阅时使用的 UA（部分 CDN 对空 UA 直接 403；用常见桌面 Chrome UA 最稳）
const String kSubscriptionUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// 单个订阅的体积上限（防止误填大文件 URL 把内存打满）
const int kSubscriptionMaxBytes = 12 * 1024 * 1024;

/// 一条订阅的缓存记录
class CachedSubscription {
  const CachedSubscription({
    required this.url,
    required this.fetchedAt,
    required this.rules,
    this.ruleCount = 0,
    this.error,
  });

  final String url;

  /// 上次成功抓取时间（毫秒时间戳；0 = 从未成功）
  final int fetchedAt;

  /// 规则原文（可能为空 = 抓过但失败）
  final String rules;

  /// 解析出的有效规则条数（展示用）
  final int ruleCount;

  /// 上次抓取的错误信息（null = 正常）
  final String? error;

  bool get hasRules => rules.trim().isNotEmpty;

  /// 缓存时间的人话描述
  String get fetchedLabel {
    if (fetchedAt <= 0) return '尚未抓取';
    final d = DateTime.fromMillisecondsSinceEpoch(fetchedAt);
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '刚刚更新';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前更新';
    if (diff.inDays < 1) return '${diff.inHours} 小时前更新';
    return '${diff.inDays} 天前更新';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'at': fetchedAt,
    'cnt': ruleCount,
    'rules': rules,
    if (error != null) 'err': error,
  };

  static CachedSubscription fromJson(String url, Object? raw) {
    if (raw is! Map) {
      return CachedSubscription(url: url, fetchedAt: 0, rules: '');
    }
    return CachedSubscription(
      url: url,
      fetchedAt: (raw['at'] as num?)?.toInt() ?? 0,
      rules: '${raw['rules'] ?? ''}',
      ruleCount: (raw['cnt'] as num?)?.toInt() ?? 0,
      error: raw['err'] == null ? null : '${raw['err']}',
    );
  }
}

/// 订阅仓库：抓取 / 缓存 / 汇总
class AdBlockSubscriptionStore {
  AdBlockSubscriptionStore(this._repo);

  final BrowserRepository _repo;

  /// 读取全部缓存（脏数据安全降级为空表）
  Future<Map<String, CachedSubscription>> load() async {
    final raw = await _repo.readRawSetting(BrowserKeys.adBlockSubsCache);
    if (raw == null || raw.trim().isEmpty) return <String, CachedSubscription>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, CachedSubscription>{};
      final out = <String, CachedSubscription>{};
      decoded.forEach((k, v) {
        final url = '$k';
        if (url.isNotEmpty) out[url] = CachedSubscription.fromJson(url, v);
      });
      return out;
    } on FormatException {
      // 落库脏数据：当作没有缓存，别让浏览器起不来
      return <String, CachedSubscription>{};
    }
  }

  /// 抓取一条订阅并写回缓存；失败时**保留旧缓存**，只记错误信息
  Future<CachedSubscription> refresh(String url) async {
    final target = url.trim();
    if (target.isEmpty) {
      return const CachedSubscription(url: '', fetchedAt: 0, rules: '');
    }
    final cache = await load();
    final previous = cache[target];
    CachedSubscription next;
    try {
      final text = await _download(target);
      next = CachedSubscription(
        url: target,
        fetchedAt: DateTime.now().millisecondsSinceEpoch,
        rules: text,
        ruleCount: parseAdblockText(text).validCount,
      );
    } catch (e) {
      next = CachedSubscription(
        url: target,
        fetchedAt: previous?.fetchedAt ?? 0,
        rules: previous?.rules ?? '',
        ruleCount: previous?.ruleCount ?? 0,
        error: _readableError(e),
      );
    }
    cache[target] = next;
    await _persist(cache);
    return next;
  }

  /// 按设置里的订阅地址顺序汇总规则行（未缓存的地址跳过）
  ///
  /// 返回的是**行列表**而非原文 —— 引擎侧只需逐行解析，避免重复 split 大字符串。
  Future<List<String>> collectRules(List<String> urls) async {
    if (urls.isEmpty) return const <String>[];
    final cache = await load();
    final out = <String>[];
    for (final url in urls) {
      final hit = cache[url];
      if (hit == null || !hit.hasRules) continue;
      out.addAll(hit.rules.split('\n'));
    }
    return out;
  }

  /// 删除一条订阅的缓存
  Future<void> remove(String url) async {
    final cache = await load();
    if (cache.remove(url.trim()) == null) return;
    await _persist(cache);
  }

  Future<void> _persist(Map<String, CachedSubscription> cache) async {
    final map = <String, Object?>{
      for (final e in cache.entries) e.key: e.value.toJson(),
    };
    await _repo.writeRawSetting(BrowserKeys.adBlockSubsCache, jsonEncode(map));
  }

  /// 下载规则文本（体积与超时双限；UTF-8 宽容解码）
  ///
  /// ⚠️ 不要手动设 `Accept-Encoding` —— 那会关掉 [HttpClient.autoUncompress]，
  /// 拿到的是 gzip 原始字节，UTF-8 解出来就是乱码。交给默认行为即可。
  Future<String> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('订阅地址无效');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = kSubscriptionUserAgent;
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: uri);
      }
      final bytes = await _readCapped(
        res,
      ).timeout(const Duration(seconds: 60));
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }

  /// 边读边累计，超上限立即中止（不做「读完再判断」——那已经爆内存了）
  Future<List<int>> _readCapped(HttpClientResponse res) async {
    final out = <int>[];
    await for (final chunk in res) {
      out.addAll(chunk);
      if (out.length > kSubscriptionMaxBytes) {
        throw const FormatException('规则文件超过 12MB，已中止');
      }
    }
    return out;
  }

  /// 把底层异常翻成给用户看的一句话
  static String _readableError(Object e) {
    if (e is TimeoutException) return '请求超时';
    if (e is SocketException) return '网络不可达';
    if (e is HttpException) return e.message;
    if (e is FormatException) return e.message;
    return '$e';
  }
}
