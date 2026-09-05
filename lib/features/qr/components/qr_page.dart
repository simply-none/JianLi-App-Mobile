// 二维码页 —— 三 Tab：生成 / 识别 / 历史
//
// 生成：qr_flutter 渲染（桌面端 qr-code-styling 的样式定制列 P2）；
// 识别：mobile_scanner 相机实时识别；历史：qr_history 表（双端同构）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/ui/ui_atoms.dart';
import '../repositories/qr_history_repository.dart';
import '../services/qr_payload_builder.dart';

/// 二维码页
class QrPage extends ConsumerStatefulWidget {
  const QrPage({super.key});

  @override
  ConsumerState<QrPage> createState() => _QrPageState();
}

class _QrPageState extends ConsumerState<QrPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  String _type = QrPayloadType.text;
  final _contentController = TextEditingController();
  final _ssidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _telController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _tab.dispose();
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
        wifi: WifiParams(ssid: _ssidController.text, password: _wifiPasswordController.text),
        contact: {
          'name': _nameController.text,
          'tel': _telController.text,
          'email': _emailController.text,
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二维码'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '生成'), Tab(text: '识别'), Tab(text: '历史')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildGenerate(), _buildScan(), _buildHistory()],
      ),
    );
  }

  // ---------- 生成 ----------
  Widget _buildGenerate() {
    final payload = _currentPayload;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 类型选择
        SegmentedButton<String>(
          segments: [
            for (final t in QrPayloadType.all)
              ButtonSegment(value: t, label: Text(QrPayloadType.label(t))),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        _buildFields(),
        const SizedBox(height: 20),
        if (payload.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(data: payload, size: 210, backgroundColor: Colors.white),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('存入历史'),
          onPressed: payload.isEmpty
              ? null
              : () async {
                  await ref.read(qrHistoryRepositoryProvider).add(type: _type, content: payload);
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('已存入历史')));
                  }
                },
        ),
      ],
    );
  }

  /// 按类型出字段
  Widget _buildFields() {
    switch (_type) {
      case QrPayloadType.wifi:
        return Column(children: [
          TextField(
            controller: _ssidController,
            decoration: const InputDecoration(labelText: 'Wi-Fi 名称', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _wifiPasswordController,
            decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ]);
      case QrPayloadType.contact:
        return Column(children: [
          for (final (c, label) in [
            (_nameController, '姓名'),
            (_telController, '电话'),
            (_emailController, '邮箱'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: c,
                decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
        ]);
      default:
        return TextField(
          controller: _contentController,
          maxLines: _type == QrPayloadType.text ? 4 : 1,
          decoration: InputDecoration(
            labelText: _type == QrPayloadType.url ? '网址' : '内容',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
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

  Future<void> _showScanResult(String value) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('识别结果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SelectableText(value),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('复制'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('存历史'),
                  onPressed: () {
                    ref.read(qrHistoryRepositoryProvider).add(type: 'scan', content: value);
                    Navigator.pop(context);
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ---------- 历史 ----------
  Widget _buildHistory() {
    final historyAsync = ref.watch(qrHistoryProvider);
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(icon: Icons.history, title: '暂无历史');
        }
        return ListView(
          children: [
            for (final row in rows)
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: Text(
                  row.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${QrPayloadType.label(row.type ?? 'text')} · ${row.createdAt ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(qrHistoryRepositoryProvider).delete(row.key),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: row.content ?? ''));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('内容已复制')));
                },
              ),
          ],
        );
      },
    );
  }
}
