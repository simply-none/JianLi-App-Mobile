// 广告拦截 · 规则语法与**内置静态规则集**（三级之一）
//
// 三级规则最终都编译成同一套匹配器（见 adblock_engine.dart）：
//   ① 内置静态规则集 —— 本文件的 [kStaticBlockedHosts] + [kStaticBlockedPatterns]
//   ② 订阅规则       —— 用户填 URL，抓回文本按 Adblock 语法解析（adblock_subscriptions.dart）
//   ③ 自定义拦截规则 —— 用户手写的 Adblock 语法行
//
// ⚠️ 本文件是**纯函数 + 常量**，不做任何 IO，便于单测。
//
// ——— 支持的语法子集（够用、无歧义）———
//   ||example.com^        域锚定 → 命中该域及其所有子域（最高频，走 Set 查找，最快）
//   |https://a.com/x      前缀锚定 → URL 以该串开头
//   /banner/*/ad.         普通子串（含 `*` 时按通配拆成多段，逐段 contains）
//   @@||a.com^            例外（白名单），**优先级最高**，命中即放行
//   ! 注释 / [Adblock…]   整行忽略
//   example.com           裸域名 → 视同域锚定
//   $third-party 等后缀选项 → **整段丢弃**（本实现不区分请求来源，见下方「局限」）
//
// ——— 局限（明确写出来，避免误以为支持全语法）———
//   · 不支持 $script / $image / $third-party 等**资源类型与来源**选项；
//     会丢掉 `$` 之后的全部内容再匹配（宁可多拦，不做过度精细）。
//   · 不支持正则形式的 `/…/`（含特殊字符的会被当普通子串）。
//   · CSS 隐藏类规则（`##.ad-banner`）不处理 —— 它属于「元素隐藏」，
//     需要注入 CSS，不在拦截引擎范围内（二期做）。

/// 单条规则的类型（决定匹配方式与索引结构）
enum AdblockRuleKind {
  /// 域锚定：命中该域及其子域（`||a.com^` / 裸域名）
  host,

  /// 前缀锚定：URL 以该串开头（`|https://a.com/x`）
  prefix,

  /// 子串：URL 含该串（普通写法 / 通配拆段后的每一段）
  pattern,
}

/// 解析累加器：把若干行规则累积成分类列表（解析是流式的，便于增量喂订阅内容）
class ParsedAdblockRules {
  /// 域锚定（拦截）
  final Set<String> blockHosts = <String>{};

  /// 域锚定（例外 / 白名单）
  final Set<String> allowHosts = <String>{};

  /// 前缀锚定（拦截 / 例外）
  final List<String> blockPrefixes = <String>[];
  final List<String> allowPrefixes = <String>[];

  /// 子串（拦截 / 例外）
  final List<String> blockPatterns = <String>[];
  final List<String> allowPatterns = <String>[];

  /// 解析过的**有效**规则条数（注释 / 空行 / 纯选项行不计）
  int validCount = 0;

  /// 解析时丢弃的行数（注释、空行、无法理解的行）——诊断用
  int droppedCount = 0;

  /// 合并另一份解析结果（订阅聚合用）
  void merge(ParsedAdblockRules other) {
    blockHosts.addAll(other.blockHosts);
    allowHosts.addAll(other.allowHosts);
    blockPrefixes.addAll(other.blockPrefixes);
    allowPrefixes.addAll(other.allowPrefixes);
    blockPatterns.addAll(other.blockPatterns);
    allowPatterns.addAll(other.allowPatterns);
    validCount += other.validCount;
    droppedCount += other.droppedCount;
  }
}

/// 内置静态规则集的**种子集**（中英文常见广告 / 统计 / 追踪域）。
///
/// 说明：完整 EasyList（约 6 万条）体量不适合硬编码进 Dart 常量，
/// 落地策略是「种子集兜底 + 订阅规则补齐」——用户订阅 EasyList China 即可拿到全量。
/// 更新种子集时只改本列表，引擎侧零改动。
const List<String> kStaticBlockedHosts = <String>[
  // —— Google 广告体系 ——
  'doubleclick.net',
  'googleadservices.com',
  'googlesyndication.com',
  'google-analytics.com',
  'googletagmanager.com',
  'googletagservices.com',
  'admob.com',
  'adsense.com',
  'adservice.google.com',
  'pagead2.googlesyndication.com',
  // —— 国际广告交易所 / 广告服务器 ——
  'adnxs.com',
  'adsrvr.org',
  'rubiconproject.com',
  'pubmatic.com',
  'openx.net',
  'criteo.com',
  'criteo.net',
  'taboola.com',
  'outbrain.com',
  'scorecardresearch.com',
  'quantserve.com',
  'moatads.com',
  'serving-sys.com',
  'amazon-adsystem.com',
  'casalemedia.com',
  'sharethrough.com',
  'smartadserver.com',
  'adform.net',
  '33across.com',
  '360yield.com',
  'sonobi.com',
  'sovrn.com',
  'indexexchange.com',
  'lijit.com',
  'gumgum.com',
  'media.net',
  'adtechus.com',
  'adtech.de',
  'bidswitch.net',
  'rtbhouse.com',
  'teads.tv',
  'servedbyadbutler.com',
  'ads.yahoo.com',
  'adserver.yahoo.com',
  'advertising.com',
  'atwola.com',
  'bluekai.com',
  'demdex.net',
  'everesttech.net',
  'krxd.net',
  'mathtag.com',
  'ml314.com',
  'nexac.com',
  'tribalfusion.com',
  'turn.com',
  'yieldmanager.com',
  'zedo.com',
  'adzerk.net',
  'buysellads.com',
  'carbonads.com',
  'carbonads.net',
  'inmobi.com',
  'mopub.com',
  'unityads.unity3d.com',
  'applovin.com',
  'vungle.com',
  'chartboost.com',
  'startappexchange.com',
  'tapjoy.com',
  // —— 百度广告 / 统计 ——
  'hm.baidu.com',
  'pos.baidu.com',
  'cpro.baidu.com',
  'cbjs.baidu.com',
  'mobads.baidu.com',
  'union.baidu.com',
  'sclick.baidu.com',
  'nsclick.baidu.com',
  'dup.baidustatic.com',
  'baidustatic.com',
  'tanx.com',
  'tanx.cn',
  'alimama.com',
  'mmstat.com',
  'simba.taobao.com',
  // —— 腾讯广告 / 统计 ——
  'e.qq.com',
  'pingjs.qq.com',
  'gdt.qq.com',
  'adsview.qq.com',
  'ad.qq.com',
  'mta.qq.com',
  'beacon.qq.com',
  'tdc.qq.com',
  'l.qq.com',
  'adx.qq.com',
  // —— 字节 / 快手广告 ——
  'ad.toutiao.com',
  'pangolin-sdk-toutiao.com',
  'oceanengine.com',
  'ad.oceanengine.com',
  'ad.kuaishou.com',
  'adkwai.com',
  // —— 第三方统计 / 埋点 ——
  'cnzz.com',
  'umeng.com',
  'umengcloud.com',
  'talkingdata.com',
  'growingio.com',
  'sensorsdata.cn',
  'zhugeio.com',
  'clicki.cn',
  '51.la',
  '51yes.com',
  'vamaker.com',
  'mc.yandex.ru',
  'hotjar.com',
  'fullstory.com',
  'mouseflow.com',
  'crazyegg.com',
  'mixpanel.com',
  'amplitude.com',
  'segment.com',
  'segment.io',
  'statsig.com',
  'optimizely.com',
  'chartbeat.com',
  'parsely.com',
  'newrelic.com',
  'bugsnag.com',
  'sentry-cdn.com',
  // —— 国内广告联盟 ——
  'mediav.com',
  'allyes.com',
  'ipinyou.com',
  'adchina.com',
  'admaster.com.cn',
  'miaozhen.com',
  'adview.cn',
  'domob.cn',
  'youmi.net',
  'waps.cn',
  'adwo.com',
  'madhouse-inc.com',
  'adp.cn',
  'hdtmedia.com',
  'winads.cn',
  'adcome.cn',
  'vamaker.cn',
  'adsame.com',
  'adpolice.gov.cn',
  // —— 弹窗 / 恶意推广 / 挖矿 ——
  'popads.net',
  'popcash.net',
  'propellerads.com',
  'onclickads.net',
  'onclckds.com',
  'adcash.com',
  'coinhive.com',
  'coin-hive.com',
  'crypto-loot.com',
  'webminepool.com',
  'authedmine.com',
  'jsecoin.com',
];

/// 内置静态规则集里的**路径子串**规则（数量刻意压到最小 —— 子串匹配比域查找慢）
const List<String> kStaticBlockedPatterns = <String>[
  '/advertisement/',
  '/advertisements/',
  '/adserver/',
  '/ad_frame',
  '/adframe',
  '/popunder',
  '/pop-under',
  '/banner_ad',
  '/bannerad',
  '/ad_banner',
  '/adbox',
  '/ads.js',
  '/analytics.js',
  '/gtag/js',
  '/tracking.js',
  '/pagead/',
];

/// 解析多行规则文本（`\n` 分隔；兼容 `\r\n`）
ParsedAdblockRules parseAdblockText(String text, {ParsedAdblockRules? into}) {
  final out = into ?? ParsedAdblockRules();
  if (text.isEmpty) return out;
  // 订阅文本动辄数 MB，split 一次比逐字符扫描快得多
  return parseAdblockLines(text.split('\n'), into: out);
}

/// 逐行解析规则（订阅内容可流式喂入，避免一次性持有全部行）
ParsedAdblockRules parseAdblockLines(
  Iterable<String> lines, {
  ParsedAdblockRules? into,
}) {
  final out = into ?? ParsedAdblockRules();
  for (final raw in lines) {
    _parseLine(raw, out);
  }
  return out;
}

/// 单行解析（返回值无意义，结果写进 [out]）
void _parseLine(String raw, ParsedAdblockRules out) {
  var line = raw.trim();
  if (line.isEmpty) {
    out.droppedCount++;
    return;
  }
  // 注释：`!` 是 Adblock 标准注释；`[Adblock Plus 2.0]` 是订阅头
  if (line.startsWith('!') || line.startsWith('[') || line.startsWith('#')) {
    out.droppedCount++;
    return;
  }
  // CSS 隐藏规则（## / #@# / #?#）—— 元素隐藏不归本引擎管，明确跳过
  if (line.contains('##') || line.contains('#@#') || line.contains('#?#')) {
    out.droppedCount++;
    return;
  }
  // 元素选项：丢掉 `$` 之后的部分（见文件头「局限」）
  final dollar = line.indexOf(r'$');
  if (dollar >= 0) line = line.substring(0, dollar).trim();
  if (line.isEmpty) {
    out.droppedCount++;
    return;
  }
  // 例外（白名单）
  var allow = false;
  if (line.startsWith('@@')) {
    allow = true;
    line = line.substring(2).trim();
    if (line.isEmpty) {
      out.droppedCount++;
      return;
    }
  }
  // 域锚定：`||host^`
  if (line.startsWith('||')) {
    final body = line.substring(2);
    // `||a.com^` / `||a.com/banner` / `||a.com*ad` —— 无通配且无路径 → 纯域规则
    final cut = _firstIndexOfAny(body, const ['^', '/', '*', '?']);
    final hostPart = (cut < 0 ? body : body.substring(0, cut)).trim();
    final restPart = cut < 0 ? '' : body.substring(cut);
    if (hostPart.isEmpty) {
      out.droppedCount++;
      return;
    }
    if (restPart.isEmpty || restPart == '^') {
      // 纯域：走 Set 后缀查找（最快）
      (allow ? out.allowHosts : out.blockHosts).add(_normalizeHost(hostPart));
      out.validCount++;
      return;
    }
    // 带路径 / 通配：退化成子串，前缀补 `//` 避免误伤（域名必须出现在 URL 主机位附近）
    _addPattern('//$hostPart${restPart == '^' ? '' : restPart}', allow, out);
    return;
  }
  // 前缀锚定：`|https://…`
  if (line.startsWith('|')) {
    final body = line.substring(1).trim();
    if (body.isEmpty) {
      out.droppedCount++;
      return;
    }
    (allow ? out.allowPrefixes : out.blockPrefixes).add(body.toLowerCase());
    out.validCount++;
    return;
  }
  // 裸域名（`ads.example.com`）→ 视同域锚定
  if (_looksLikeBareHost(line)) {
    (allow ? out.allowHosts : out.blockHosts).add(_normalizeHost(line));
    out.validCount++;
    return;
  }
  _addPattern(line, allow, out);
}

/// 子串规则：含 `*` 时按通配拆段，每段各成一条子串规则（同一条规则内所有段都要命中才拦）
///
/// ⚠️ 拆段后无法表达「同一条规则内 AND」的语义，这里选择**放宽**（任一命中即拦）——
/// 对拦截场景是安全侧倾斜（宁可多拦，用户可通过例外规则放行）。
void _addPattern(String pattern, bool allow, ParsedAdblockRules out) {
  var p = pattern.trim().toLowerCase();
  if (p.isEmpty) {
    out.droppedCount++;
    return;
  }
  if (p.contains('*')) {
    var added = false;
    for (final seg in p.split('*')) {
      final s = seg.trim();
      if (s.length < 3) continue; // 太短的段误伤率极高，丢
      (allow ? out.allowPatterns : out.blockPatterns).add(s);
      added = true;
    }
    if (!added) {
      out.droppedCount++;
      return;
    }
    out.validCount++;
    return;
  }
  if (p.length < 3) {
    out.droppedCount++;
    return;
  }
  (allow ? out.allowPatterns : out.blockPatterns).add(p);
  out.validCount++;
}

/// 是否是「裸域名」（`a.com` / `ad.example.co.uk`，无协议、无路径、无通配）
bool _looksLikeBareHost(String s) {
  if (s.contains(' ') || s.contains('/') || s.contains('*')) return false;
  final host = s.startsWith('.') ? s.substring(1) : s;
  if (!host.contains('.')) return false;
  return RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(host);
}

String _normalizeHost(String host) {
  var h = host.trim().toLowerCase();
  while (h.startsWith('.')) {
    h = h.substring(1);
  }
  return h;
}

int _firstIndexOfAny(String s, List<String> chars) {
  var best = -1;
  for (final c in chars) {
    final i = s.indexOf(c);
    if (i >= 0 && (best < 0 || i < best)) best = i;
  }
  return best;
}
