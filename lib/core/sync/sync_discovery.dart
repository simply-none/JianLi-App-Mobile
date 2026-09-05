// 局域网设备发现（类 LocalSend，自定义极简 UDP 协议，零依赖）
//
// 协议 v1：
//   发现请求：UDP 广播（端口 47123）文本 "JIANLI_SYNC_DISCOVER_V1"
//   应答：    UDP 回包 "JIANLI_SYNC_INFO_V1|{json: {name, id, platform}}"
// PC 端（electron/main/module/sync）以同协议应答；后续可平滑升级 mDNS。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 同步协议常量
class SyncProtocol {
  SyncProtocol._();

  /// UDP 发现端口
  static const int discoveryPort = 47123;

  /// TCP 数据端口
  static const int dataPort = 47124;

  static const String discoverPacket = 'JIANLI_SYNC_DISCOVER_V1';
  static const String infoPrefix = 'JIANLI_SYNC_INFO_V1|';
}

/// 局域网内的对端设备
class PeerDevice {
  const PeerDevice({required this.ip, required this.name, required this.id, required this.platform});

  final String ip;
  final String name;
  final String id;
  final String platform;

  factory PeerDevice.fromJson(String ip, Map<String, dynamic> json) => PeerDevice(
        ip: ip,
        name: json['name'] as String? ?? '未知设备',
        id: json['id'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'id': id, 'platform': platform};
}

/// 本机信息
String get localDeviceName => Platform.localHostname;

/// 本机稳定 id（主机名稳定哈希，与 PC 端同算法）
String get localDeviceId => localDeviceName.hashCode.toUnsigned(32).toString();

String get localPlatform => Platform.operatingSystem;

/// 发现服务：监听发现请求（可被发现）+ 主动扫描
class SyncDiscovery {
  RawDatagramSocket? _socket;
  final Map<String, PeerDevice> _found = {};
  final _peersController = StreamController<Map<String, PeerDevice>>.broadcast();

  /// 当前已发现设备流
  Stream<Map<String, PeerDevice>> get peersStream => _peersController.stream;
  Map<String, PeerDevice> get peers => _found;

  /// 广播地址（简化：全网段广播；多网卡环境 TODO(P3) 逐网卡发送）
  static final InternetAddress broadcastAddr = InternetAddress('255.255.255.255');

  /// 启动监听（响应别人的发现请求）
  Future<void> startResponder({String name = '', String id = '', String platform = ''}) async {
    _socket ??= await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      SyncProtocol.discoveryPort,
      reuseAddress: true,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _socket!.receive();
      if (dg == null) return;
      final msg = utf8.decode(dg.data, allowMalformed: true);
      if (msg == SyncProtocol.discoverPacket) {
        final info = utf8.encode(
          '${SyncProtocol.infoPrefix}${jsonEncode({
                'name': name.isEmpty ? localDeviceName : name,
                'id': id.isEmpty ? localDeviceId : id,
                'platform': platform.isEmpty ? localPlatform : platform,
              })}',
        );
        _socket!.send(info, dg.address, dg.port);
      }
    });
  }

  /// 主动扫描一轮（广播 + 收集 3 秒应答）
  Future<Map<String, PeerDevice>> scan({Duration wait = const Duration(seconds: 3)}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.send(
      utf8.encode(SyncProtocol.discoverPacket),
      broadcastAddr,
      SyncProtocol.discoveryPort,
    );

    final completer = Completer<Map<String, PeerDevice>>();
    final timer = Timer(wait, () {
      if (!completer.isCompleted) completer.complete(Map.of(_found));
    });
    late final StreamSubscription<RawSocketEvent> sub;
    sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final msg = utf8.decode(dg.data, allowMalformed: true);
      if (!msg.startsWith(SyncProtocol.infoPrefix)) return;
      try {
        final json =
            jsonDecode(msg.substring(SyncProtocol.infoPrefix.length)) as Map<String, dynamic>;
        final peer = PeerDevice.fromJson(dg.address.address, json);
        _found[peer.ip] = peer;
        _peersController.add(Map.of(_found));
      } catch (_) {
        // 非法应答忽略
      }
    });
    final result = await completer.future;
    timer.cancel();
    await sub.cancel();
    socket.close();
    return result;
  }

  /// 停止响应者
  void stop() {
    _socket?.close();
    _socket = null;
  }
}
