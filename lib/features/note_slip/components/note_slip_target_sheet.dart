// P1-6 小纸条 —— 「发送到」目标选择抽屉（lg 档 80vh）
//
// 2026-09-22 改版（用户诉求）：
//   ① 【扫描局域网】不再「关掉本抽屉 → 再开一个新抽屉」——就地扫描、就地列出设备
//      （扫描中有 spinner + 提示，空结果给就地空态，不弹 toast、不关抽屉）；
//   ② 抽屉高度 md(50%) → **lg(80vh)**，装得下「局域网设备 + 历史设备」两个区块；
//   ③ 历史设备行右侧给垃圾桶：直接删除该条（不弹二次确认），删完原地刷新。
//
// 返回值（`showFSheet<Object?>`）：
//   SlipTarget → 选中某台设备（扫描结果 / 历史设备都走这里）
//   'manual'   → 点了「手动输入 IP」，由调用方开 md 输入抽屉
//   null       → 仅关闭（其间可能删过历史设备，调用方回读一次保持一致）
//
// ⚠️ 抽屉属于 Navigator overlay 子树，**自带 ConsumerStatefulWidget** 订阅 provider
//（红线 #28：在 builder 里用页面 State 的 ref.watch 会永远停在首帧）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/ui/sheet_form.dart';
// ⚠️ SheetSize 在 sheet_surface.dart（sheet_form.dart 不 re-export，须双导，红线）
import '../../../app/ui/sheet_surface.dart' show SheetSize;
import '../../../app/ui/ui_atoms.dart' show SectionHeader;
import '../../../core/sync/sync_discovery.dart';
import '../providers/note_slip_providers.dart';
import '../services/note_slip_client.dart';

/// 「手动输入 IP」的返回信号（区分「选中了某台设备」）
const String kSlipTargetManual = 'manual';

/// 小纸条发送目标选择抽屉
class NoteSlipTargetSheet extends ConsumerStatefulWidget {
  const NoteSlipTargetSheet({super.key, required this.targets});

  /// 打开时的历史设备（页面已读库，避免抽屉再查一次）
  final List<SlipTarget> targets;

  @override
  ConsumerState<NoteSlipTargetSheet> createState() =>
      _NoteSlipTargetSheetState();
}

class _NoteSlipTargetSheetState extends ConsumerState<NoteSlipTargetSheet> {
  late List<SlipTarget> _targets = List.of(widget.targets);

  /// 本轮扫描结果（排除本机）
  List<PeerDevice> _found = const [];

  bool _scanning = false;

  /// 是否已扫过（决定空态是否出现，避免一进抽屉就写「未发现设备」）
  bool _scanned = false;

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final peers = await SyncDiscovery().scan();
      if (!mounted) return;
      // 排除自己（id = 本机稳定 hash），其余都列（PC 的 platform = 'win32-electron'）
      final list = peers.values.where((p) => p.id != localDeviceId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _found = list;
        _scanned = true;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanned = true;
      });
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: const Text('扫描失败'),
        description: Text('$e'),
      );
    }
  }

  Future<void> _remove(SlipTarget target) async {
    final client = ref.read(noteSlipClientProvider);
    await client.removeTarget(target.ip);
    final rest = await client.loadTargets();
    if (!mounted) return;
    setState(() => _targets = rest);
    showFToast(context: context, title: Text('已删除 ${target.name}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetScaffold(
      title: '发送到',
      size: SheetSize.lg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- 局域网设备 ----------
          _row(
            t,
            icon: FLucideIcons.scanLine,
            label: _scanning ? '扫描中…' : (_scanned ? '重新扫描局域网' : '扫描局域网'),
            onPress: _scanning ? null : _scan,
            trailing: _scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: FCircularProgress(),
                  )
                : null,
          ),
          if (_scanning) _hint(t, '正在搜索同一局域网内已打开渐离App 的设备…'),
          if (!_scanning && _scanned && _found.isEmpty)
            _hint(t, '未发现设备。请确认对端渐离App 已打开，且与本机在同一局域网。'),
          for (final p in _found)
            _row(
              t,
              icon: p.platform.contains('electron')
                  ? FLucideIcons.monitor
                  : FLucideIcons.smartphone,
              label: '${p.name}（${p.ip}）',
              onPress: () =>
                  Navigator.pop(context, SlipTarget(ip: p.ip, name: p.name)),
            ),

          // ---------- 历史设备（可删） ----------
          if (_targets.isNotEmpty) ...[
            const SectionHeader(title: '历史设备'),
            for (final target in _targets)
              _row(
                t,
                icon: FLucideIcons.history,
                label: '${target.name}（${target.ip}）',
                onPress: () => Navigator.pop(context, target),
                trailing: _trailingIcon(
                  t,
                  FLucideIcons.trash2,
                  t.colors.destructive,
                  () => _remove(target),
                ),
              ),
          ],

          // ---------- 手动输入 ----------
          const SectionHeader(title: '其他'),
          _row(
            t,
            icon: FLucideIcons.plus,
            label: '手动输入 IP',
            onPress: () => Navigator.pop(context, kSlipTargetManual),
          ),
        ],
      ),
    );
  }

  /// 就地提示行（扫描中 / 空态）
  Widget _hint(FThemeData t, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Text(
      text,
      style: t.typography.body.xs.copyWith(
        fontSize: 12,
        height: 1.5,
        color: t.colors.mutedForeground,
      ),
    ),
  );

  /// 行尾图标钮
  Widget _trailingIcon(
    FThemeData t,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => FTappable(
    onPress: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      child: Icon(icon, size: 17, color: color),
    ),
  );

  /// 设备/动作行：左侧图标 + 文字（点左块 = 选中），右侧可选尾部钮。
  ///
  /// ⚠️ 尾部钮与左块是**并排两个 FTappable**，不做「外层 FTappable 里再套一层 tap」的
  /// 嵌套手势 —— 命中区互不重叠，点删除不会顺手选中设备（也不会双触发）。
  Widget _row(
    FThemeData t, {
    required IconData icon,
    required String label,
    VoidCallback? onPress,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: t.colors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: FTappable(
                onPress: onPress,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    trailing == null ? 12 : 4,
                    12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: t.colors.foreground),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: t.typography.body.sm.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.colors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
