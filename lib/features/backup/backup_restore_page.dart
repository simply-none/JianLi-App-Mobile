// 备份与恢复页（2026-09-22 用户定案：由「数据同步」+「数据管理」合并而来）
//
// 合并规则：数据同步（设备发现 / 拉取发送 / 同步日志）在前，
// 数据管理（存储位置 / 导出 / 导入）在后，共用**一个**头部与**一条**滚动区。
//
// 实现走「最小改动」路线 —— 不搬业务代码，只给原两页各加一个 `embedded` 模式：
//   - `SyncPage(embedded: true)`：正文整块（含顶部横幅；横幅标题被改写成整页横幅）
//   - `DataManagementPage(embedded: true)`：正文整块
// 两页各自仍能独立打开（旧路由 `/sync`、`/data-management` 保留，避免旧深链失效）。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui/tap_scale.dart';
import '../../app/ui/ui_atoms.dart';
import '../data_management/data_management_page.dart';
import '../sync/components/sync_page.dart';

/// 备份与恢复页（工具分组入口，路由 `/backup`）
class BackupRestorePage extends StatelessWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
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
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    AppTokens.listTopGapOf(context),
                    AppTokens.pagePadding,
                    AppTokens.pageBottomGapOf(context),
                  ),
                  children: const [
                    // ① 数据同步段：横幅改写成整页横幅（横幅内的
                    //    「发现设备 / 可同步表」统计值仍由同步段自身状态提供）
                    SyncPage(
                      embedded: true,
                      bannerTitle: '备份与恢复',
                      bannerSubtitle: '局域网同步 · 数据库导入导出',
                      bannerIcon: FLucideIcons.databaseBackup,
                    ),
                    // ② 数据管理段的段落标题
                    SectionHeader(title: '数据管理'),
                    // ③ 数据管理段正文
                    DataManagementPage(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== 头部（对齐数据同步 / 数据管理：‹ / 标题） =====================

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
            '备份与恢复',
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
