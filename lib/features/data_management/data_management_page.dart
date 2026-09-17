// 数据管理页（设置面板「数据管理」入口，路由 /data-management）
//
// 两个能力（对应 2026-09-17 需求）：
// 1. 展示当前数据库存储位置与模式（公共 Download / 沙盒）；沙盒时给红色警告，
//    并提供「迁移到公共存储」按钮（申请所有文件访问 → 拷贝到 Download/渐离App）。
// 2. 「导入数据库」：file_picker 选 .sqlite/.db → 底部抽屉确认 → 按主键合并进默认库
//    （非破坏式，见 core/db/db_import.dart）。
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui/sheet_form.dart' show SheetSize, showSheetConfirm;
import '../../app/ui/tap_scale.dart';
import '../../app/ui/ui_atoms.dart';
import '../../app/di/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_export.dart';
import '../../core/db/db_import.dart';
import '../../core/db/db_location.dart';

/// 数据管理页
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _loading = true;
  bool _shared = false;
  String _path = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shared = await isUsingSharedStorage();
    final path = await describeDatabasePath();
    if (mounted) {
      setState(() {
        _shared = shared;
        _path = path;
        _loading = false;
      });
    }
  }

  Future<void> _exportDb() async {
    if (_busy) return;
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    await exportDatabaseFile(db, context: context); // 内部已做成功/失败提示
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _pickAndImport() async {
    if (_busy) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db', 'sqlite3'],
    );
    if (result.isEmpty) return;
    final path = result.first.path;
    if (path == null || !mounted) return;

    final ok = await showSheetConfirm(
      context,
      title: '导入数据库',
      message: '将把所选文件的数据按主键合并进当前数据库（本地配置如 2FA 保险库路径不会被覆盖）。'
          '该操作不可撤销，是否继续？',
      confirmLabel: '导入',
      cancelLabel: '取消',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    final res = await importDatabaseFile(db, path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      showFToast(context: context, title: Text(res.message));
    } else {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: Text(res.message),
      );
    }
  }

  Future<void> _migrate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await migrateToSharedStorage();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      showFToast(context: context, title: Text(res.message));
      await _load(); // 刷新存储模式与路径展示
    } else {
      showFToast(
        context: context,
        variant: FToastVariant.destructive,
        title: Text(res.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
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
                        '数据管理',
                        style: t.typography.body.lg.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: t.colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.pagePadding,
                          4,
                          AppTokens.pagePadding,
                          AppTokens.pageBottomGapOf(context),
                        ),
                        children: [
                          _storageCard(context),
                          const SizedBox(height: 14),
                          _exportCard(context),
                          const SizedBox(height: 14),
                          _importCard(context),
                          const SizedBox(height: 14),
                          _noteCard(context),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 存储位置卡：显示模式 + 路径 + （沙盒时）红色警告 + 迁移按钮
  Widget _storageCard(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppTokens.accentGradient(t.colors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  FLucideIcons.database,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '数据库存储位置',
                style: t.typography.body.md.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _shared
                      ? AppTokens.accentSoft(context, t.colors.primary)
                      : t.colors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _shared ? '公共 Download（重装不丢）' : '应用沙盒（重装会清空）',
                  style: t.typography.body.xs.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _shared ? t.colors.primary : t.colors.foreground,
                  ),
                ),
              ),
            ],
          ),
          SelectableText(
            _path,
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
            ),
          ),
          if (!_shared)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.colors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: t.colors.destructive.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FLucideIcons.triangleAlert,
                    size: 16,
                    color: t.colors.destructive,
                  ),
                  Expanded(
                    child: Text(
                      '当前数据库在应用沙盒内，卸载或重装 App 会被清空。'
                      '建议迁移到公共存储 Download/渐离App（需授予「所有文件访问」权限）。',
                      style: t.typography.body.xs.copyWith(
                        fontSize: 12,
                        color: t.colors.destructive,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!_shared)
            FButton(
              onPress: _busy ? null : () => _migrate(),
              child: Text(_busy ? '处理中…' : '迁移到公共存储'),
              prefix: const Icon(FLucideIcons.uploadCloud),
            ),
        ],
      ),
    );
  }

  /// 导出数据库卡
  Widget _exportCard(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppTokens.accentGradient(t.colors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  FLucideIcons.download,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '导出数据库',
                style: t.typography.body.md.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '将当前数据库导出为独立 .sqlite 快照文件，'
            '保存到系统 Download/渐离App导出/（未授权时暂存应用沙盒）。'
            '可用于备份或迁移到桌面端。',
            style: t.typography.body.sm.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
              height: 1.6,
            ),
          ),
          FButton(
            onPress: _busy ? null : () => _exportDb(),
            child: Text(_busy ? '处理中…' : '导出数据库文件'),
            prefix: const Icon(FLucideIcons.download),
          ),
        ],
      ),
    );
  }

  /// 导入数据库卡
  Widget _importCard(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppTokens.accentGradient(t.colors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  FLucideIcons.fileInput,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '导入数据库',
                style: t.typography.body.md.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '选择一个本机或桌面端导出的数据库文件（.sqlite / .db），'
            '将其中的数据按主键合并进当前数据库。本地配置（如 2FA 保险库路径）不会被覆盖。',
            style: t.typography.body.sm.copyWith(
              fontSize: 13,
              color: t.colors.mutedForeground,
              height: 1.6,
            ),
          ),
          FButton(
            onPress: _busy ? null : () => _pickAndImport(),
            child: Text(_busy ? '处理中…' : '选择数据库文件导入'),
            prefix: const Icon(FLucideIcons.fileUp),
          ),
        ],
      ),
    );
  }

  /// 说明卡
  Widget _noteCard(BuildContext context) {
    final t = context.theme;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            '关于数据安全',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.colors.mutedForeground,
            ),
          ),
          Text(
            '· 数据库默认位于系统 Download/渐离App，重装 App 不会被清除。\n'
            '· 迁移 / 导入后建议完全退出并重新打开 App 以使变更完全生效。\n'
            '· 导入为「合并」语义：仅用导入文件覆盖同主键记录，不影响导入文件未包含的本地数据。',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              color: t.colors.mutedForeground,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
