// 关于页 —— App 基本功能描述 + 依赖鸣谢（设置面板「关于」跳转）
//
// 内容：一句话定位 + 功能总览（效率 / 内容 / 工具 三域）+ 双端协同说明 +
// 安全与隐私说明 + 依赖鸣谢（开源项目分组列表）+ 版本号。
// 版本号与 pubspec.yaml version 字段保持一致（改版本时同步更新 [kAppVersion]）。
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui/settings_panel.dart' show kAppVersion;
import '../../app/ui/squircle_box.dart';
import '../../app/ui/tap_scale.dart';
import '../../app/ui/ui_atoms.dart';

/// 关于页
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return FScaffold(
      childPad: false,
      child: ColoredBox(
        // 全局渐变背板由 app.dart 根容器绘制，页面保持透明以透出背板
        color: AppTokens.pageTint(context),
        child: SafeArea(
          child: Column(
            children: [
              // 头部（对齐待办：‹ / 关于）
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
                        '关于',
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
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    4,
                    AppTokens.pagePadding,
                    AppTokens.pageBottomGapOf(context),
                  ),
                  children: [
                    _hero(context),
                    const SizedBox(height: 16),
                    _card(
                      context,
                      icon: FLucideIcons.sparkles,
                      title: '这是什么',
                      child: Text(
                        '渐离App 是一款「效率 · 内容 · 工具」一体的个人工作台，'
                        '数据全部保存在本机，可与你电脑上的桌面版渐离App 在局域网内'
                        '互相同步与传书，随时随地无缝衔接。',
                        style: t.typography.body.sm.copyWith(
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      context,
                      icon: FLucideIcons.layoutGrid,
                      title: '功能总览',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          _featureGroup(context, '效率', AppTokens.accent(0), [
                            '习惯打卡',
                            '待办事项',
                            '番茄钟',
                            '倒计时',
                            '提醒管理',
                          ]),
                          _featureGroup(context, '内容', AppTokens.accent(3), [
                            '可归类笔记',
                            '主题对话',
                            '电子书阅读',
                          ]),
                          _featureGroup(context, '工具', AppTokens.accent(5), [
                            '2FA 验证器',
                            '密码库',
                            '文件保险箱',
                            '二维码',
                            '数据同步',
                            '文件互传',
                            '隔空互传',
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      context,
                      icon: FLucideIcons.refreshCw,
                      title: '双端协同',
                      child: Text(
                        '与桌面版共用一套数据结构与同步协议：习惯 / 待办 / 笔记 / '
                        '主题对话 / 电子书书架等表可在受信局域网内一键互推互拉；'
                        '电子书支持 PC ↔ 手机一键传书，文件互传与隔空互传让'
                        '文件与文本跨设备即扫即得。',
                        style: t.typography.body.sm.copyWith(
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      context,
                      icon: FLucideIcons.shieldCheck,
                      title: '安全与隐私',
                      child: Text(
                        '2FA 验证器与密码库采用 AES-256-GCM + PBKDF2 加密的'
                        '保险库文件，明文只在解锁期间驻留内存，离开页面即锁定；'
                        '文件保险箱对文件名与内容双重加密。所有数据不出本机，'
                        '同步传输仅发生在你信任的局域网内。',
                        style: t.typography.body.sm.copyWith(
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      context,
                      icon: FLucideIcons.heart,
                      title: '依赖鸣谢',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 14,
                        children: [
                          _depsGroup(context, '界面与状态', [
                            ('Flutter', '跨平台 UI 框架'),
                            ('forui', 'shadcn 风格的 Flutter 组件库'),
                            ('flutter_riverpod', '响应式状态管理'),
                            ('go_router', '声明式路由'),
                          ]),
                          _depsGroup(context, '数据与存储', [
                            ('drift + sqlite3', '类型安全的本地数据库'),
                            ('shared_preferences', '轻量键值存储'),
                          ]),
                          _depsGroup(context, '内容与富媒体', [
                            ('epubx', 'EPUB 解析'),
                            ('flutter_quill', '富文本编辑器'),
                            ('flutter_widget_from_html', 'HTML 渲染'),
                            ('fast_gbk', 'TXT 中文编码识别'),
                          ]),
                          _depsGroup(context, '工具与安全', [
                            ('mobile_scanner', '相机扫码识别'),
                            ('qr_flutter', '二维码生成与导出'),
                            ('cryptography', 'AES-256-GCM / PBKDF2 加密'),
                            ('awesome_notifications', '通知与提醒'),
                            ('file_picker', '文件选择'),
                            ('share_plus', '系统分享'),
                            ('webview_flutter', '内嵌网页（隔空互传）'),
                          ]),
                          _depsGroup(context, '网络与同步', [
                            ('同步协议', 'UDP 发现 + HTTP 数据面'),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '渐离App Mobile · v$kAppVersion · 基于 Flutter 构建',
                        style: t.typography.body.xs.copyWith(
                          fontSize: 12,
                          color: t.colors.mutedForeground,
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

  // ---------- 区块 ----------

  /// 顶部品牌区（渐变图标盘 + 名称 + 版本 + slogan）
  Widget _hero(BuildContext context) {
    final t = context.theme;
    return Column(
      children: [
        const SizedBox(height: 8),
        SquircleBox(
          size: 84,
          radius: 28,
          gradient: AppTokens.primaryGradient(context),
          alignment: Alignment.center,
          child: Icon(
            FLucideIcons.zap,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '渐离App',
          style: t.typography.body.lg.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '效率 · 内容 · 工具 一体工作台',
          style: t.typography.body.sm.copyWith(
            color: t.colors.mutedForeground,
          ),
        ),
        Text(
          'v$kAppVersion',
          style: t.typography.body.xs.copyWith(
            color: t.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  /// 通用信息卡（图标 + 标题 + 内容）
  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final t = context.theme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              SquircleBox(
                size: 34,
                radius: 11,
                color: AppTokens.accentSoft(context, t.colors.primary),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: t.colors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: t.typography.body.md.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// 功能域分组：域标签 + 功能 pill 换行
  Widget _featureGroup(
    BuildContext context,
    String domain,
    Color accent,
    List<String> items,
  ) {
    final t = context.theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            domain,
            textAlign: TextAlign.center,
            style: t.typography.body.xs.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: t.colors.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      color: t.colors.foreground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 依赖分组：组名 + 每行「名称 — 一句话说明」
  Widget _depsGroup(
    BuildContext context,
    String group,
    List<(String, String)> deps,
  ) {
    final t = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          group,
          style: t.typography.body.xs.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: t.colors.mutedForeground,
          ),
        ),
        for (final (name, desc) in deps)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: t.typography.body.sm.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    desc,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 13,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
