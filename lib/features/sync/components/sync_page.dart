// 局域网同步页 —— 扫描设备 / 选择表 / 发送；接收端随 App 启动常驻
//
// forui 化改造说明：
// - 骨架改为 FScaffold + FHeader.nested（返回键）；
// - 扫描按钮 / 设备行的拉取与发送 / 手动添加 → FButton（含 sm 尺寸与禁用态）；
// - 手动 IP 输入 → FTextField；表选择 FilterChip → FCheckbox；
// - 取色/字体全部走 forui token（mutedForeground 辅助文案）；
// - 扫描/推送/拉取/手动加设备业务逻辑与原来完全一致（日志仍走本地 _log）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/squircle_box.dart';
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
    setState(
      () => _logs.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $msg',
      ),
    );
  }

  /// 向对端推送选中的表（手机 → PC 方向）
  Future<void> _send(PeerDevice peer) async {
    final service = ref.read(syncServiceProvider);
    final tables = _selectedTable.entries
        .where((e) => e.value)
        .map((e) => e.key);
    for (final table in tables) {
      final result = await service.sendTable(peer, table);
      _log(result.message);
    }
  }

  /// 从对端拉取选中的表（PC → 手机方向）
  Future<void> _fetch(PeerDevice peer) async {
    final service = ref.read(syncServiceProvider);
    final tables = _selectedTable.entries
        .where((e) => e.value)
        .map((e) => e.key);
    for (final table in tables) {
      final result = await service.fetchTable(peer, table);
      _log(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('局域网同步'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: ListView(
          padding: EdgeInsets.only(
            top: AppTokens.listTopGapOf(context),
            bottom: AppTokens.pageBottomGapOf(context),
          ),
          children: [
            // 页面专属青渐变横幅（与工具分组页「同步」入口色对齐）
            PageBanner(
              icon: FLucideIcons.refreshCw,
              title: '局域网同步',
              subtitle: '类 LocalSend 双端直连，数据不出内网',
              accentIndex: 5,
              stats: [
                ('${_peers.length}', '发现设备'),
                ('${kSyncableTables.length}', '可同步表'),
              ],
            ),
            // 设备区
            const SectionHeader(title: '发现设备'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '需 PC 端渐离在线',
                          style: t.typography.body.sm.copyWith(
                            color: t.colors.mutedForeground,
                          ),
                        ),
                      ),
                      FButton(
                        variant: FButtonVariant.outline,
                        size: FButtonSizeVariant.sm,
                        onPress: _scanning ? null : _scan,
                        prefix: _scanning
                            // 扫描中的小尺寸加载指示
                            ? const FCircularProgress(
                                size: FCircularProgressSizeVariant.xs,
                              )
                            : const Icon(FLucideIcons.radar, size: 16),
                        child: const Text('扫描'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_peers.isEmpty)
                    Text(
                      '暂无设备。真机：PC 与手机连同一 Wi-Fi 后扫描；\n模拟器：广播不通，直接手动填宿主 IP 10.0.2.2。',
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    )
                  else
                    // 发现的设备行：两行布局——名称/平台 + IP 独占一行，
                    // 拉取/发送按钮第二行右对齐，窄屏下设备名不再被按钮挤压截断
                    for (final peer in _peers.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                SquircleBox(
                                  size: 36,
                                  radius: 10,
                                  gradient: AppTokens.accentGradient(
                                    AppTokens.accent(5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    FLucideIcons.monitorSmartphone,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${peer.name} (${peer.platform})',
                                        style: t.typography.body.sm.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        peer.ip,
                                        style: t.typography.body.xs.copyWith(
                                          color: t.colors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 操作行：右对齐，不与设备名争宽度
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FButton(
                                  variant: FButtonVariant.outline,
                                  size: FButtonSizeVariant.sm,
                                  onPress: () => _fetch(peer),
                                  child: const Text('拉取'),
                                ),
                                const SizedBox(width: 6),
                                FButton(
                                  size: FButtonSizeVariant.sm,
                                  onPress: () => _send(peer),
                                  child: const Text('发送'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  // 手动添加设备（模拟器 NAT 场景广播不可达，直接填宿主 IP）
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FTextField(
                          control: FTextFieldControl.managed(
                            controller: _manualIp,
                          ),
                          hint: '手动填 IP（模拟器填 10.0.2.2）',
                          keyboardType: TextInputType.number,
                          size: FTextFieldSizeVariant.sm,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FButton(
                        variant: FButtonVariant.outline,
                        onPress: () {
                          final ip = _manualIp.text.trim();
                          if (ip.isEmpty) return;
                          setState(() {
                            _peers = {
                              ..._peers,
                              ip: PeerDevice(
                                ip: ip,
                                name: '手动添加',
                                id: ip,
                                platform: '-',
                              ),
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
            const SectionHeader(title: '选择要同步的表'),
            AppCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final table in kSyncableTables)
                    FCheckbox(
                      value: _selectedTable[table] ?? false,
                      label: Text(table, style: t.typography.body.sm),
                      onChange: (v) =>
                          setState(() => _selectedTable[table] = v),
                    ),
                ],
              ),
            ),
            // 日志
            const SectionHeader(title: '同步日志'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_logs.isEmpty)
                    Text(
                      '暂无记录',
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    )
                  else
                    for (final l in _logs.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(l, style: t.typography.body.xs),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
