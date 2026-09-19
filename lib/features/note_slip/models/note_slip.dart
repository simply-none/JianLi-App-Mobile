// P1-6 小纸条 —— 模型与纯函数（方向/类型常量、URL 判定、摘要）
//
// 只放**不依赖 drift / Flutter** 的纯逻辑，便于页面、通知、发送端共用同一套判定，
// 也与桌面端 noteSlip.ts 的 kind 判定规则保持一致（避免双端对同一段文字判出不同类型）。

/// 方向：收到的
const String kSlipDirectionIn = 'in';

/// 方向：发出的
const String kSlipDirectionOut = 'out';

/// 内容类型：普通文本
const String kSlipKindText = 'text';

/// 内容类型：链接
const String kSlipKindUrl = 'url';

/// 单条内容上限（字符）：超过即拒收/拒发（与桌面端一致）
const int kSlipMaxChars = 8000;

/// 保留条数上限（超出按时间删最旧）
const int kSlipKeepRows = 300;

/// 启发式 URL 判定：整段无空白 + 以 http(s):// 开头（与 share_intake 同款规则）。
bool looksLikeSlipUrl(String s) {
  if (s.contains('\n') || s.contains(' ')) return false;
  return s.startsWith('http://') || s.startsWith('https://');
}

/// 按内容判定类型（双端同一判据）
String slipKindOf(String content) =>
    looksLikeSlipUrl(content.trim()) ? kSlipKindUrl : kSlipKindText;

/// 列表/通知标题：取首行、截 40 字（空内容给兜底）
String slipTitleOf(String content) {
  final line = content.split('\n').first.trim();
  if (line.isEmpty) return '小纸条';
  return line.length <= 40 ? line : '${line.substring(0, 40)}…';
}

/// 通知正文预览：取首行、截 80 字
String slipPreviewOf(String content) {
  final line = content.split('\n').first.trim();
  if (line.isEmpty) return '（空内容）';
  return line.length <= 80 ? line : '${line.substring(0, 80)}…';
}

/// 时间戳毫秒 → 'MM-DD HH:mm'（列表行尾展示用）
String slipTimeLabel(int? ms) {
  if (ms == null || ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
