// P3-3 遥控 PC —— 页面（工具分组入口 /remote）
//
// 结构：目标设备卡（扫描局域网 / 手动 IP / 已保存设备选择 + 配对状态）→
//       命令网格 2 列（演示翻页×2 + 黑屏 + 锁屏[长按确认] + 媒体×4 + 音量×3）。
// 通信走 RemoteService（47124 数据面 /remote/*，4 位配对码换 token，命令白名单在 PC 端）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/di/app_providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/ui/sheet_form.dart';
import '../../app/ui/sheet_surface.dart' show SheetSize;
import '../../core/sync/sync_discovery.dart';
import 'remote_service.dart';

/// 遥控命令元组：cmd / 图标 / 标签（锁屏特殊：长按确认）
const _commands = <(String, IconData, String)>[
  ('page-prev', FLucideIcons.chevronUp, '上一页'),
  ('page-next', FLucideIcons.chevronDown, '下一页'),
  ('screen-black', FLucideIcons.monitor, '黑屏'),
  ('lock', FLucideIcons.lockKeyhole, '锁屏'),
  ('media-play', FLucideIcons.play, '播放/暂停'),
  ('vol-mute', FLucideIcons.volumeX, '静音'),
  ('media-prev', FLucideIcons.skipBack, '上一首'),
  ('media-next', FLucideIcons.skipForward, '下一首'),
  ('vol-up', FLucideIcons.volume2, '音量 +'),
  ('vol-down', FLucideIcons.volume1, '音量 −'),
];

class RemotePage extends ConsumerStatefulWidget {
  const RemotePage({super.key});

  @override
  ConsumerState<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends ConsumerState<RemotePage> {
  late final RemoteService _service =
      RemoteService(ref.read(appDatabaseProvider));

  List<RemoteTarget> _targets = [];
  RemoteTarget? _current;
  bool _scanning = false;
  String? _pendingCmd; // 防连点：正在执行的命令

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    final targets = await _service.loadTargets();
    if (!mounted) return;
    setState(() {
      _targets = targets;
      _current = _current ?? (targets.isEmpty ? null : targets.first);
    });
  }

  Future<void> _saveTarget(RemoteTarget t) async {
    final next = [
      t,
      ..._targets.where((e) => e.ip != t.ip),
    ];
    await _service.saveTargets(next);
    if (!mounted) return;
    setState(() {
      _targets = next;
      _current = t;
    });
  }

  // ---------- 设备发现 ----------

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final peers = await SyncDiscovery().scan();
      if (!mounted) return;
      // 只列 PC（deviceInfo.platform = 'win32-electron'；手动 IP 兜底不在扫描路径）
      final pcs = peers.values
          .where((p) => p.platform.contains('electron'))
          .toList();
      if (pcs.isEmpty) {
        showFToast(
          context: context,
          title: const Text('未发现 PC'),
          description: const Text('请确认 PC 端渐离App 已打开并在同一局域网'),
        );
        return;
      }
      await _pickFromScan(pcs);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickFromScan(List<PeerDevice> pcs) {
    final t = context.theme;
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '选择 PC',
        size: SheetSize.sm,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in pcs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FTappable(
                  onPress: () {
                    Navigator.pop(c);
                    _saveTarget(RemoteTarget(ip: p.ip, name: p.name));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.colors.muted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(FLucideIcons.monitor,
                            size: 18, color: t.colors.foreground),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p.name}（${p.ip}）',
                            overflow: TextOverflow.ellipsis,
                            style: t.typography.body.sm.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 手动输入 IP（md 输入抽屉）
  Future<void> _addManualIp() {
    final controller = TextEditingController();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: true, // 含输入框 → 抽屉抬到键盘上方
      builder: (c) => SheetScaffold(
        title: '手动添加 PC',
        size: SheetSize.md,
        body: SheetInputBox(
          controller: controller,
          hintText: '例如 192.168.1.100',
        ),
        bottomBar: [
          Expanded(
            child: SheetActionButton(
              label: '添加',
              onTap: () {
                final ip = controller.text.trim();
                if (ip.isEmpty) return;
                Navigator.pop(c);
                _saveTarget(RemoteTarget(ip: ip, name: ip));
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 配对 ----------

  bool? _pairedCached; // 当前目标是否已配对（进页/切换时算一次）

  Future<void> _refreshPaired() async {
    final current = _current;
    if (current == null) return;
    final token = await _service.loadToken(current.ip);
    if (!mounted) return;
    setState(() => _pairedCached = token != null);
  }

  Future<void> _startPairing() async {
    final current = _current;
    if (current == null) return;
    final r1 = await _service.requestPair(current.ip);
    if (!mounted) return;
    if (!r1.ok) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('配对失败'),
        description: Text(r1.error ?? 'PC 未响应（确认渐离App 已打开）'),
      );
      return;
    }
    await _inputPairCode();
  }

  Future<void> _inputPairCode() {
    final t = context.theme;
    final controller = TextEditingController();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: true,
      builder: (c) => SheetScaffold(
        title: '输入配对码',
        size: SheetSize.md,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PC 屏幕上已弹出 4 位配对码（10 分钟内有效），输入后点确认完成配对。',
              style: t.typography.body.sm.copyWith(
                color: t.colors.mutedForeground,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SheetInputBox(
              controller: controller,
              hintText: '4 位数字',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        bottomBar: [
          Expanded(
            child: SheetActionButton(
              label: '确认配对',
              onTap: () async {
                final code = controller.text.trim();
                Navigator.pop(c);
                if (code.length != 4) {
                  if (!mounted) return;
                  showFToast(
                    context: context,
                    title: const Text('请输入 4 位配对码'),
                  );
                  return;
                }
                final r = await _service.confirmPair(_current!.ip, code);
                if (!mounted) return;
                showFToast(
                  context: context,
                  title: Text(r.ok ? '配对成功' : '配对失败'),
                  description: r.ok ? null : Text(r.error ?? ''),
                );
                await _refreshPaired();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 命令 ----------

  Future<void> _send(String cmd) async {
    final current = _current;
    if (current == null) {
      showFToast(
        context: context,
        title: const Text('请先选择 PC'),
        description: const Text('扫描局域网或手动输入 IP'),
      );
      return;
    }
    if (_pendingCmd != null) return;
    setState(() => _pendingCmd = cmd);
    final r = await _service.sendCmd(current.ip, cmd);
    if (!mounted) return;
    setState(() => _pendingCmd = null);
    if (r.unpaired) {
      showFToast(
        context: context,
        title: const Text('需要重新配对'),
        description: Text(r.error ?? 'token 已失效'),
      );
      await _refreshPaired();
      return;
    }
    if (!r.ok) {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('执行失败'),
        description: Text(r.error ?? ''),
      );
    }
  }

  Future<void> _lockWithConfirm() async {
    final ok = await showSheetConfirm(
      context,
      title: '锁定 PC',
      message: '确定要锁定当前电脑吗？',
      confirmLabel: '锁屏',
    );
    if (ok) await _send('lock');
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final current = _current;
    final paired = _pairedCached;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('遥控 PC'),
        prefixes: [
          FHeaderAction(
            icon: Icon(FLucideIcons.chevronLeft),
            onPress: () => context.pop(),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // —— 目标设备卡 ——
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.colors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: t.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        FLucideIcons.monitorSpeaker,
                        size: 20,
                        color: current != null
                            ? t.colors.primary
                            : t.colors.mutedForeground,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          current == null
                              ? '未选择设备'
                              : '${current.name} · ${current.ip}',
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.body.sm.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (current != null && paired != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          paired
                              ? FLucideIcons.circleCheck
                              : FLucideIcons.circleAlert,
                          size: 14,
                          color: paired
                              ? t.colors.primary
                              : t.colors.destructive,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          paired ? '已配对' : '未配对（点下方按钮开始）',
                          style: t.typography.body.xs.copyWith(
                            color: paired
                                ? t.colors.primary
                                : t.colors.destructive,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _actionChip(
                          context,
                          icon: FLucideIcons.scanLine,
                          label: _scanning ? '扫描中…' : '扫描局域网',
                          onTap: _scan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionChip(
                          context,
                          icon: FLucideIcons.plus,
                          label: '手动 IP',
                          onTap: _addManualIp,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionChip(
                          context,
                          icon: FLucideIcons.fingerprint,
                          label: '配对',
                          onTap: current == null ? null : _startPairing,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '命令',
              style: t.typography.body.sm.copyWith(
                color: t.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            // —— 命令网格（2 列；锁屏长按确认） ——
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (cmd, icon, label) in _commands)
                  _cmdTile(context, cmd, icon, label),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '翻页/黑屏作用于 PC 当前前台窗口（演示/阅读器通用）；'
              '媒体键依赖系统的媒体会话；「锁屏」需长按确认。',
              style: t.typography.body.xs.copyWith(
                color: t.colors.mutedForeground,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final t = context.theme;
    final enabled = onTap != null;
    return FTappable(
      onPress: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color:
                  enabled ? t.colors.foreground : t.colors.mutedForeground,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.xs.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? t.colors.foreground
                      : t.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cmdTile(
    BuildContext context,
    String cmd,
    IconData icon,
    String label,
  ) {
    final t = context.theme;
    final isLock = cmd == 'lock';
    final busy = _pendingCmd == cmd;
    final tile = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLock ? t.colors.destructive.withValues(alpha: 0.08) : t.colors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: isLock
              ? t.colors.destructive.withValues(alpha: 0.35)
              : t.colors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: isLock ? t.colors.destructive : t.colors.foreground,
          ),
          const SizedBox(width: 8),
          Text(
            busy ? '执行中…' : (isLock ? '锁屏（长按）' : label),
            style: t.typography.body.sm.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isLock ? t.colors.destructive : t.colors.foreground,
            ),
          ),
        ],
      ),
    );
    if (isLock) {
      return GestureDetector(
        onLongPress: _lockWithConfirm,
        child: tile,
      );
    }
    return FTappable(onPress: () => _send(cmd), child: tile);
  }
}
