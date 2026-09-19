// 媒体资源嗅探器 —— Via 同构的「网络层观察 + JS hook 回传」双通道。
//
// 分工：
//   - browser_page.dart 的 `shouldInterceptRequest` 观察所有子资源请求（网络层，
//     依赖 useShouldInterceptRequest 常开，独立开关 browser_sniff）
//   - UserScript（document-start）hook fetch / XHR / video·audio·source src，
//     经 `callHandler('browserSniff')` 回传（抓无后缀接口 / 动态注入的媒体）
//   - 本文件只做：URL 扩展名分类（stream/video/audio/image/link）、去重、容量上限。
//     分类唯一真源在这里，JS 侧只报 URL + 来源标签，不做判定。
//
// ⚠️ 流媒体（m3u8 / mpd）嗅探到的只是**清单链接**，不是完整视频：
//    面板里流媒体条目走「复制链接」，交给外部 HLS 工具下载/播放
//    （内置清单解析 + 分片合成下载是独立工程，见 sniff-plan 备忘）。

/// 嗅探到的资源类型
enum BrowserSniffKind { stream, video, audio, image, link }

/// 嗅探到的单个资源
class BrowserSniffedResource {
  const BrowserSniffedResource({
    required this.url,
    required this.kind,
    this.tagName,
  });

  final String url;
  final BrowserSniffKind kind;

  /// 来源标签（video / audio / xhr / fetch / a 等），仅展示用
  final String? tagName;
}

/// 扩展名 → 类型映射（小写；判定基于 URL path 末段扩展名，忽略 query/fragment）
const Map<String, BrowserSniffKind> kSniffExtKinds = <String, BrowserSniffKind>{
  // 流媒体清单 / 描述文件
  'm3u8': BrowserSniffKind.stream,
  'm3u': BrowserSniffKind.stream,
  'mpd': BrowserSniffKind.stream,
  // 视频（flv/ts 归视频：可能是点播文件或分片，UI 上注明即可）
  'mp4': BrowserSniffKind.video,
  'm4v': BrowserSniffKind.video,
  'webm': BrowserSniffKind.video,
  'mkv': BrowserSniffKind.video,
  'mov': BrowserSniffKind.video,
  'avi': BrowserSniffKind.video,
  '3gp': BrowserSniffKind.video,
  'flv': BrowserSniffKind.video,
  'ts': BrowserSniffKind.video,
  'm2ts': BrowserSniffKind.video,
  'm4s': BrowserSniffKind.video,
  // 音频
  'mp3': BrowserSniffKind.audio,
  'm4a': BrowserSniffKind.audio,
  'aac': BrowserSniffKind.audio,
  'flac': BrowserSniffKind.audio,
  'ogg': BrowserSniffKind.audio,
  'opus': BrowserSniffKind.audio,
  'wav': BrowserSniffKind.audio,
  'amr': BrowserSniffKind.audio,
  'wma': BrowserSniffKind.audio,
  // 图片
  'jpg': BrowserSniffKind.image,
  'jpeg': BrowserSniffKind.image,
  'png': BrowserSniffKind.image,
  'gif': BrowserSniffKind.image,
  'webp': BrowserSniffKind.image,
  'bmp': BrowserSniffKind.image,
  'svg': BrowserSniffKind.image,
  'ico': BrowserSniffKind.image,
};

/// URL 末段扩展名（匹配 `xxx.ext` 后紧跟 `?` / `#` / 结尾，避免命中路径中间段）
final RegExp _sniffExtRegExp = RegExp(
  r'\.([a-z0-9]{2,5})(?:[?#]|$)',
  caseSensitive: false,
);

/// 按 URL 扩展名分类；不是已知媒体扩展名返回 null
BrowserSniffKind? classifySniffUrl(String url) {
  final m = _sniffExtRegExp.firstMatch(url);
  if (m == null) return null;
  return kSniffExtKinds[m.group(1)!.toLowerCase()];
}

/// 单个标签页的嗅探结果聚合（当前页导航切换时 [reset]）
class BrowserSniffer {
  final Map<String, BrowserSniffedResource> _hits =
      <String, BrowserSniffedResource>{};

  /// 容量上限：防部分页面（图站/直播）刷爆内存；满了优先丢弃图片
  static const int _maxHits = 300;

  /// 当前累计命中（按 stream → video → audio → image → link 分组排序）
  List<BrowserSniffedResource> get hits {
    final list = _hits.values.toList();
    int rank(BrowserSniffKind k) => switch (k) {
          BrowserSniffKind.stream => 0,
          BrowserSniffKind.video => 1,
          BrowserSniffKind.audio => 2,
          BrowserSniffKind.image => 3,
          BrowserSniffKind.link => 4,
        };
    list.sort((a, b) => rank(a.kind).compareTo(rank(b.kind)));
    return list;
  }

  int get count => _hits.length;

  /// 换页（主文档开始加载新页面）时清空
  void reset() => _hits.clear();

  /// 记录一次命中。分类以扩展名为准；无扩展名但 JS 侧明确是 video/audio
  /// （如 `<video src="/api/media?id=1">`）用 [hint] 兜底。
  void observe(String url, {String? hint}) {
    if (url.isEmpty ||
        url.length > 2048 ||
        url.startsWith('data:') ||
        url.startsWith('blob:')) {
      return;
    }
    if (_hits.containsKey(url)) return;
    if (_hits.length >= _maxHits) return;
    final kind = classifySniffUrl(url) ?? _kindFromHint(hint);
    if (kind == null) return;
    _hits[url] = BrowserSniffedResource(url: url, kind: kind, tagName: hint);
  }

  static BrowserSniffKind? _kindFromHint(String? hint) {
    switch (hint) {
      case 'video':
        return BrowserSniffKind.video;
      case 'audio':
        return BrowserSniffKind.audio;
      case 'image':
        return BrowserSniffKind.image;
      case 'link':
        return BrowserSniffKind.link;
      default:
        return null;
    }
  }
}
