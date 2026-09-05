// 局域网同步页 —— 扫描设备 / 选择表 / 发送；接收端随 App 启动常驻
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui/ui_atoms.dart';
import '../../../core/sync/sync_discovery.dart';
import '../../../core/sync/sync_service.dart';

/// 同步页
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final SyncDiscovery _discovery = SyncDiscovery();
  final TextEditingController _manualIp = TextEditingController();
  final Map<String, bool> _selectedTable = {
    for (final t in kSyncableTables) t: true,
  };
  bool _scanning = false;
  Map<String, PeerDevice> _peers = const {};
  final List<String> _logs = [];


  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 启动接收端 + 可被发现（带上本机名，对端设备列表才能显示可读名字）
    final service = ref.read(syncServiceProvider);
    await service.startServer(name: localDeviceName, id: localDeviceId);
    await _discovery.startResponder(name: localDeviceName, id: localDeviceId);
  }

  @override
  void dispose() {
    _manualIp.dispose();
    _discovery.stop();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final found = await _discovery.scan();
    if (mounted) {
      setState(() {
        _peers = found;
        _scanning = false;
        _log('扫描到 ${found.length} 台设备');
      });
    }
  }

  void _log(String msg) {
    setState(() => _logs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}  $msg'));
  }

  Future<void> _send(PeerDevice peer) async {
    final service = ref.read(syncServiceProvider);
    final tables = _selectedTable.entries.where((e) => e.value).map((e) => e.key);
    for (final table in tables) {
      final result = await service.sendTable(peer, table);
      _log(result.message);
    }
  }

  /// 从对端拉取选中的表（PC → 手机方向）
  Future<void> _fetch(PeerDevice peer) async {
    final service = ref.read(syncServiceProvider);
    final tables = _selectedTable.entries.where((e) => e.value).map((e) => e.key);
    for (final table in tables) {
      final result = await service.fetchTable(peer, table);
      _log(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('局域网同步')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 设备区
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('发现设备（需 PC 端渐离在线）',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    TextButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.radar, size: 18),
                      label: const Text('扫描'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_peers.isEmpty)
                  Text(
                    '暂无设备。真机：PC 与手机连同一 Wi-Fi 后扫描；\n模拟器：广播不通，直接手动填宿主 IP 10.0.2.2。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                  )
                else
                  for (final peer in _peers.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.devices),
                      title: Text('${peer.name} (${peer.platform})'),
                      subtitle: Text(peer.ip),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _fetch(peer),
                            child: const Text('拉取'),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: () => _send(peer),
                            child: const Text('发送'),
                          ),
                        ],
                      ),
                    ),
                // 手动添加设备（模拟器 NAT 场景广播不可达，直接填宿主 IP）
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualIp,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '手动填 IP（模拟器填 10.0.2.2）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        final ip = _manualIp.text.trim();
                        if (ip.isEmpty) return;
                        setState(() {
                          _peers = {
                            ..._peers,
                            ip: PeerDevice(
                                ip: ip, name: '手动添加', id: ip, platform: '-')
                          };
                        });
                        _log('已添加手动设备 $ip');
                      },
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 表选择
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择要同步的表', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 6,
                  runSpacing: -8,
                  children: [
                    for (final t in kSyncableTables)
                      FilterChip(
                        label: Text(t),
                        selected: _selectedTable[t] ?? false,
                        onSelected: (v) => setState(() => _selectedTable[t] = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // 日志
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('同步日志', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                if (_logs.isEmpty)
                  Text('暂无记录', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline))
                else
                  for (final l in _logs.take(10))
                    Text(l, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
