// 局域网设备发现（类 LocalSend，自定义极简 UDP 协议，零依赖）
//
// 协议 v1：
//   发现请求：UDP 广播（端口 47123）文本 "JIANLI_SYNC_DISCOVER_V1"
//   应答：    UDP 回包 "JIANLI_SYNC_INFO_V1|{json: {name, id, platform}}"
// PC 端（electron/main/module/sync）以同协议应答；后续可平滑升级 mDNS。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'device_nickname.dart';

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
  const PeerDevice({
    required this.ip,
    required this.name,
    required this.id,
    required this.platform,
  });

  final String ip;
  final String name;
  final String id;
  final String platform;

  factory PeerDevice.fromJson(String ip, Map<String, dynamic> json) =>
      PeerDevice(
        ip: ip,
        name: json['name'] as String? ?? '未知设备',
        id: json['id'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'platform': platform,
  };
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
  final _peersController =
      StreamController<Map<String, PeerDevice>>.broadcast();

  /// 当前已发现设备流
  Stream<Map<String, PeerDevice>> get peersStream => _peersController.stream;
  Map<String, PeerDevice> get peers => _found;

  /// 发现广播候选地址（逐网卡定向广播 + 全网广播兜底）
  ///
  /// ⚠️ 只发 255.255.255.255 在「手机开热点」场景必挂：热点接口不是手机的默认
  /// 路由，受限广播从默认网络口出去，到不了热点网段（PC 收不到请求 → 不应答 →
  /// 「PC 能搜到手机、手机搜不到 PC」的不对称）。定向广播 x.y.z.255 走直连路由，
  /// 由 OS 按路由表选对网卡（2026-09-05 修复，取代原「逐网卡发送 TODO(P3)」）。
  static Future<List<InternetAddress>> broadcastCandidates() async {
    final candidates = <String>{'255.255.255.255'};
    try {
      // NetworkInterface.list 是异步 API，必须 await（漏写编译报错实踩）
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final octets = addr.address.split('.');
          if (octets.length != 4) continue;
          // /24 定向广播简化（热点/家用 Wi-Fi 均为 /24；非常规掩码由全网广播兜底）
          candidates.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
        }
      }
    } catch (_) {
      // 网卡枚举失败仅退回全网广播
    }
    return [for (final c in candidates) InternetAddress(c)];
  }

  /// 启动监听（响应别人的发现请求）
  Future<void> startResponder({
    String name = '',
    String id = '',
    String platform = '',
  }) async {
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
          '${SyncProtocol.infoPrefix}${jsonEncode({'name': name.isEmpty ? localBroadcastName : name, 'id': id.isEmpty ? localDeviceId : id, 'platform': platform.isEmpty ? localPlatform : platform})}',
        );
        _socket!.send(info, dg.address, dg.port);
      }
    });
  }

  /// 主动扫描一轮（逐网卡定向广播 + 收集 3 秒应答）
  Future<Map<String, PeerDevice>> scan({
    Duration wait = const Duration(seconds: 3),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final packet = utf8.encode(SyncProtocol.discoverPacket);
    // 每个候选广播地址都发一份（OS 按直连路由选网卡；重复发送幂等，应答按 ip 去重）
    for (final addr in await SyncDiscovery.broadcastCandidates()) {
      socket.send(packet, addr, SyncProtocol.discoveryPort);
    }

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
        final json = jsonDecode(
          msg.substring(SyncProtocol.infoPrefix.length),
        ) as Map<String, dynamic>;
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
