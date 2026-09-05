// 二维码页 —— 三 Tab：生成 / 识别 / 历史
//
// forui 化改造说明：
// - TabBar/TabBarView → FTabs（forui 原生标签页）；
// - 类型选择 SegmentedButton → FSelect；输入框 → FTextField；
// - 识别结果弹层 showModalBottomSheet → showFSheet；SnackBar → showFToast；
// - 历史列表 → FTileGroup + FTile（点击复制，尾部删除按钮）；
// - 业务逻辑（payload 拼装 / 扫码识别 / 历史表读写）与原来完全一致。
// 识别页需要全屏取景：FScaffold 用 childPad: false，各 Tab 自行管理内边距。
// 生成：qr_flutter 渲染（桌面端 qr-code-styling 的样式定制列 P2）；
// 识别：mobile_scanner 相机实时识别；历史：qr_history 表（双端同构）。
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/squircle_box.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../repositories/qr_history_repository.dart';
import '../services/qr_payload_builder.dart';

/// 二维码页
class QrPage extends ConsumerStatefulWidget {
  const QrPage({super.key});

  @override
  ConsumerState<QrPage> createState() => _QrPageState();
}

class _QrPageState extends ConsumerState<QrPage> {
  String _type = QrPayloadType.text;
  final _contentController = TextEditingController();
  final _ssidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _telController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    _ssidController.dispose();
    _wifiPasswordController.dispose();
    _nameController.dispose();
    _telController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String get _currentPayload => buildQrPayload(
    _type,
    text: _contentController.text,
    wifi: WifiParams(
      ssid: _ssidController.text,
      password: _wifiPasswordController.text,
    ),
    contact: {
      'name': _nameController.text,
      'tel': _telController.text,
      'email': _emailController.text,
    },
  );

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      // 识别 Tab 需要全屏取景：关闭默认水平内边距，由各 Tab 自行处理
      childPad: false,
      header: FHeader.nested(
        title: const Text('二维码'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      // ⚠️ expands:true 必须开：默认 false 时 Tab 内容不走 Expanded，
      // 无界高度下内容区（ListView/FSelect 下拉）布局全灭 → 整页白屏且无异常打印
      // 顶部加专属琥珀渐变横幅（与工具分组页「二维码」入口色对齐），Tab 区在 Expanded 内
      child: Column(
        children: [
          PageBanner(
            icon: FLucideIcons.qrCode,
            title: '二维码',
            subtitle: '生成 / 识别 / 历史，一页搞定',
            accentIndex: 3,
          ),
          Expanded(
            child: FTabs(
              expands: true,
              children: [
                FTabEntry(label: const Text('生成'), child: _buildGenerate()),
                FTabEntry(label: const Text('识别'), child: _buildScan()),
                FTabEntry(label: const Text('历史'), child: _buildHistory()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 生成 ----------
  Widget _buildGenerate() {
    final payload = _currentPayload;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // 类型选择
        FSelect<String>(
          items: {for (final t in QrPayloadType.all) QrPayloadType.label(t): t},
          label: const Text('类型'),
          control: FSelectControl<String>.managed(
            initial: _type,
            onChange: (v) => setState(() => _type = v ?? QrPayloadType.text),
          ),
        ),
        const SizedBox(height: 16),
        _buildFields(),
        const SizedBox(height: 20),
        if (payload.isNotEmpty)
          Center(
            // 二维码数据面必须白底黑码才能被相机识别（qr_flutter 渲染参数，非 UI 配色）
            child: QrImageView(
              data: payload,
              size: 210,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
        const SizedBox(height: 16),
        FButton(
          prefix: const Icon(FLucideIcons.save, size: 18),
          onPress: payload.isEmpty
              ? null
              : () async {
                  await ref
                      .read(qrHistoryRepositoryProvider)
                      .add(type: _type, content: payload);
                  if (mounted) {
                    showFToast(context: context, title: const Text('已存入历史'));
                  }
                },
          child: const Text('存入历史'),
        ),
      ],
    );
  }

  /// 按类型出字段
  Widget _buildFields() {
    switch (_type) {
      case QrPayloadType.wifi:
        return Column(
          children: [
            FTextField(
              control: FTextFieldControl.managed(
                controller: _ssidController,
                onChange: (_) => setState(() {}),
              ),
              label: const Text('Wi-Fi 名称'),
            ),
            const SizedBox(height: 10),
            // Wi-Fi 密码：自带明/暗文切换
            FTextField.password(
              control: FTextFieldControl.managed(
                controller: _wifiPasswordController,
                onChange: (_) => setState(() {}),
              ),
              label: const Text('密码'),
            ),
          ],
        );
      case QrPayloadType.contact:
        return Column(
          children: [
            for (final (c, label) in [
              (_nameController, '姓名'),
              (_telController, '电话'),
              (_emailController, '邮箱'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FTextField(
                  control: FTextFieldControl.managed(
                    controller: c,
                    onChange: (_) => setState(() {}),
                  ),
                  label: Text(label),
                ),
              ),
          ],
        );
      default:
        return FTextField(
          control: FTextFieldControl.managed(
            controller: _contentController,
            onChange: (_) => setState(() {}),
          ),
          label: Text(_type == QrPayloadType.url ? '网址' : '内容'),
          maxLines: _type == QrPayloadType.text ? 4 : 1,
        );
    }
  }

  // ---------- 识别 ----------
  Widget _buildScan() {
    return MobileScanner(
      onDetect: (capture) {
        final code = capture.barcodes.firstOrNull;
        if (code?.rawValue == null || code!.rawValue!.isEmpty) return;
        _showScanResult(code.rawValue!);
      },
    );
  }

  /// 识别结果弹层（复制 / 存历史）
  Future<void> _showScanResult(String value) async {
    final t = context.theme;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '识别结果',
              style: t.typography.body.md.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SelectableText(value),
            const SizedBox(height: 16),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: FButton(
                    variant: FButtonVariant.outline,
                    prefix: const Icon(FLucideIcons.copy, size: 18),
                    onPress: () {
                      Clipboard.setData(ClipboardData(text: value));
                      Navigator.pop(context);
                    },
                    child: const Text('复制'),
                  ),
                ),
                Expanded(
                  child: FButton(
                    prefix: const Icon(FLucideIcons.save, size: 18),
                    onPress: () {
                      ref
                          .read(qrHistoryRepositoryProvider)
                          .add(type: 'scan', content: value);
                      Navigator.pop(context);
                    },
                    child: const Text('存历史'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 历史 ----------
  Widget _buildHistory() {
    final t = context.theme;
    final historyAsync = ref.watch(qrHistoryProvider);
    return historyAsync.when(
      loading: () => const Center(child: FCircularProgress()),
      error: (e, _) => Center(
        child: Text(
          '加载失败：$e',
          style: t.typography.body.sm.copyWith(color: t.colors.error),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(icon: FLucideIcons.history, title: '暂无历史');
        }
        return ColoredBox(
          color: AppTokens.pageTint(context),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              StaggerList(
                children: [
                  for (final row in rows)
                    _QrHistoryTile(
                      row: row,
                      onCopy: () {
                        Clipboard.setData(
                          ClipboardData(text: row.content ?? ''),
                        );
                        showFToast(
                          context: context,
                          title: const Text('内容已复制'),
                        );
                      },
                      onDelete: () =>
                          ref.read(qrHistoryRepositoryProvider).delete(row.key),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 二维码历史条目卡（专属琥珀色图标盘 + 内容 + 删除），替换原 FTile
class _QrHistoryTile extends StatelessWidget {
  const _QrHistoryTile({
    required this.row,
    required this.onCopy,
    required this.onDelete,
  });

  final QrHistoryData row;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onCopy,
      child: Row(
        children: [
          SquircleBox(
            size: 40,
            radius: 12,
            gradient: AppTokens.accentGradient(AppTokens.accent(3)),
            alignment: Alignment.center,
            child: Icon(FLucideIcons.qrCode, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.content ?? '',
                  style: t.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${QrPayloadType.label(row.type ?? 'text')} · ${row.createdAt ?? ''}',
                  style: t.typography.body.xs.copyWith(
                    color: t.colors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          FButton.icon(
            variant: FButtonVariant.ghost,
            onPress: onDelete,
            child: Icon(
              FLucideIcons.trash2,
              size: 18,
              color: t.colors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}
