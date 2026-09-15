// 二维码页 —— 对齐待办列表页骨架（专属色横幅统计 + 分段模式切换 + 内容区）
//
// 骨架（interaction-patterns.md §三）：
//   头部    ‹22 · 二维码18/Bold
//   统计横幅 PageBanner 琥珀专属渐变 · stats 历史条数/类型数（随滚动移出）
//   模式行  JianliSegmented 生成 / 识别 / 历史（替代旧 FTabs，视觉与全 App 统一）
//   内容区  生成 = 类型九选 + 动态字段 + 样式选项（前景/背景色 + 容错率）+ 实时预览
//           识别 = 相机实时取景（全幅）+ 识别结果抽屉
//           历史 = 来源过滤 chips + 历史卡（复制/长按菜单删除）
//
// 能力对齐 PC 端 qrCode：9 种内容类型（文本/网址/WiFi/联系人/邮件/短信/电话/位置/
// 日历事件）、样式选项（前景/背景色 + 容错率）、分享 PNG、识别结果复制/存历史、
// 历史按来源过滤（本机 qrMobile / 桌面端 qrCode）。
// 生成：qr_flutter 渲染 + QrPainter 导出 PNG；识别：mobile_scanner；历史：qr_history 表。
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/datetime_pickers.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/stagger_list.dart';
import '../../../app/ui/tap_scale.dart';
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
  /// 二维码域专属琥珀强调色（与工具分组页「二维码」入口色对齐）
  static final Color _accent = AppTokens.accent(3);

  String _tab = 'gen';

  /// 已识别的最后一个二维码内容（去重：同一码不重复弹底部弹窗）
  String? _lastScanned;

  /// 识别结果底部弹窗是否正在显示（防止并发弹出多个）
  bool _scanSheetOpen = false;

  // —— 生成 ——
  String _type = QrPayloadType.text;
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _ctl(String key) => _controllers.putIfAbsent(
        key,
        () => TextEditingController(),
      );

  // 日历事件的起止时间（选择器产出）
  DateTime? _evStart;
  DateTime? _evEnd;

  // 样式选项（PC StylePicker 的移动端子集：前景/背景色 + 容错率）
  Color _fg = const Color(0xFF000000);
  Color _bg = Colors.white;
  int _ecLevel = QrErrorCorrectLevel.M;

  static const List<int> _ecLevels = [
    QrErrorCorrectLevel.L,
    QrErrorCorrectLevel.M,
    QrErrorCorrectLevel.Q,
    QrErrorCorrectLevel.H,
  ];
  int get _ecIndex => _ecLevels.indexOf(_ecLevel);

  static const List<Color> _fgChoices = [
    Color(0xFF000000), // 黑
    Color(0xFF1D4ED8), // 蓝
    Color(0xFF047857), // 绿
    Color(0xFFBE185D), // 粉
    Color(0xFF92400E), // 棕
  ];
  static const List<Color> _bgChoices = [
    Colors.white,
    Color(0xFFFEF9C3), // 浅黄
    Color(0xFFDBEAFE), // 浅蓝
    Color(0xFFFCE7F3), // 浅粉
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _field(String key) => _ctl(key).text;

  String get _currentPayload => buildQrPayload(
        _type,
        text: _field('content'),
        wifi: WifiParams(ssid: _field('ssid'), password: _field('wifiPwd')),
        contact: {
          'name': _field('name'),
          'tel': _field('tel'),
          'email': _field('email'),
        },
        extra: {
          'tel': _field('tel'),
          'msg': _field('smsMsg'),
          'lat': _field('lat'),
          'lng': _field('lng'),
          'title': _field('evTitle'),
          'start': _fmtDt(_evStart),
          'end': _fmtDt(_evEnd),
          'location': _field('evLocation'),
        },
      );

  @override
  Widget build(BuildContext context) {
    final historyCount = ref.watch(qrHistoryProvider).value?.length ?? 0;

    return FScaffold(
      // 识别模式需要全屏取景：关闭默认内边距，由内容区自行管理
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              // 横幅（专属琥珀渐变 + 纹理 + 圆环；统计随历史/类型数联动）
              PageBanner(
                icon: FLucideIcons.qrCode,
                title: '二维码',
                subtitle: '生成 / 识别 / 历史，一页搞定',
                accentIndex: 3,
                cornerRadius: 22,
                ringDecor: true,
                shadow: false,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                stats: [
                  ('$historyCount', '历史'),
                  ('${QrPayloadType.all.length}', '类型'),
                ],
              ),
              const SizedBox(height: 8),
              // 模式切换（生成 / 识别 / 历史）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: JianliSegmented(
                  items: const [
                    (FLucideIcons.qrCode, '生成'),
                    (FLucideIcons.scanLine, '识别'),
                    (FLucideIcons.history, '历史'),
                  ],
                  selected: _tab == 'gen'
                      ? 0
                      : _tab == 'scan'
                          ? 1
                          : 2,
                  onSelect: (i) => setState(
                    () {
                      _tab = i == 0 ? 'gen' : (i == 1 ? 'scan' : 'history');
                      // 重新进入识别页时重置去重 / 弹窗占用状态
                      if (_tab == 'scan') {
                        _lastScanned = null;
                        _scanSheetOpen = false;
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: _tab == 'gen'
                    ? _buildGenerate()
                    : _tab == 'scan'
                        ? _buildScan()
                        : _buildHistory(),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              '二维码',
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

  // ---------- 生成 ----------
  Widget _buildGenerate() {
    final payload = _currentPayload;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.pagePadding,
        12,
        AppTokens.pagePadding,
        AppTokens.pageBottomGapOf(context),
      ),
      children: [
        // ① 类型（分组卡片：九选 chip，选中色跟随主题主色）
        _groupCard(
          title: '类型',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in QrPayloadType.all)
                SheetChoiceChip(
                  label: QrPayloadType.label(type),
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ② 内容（分组卡片：按类型出动态字段）
        _groupCard(
          title: '内容',
          child: _buildFields(),
        ),
        const SizedBox(height: 12),
        // ③ 样式（分组卡片：前景/背景色板）
        _groupCard(
          title: '样式',
          child: _styleSection(),
        ),
        const SizedBox(height: 12),
        // ④ 容错率（分组卡片：分段控件，M·15% 默认选中）
        _groupCard(
          title: '容错率',
          child: _ecSection(),
        ),
        const SizedBox(height: 14),
        // 实时预览（底色跟随二维码背景色，消除白框）
        if (payload.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                boxShadow: AppTokens.elevation(context, level: 1),
              ),
              // 数据面用所选前景/背景色（保证对比度可扫）
              child: QrImageView(
                data: payload,
                size: 210,
                backgroundColor: _bg,
                errorCorrectionLevel: _ecLevel,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _fg),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: _fg,
                ),
              ),
            ),
          ),
        if (payload.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '内容 ${payload.characters.length} 字符 · 容错率 ${_ecLabel()}',
              style: context.theme.typography.body.xs.copyWith(
                fontSize: 12,
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // ⑤ 操作按钮行：存入历史 → 复制 → 分享图片
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: _qrActionButton(
                label: '存入历史',
                icon: FLucideIcons.history,
                primary: false,
                onTap: payload.isEmpty
                    ? null
                    : () async {
                        await ref
                            .read(qrHistoryRepositoryProvider)
                            .add(type: _type, content: payload);
                        if (mounted) {
                          showFToast(
                            context: context,
                            title: const Text('已存入历史'),
                          );
                        }
                      },
              ),
            ),
            Expanded(
              child: _qrActionButton(
                label: '复制',
                icon: FLucideIcons.copy,
                primary: false,
                onTap: payload.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: payload));
                        if (mounted) {
                          showFToast(
                            context: context,
                            title: const Text('内容已复制'),
                          );
                        }
                      },
              ),
            ),
            Expanded(
              child: _qrActionButton(
                label: '分享图片',
                icon: FLucideIcons.share2,
                primary: true,
                onTap: payload.isEmpty ? null : () => _sharePng(payload),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 分组卡片：标题 + 内容（统一 生成 tab 的卡片化视觉，对齐列表卡规格）
  Widget _groupCard({required String title, required Widget child}) {
    final t = context.theme;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            title,
            style: t.typography.body.md.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.colors.foreground,
            ),
          ),
          child,
        ],
      ),
    );
  }

  /// 容错率分段控件（替代旧 chip 组；选中色跟随主题主色）
  Widget _ecSection() {
    return JianliSegmented(
      items: const [
        (null, 'L · 7%'),
        (null, 'M · 15%'),
        (null, 'Q · 25%'),
        (null, 'H · 30%'),
      ],
      selected: _ecIndex,
      onSelect: (i) => setState(() => _ecLevel = _ecLevels[i]),
    );
  }

  /// 底部操作按钮：次级（渐变灰）/ 主操作（主色渐变），图标与文字同色
  Widget _qrActionButton({
    required String label,
    required IconData icon,
    required bool primary,
    required VoidCallback? onTap,
  }) {
    final t = context.theme;
    final enabled = onTap != null;
    final fg = primary ? t.colors.primaryForeground : t.colors.foreground;
    final gradient = primary
        ? AppTokens.primaryGradient(context)
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.colors.card, t.colors.muted],
          );
    final child = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: primary ? Colors.transparent : t.colors.border,
        ),
      ),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: t.typography.body.sm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
    return TapScale(scale: 0.96, onTap: onTap, child: child);
  }

  /// 样式选项区（仅前景色 / 背景色色板；容错率已独立成卡片）
  Widget _styleSection() {
    final t = context.theme;
    Widget swatches(
      String key,
      List<Color> colors,
      Color current,
      ValueChanged<Color> onPick,
    ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetFieldLabel(key == 'fg' ? '前景色' : '背景色'),
            Wrap(
              spacing: 10,
              children: [
                for (final c in colors)
                  GestureDetector(
                    onTap: () {
                      // 前景/背景选成同色时跳过（保证可扫）
                      if (key == 'fg' && c == _bg) return;
                      if (key == 'bg' && c == _fg) return;
                      setState(() => onPick(c));
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: Border.all(
                          color: t.colors.border,
                          width: 1,
                        ),
                        boxShadow: current == c
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.5),
                                  blurRadius: 0,
                                  spreadRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        swatches('fg', _fgChoices, _fg, (c) => _fg = c),
        swatches('bg', _bgChoices, _bg, (c) => _bg = c),
      ],
    );
  }

  String _ecLabel() {
    switch (_ecLevel) {
      case QrErrorCorrectLevel.L:
        return 'L';
      case QrErrorCorrectLevel.Q:
        return 'Q';
      case QrErrorCorrectLevel.H:
        return 'H';
      default:
        return 'M';
    }
  }

  /// 历史记录时间格式化：ISO → 'yyyy-MM-dd HH:mm'（本地时区）
  static String _fmtCreatedAt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  /// 日期时间选择行（点击开 FDateTimePicker 抽屉；§4.6 同款等高形态）
  Widget _dtField(
    BuildContext context,
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onTap,
  ) {
    final t = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetFieldLabel(label),
        FTappable(
          onPress: () async {
            final picked = await showDateTimePickerSheet(
              context,
              initial: value,
              title: label,
            );
            if (picked != null) onTap(picked);
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.colors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  FLucideIcons.calendarDays,
                  size: 15,
                  color: t.colors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fmtDt(value).isEmpty ? '选择日期时间' : _fmtDt(value),
                    style: t.typography.body.sm.copyWith(
                      fontSize: 14,
                      color: _fmtDt(value).isEmpty
                          ? t.colors.mutedForeground
                          : t.colors.foreground,
                    ),
                  ),
                ),
                Icon(
                  FLucideIcons.chevronDown,
                  size: 16,
                  color: t.colors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// DateTime → 'yyyy-MM-dd HH:mm'（payload 拼装格式；空返回空串）
  String _fmtDt(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// 按类型出字段（SheetInputBox 同款盒子，对齐全 App 输入规范）
  Widget _buildFields() {
    Widget field(String label, String key, {String? hint, bool multiline = false}) {
      final controller = _ctl(key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetFieldLabel(label),
          if (multiline)
            SheetMultilineBox(
              controller: controller,
              hintText: hint ?? label,
              minLines: 3,
              onChanged: (_) => setState(() {}),
            )
          else
            SheetInputBox(
              controller: controller,
              hintText: hint ?? label,
              onChanged: (_) => setState(() {}),
            ),
        ],
      );
    }

    switch (_type) {
      case QrPayloadType.wifi:
        return Column(
          spacing: 12,
          children: [
            field('Wi-Fi 名称', 'ssid', hint: 'SSID'),
            field('密码', 'wifiPwd', hint: 'Wi-Fi 密码'),
          ],
        );
      case QrPayloadType.contact:
        return Column(
          spacing: 12,
          children: [
            field('姓名', 'name'),
            field('电话', 'tel'),
            field('邮箱', 'email'),
          ],
        );
      case QrPayloadType.sms:
        return Column(
          spacing: 12,
          children: [
            field('电话', 'tel'),
            field('短信内容', 'smsMsg', multiline: true),
          ],
        );
      case QrPayloadType.tel:
        return field('电话号码', 'tel');
      case QrPayloadType.geo:
        return Column(
          spacing: 12,
          children: [
            field('纬度', 'lat', hint: '如 39.9042'),
            field('经度', 'lng', hint: '如 116.4074'),
          ],
        );
      case QrPayloadType.event:
        return Column(
          spacing: 12,
          children: [
            field('事件标题', 'evTitle'),
            _dtField(context, '开始时间', _evStart,
                (v) => setState(() => _evStart = v)),
            _dtField(context, '结束时间', _evEnd,
                (v) => setState(() => _evEnd = v)),
            field('地点', 'evLocation'),
          ],
        );
      case QrPayloadType.text:
        return field('内容', 'content', multiline: true);
      case QrPayloadType.url:
      case QrPayloadType.email:
      default:
        return field(
          _type == QrPayloadType.url ? '网址' : '邮箱',
          'content',
        );
    }
  }

  // ---------- 识别 ----------
  Widget _buildScan() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanSheetOpen) return;
              final code = capture.barcodes.firstOrNull;
              if (code?.rawValue == null || code!.rawValue!.isEmpty) return;
              // 同一二维码在镜头内持续出现时只弹一次
              if (_lastScanned == code.rawValue) return;
              _lastScanned = code.rawValue;
              _scanSheetOpen = true;
              _showScanResult(code.rawValue!).whenComplete(() {
                if (mounted) setState(() => _scanSheetOpen = false);
              });
            },
          ),
          // 提示条
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: const Text(
                  '对准二维码自动识别，识别结果可复制或存历史',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 识别结果抽屉（sm 三档制：复制 / 存历史）
  Future<void> _showScanResult(String value) async {
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: AppTokens.sheetHeightLg,
      resizeToAvoidBottomInset: false,
      builder: (c) => SheetScaffold(
        title: '识别结果',
        size: SheetSize.sm,
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.theme.colors.muted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          child: SelectableText(
            value,
            style: c.theme.typography.body.sm.copyWith(fontSize: 14),
          ),
        ),
        bottomBar: [
          Expanded(
            child: FButton(
              variant: FButtonVariant.outline,
              prefix: const Icon(FLucideIcons.copy, size: 16),
              onPress: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('复制'),
            ),
          ),
          Expanded(
            child: GradientButton(
              label: '存历史',
              icon: FLucideIcons.save,
              onPress: () {
                ref
                    .read(qrHistoryRepositoryProvider)
                    .add(type: 'scan', content: value);
                Navigator.pop(c);
              },
            ),
          ),
        ],
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 14,
              children: [
                // 空态图标也统一为渐变瓷片（与列表卡图标同配方）
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTokens.accentGradient(_accent),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    FLucideIcons.history,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                Text(
                  '暂无历史',
                  style: t.typography.body.lg.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.colors.foreground,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppTokens.pagePadding,
            12,
            AppTokens.pagePadding,
            AppTokens.pageBottomGapOf(context),
          ),
          children: [
            StaggerList(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QrHistoryTile(
                      row: row,
                      onCopy: () async {
                        await Clipboard.setData(
                          ClipboardData(text: row.content ?? ''),
                        );
                        if (mounted) {
                          showFToast(
                            context: context,
                            title: const Text('内容已复制'),
                          );
                        }
                      },
                      onDelete: () async {
                        final ok = await showSheetConfirm(
                          context,
                          title: '删除历史',
                          message: '确定删除这条历史记录？',
                        );
                        if (ok) {
                          await ref
                              .read(qrHistoryRepositoryProvider)
                              .delete(row.key);
                        }
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TapScale(
                onTap: () async {
                  final ok = await showSheetConfirm(
                    context,
                    title: '清空本机历史',
                    message: '确定清空本机生成的全部历史？（桌面端来源记录保留）',
                    confirmLabel: '清空',
                  );
                  if (ok) {
                    await ref.read(qrHistoryRepositoryProvider).clearMobile();
                  }
                },
                child: Text(
                  '清空本机历史',
                  style: t.typography.body.sm.copyWith(
                    fontSize: 13,
                    color: t.colors.destructive,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 生成带圆角留白的卡片式 PNG 并经系统分享面板导出
  ///
  /// 画布布局（总尺寸 640×640）：
  ///   - 底色 = 二维码背景色 `_bg`
  ///   - 内边距 = 48px（四周均匀留白）
  ///   - 二维码居中，尺寸自适应（544×544）
  Future<void> _sharePng(String payload) async {
    try {
      const totalSize = 640.0;
      const innerPadding = 48.0;
      final qrSize = totalSize - innerPadding * 2; // 544

      // 1. 渲染纯二维码位图
      final qrPainter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: _ecLevel,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _fg),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: _fg,
        ),
      );
      final qrBytes = await qrPainter.toImageData(qrSize, format: ImageByteFormat.png);
      if (qrBytes == null) throw Exception('渲染二维码失败');

      // 2. 合成到带圆角+留白的卡片画布
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final cardRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, totalSize, totalSize),
        const Radius.circular(24),
      );

      // 圆角裁剪 + 底色填充
      canvas.save();
      canvas.clipRRect(cardRRect);
      canvas.drawColor(_bg, BlendMode.srcOver);

      // 绘制二维码（居中）
      final qrImage = await decodeImageFromList(Uint8List.view(qrBytes.buffer));
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(innerPadding, innerPadding, qrSize, qrSize),
        image: qrImage,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();

      // 3. 导出 PNG
      final picture = recorder.endRecording();
      final byteData = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      final bytes = await byteData.toByteData(format: ImageByteFormat.png);
      if (bytes == null) throw Exception('合成图片失败');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/二维码_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(Uint8List.view(bytes.buffer), flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: '渐离App 二维码'),
      );
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: const Text('导出失败'),
          description: Text('$e'),
        );
      }
    }
  }
}

/// 二维码历史条目卡（专属琥珀色图标盘 + 内容 + 删除）
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
    final source = row.source == kQrSourceMobile ? '本机' : '桌面端';
    return AppCard(
      // 列表卡 margin 清零：间距只由外层 Padding(bottom:10) 提供
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.pagePadding,
        vertical: 12,
      ),
      onTap: onCopy,
      onLongPress: onDelete,
      child: Row(
        children: [
          // 图标瓷片统一配方：Container + accentGradient + 圆角≈size×0.33
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTokens.accentGradient(AppTokens.accent(3)),
              borderRadius: BorderRadius.circular(14),
            ),
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
                  '${QrPayloadType.label(row.type ?? 'text')} · $source · ${_QrPageState._fmtCreatedAt(row.createdAt)}',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 11,
                    color: t.colors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
