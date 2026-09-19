// 广告拦截 · 引擎（三级规则 → 统一匹配器）
//
// 输入：设置里的三级开关/内容（内置静态规则集 / 订阅规则 / 自定义规则）
// 输出：[AdBlockEngine] —— 一个不可变、可 O(标签数) 查询的匹配器。
//
// ——— 为什么要做「索引」而不是遍历规则 ———
// 订阅规则动辄上万条。若每次请求都遍历一遍规则列表（每页几十~上百个请求），
// 主线程会被拖死。这里按规则类型分别处理：
//   · 域锚定（最高频）→ `Set<String>` + **按 `.` 逐级后缀查找**，复杂度 O(标签数)≈3~5
//   · 前缀锚定       → 小列表遍历（用户手写的很少）
//   · 子串           → **分词索引**：取规则里最长的连续字母数字段作 key，
//                      请求 URL 先分词（O(长度)），再用词 token 反查候选规则，
//                      最后对候选做一次完整 `contains` 校验（精准、不误伤）
//
// 例外规则（`@@`）优先级最高：先查例外，命中即放行，不看拦截规则。
import 'adblock_rules.dart';

/// 广告拦截引擎（不可变；设置变更时重新 [compile] 一个即可）
///
/// 私有字段用 `this._x` 直接初始化（Dart 3.6+ 的私有具名参数：对外名仍是 `x`，
/// 调用点写 `blockHosts:` 即可，只是省掉了「参数 → 字段」那层搬运）。
class AdBlockEngine {
  const AdBlockEngine._({
    required this.enabled,
    required this.ruleCount,
    required this.hostRuleCount,
    required this.patternRuleCount,
    required this._blockHosts,
    required this._allowHosts,
    required this._blockPrefixes,
    required this._allowPrefixes,
    required this._blockIndex,
    required this._allowIndex,
    required this._blockGeneric,
    required this._allowGeneric,
  });

  /// 关闭态的引擎（总开关关闭时用它，`shouldBlock` 恒 false，零开销）
  static const AdBlockEngine none = AdBlockEngine._(
    enabled: false,
    ruleCount: 0,
    hostRuleCount: 0,
    patternRuleCount: 0,
    blockHosts: <String>{},
    allowHosts: <String>{},
    blockPrefixes: <String>[],
    allowPrefixes: <String>[],
    blockIndex: <String, List<String>>{},
    allowIndex: <String, List<String>>{},
    blockGeneric: <String>[],
    allowGeneric: <String>[],
  );

  /// 总开关是否开启
  final bool enabled;

  /// 生效规则总条数（设置页展示用）
  final int ruleCount;

  /// 域锚定规则条数
  final int hostRuleCount;

  /// 子串/前缀规则条数
  final int patternRuleCount;

  final Set<String> _blockHosts;
  final Set<String> _allowHosts;
  final List<String> _blockPrefixes;
  final List<String> _allowPrefixes;
  final Map<String, List<String>> _blockIndex;
  final Map<String, List<String>> _allowIndex;
  final List<String> _blockGeneric;
  final List<String> _allowGeneric;

  /// 编译三级规则。
  ///
  /// [staticRulesEnabled] 关掉时**不加载**内置种子集（订阅与自定义仍生效）。
  /// [subscriptionRules] 是订阅规则的**原始行**（已抓回并缓存，见 adblock_subscriptions.dart）。
  factory AdBlockEngine.compile({
    required bool enabled,
    required bool staticRulesEnabled,
    List<String> subscriptionRules = const <String>[],
    List<String> customRules = const <String>[],
  }) {
    if (!enabled) return AdBlockEngine.none;
    final parsed = ParsedAdblockRules();
    if (staticRulesEnabled) {
      parsed.blockHosts.addAll(kStaticBlockedHosts);
      parsed.validCount += kStaticBlockedHosts.length;
      // 内置子串规则条数少，直接塞进 blockPatterns（会被索引化）
      parsed.blockPatterns.addAll(kStaticBlockedPatterns);
    }
    if (customRules.isNotEmpty) {
      parseAdblockLines(customRules, into: parsed);
    }
    if (subscriptionRules.isNotEmpty) {
      parseAdblockLines(subscriptionRules, into: parsed);
    }

    final blockIndexed = _indexPatterns(parsed.blockPatterns);
    final allowIndexed = _indexPatterns(parsed.allowPatterns);
    final patternCount =
        parsed.blockPrefixes.length +
        blockIndexed.index.length +
        blockIndexed.generic.length;

    return AdBlockEngine._(
      enabled: true,
      ruleCount: parsed.blockHosts.length + patternCount,
      hostRuleCount: parsed.blockHosts.length,
      patternRuleCount: patternCount,
      blockHosts: parsed.blockHosts,
      allowHosts: parsed.allowHosts,
      blockPrefixes: parsed.blockPrefixes,
      allowPrefixes: parsed.allowPrefixes,
      blockIndex: blockIndexed.index,
      allowIndex: allowIndexed.index,
      blockGeneric: blockIndexed.generic,
      allowGeneric: allowIndexed.generic,
    );
  }

  /// 是否应该拦截该请求 URL。
  ///
  /// ⚠️ 调用方**必须**先排除主文档请求（主文档被拦 = 白屏），见 browser_page.dart
  /// 里对 `request.isForMainFrame` 的判断。
  bool shouldBlock(String url) {
    if (!enabled) return false;
    if (url.isEmpty) return false;
    // 只处理网络资源；data:/blob:/about: 一律放行
    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    final host = _hostOf(lower);
    if (host.isEmpty) return false;

    // ① 例外（白名单）优先
    if (_allowHosts.isNotEmpty && _matchHost(_allowHosts, host)) return false;
    for (final p in _allowPrefixes) {
      if (lower.startsWith(p)) return false;
    }
    if (_allowIndex.isNotEmpty || _allowGeneric.isNotEmpty) {
      if (_matchPattern(lower, _allowIndex, _allowGeneric)) return false;
    }

    // ② 拦截规则
    if (_blockHosts.isNotEmpty && _matchHost(_blockHosts, host)) return true;
    for (final p in _blockPrefixes) {
      if (lower.startsWith(p)) return true;
    }
    return _matchPattern(lower, _blockIndex, _blockGeneric);
  }

  static String _hostOf(String url) {
    final start = url.indexOf('://');
    if (start < 0) return '';
    final rest = url.substring(start + 3);
    var end = rest.length;
    for (final sep in const ['/', '?', '#']) {
      final i = rest.indexOf(sep);
      if (i >= 0 && i < end) end = i;
    }
    var host = rest.substring(0, end);
    final colon = host.indexOf(':');
    if (colon >= 0) host = host.substring(0, colon);
    final at = host.indexOf('@');
    if (at >= 0) host = host.substring(at + 1);
    return host;
  }

  /// 按 `.` 逐级后缀查找（`a.b.example.com` → 依次查 `a.b.example.com` / `b.example.com` / …）
  static bool _matchHost(Set<String> set, String host) {
    var start = 0;
    while (true) {
      if (set.contains(host.substring(start))) return true;
      final dot = host.indexOf('.', start);
      if (dot < 0) return false;
      start = dot + 1;
    }
  }

  /// 分词反查 + 完整校验（见文件头说明）
  static bool _matchPattern(
    String url,
    Map<String, List<String>> index,
    List<String> generic,
  ) {
    if (index.isNotEmpty) {
      for (final token in _tokensOf(url)) {
        final candidates = index[token];
        if (candidates == null) continue;
        for (final p in candidates) {
          if (url.contains(p)) return true;
        }
      }
    }
    for (final p in generic) {
      if (url.contains(p)) return true;
    }
    return false;
  }

  /// URL 分词：按非字母数字切成词，只保留长度 ≥3 的词（短词误伤率太高）
  static Iterable<String> _tokensOf(String url) {
    final out = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < url.length; i++) {
      final c = url.codeUnitAt(i);
      final isAlnum =
          (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39); // a-z / 0-9
      if (isAlnum) {
        buf.writeCharCode(c);
      } else {
        if (buf.length >= 3) out.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.length >= 3) out.add(buf.toString());
    return out;
  }

  /// 规则 → 索引：key = 规则里最长的连续字母数字段；无可用段则落到 generic 列表
  static _IndexedPatterns _indexPatterns(List<String> patterns) {
    final index = <String, List<String>>{};
    final generic = <String>[];
    final seen = <String>{};
    for (final raw in patterns) {
      final p = raw.trim().toLowerCase();
      if (p.length < 3) continue;
      if (!seen.add(p)) continue; // 去重（订阅之间大量重复）
      final key = _keyOf(p);
      if (key == null) {
        // 无可分词（例如纯符号），退化成全量 contains —— 数量极少
        if (generic.length < 500) generic.add(p);
        continue;
      }
      index.putIfAbsent(key, () => <String>[]).add(p);
    }
    return _IndexedPatterns(index: index, generic: generic);
  }

  /// 取规则里最长的字母数字段作为索引键（长度 <3 视为不可用）
  static String? _keyOf(String pattern) {
    String? best;
    final buf = StringBuffer();
    void flush() {
      if (buf.length >= 3 && (best == null || buf.length > best!.length)) {
        best = buf.toString();
      }
      buf.clear();
    }

    for (var i = 0; i < pattern.length; i++) {
      final c = pattern.codeUnitAt(i);
      final isAlnum =
          (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39);
      if (isAlnum) {
        buf.writeCharCode(c);
      } else {
        flush();
      }
    }
    flush();
    return best;
  }
}

/// 索引结果（词 → 候选规则 + 无法分词的回退列表）
class _IndexedPatterns {
  const _IndexedPatterns({required this.index, required this.generic});

  final Map<String, List<String>> index;
  final List<String> generic;
}
