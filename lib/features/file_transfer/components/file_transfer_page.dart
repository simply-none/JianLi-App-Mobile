// 文件互传页 —— 设备发现 / 选文件批量发送 / 接收（自动接收可关）/ 传输记录
//
// forui 化：FScaffold + FHeader.nested + PageBanner（粉 accent 4）+ SectionHeader + AppCard；
// 入页即 startServer + startResponder（幂等，与同步页同款 _init），并拉起接收端路由注册。
// 进度：逐文件 FDeterminateProgress；记录：收/发双色图标 + 大小 + 时间 + 状态色。
//
// 已实现的增强（2026-09-06 之后）：
//   #9  重名策略开关（rename 默认 / overwrite）
//   #11 最近设备区（持久化，离线可见）
//   #14 传输加密开关（AES-256-CTR，需双端开启）
//   #15 接收询问弹窗（关自动接收时弹出，等待用户答复）
//   #19 后台保活（发送全程 Wakelock，由 TransferClient 包裹）
//   #20 历史分页（加载更多）
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/sync/sync_discovery.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/db/app_database.dart';
import '../models/recent_peers.dart';
import '../models/transfer_models.dart';
import '../providers/file_transfer_providers.dart';
import '../repositories/transfer_repository.dart';
import '../services/transfer_client.dart';
import '../services/transfer_server.dart';

/// 文件互传页
class FileTransferPage extends ConsumerStatefulWidget {
  const FileTransferPage({super.key});

  @override
  ConsumerState<FileTransferPage> createState() => _FileTransferPageState();
}

class _FileTransferPageState extends ConsumerState<FileTransferPage> {
  final SyncDiscovery _discovery = SyncDiscovery();
  final TextEditingController _manualIp = TextEditingController();
  final Map<String, PeerDevice> _peers = {};
  bool _scanning = false;
  final List<File> _selectedFiles = [];
  final Map<String, TransferProgress> _progress = {};
  bool _sending = false;
  bool _autoAccept = kDefaultAutoAccept;
  bool _renameOverwrite = false; // #9 开关 ON = 覆盖
  bool _enc = kDefaultEnc; // #14 开关 ON = 加密
  List<RecentPeer> _recentPeers = const []; // #11
  IncomingAsk? _ask; // #15 待答复
  StreamSubscription<IncomingAsk>? _askSub;
  int _historyLimit = 30; // #20 分页
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 拉起接收端路由（幂等注册 /file/*）
    ref.read(transferServerProvider);
    // 启动数据面 + 可被发现（与同步页同款）
    final service = ref.read(syncServiceProvider);
    await service.startServer(name: localDeviceName, id: localDeviceId);
    await _discovery.startResponder(name: localDeviceName, id: localDeviceId);
    final settings = ref.read(transferSettingsProvider);
    _autoAccept = settings.autoAccept;
    _renameOverwrite = settings.renameStrategy == 'overwrite';
    _enc = settings.enc;
    _recentPeers = await RecentPeers.load(); // #11
    // #15 订阅接收询问流，弹出确认框
    _askSub = ref.read(transferServerProvider).askStream.listen((ask) {
      if (!mounted) return;
      setState(() => _ask = ask);
      _showAskDialog(ask);
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _manualIp.dispose();
    _askSub?.cancel();
    _discovery.stop();
    super.dispose();
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(
      () => _logs.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $msg',
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final found = await _discovery.scan();
    if (mounted) {
      setState(() {
        _peers
          ..clear()
          ..addAll(found);
        _scanning = false;
        _log('扫描到 ${found.length} 台设备');
      });
      // #11 持久化扫描到的对端（离线可见）
      unawaited(_persistPeers(found.values));
    }
  }

  Future<void> _persistPeers(Iterable<PeerDevice> peers) async {
    for (final p in peers) {
      await RecentPeers.remember(p);
    }
    final loaded = await RecentPeers.load();
    if (mounted) setState(() => _recentPeers = loaded);
  }

  Future<void> _pickFiles() async {
    final List<PlatformFile> result = await FilePicker.pickFiles(
      allowMultiple: true,
    );
    if (result.isEmpty) return;
    final files =
        result
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
    if (files.isNotEmpty) {
      setState(() => _selectedFiles.addAll(files));
      _log('已选择 ${_selectedFiles.length} 个文件');
    }
  }

  void _toggleAutoAccept(bool v) {
    setState(() => _autoAccept = v);
    final s = ref.read(transferSettingsProvider);
    s.autoAccept = v;
    unawaited(s.persist());
  }

  void _toggleRename(bool v) {
    setState(() => _renameOverwrite = v);
    final s = ref.read(transferSettingsProvider);
    s.renameStrategy = v ? 'overwrite' : 'rename';
    unawaited(s.persist());
  }

  void _toggleEnc(bool v) {
    setState(() => _enc = v);
    final s = ref.read(transferSettingsProvider);
    s.enc = v;
    unawaited(s.persist());
  }

  Future<void> _sendToPeer(PeerDevice peer) async {
    if (_selectedFiles.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _progress.clear();
    });
    final client = ref.read(transferClientProvider);
    final result = await client.sendBatch(
      peer: peer,
      files: List.of(_selectedFiles),
      onProgress: (p) {
        if (mounted) setState(() => _progress[p.fid] = p);
      },
    );
    if (mounted) {
      setState(() {
        _sending = false;
        _progress.clear();
      });
      if (result.ok) {
        // #11 发送成功记住对端
        await RecentPeers.remember(peer);
        setState(() => _selectedFiles.clear());
        _log(result.message);
        showFToast(context: context, title: const Text('发送完成'));
      } else {
        setState(() => _selectedFiles.clear());
        _log(result.message);
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('发送未完成'),
          description: Text(result.message),
        );
      }
    }
  }

  void _cancelSend() {
    ref.read(transferClientProvider).cancel();
    _log('已请求取消本批次');
  }

  // #15 接收询问弹窗：等待用户选择接收/拒绝
  void _showAskDialog(IncomingAsk ask) {
    unawaited(
      showFDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c, style, _) => FDialog(
          builder: (c, style) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${ask.name} 发起文件传输', style: style.titleTextStyle),
              const SizedBox(height: 8),
              Text(
                '共 ${ask.count} 个文件 / ${_formatSize(ask.total)}，是否接收？',
                style: style.bodyTextStyle,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    onPress: () {
                      ref
                          .read(transferServerProvider)
                          .answerAsk(ask.tid, false);
                      Navigator.of(c).pop();
                    },
                    child: const Text('拒绝'),
                  ),
                  FButton(
                    onPress: () {
                      ref
                          .read(transferServerProvider)
                          .answerAsk(ask.tid, true);
                      Navigator.of(c).pop();
                    },
                    child: const Text('接收'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).then((_) {
        if (mounted) setState(() => _ask = null);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final historyAsync = ref.watch(transferHistoryProvider);
    final history = historyAsync.value ?? const <FileTransferData>[];

    return FScaffold(
      header: FHeader.nested(
        title: const Text('文件互传'),
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
            PageBanner(
              icon: FLucideIcons.arrowLeftRight,
              title: '文件互传',
              subtitle: '双端批量收发，局域网直连不出内网',
              accentIndex: 4,
              stats: [
                ('${_peers.length}', '发现设备'),
                ('${history.length}', '已传文件'),
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
                          '需另一端渐离在线；模拟器填 10.0.2.2',
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
                      '暂无设备。真机：双端同 Wi-Fi 后扫描；\n模拟器：广播不通，手动填宿主 IP 10.0.2.2。',
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    )
                  else
                    for (final peer in _peers.values)
                      _PeerRow(
                        peer: peer,
                        enabled: _selectedFiles.isNotEmpty && !_sending,
                        onSend: () => _sendToPeer(peer),
                      ),
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
                          final peer = PeerDevice(
                            ip: ip,
                            name: '手动添加',
                            id: ip,
                            platform: '-',
                          );
                          setState(() => _peers[ip] = peer);
                          unawaited(RecentPeers.remember(peer));
                          _log('已添加手动设备 $ip');
                        },
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // #11 最近设备区（离线可见）
            if (_recentPeers.isNotEmpty) ...[
              const SectionHeader(title: '最近设备'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final rp in _recentPeers)
                      _RecentRow(
                        peer: rp,
                        enabled: _selectedFiles.isNotEmpty && !_sending,
                        onSend: () => _sendToPeer(rp.toPeer()),
                        onForget: () async {
                          await RecentPeers.forget(rp.ip);
                          final peers = await RecentPeers.load();
                          if (mounted) setState(() => _recentPeers = peers);
                        },
                      ),
                  ],
                ),
              ),
            ],
            // 发送区
            const SectionHeader(title: '发送文件'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已选 ${_selectedFiles.length} 个文件',
                          style: t.typography.body.sm.copyWith(
                            color: t.colors.mutedForeground,
                          ),
                        ),
                      ),
                      if (_sending)
                        FButton(
                          variant: FButtonVariant.destructive,
                          size: FButtonSizeVariant.sm,
                          onPress: _cancelSend,
                          child: const Text('取消'),
                        )
                      else
                        FButton(
                          variant: FButtonVariant.outline,
                          size: FButtonSizeVariant.sm,
                          onPress: _pickFiles,
                          prefix: const Icon(FLucideIcons.folderOpen, size: 16),
                          child: const Text('选文件'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFiles.isEmpty)
                    Text(
                      '点击下方「选文件」批量选择；在上方选设备点「发到此处」。',
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    )
                  else
                    for (final file in _selectedFiles)
                      _FileProgressTile(
                        file: file,
                        progress: _progress['${_selectedFiles.indexOf(file) + 1}'],
                      ),
                  const SizedBox(height: 12),
                  // #9 重名策略：默认自动重命名，开启则覆盖
                  FSwitch(
                    value: _renameOverwrite,
                    onChange: _toggleRename,
                    label: const Text('重名时覆盖（关闭则自动重命名）'),
                  ),
                  // #14 传输加密（需双端开启）
                  FSwitch(
                    value: _enc,
                    onChange: _toggleEnc,
                    label: const Text('传输加密（AES-256-CTR，需收发双端均开启）'),
                  ),
                  // 自动接收开关（接收端设置，供对端 offer 时判定；关闭则弹窗询问 #15）
                  FSwitch(
                    value: _autoAccept,
                    onChange: _toggleAutoAccept,
                    label: const Text('自动接收（关闭后需手动确认他人发送）'),
                  ),
                ],
              ),
            ),
            // 记录区（#20 分页）
            const SectionHeader(title: '传输记录'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (history.isEmpty)
                    Text(
                      '暂无记录',
                      style: t.typography.body.xs.copyWith(
                        color: t.colors.mutedForeground,
                      ),
                    )
                  else ...[
                    for (final row in history.take(_historyLimit))
                      _HistoryTile(row: row),
                    if (history.length > _historyLimit)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FButton(
                          variant: FButtonVariant.outline,
                          size: FButtonSizeVariant.sm,
                          onPress: () => setState(() => _historyLimit += 30),
                          child: const Text('加载更多'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_logs.isNotEmpty) ...[
              const SectionHeader(title: '日志'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in _logs.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(l, style: t.typography.body.xs),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 发现设备行
class _PeerRow extends StatelessWidget {
  const _PeerRow({
    required this.peer,
    required this.enabled,
    required this.onSend,
  });

  final PeerDevice peer;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SquircleBox(
            size: 36,
            radius: 10,
            gradient: AppTokens.accentGradient(AppTokens.accent(4)),
            alignment: Alignment.center,
            child: const Icon(
              FLucideIcons.monitorSmartphone,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
          FButton(
            size: FButtonSizeVariant.sm,
            onPress: enabled ? onSend : null,
            child: const Text('发到此处'),
          ),
        ],
      ),
    );
  }
}

/// 最近设备行（#11，含「忘记」）
class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.peer,
    required this.enabled,
    required this.onSend,
    required this.onForget,
  });

  final RecentPeer peer;
  final bool enabled;
  final VoidCallback onSend;
  final Future<void> Function() onForget;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SquircleBox(
            size: 36,
            radius: 10,
            gradient: AppTokens.accentGradient(AppTokens.accent(5)),
            alignment: Alignment.center,
            child: const Icon(
              FLucideIcons.history,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  '${peer.ip} · ${_formatAgo(peer.lastSeen)}',
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          FButton(
            size: FButtonSizeVariant.sm,
            onPress: enabled ? onSend : null,
            child: const Text('发到此处'),
          ),
          FButton(
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.sm,
            onPress: () => unawaited(onForget()),
            child: const Text('忘记'),
          ),
        ],
      ),
    );
  }
}

/// 发送中单文件进度行
class _FileProgressTile extends StatelessWidget {
  const _FileProgressTile({required this.file, this.progress});

  final File file;
  final TransferProgress? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final name = file.path.split(RegExp(r'[/\\]')).last;
    final ratio = progress?.ratio ?? 0.0;
    final phase = progress?.phase ?? '';
    final label =
        phase == 'done'
            ? '完成'
            : phase == 'failed'
            ? '失败'
            : phase == 'data'
            ? '${(ratio * 100).toInt()}%'
            : '等待';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: t.typography.body.sm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                label,
                style: t.typography.body.xs.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FDeterminateProgress(value: ratio),
        ],
      ),
    );
  }
}

/// 历史记录行
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row});

  final FileTransferData row;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final isSend = row.direction == 'send';
    final color =
        row.status == 'failed'
            ? t.colors.destructive
            : row.status == 'canceled'
            ? t.colors.mutedForeground
            : AppTokens.accent(isSend ? 4 : 5);
    final statusText =
        row.status == 'done'
            ? '完成'
            : row.status == 'failed'
            ? '失败'
            : '已取消';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SquircleBox(
            size: 36,
            radius: 10,
            gradient: AppTokens.accentGradient(color),
            alignment: Alignment.center,
            child: Icon(
              isSend ? FLucideIcons.upload : FLucideIcons.download,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.fileName ?? '未命名',
                  style: t.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${isSend ? '发往' : '来自'} ${row.peerName ?? row.peerIp ?? '-'} · '
                  '${_formatSize(row.size ?? 0)} · ${row.createdAt ?? ''}',
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                ),
                if (row.error != null && row.error!.isNotEmpty)
                  Text(
                    row.error!,
                    style: t.typography.body.xs.copyWith(
                      color: t.colors.destructive,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusText,
                style: t.typography.body.xs.copyWith(color: color),
              ),
              if (row.status == 'done' && (row.path ?? '').isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FButton(
                      variant: FButtonVariant.ghost,
                      size: FButtonSizeVariant.sm,
                      onPress: () => _open(context, row.path!),
                      prefix: const Icon(FLucideIcons.folderOpen, size: 14),
                      child: const Text('打开'),
                    ),
                    FButton(
                      variant: FButtonVariant.ghost,
                      size: FButtonSizeVariant.sm,
                      onPress: () => _share(row.path!),
                      prefix: const Icon(FLucideIcons.share2, size: 14),
                      child: const Text('分享'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String path) async {
    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && context.mounted) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('无法打开'),
        description: Text(res.message),
      );
    }
  }

  Future<void> _share(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: '来自渐离文件互传'),
    );
  }
}

/// 字节数格式化
String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// 相对时间（最近设备「上次」）
String _formatAgo(int ms) {
  if (ms <= 0) return '未知';
  final diff = DateTime.now().millisecondsSinceEpoch - ms;
  if (diff < 60 * 1000) return '刚刚';
  if (diff < 60 * 60 * 1000) return '${(diff / 60000).floor()} 分钟前';
  if (diff < 24 * 60 * 60 * 1000) return '${(diff / 3600000).floor()} 小时前';
  return '${(diff / 86400000).floor()} 天前';
}
