// 浏览器功能域 —— 领域常量、默认数据与纯函数工具（无 UI / 无 IO，便于单测与复用）
//
// 只放「与展示无关」的东西：固定标签槽位规则、默认站点、搜索引擎、地址解析。
// 具体页面的 UI 规格在 components/ 下各自文件里，不要往这里堆 Widget。
/// 固定标签页槽位上限（用户定案：默认 8 个、2×4 九宫格；第 9 个**替换最早加入的**）。
const int kPinnedMaxSlots = 8;

/// 固定标签页站点规格（首次启动写入 DB 的默认值，之后由用户在设置里编辑）。
class PinnedSiteSpec {
  const PinnedSiteSpec({
    required this.title,
    required this.url,
    required this.letter,
    required this.color,
  });

  final String title;
  final String url;

  /// 没有 favicon 时的占位字（中文取首字 / 英文取首字母）。
  final String letter;

  /// 占位字品牌色 `#RRGGBB`（落地换真实 favicon 后仅作兜底）。
  final String color;
}

/// 默认 8 个常用站点（与设计稿逐项一致）。
const List<PinnedSiteSpec> kDefaultPinnedSites = [
  PinnedSiteSpec(
    title: '百度',
    url: 'https://www.baidu.com',
    letter: '百',
    color: '#2932E1',
  ),
  PinnedSiteSpec(
    title: '淘宝',
    url: 'https://www.taobao.com',
    letter: '淘',
    color: '#FF5000',
  ),
  PinnedSiteSpec(
    title: '京东',
    url: 'https://www.jd.com',
    letter: '京',
    color: '#E1251B',
  ),
  PinnedSiteSpec(
    title: '微博',
    url: 'https://m.weibo.cn',
    letter: '微',
    color: '#FF8200',
  ),
  PinnedSiteSpec(
    title: '知乎',
    url: 'https://www.zhihu.com',
    letter: '知',
    color: '#0084FF',
  ),
  PinnedSiteSpec(
    title: '哔哩哔哩',
    url: 'https://m.bilibili.com',
    letter: 'B',
    color: '#FB7299',
  ),
  PinnedSiteSpec(
    title: '豆瓣',
    url: 'https://www.douban.com',
    letter: '豆',
    color: '#2E963D',
  ),
  PinnedSiteSpec(
    title: '小红书',
    url: 'https://www.xiaohongshu.com',
    letter: '红',
    color: '#FF2442',
  ),
];

/// 无痕 / 新标签页的固定占位（地址栏与标签标题都用它）。
const String kBlankTabTitle = '新标签页';

/// 搜索引擎（首页搜索栏 / 地址栏输入关键词时用它拼 URL）。
class BrowserEngine {
  const BrowserEngine({
    required this.id,
    required this.name,
    required this.template,
  });

  final String id;
  final String name;

  /// 查询模板，`%s` 为占位（自定义引擎由设置页写入同一格式）。
  final String template;

  /// 拼搜索地址；模板为空（自定义未配置）时回落到百度。
  String searchUrl(String query) {
    final q = Uri.encodeQueryComponent(query);
    if (template.trim().isEmpty) {
      return 'https://www.baidu.com/s?wd=$q';
    }
    return template.contains('%s')
        ? template.replaceFirst('%s', q)
        : '$template$q';
  }
}

/// 可选搜索引擎（设置页「搜索引擎」）。
const List<BrowserEngine> kBrowserEngines = [
  BrowserEngine(
    id: 'baidu',
    name: '百度',
    template: 'https://www.baidu.com/s?wd=%s',
  ),
  BrowserEngine(
    id: 'bing',
    name: '必应',
    template: 'https://cn.bing.com/search?q=%s',
  ),
  BrowserEngine(
    id: 'google',
    name: 'Google',
    template: 'https://www.google.com/search?q=%s',
  ),
  BrowserEngine(
    id: 'sogou',
    name: '搜狗',
    template: 'https://www.sogou.com/web?query=%s',
  ),
  BrowserEngine(id: 'custom', name: '自定义', template: ''),
];

/// 按 id 取搜索引擎（未知名回落百度，不抛异常）。
BrowserEngine engineById(String? id) => kBrowserEngines.firstWhere(
  (e) => e.id == id,
  orElse: () => kBrowserEngines.first,
);

/// 判断输入「像不像一个网址」——决定回车是导航还是搜索。
///
/// 规则（与 Chrome 的 omnibox 简化版一致）：
/// 含协议前缀 / `localhost` / IP 直连 → 网址；
/// 含 `.` 且首段不是中文、且整串无空格 → 网址（`zhihu.com`、`b23.tv/x`）；
/// 其余（含空格 / 纯中文 / 无点）→ 搜索词。
bool looksLikeUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s)) return true;
  if (s.startsWith('localhost') || s.startsWith('127.0.0.1')) return true;
  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?').hasMatch(s)) return true;
  if (s.contains(' ')) return false;
  final host = s.split('/').first.split(':').first;
  if (!host.contains('.')) return false;
  final tld = host.split('.').last;
  // 顶级域至少 2 个 ASCII 字母，避免把「3.5」「第1.2章」当网址。
  return RegExp(r'^[a-zA-Z]{2,}$').hasMatch(tld);
}

/// 补全协议：无协议时 localhost / IP 走 http，其余走 https。
String normalizeUrl(String raw) {
  final s = raw.trim();
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s)) return s;
  final isLocal =
      s.startsWith('localhost') || RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(s);
  return '${isLocal ? 'http' : 'https'}://$s';
}

/// 地址栏 / 搜索栏输入 → 最终加载地址。
///
/// 看起来是网址就补协议，否则按当前搜索引擎搜。**这是地址栏的唯一入口**，
/// 不要在页面里另写一套判断（否则「同一个输入在不同入口行为不同」）。
String resolveInput(
  String raw, {
  required BrowserEngine engine,
  String customTemplate = '',
}) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (looksLikeUrl(s)) return normalizeUrl(s);
  final custom = customTemplate.trim();
  // 自定义引擎且已配置模板时才用设置里的模板，否则用引擎自带模板。
  final tmpl = (engine.id == 'custom' && custom.isNotEmpty)
      ? custom
      : engine.template;
  final q = Uri.encodeQueryComponent(s);
  if (tmpl.trim().isEmpty) return 'https://www.baidu.com/s?wd=$q';
  return tmpl.contains('%s')
      ? tmpl.replaceFirst('%s', q)
      : '$tmpl$q';
}

/// 取主机名（地址栏展示用）；解析失败回落原串。
String hostOf(String url) {
  final uri = Uri.tryParse(url);
  final host = uri?.host ?? '';
  if (host.isEmpty) return url;
  return uri!.hasPort ? '$host:${uri.port}' : host;
}

/// 地址栏展示文本：去掉协议与结尾斜杠（`https://zhihu.com/` → `zhihu.com`）。
String displayUrl(String url) {
  var s = url.trim();
  s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  return s;
}

/// 无 favicon 时的占位字：中文取首字，英文取首字母（大写）。
String letterOfSite(String titleOrUrl) {
  final s = titleOrUrl.trim();
  if (s.isEmpty) return '·';
  // 用 runes 取首字符，避免代理对被截成半个字符。
  final first = String.fromCharCode(s.runes.first);
  return RegExp(r'[A-Za-z]').hasMatch(first) ? first.toUpperCase() : first;
}

/// 历史 / 书签 key 的稳定哈希（FNV-1a 32bit，跨重启一致）——保证同一地址只留一行。
String urlKeyOf(String url) {
  var hash = 0x811c9dc5;
  for (final code in url.trim().toLowerCase().codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return 'h_${hash.toRadixString(16).padLeft(8, '0')}';
}
