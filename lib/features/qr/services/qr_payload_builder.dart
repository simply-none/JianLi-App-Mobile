// 二维码内容拼装 —— 对齐桌面端 src/utils/qrcode/payload.ts 的常用子集
//
// 桌面端共 9 种（text/url/wifi/contact/email/sms/tel/geo/event）；
// 移动端首批落地最常用的 5 种，其余沿用同一 buildPayload 扩展点（P2 补齐）。
class QrPayloadType {
  QrPayloadType._();

  static const text = 'text';
  static const url = 'url';
  static const wifi = 'wifi';
  static const contact = 'contact';
  static const email = 'email';

  /// 类型清单（下拉选择用）
  static const all = [text, url, wifi, contact, email];

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
      default:
        return '文本';
    }
  }
}

/// Wi-Fi 参数
class WifiParams {
  const WifiParams({required this.ssid, required this.password, this.encryption = 'WPA'});

  final String ssid;
  final String password;
  final String encryption;
}

/// 拼装二维码内容（与桌面端格式一致，扫码端可互相识别）
String buildQrPayload(String type, {String? text, WifiParams? wifi, Map<String, String>? contact}) {
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
    case QrPayloadType.text:
    default:
      return text ?? '';
  }
}

/// Wi-Fi/vCard 值转义（\ ; , : "）
String _escape(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll(':', r'\:').replaceAll('"', r'\"');
