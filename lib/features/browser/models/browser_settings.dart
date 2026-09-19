// 浏览器设置模型 —— 持久化在 `basic_info` 表（与 App 其它配置同源，不另开表）
//
// 键前缀统一 `browser_`，见 [BrowserKeys]。序列化只做「字符串 ↔ 模型」的映射，
// 复杂字段（订阅规则 / 自定义规则）用 JSON 串存，读写都收口在本文件。
import 'dart:convert';

import 'browser_models.dart';

/// 桌面版（请求桌面网站）统一使用的 UA。电脑模式 / Chrome 桌面版预设共用同一段，
/// 差别只在前者是开关、后者是预设。
const String kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// 默认移动端 UA（标准 Chrome on Android 的 Reduced UA 形态）。
///
/// 不用 WebView 的原生默认 UA：WebView 默认串里带 `; wv` 标记，部分站点
/// （百度等）会据此识别出「非正规浏览器」并注入「唤起自家 App」的 scheme
/// 跳转（baiduboxapp:// / intent://），标准 Chrome UA 能减少这类注入。
const String kMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

/// 浏览器配置键（`basic_info.key`）
abstract final class BrowserKeys {
  static const String engine = 'browser_engine';
  static const String engineCustom = 'browser_engine_custom';
  static const String homePinned = 'browser_home_pinned';
  static const String darkMode = 'browser_dark_mode';
  static const String fontScale = 'browser_font_scale';
  static const String adBlock = 'browser_adblock';
  static const String adBlockStatic = 'browser_adblock_static';
  static const String adBlockSubs = 'browser_adblock_subs';
  static const String adBlockCustom = 'browser_adblock_custom';
  static const String incognito = 'browser_incognito';
  static const String doNotTrack = 'browser_dnt';
  static const String newTabMode = 'browser_new_tab_mode';

  /// 电脑模式（请求桌面版网站）
  static const String desktopMode = 'browser_desktop_mode';
  /// 浏览器标识（UA 预设）
  static const String uaPreset = 'browser_ua_preset';
  /// 自定义 UA 文本（uaPreset == custom 时生效）
  static const String uaCustom = 'browser_ua_custom';
  /// 无图模式
  static const String noImage = 'browser_no_image';
  /// 媒体嗅探（shouldInterceptRequest 常开观察 + JS hook，见 browser_sniffer.dart）
  static const String sniff = 'browser_sniff';

  /// ⚠️ 订阅规则**原文缓存**（体积可达数 MB，见 adblock_subscriptions.dart）。
  ///
  /// 刻意**不放进 [all]**：`readSettings()` 会一次性把 [all] 全读进内存，
  /// 混进来会让每次进浏览器都白读几 MB。它由 `readRawSetting` 单独按需读取。
  static const String adBlockSubsCache = 'browser_adblock_subs_cache';

  /// 全部键（用于一次性读取；新增键记得加进来）
  static const List<String> all = [
    engine,
    engineCustom,
    homePinned,
    darkMode,
    fontScale,
    adBlock,
    adBlockStatic,
    adBlockSubs,
    adBlockCustom,
    incognito,
    doNotTrack,
    newTabMode,
    desktopMode,
    uaPreset,
    uaCustom,
    noImage,
    sniff,
  ];
}

/// 新标签页打开方式（网页里 `target="_blank"` 的链接怎么开）
enum BrowserNewTabMode {
  /// 前台打开：立即切到新标签（Chrome 默认）
  foreground('foreground', '前台打开', '立即切到新标签'),

  /// 后台打开：留在当前页，新标签放到队尾
  background('background', '后台打开', '不打断当前页面');

  const BrowserNewTabMode(this.id, this.label, this.hint);

  final String id;
  final String label;
  final String hint;

  static BrowserNewTabMode fromId(String? id) => values.firstWhere(
    (e) => e.id == id,
    orElse: () => BrowserNewTabMode.foreground,
  );
}

/// 深色模式（网页层）
enum BrowserDarkMode {
  system('system', '跟随系统'),
  light('light', '亮色'),
  dark('dark', '深色');

  const BrowserDarkMode(this.id, this.label);

  final String id;
  final String label;

  static BrowserDarkMode fromId(String? id) => values.firstWhere(
    (e) => e.id == id,
    orElse: () => BrowserDarkMode.system,
  );
}

/// 浏览器标识（UA 预设）
///
/// `mobile` = 不覆盖（让 WebView 用当前设备默认移动 UA）；其余预设各自带一份 UA 串。
/// `custom` 的 UA 串来自 [BrowserSettings.customUa]（用户在「浏览器标识」里手填）。
enum BrowserUaPreset {
  mobile('mobile', '默认（移动端）', null),
  chrome(
    'chrome',
    'Chrome 桌面版',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  ),
  edge(
    'edge',
    'Edge 桌面版',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0',
  ),
  iphone(
    'iphone',
    'iPhone（Safari）',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  ),
  mac(
    'mac',
    'Mac（Safari）',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.0 Safari/605.1.15',
  ),
  custom('custom', '自定义 UA', null);

  const BrowserUaPreset(this.id, this.label, this.ua);

  final String id;
  final String label;

  /// 该预设对应的完整 UA 串；`null` 表示「不覆盖」（mobile）或「用 customUa」（custom）
  final String? ua;

  static BrowserUaPreset fromId(String? id) => values.firstWhere(
    (e) => e.id == id,
    orElse: () => BrowserUaPreset.mobile,
  );
}

/// 浏览器设置（不可变；改一项走 [copyWith]）
class BrowserSettings {
  const BrowserSettings({
    this.engineId = 'baidu',
    this.customSearchTemplate = '',
    this.showPinnedOnHome = true,
    this.darkMode = BrowserDarkMode.system,
    this.fontScale = 1.0,
    this.adBlockEnabled = true,
    this.staticRulesEnabled = true,
    this.subscriptions = const <String>[],
    this.customRules = const <String>[],
    this.incognito = false,
    this.doNotTrack = true,
    this.newTabMode = BrowserNewTabMode.foreground,
    this.desktopMode = false,
    this.uaPreset = BrowserUaPreset.mobile,
    this.customUa = '',
    this.noImage = false,
    this.sniffEnabled = true,
  });

  /// 搜索引擎 id（见 [kBrowserEngines]）
  final String engineId;

  /// 自定义搜索引擎模板（含 `%s`）
  final String customSearchTemplate;

  /// 首页是否显示固定标签页九宫格（用户定案：该区块「可选」）
  final bool showPinnedOnHome;

  final BrowserDarkMode darkMode;

  /// 网页字号缩放（0.8 ~ 1.5，1.0 = 100%）
  final double fontScale;

  /// 广告拦截总开关
  final bool adBlockEnabled;

  /// 内置静态规则集（三级之一）
  final bool staticRulesEnabled;

  /// 可订阅规则（三级之二）：URL 列表
  final List<String> subscriptions;

  /// 自定义拦截规则（三级之三）：Adblock 语法行
  final List<String> customRules;

  /// 无痕模式（不写历史、退出清 Cookie）
  final bool incognito;

  /// 不追踪请求（发 DNT: 1）
  final bool doNotTrack;

  /// 网页 `target="_blank"` 链接的打开方式
  final BrowserNewTabMode newTabMode;

  /// 电脑模式（请求桌面版网站）：命中时套桌面 UA
  final bool desktopMode;

  /// 浏览器标识（UA 预设）
  final BrowserUaPreset uaPreset;

  /// 自定义 UA（[uaPreset] == custom 时生效）
  final String customUa;

  /// 无图模式（拦截图片请求，省流量）
  final bool noImage;

  /// 媒体嗅探（网络层观察 + JS hook；开启会让 useShouldInterceptRequest 常开）
  final bool sniffEnabled;

  /// 当前搜索引擎对象
  BrowserEngine get engine => engineById(engineId);

  /// 有效规则条数（设置页展示用；静态集为打包常量，见 adblock 服务）
  int get ruleCountPreview => customRules.length + subscriptions.length;

  /// 生效的自定义 UA。
  ///
  /// 返回 `null` 表示不覆盖（让 WebView 用当前设备默认 UA）。优先级：
  /// 1. 选了非 mobile 预设 → 用该预设 UA（custom 时用 [customUa]）
  /// 2. 开了电脑模式 → 用桌面 UA
  /// 3. 否则不覆盖
  String? get effectiveUserAgent {
    if (uaPreset != BrowserUaPreset.mobile) {
      if (uaPreset == BrowserUaPreset.custom) {
        final c = customUa.trim();
        return c.isEmpty ? null : c;
      }
      return uaPreset.ua;
    }
    if (desktopMode) return kDesktopUserAgent;
    return null;
  }

  BrowserSettings copyWith({
    String? engineId,
    String? customSearchTemplate,
    bool? showPinnedOnHome,
    BrowserDarkMode? darkMode,
    double? fontScale,
    bool? adBlockEnabled,
    bool? staticRulesEnabled,
    List<String>? subscriptions,
    List<String>? customRules,
    bool? incognito,
    bool? doNotTrack,
    BrowserNewTabMode? newTabMode,
    bool? desktopMode,
    BrowserUaPreset? uaPreset,
    String? customUa,
    bool? noImage,
    bool? sniffEnabled,
  }) {
    return BrowserSettings(
      engineId: engineId ?? this.engineId,
      customSearchTemplate: customSearchTemplate ?? this.customSearchTemplate,
      showPinnedOnHome: showPinnedOnHome ?? this.showPinnedOnHome,
      darkMode: darkMode ?? this.darkMode,
      fontScale: fontScale ?? this.fontScale,
      adBlockEnabled: adBlockEnabled ?? this.adBlockEnabled,
      staticRulesEnabled: staticRulesEnabled ?? this.staticRulesEnabled,
      subscriptions: subscriptions ?? this.subscriptions,
      customRules: customRules ?? this.customRules,
      incognito: incognito ?? this.incognito,
      doNotTrack: doNotTrack ?? this.doNotTrack,
      newTabMode: newTabMode ?? this.newTabMode,
      desktopMode: desktopMode ?? this.desktopMode,
      uaPreset: uaPreset ?? this.uaPreset,
      customUa: customUa ?? this.customUa,
      noImage: noImage ?? this.noImage,
      sniffEnabled: sniffEnabled ?? this.sniffEnabled,
    );
  }

  /// 从 basic_info 键值对反序列化（缺失键一律用默认值，不抛异常）
  factory BrowserSettings.fromMap(Map<String, String?> map) {
    return BrowserSettings(
      engineId: map[BrowserKeys.engine] ?? 'baidu',
      customSearchTemplate: map[BrowserKeys.engineCustom] ?? '',
      showPinnedOnHome: _bool(map[BrowserKeys.homePinned], fallback: true),
      darkMode: BrowserDarkMode.fromId(map[BrowserKeys.darkMode]),
      fontScale: double.tryParse(map[BrowserKeys.fontScale] ?? '') ?? 1.0,
      adBlockEnabled: _bool(map[BrowserKeys.adBlock], fallback: true),
      staticRulesEnabled: _bool(
        map[BrowserKeys.adBlockStatic],
        fallback: true,
      ),
      subscriptions: _list(map[BrowserKeys.adBlockSubs]),
      customRules: _list(map[BrowserKeys.adBlockCustom]),
      incognito: _bool(map[BrowserKeys.incognito], fallback: false),
      doNotTrack: _bool(map[BrowserKeys.doNotTrack], fallback: true),
      newTabMode: BrowserNewTabMode.fromId(map[BrowserKeys.newTabMode]),
      desktopMode: _bool(map[BrowserKeys.desktopMode], fallback: false),
      uaPreset: BrowserUaPreset.fromId(map[BrowserKeys.uaPreset]),
      customUa: map[BrowserKeys.uaCustom] ?? '',
      noImage: _bool(map[BrowserKeys.noImage], fallback: false),
      sniffEnabled: _bool(map[BrowserKeys.sniff], fallback: true),
    );
  }

  /// 序列化：输出**完整快照**（[BrowserKeys.all] 的每个键都有值）。
  ///
  /// ⚠️ 必须是完整快照、不能只写「与默认值不同」的项：否则把某个开关改回默认后，
  /// 旧的非默认值会**永久留在 basic_info 里**，下次启动读回来的还是旧值
  /// （例：无痕开→关，重启后又变回开）。全部键的冗余代价可以忽略，正确性优先。
  Map<String, String> toMap() {
    return <String, String>{
      BrowserKeys.engine: engineId,
      BrowserKeys.engineCustom: customSearchTemplate,
      BrowserKeys.homePinned: showPinnedOnHome ? '1' : '0',
      BrowserKeys.darkMode: darkMode.id,
      BrowserKeys.fontScale: fontScale.toStringAsFixed(2),
      BrowserKeys.adBlock: adBlockEnabled ? '1' : '0',
      BrowserKeys.adBlockStatic: staticRulesEnabled ? '1' : '0',
      BrowserKeys.adBlockSubs: jsonEncode(subscriptions),
      BrowserKeys.adBlockCustom: jsonEncode(customRules),
      BrowserKeys.incognito: incognito ? '1' : '0',
      BrowserKeys.doNotTrack: doNotTrack ? '1' : '0',
      BrowserKeys.newTabMode: newTabMode.id,
      BrowserKeys.desktopMode: desktopMode ? '1' : '0',
      BrowserKeys.uaPreset: uaPreset.id,
      BrowserKeys.uaCustom: customUa,
      BrowserKeys.noImage: noImage ? '1' : '0',
      BrowserKeys.sniff: sniffEnabled ? '1' : '0',
    };
  }
}

/// 布尔键解析：`'1'`/`'true'` 为真，其余为假，缺失用 [fallback]
bool _bool(String? raw, {required bool fallback}) {
  if (raw == null || raw.isEmpty) return fallback;
  return raw == '1' || raw.toLowerCase() == 'true';
}

/// JSON 数组键解析（脏数据安全降级为空列表）
List<String> _list(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
  } on FormatException {
    // 落库脏数据：忽略即可，别让设置页打不开
  }
  return const <String>[];
}
