// 二维码内容拼装 —— 对齐桌面端 src/utils/qrcode/payload.ts 的 9 种类型全集
//
// 桌面端 9 种：text/url/wifi/contact/email/sms/tel/geo/event；本实现与桌面端格式一致，
// 扫码端可互相识别。extra 为自由字段表（sms/tel/geo/event 的动态字段）。
class QrPayloadType {
  QrPayloadType._();

  static const text = 'text';
  static const url = 'url';
  static const wifi = 'wifi';
  static const contact = 'contact';
  static const email = 'email';
  static const sms = 'sms';
  static const tel = 'tel';
  static const geo = 'geo';
  static const event = 'event';

  /// 类型清单（生成页选择用，与 PC 生成 Tab 同序）
  static const all = [text, url, wifi, contact, email, sms, tel, geo, event];

  static String label(String type) {
    switch (type) {
      case url:
        return '网址';
      case wifi:
        return 'Wi-Fi';
      case contact:
        return '联系人';
      case email:
        return '邮件';
      case sms:
        return '短信';
      case tel:
        return '电话';
      case geo:
        return '位置';
      case event:
        return '日历事件';
      default:
        return '文本';
    }
  }
}

/// Wi-Fi 参数
class WifiParams {
  const WifiParams({
    required this.ssid,
    required this.password,
    this.encryption = 'WPA',
  });

  final String ssid;
  final String password;
  final String encryption;
}

/// 拼装二维码内容（与桌面端格式一致，扫码端可互相识别）
///
/// [extra]：sms/tel/geo/event 类型的动态字段（tel/msg/lat/lng/title/start/end/location）。
String buildQrPayload(
  String type, {
  String? text,
  WifiParams? wifi,
  Map<String, String>? contact,
  Map<String, String>? extra,
}) {
  final f = extra ?? const {};
  switch (type) {
    case QrPayloadType.url:
      final v = text ?? '';
      return v.startsWith('http') ? v : 'https://$v';
    case QrPayloadType.wifi:
      // WIFI:T:WPA;S:<ssid>;P:<password>;; 标准格式
      final w = wifi ?? const WifiParams(ssid: '', password: '');
      return 'WIFI:T:${w.encryption};S:${_escape(w.ssid)};P:${_escape(w.password)};;';
    case QrPayloadType.contact:
      // vCard 3.0 精简版
      final c = contact ?? const {};
      return [
        'BEGIN:VCARD',
        'VERSION:3.0',
        'FN:${c['name'] ?? ''}',
        'TEL:${c['tel'] ?? ''}',
        'EMAIL:${c['email'] ?? ''}',
        'END:VCARD',
      ].join('\n');
    case QrPayloadType.email:
      return 'mailto:${text ?? ''}';
    case QrPayloadType.sms:
      // SMSTO:号码:内容（扫码端填充短信草稿）
      return 'SMSTO:${f['tel'] ?? ''}:${f['msg'] ?? ''}';
    case QrPayloadType.tel:
      return 'tel:${f['tel'] ?? ''}';
    case QrPayloadType.geo:
      // geo:纬度,经度（Google Maps 兼容格式）
      return 'geo:${f['lat'] ?? ''},${f['lng'] ?? ''}';
    case QrPayloadType.event:
      // vEvent 精简版（时间格式 YYYYMMDDTHHMMSS；调用方已按此提示）
      return [
        'BEGIN:VEVENT',
        'SUMMARY:${f['title'] ?? ''}',
        'DTSTART:${_compactTime(f['start'] ?? '')}',
        'DTEND:${_compactTime(f['end'] ?? '')}',
        'LOCATION:${f['location'] ?? ''}',
        'END:VEVENT',
      ].join('\n');
    case QrPayloadType.text:
    default:
      return text ?? '';
  }
}

/// '2026-09-13 09:00' → '20260913T090000'（vEvent DTSTART 格式；解析失败原样返回）
String _compactTime(String raw) {
  final m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})',
  ).firstMatch(raw.trim());
  if (m == null) return raw.replaceAll(RegExp(r'[^0-9T]'), '');
  return '${m.group(1)}${m.group(2)}${m.group(3)}T${m.group(4)}${m.group(5)}00';
}

/// Wi-Fi/vCard 值转义（\ ; , : "）
String _escape(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(':', r'\:')
    .replaceAll('"', r'\"');
