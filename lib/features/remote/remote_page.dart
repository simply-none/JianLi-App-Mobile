// P3-3 遥控 PC —— 页面（工具分组入口 /remote）
//
// 结构（2026-09-22 改版 · 画布方案 C）：
//   PageBanner（琥珀 accentIndex=3，与 Hub「遥控 PC」入口同色）
//   → 设备连接卡（accentGradient 图标盘 + 设备名/IP + 配对状态胶囊 + 扫描/手动IP/配对）
//   → 遥控面板 = 媒体卡（上一首 · 播放暂停大圆钮 · 下一首）
//              + 2×2 大键（上一页 / 下一页 / 黑屏 / 白屏）
//              + 一行 4 小键（音量− / 音量+ / 静音 / 长按锁屏）
//              + 「更多命令」入口（8 项：结束放映 / 显示桌面 / 切换窗口 / 关闭窗口 /
//                关闭显示器 / 方向键 / 发送文本到 PC / 打开网址）
//   → 底部说明。
// 通信走 RemoteService（47124 数据面 /remote/*，4 位配对码换 token，命令白名单在 PC 端
// electron/main/module/remoteControl.ts，白名单外一律 400；`clipboard-text` / `open-url`
// 经 body.arg 传参）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/di/app_providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/ui/page_banner.dart';
import '../../app/ui/sheet_form.dart';
import '../../app/ui/sheet_surface.dart' show SheetSize;
import '../../app/ui/tap_scale.dart';
import '../../core/sync/sync_discovery.dart';
import 'remote_service.dart';

/// 遥控 PC 页专属强调色（AppTokens.accents[3] 琥珀，与 Hub 入口 accentIndex 对齐）
const int _kAccentIndex = 3;

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
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusSm),
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

  Future<void> _send(String cmd, {String? arg}) async {
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
    final r = await _service.sendCmd(current.ip, cmd, arg: arg);
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
    if (!mounted) return;
    if (ok) await _send('lock');
  }

  /// 关闭窗口（Alt+F4）——可能触发未保存提示，二次确认后执行
  Future<void> _closeWindowWithConfirm() async {
    final ok = await showSheetConfirm(
      context,
      title: '关闭窗口',
      message: '确定要关闭 PC 当前前台窗口吗？未保存的内容可能丢失。',
      confirmLabel: '关闭窗口',
    );
    if (!mounted) return;
    if (ok) await _send('alt-f4');
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final current = _current;
    final paired = _pairedCached;
    return FScaffold(
      childPad: false,
      // 间距对齐 note_slip_page（小纸条）：自绘头部（16/12/12）+ banner margin 0，
      // 不走 FScaffold.header —— FHeader.nested 自带内边距会与 banner 叠出顶部空隙
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  // PageBanner 自带水平 pagePadding，列表不再叠一层
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                  children: [
                    PageBanner(
                      icon: FLucideIcons.monitorSpeaker,
                      title: '遥控 PC',
                      subtitle: '局域网直连 · 无需登录',
                      accentIndex: _kAccentIndex,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.pagePadding),
                      child: _deviceCard(context, current, paired),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.pagePadding),
                      child: _commandPanel(context),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.pagePadding),
                      child: Text(
                        '翻页/黑屏/白屏作用于 PC 当前前台窗口（演示/阅读器通用）；'
                        '媒体键依赖系统的媒体会话；「锁屏」「关闭窗口」需确认；'
                        '更多命令见「更多命令」抽屉。',
                        style: t.typography.body.xs.copyWith(
                          color: t.colors.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部（对齐小纸条/倒计时：‹ 22 + 标题 18 Bold，上下 12）
  Widget _header(BuildContext context) {
    final t = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        spacing: 10,
        children: [
          TapScale(
            onTap: () => context.pop(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 22,
              color: t.colors.foreground,
            ),
          ),
          Expanded(
            child: Text(
              '遥控 PC',
              style: t.typography.body.lg.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // —— 设备连接卡 ——

  Widget _deviceCard(
    BuildContext context,
    RemoteTarget? current,
    bool? paired,
  ) {
    final t = context.theme;
    final accent = AppTokens.accent(_kAccentIndex);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: t.colors.border),
        boxShadow: AppTokens.elevation(context, level: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTokens.accentGradient(accent),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(FLucideIcons.monitorSpeaker,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current == null ? '未选择设备' : current.name,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.body.sm.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current == null ? '扫描局域网或手动输入 IP' : current.ip,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.body.xs.copyWith(
                        fontSize: 11,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (current != null && paired != null)
                _statusPill(context, paired),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: t.colors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _opChip(
                  context,
                  icon: FLucideIcons.scanLine,
                  label: _scanning ? '扫描中…' : '扫描局域网',
                  onTap: _scan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _opChip(
                  context,
                  icon: FLucideIcons.plus,
                  label: '手动 IP',
                  onTap: _addManualIp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _opChip(
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
    );
  }

  /// 配对状态胶囊：已配对绿（accent 2）/ 未配对琥珀（accent 3）
  Widget _statusPill(BuildContext context, bool paired) {
    final t = context.theme;
    final color = paired ? AppTokens.accent(2) : AppTokens.accent(_kAccentIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTokens.soft(context, color),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paired ? FLucideIcons.circleCheck : FLucideIcons.circleAlert,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            paired ? '已配对' : '未配对',
            style: t.typography.body.xs.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _opChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final t = context.theme;
    final enabled = onTap != null;
    final accent = AppTokens.accent(_kAccentIndex);
    return FTappable(
      onPress: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? AppTokens.accentSoft(context, accent)
              : t.colors.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled ? accent : t.colors.mutedForeground,
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
                  color: enabled ? t.colors.foreground : t.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —— 遥控面板（方案 C）——

  Widget _commandPanel(BuildContext context) {
    final t = context.theme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: t.colors.border),
        boxShadow: AppTokens.elevation(context, level: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _mediaCard(context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bigKey(context, 'page-prev',
                    FLucideIcons.chevronUp, '上一页'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigKey(context, 'page-next',
                    FLucideIcons.chevronDown, '下一页'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _bigKey(
                    context, 'screen-black', FLucideIcons.monitorOff, '黑屏'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    _bigKey(context, 'screen-white', FLucideIcons.sun, '白屏'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallKey(
                    context, 'vol-down', FLucideIcons.volume1, '音量 −'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallKey(
                    context, 'vol-up', FLucideIcons.volume2, '音量 +'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallKey(
                    context, 'vol-mute', FLucideIcons.volumeX, '静音'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallKey(
                    context, 'lock', FLucideIcons.lockKeyhole, '长按锁屏'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _moreBar(context),
        ],
      ),
    );
  }

  /// 媒体卡：琥珀软底 + 上一首 / 播放暂停大圆钮 / 下一首
  Widget _mediaCard(BuildContext context) {
    final t = context.theme;
    final accent = AppTokens.accent(_kAccentIndex);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppTokens.accentSoft(context, accent),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PC 媒体',
            style: t.typography.body.xs.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              // 主色压暗一档（同 accentGradient 的 lerp 口径），保证浅底上可读
              color: Color.lerp(accent, Colors.black, 0.3),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundKey(context, 'media-prev', FLucideIcons.skipBack, 44),
              const SizedBox(width: 28),
              _roundKey(
                context,
                'media-play',
                FLucideIcons.play,
                56,
                filled: true,
              ),
              const SizedBox(width: 28),
              _roundKey(context, 'media-next', FLucideIcons.skipForward, 44),
            ],
          ),
        ],
      ),
    );
  }

  /// 圆形媒体键：[filled] = 播放/暂停（主色渐变实心 + 投影），其余白底描边
  Widget _roundKey(
    BuildContext context,
    String cmd,
    IconData icon,
    double size, {
    bool filled = false,
  }) {
    final t = context.theme;
    final accent = AppTokens.accent(_kAccentIndex);
    final busy = _pendingCmd == cmd;
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: FTappable(
        onPress: () => _send(cmd),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: filled ? AppTokens.accentGradient(accent) : null,
            color: filled ? null : t.colors.card,
            shape: BoxShape.circle,
            border: filled ? null : Border.all(color: t.colors.border),
            boxShadow: filled ? AppTokens.elevation(context, level: 2) : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: size * 0.4,
            color: filled ? Colors.white : t.colors.foreground,
          ),
        ),
      ),
    );
  }

  /// 2×2 大键（161×64 观感）：accentSoft 图标盘 + 标签
  Widget _bigKey(BuildContext context, String cmd, IconData icon, String label) {
    final t = context.theme;
    final accent = AppTokens.accent(_kAccentIndex);
    final busy = _pendingCmd == cmd;
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: FTappable(
        onPress: () => _send(cmd),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.colors.muted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTokens.accentSoft(context, accent),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一行 4 小键（h60）：图标盘上、标签下；锁屏 = 红软底 + 长按确认，静音 = 中性
  Widget _smallKey(
    BuildContext context,
    String cmd,
    IconData icon,
    String label,
  ) {
    final t = context.theme;
    final isLock = cmd == 'lock';
    final isMute = cmd == 'vol-mute';
    final accent = AppTokens.accent(_kAccentIndex);
    final iconColor = isLock
        ? t.colors.destructive
        : isMute
            ? t.colors.mutedForeground
            : accent;
    final plate = isLock
        ? t.colors.destructive.withValues(alpha: 0.12)
        : isMute
            ? t.colors.mutedForeground.withValues(alpha: 0.12)
            : AppTokens.accentSoft(context, accent);
    final busy = _pendingCmd == cmd;
    final key = Container(
      height: 60,
      // 上下 6：28 图标盘 + 4 间距 + 12 文字(height 1.2) = 44，须 ≤ 60-2*6，否则溢出
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: t.colors.muted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: plate,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typography.body.xs.copyWith(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: isLock ? t.colors.destructive : t.colors.foreground,
            ),
          ),
        ],
      ),
    );
    if (isLock) {
      // 危险动作：仅长按触发（复用危险确认抽屉）
      return GestureDetector(onLongPress: _lockWithConfirm, child: key);
    }
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: FTappable(onPress: () => _send(cmd), child: key),
    );
  }

  /// 「更多命令」入口条
  Widget _moreBar(BuildContext context) {
    final t = context.theme;
    return FTappable(
      onPress: _openMoreSheet,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          children: [
            Text(
              '更多命令',
              style: t.typography.body.sm.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '8 项',
              style: t.typography.body.xs.copyWith(
                fontSize: 11,
                color: t.colors.mutedForeground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(FLucideIcons.chevronRight,
                size: 14, color: t.colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  // —— 更多命令抽屉（第二批命令，2 列 × 4 行） ——

  Future<void> _openMoreSheet() {
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '更多命令',
        size: SheetSize.md,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _drawerTile(
                      c, 'presentation-end', FLucideIcons.square, '结束放映'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drawerTile(c, 'show-desktop',
                      FLucideIcons.layoutGrid, '显示桌面'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _drawerTile(
                      c, 'alt-tab', FLucideIcons.copy, '切换窗口'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drawerTile(
                      c, 'alt-f4', FLucideIcons.x, '关闭窗口'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _drawerTile(
                      c, 'monitor-off', FLucideIcons.power, '关闭显示器'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drawerTile(c, 'dpad', FLucideIcons.move, '方向键'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _drawerTile(c, 'clipboard-text',
                      FLucideIcons.clipboard, '发送文本到 PC'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drawerTile(
                      c, 'open-url', FLucideIcons.link, '打开网址'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext sheetContext,
    String cmd,
    IconData icon,
    String label,
  ) {
    final t = context.theme;
    final accent = AppTokens.accent(_kAccentIndex);
    final isClose = cmd == 'alt-f4';
    final iconColor = isClose ? t.colors.destructive : accent;
    return FTappable(
      onPress: () => _onDrawerTap(sheetContext, cmd),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isClose
                    ? t.colors.destructive.withValues(alpha: 0.12)
                    : AppTokens.accentSoft(context, accent),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.sm.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDrawerTap(BuildContext sheetContext, String cmd) {
    Navigator.pop(sheetContext);
    switch (cmd) {
      case 'dpad':
        _openDpadSheet();
      case 'clipboard-text':
        _sendTextSheet();
      case 'open-url':
        _sendUrlSheet();
      case 'alt-f4':
        _closeWindowWithConfirm();
      default:
        _send(cmd);
    }
  }

  /// 方向键（sm 抽屉：上 / 左·下·右）
  Future<void> _openDpadSheet() {
    final t = context.theme;
    Widget pad(String cmd, IconData icon) => FTappable(
          onPress: () => _send(cmd),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: t.colors.muted,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: t.colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: t.colors.foreground),
          ),
        );
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '方向键',
        size: SheetSize.sm,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                SizedBox(width: 120, child: pad('key-up', FLucideIcons.chevronUp)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: pad('key-left', FLucideIcons.chevronLeft)),
                const SizedBox(width: 10),
                Expanded(child: pad('key-down', FLucideIcons.chevronDown)),
                const SizedBox(width: 10),
                Expanded(child: pad('key-right', FLucideIcons.chevronRight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 发送文本到 PC（写入 PC 剪贴板，PC 上 Ctrl+V 粘贴）
  Future<void> _sendTextSheet() {
    final t = context.theme;
    final controller = TextEditingController();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: true,
      builder: (c) => SheetScaffold(
        title: '发送文本到 PC',
        size: SheetSize.md,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '文本会写入 PC 剪贴板（上限 3000 字），在电脑上 Ctrl+V 即可粘贴。',
              style: t.typography.body.sm.copyWith(
                fontSize: 13,
                color: t.colors.mutedForeground,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SheetMultilineBox(
              controller: controller,
              hintText: '要发送的文本…',
              minLines: 4,
            ),
          ],
        ),
        bottomBar: sheetBottomActions(
          c,
          actionLabel: '发送到 PC',
          actionIcon: FLucideIcons.clipboard,
          onAction: () {
            final text = controller.text;
            Navigator.pop(c);
            if (text.trim().isEmpty) {
              showFToast(context: context, title: const Text('请输入要发送的文本'));
              return;
            }
            _send('clipboard-text', arg: text);
          },
        ),
      ),
    );
  }

  /// 让 PC 打开网址（仅 http/https）
  Future<void> _sendUrlSheet() {
    final t = context.theme;
    final controller = TextEditingController();
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: true,
      builder: (c) => SheetScaffold(
        title: '在 PC 上打开网址',
        size: SheetSize.md,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '用 PC 默认浏览器打开链接，仅支持 http/https。',
              style: t.typography.body.sm.copyWith(
                fontSize: 13,
                color: t.colors.mutedForeground,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SheetInputBox(
              controller: controller,
              hintText: 'https://example.com',
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        bottomBar: sheetBottomActions(
          c,
          actionLabel: '打开',
          actionIcon: FLucideIcons.externalLink,
          onAction: () {
            final url = controller.text.trim();
            Navigator.pop(c);
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              showFToast(
                context: context,
                variant: FToastVariant.destructive,
                title: const Text('链接需以 http:// 或 https:// 开头'),
              );
              return;
            }
            _send('open-url', arg: url);
          },
        ),
      ),
    );
  }
}
