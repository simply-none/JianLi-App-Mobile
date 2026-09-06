// 文件互传 · 最近设备持久化（shared_preferences；离线也能显示，#11）
//
// 与 PC 端 transferModule.ts 的 RecentPeer 同构：扫描到/发送过的对端写入本地，
// 下次进入即使局域网未扫到也展示「最近设备」，点按即可重发。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/sync_discovery.dart';

/// 一个最近对端（持久化单元）
class RecentPeer {
  const RecentPeer({
    required this.ip,
    required this.name,
    required this.id,
    required this.platform,
    required this.lastSeen,
  });

  final String ip;
  final String name;
  final String id;
  final String platform;
  final int lastSeen; // epoch ms

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'name': name,
        'id': id,
        'platform': platform,
        'lastSeen': lastSeen,
      };

  factory RecentPeer.fromJson(Map<String, dynamic> j) => RecentPeer(
        ip: j['ip'] as String? ?? '',
        name: j['name'] as String? ?? '未知设备',
        id: j['id'] as String? ?? '',
        platform: j['platform'] as String? ?? '',
        lastSeen: (j['lastSeen'] as num?)?.toInt() ?? 0,
      );

  PeerDevice toPeer() =>
      PeerDevice(ip: ip, name: name, id: id, platform: platform);
}

/// 最近设备读写（shared_preferences 单键 JSON 列表，最多保留 20 条）
class RecentPeers {
  RecentPeers._();

  static const _key = 'transfer_recent_peers';
  static const _max = 20;

  static Future<List<RecentPeer>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RecentPeer.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 记住一个对端：已存在的同 IP 移到队首，更新 lastSeen，超量截断
  static Future<void> remember(PeerDevice p) async {
    final list = await load();
    list.removeWhere((e) => e.ip == p.ip);
    list.insert(
      0,
      RecentPeer(
        ip: p.ip,
        name: p.name,
        id: p.id,
        platform: p.platform,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final trimmed = list.take(_max).toList();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> forget(String ip) async {
    final list = await load();
    list.removeWhere((e) => e.ip == ip);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }
}
