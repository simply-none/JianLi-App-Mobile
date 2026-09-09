// 笔记详情页 —— flutter_widget_from_html 渲染 vue-quill 富文本 HTML（forui 化）
//
// 说明：flutter-port.md 原计划「flutter_quill 直吃 html」，实测 quill 消费 html
// 需经 delta 转换且兼容性有限；阅读场景改用 flutter_widget_from_html 保真渲染，
// 编辑器（flutter_quill）列入 P2。图片（data URL / 网络）由该库自动处理。
// 编辑/删除入口在顶栏；删除走 showFDialog 二次确认（业务操作与原版一致）。
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/squircle_box.dart';
import '../models/note_item.dart';
import '../models/note_tag.dart';
import '../providers/note_providers.dart';
import 'note_tag_chip.dart';

/// 笔记详情页（路由参数：笔记 key）
class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.noteKey});

  final String noteKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(noteRepositoryProvider);
    final t = context.theme;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('笔记'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.pencil),
            onPress: () => context.push(
              '/notes/edit?noteKey=${Uri.encodeComponent(noteKey)}',
            ),
          ),
          FHeaderAction(
            icon: Icon(FLucideIcons.trash2, color: t.colors.destructive),
            onPress: () => _delete(context, ref),
          ),
        ],
      ),
      child: FutureBuilder<NoteItem?>(
        future: repo.getNote(noteKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: FCircularProgress());
          }
          final note = snapshot.data;
          if (note == null) {
            return Center(child: Text('未找到笔记：$noteKey'));
          }
          // 标签 key → 定义（名称/颜色），来自 basic_info.note_tags
          final tagDefs =
              ref.watch(noteTagsProvider).value ?? const <NoteTag>[];
          final defByKey = {for (final d in tagDefs) d.key: d};
          final badges = [
            for (final k in note.tags)
              if (defByKey[k] != null) defByKey[k]!,
          ];
          return ColoredBox(
            color: AppTokens.pageTint(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    14,
                    AppTokens.pagePadding,
                    4,
                  ),
                  child: Row(
                    children: [
                      SquircleBox(
                        size: 40,
                        radius: 12,
                        gradient: AppTokens.accentGradient(AppTokens.accent(3)),
                        alignment: Alignment.center,
                        child: Icon(
                          FLucideIcons.notebookPen,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(note.title, style: t.typography.body.xl),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    0,
                    AppTokens.pagePadding,
                    8,
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 分类 chip：琥珀软底 + 专属色文字（与笔记域强调色一致）
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.accentSoft(
                            context,
                            AppTokens.accent(3),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          note.category ?? '未分类',
                          style: t.typography.body.xs.copyWith(
                            color: AppTokens.accent(3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // 标签彩色徽标（对齐 PC 列表/详情的标签展示）
                      for (final tag in badges) NoteTagBadge(tag: tag),
                      Text(
                        '更新于 ${note.updateTime}',
                        style: t.typography.body.sm.copyWith(
                          color: t.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const FDivider(),
                // 正文字号随全局基准字号体系（阅览模式在根组件驱动主题，无需页内缩放）
                Expanded(child: NoteHtmlView(html: note.html)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 删除（showFDialog 二次确认，确认后调用仓库删除并返回列表）
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (c, style, _) => FDialog(
        builder: (c, style) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确认删除这篇笔记？', style: style.titleTextStyle),
            const SizedBox(height: 8),
            Text('删除后不可恢复', style: style.bodyTextStyle),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.pop(c),
                  child: const Text('取消'),
                ),
                FButton(
                  variant: FButtonVariant.destructive,
                  onPress: () => Navigator.pop(c, true),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(noteRepositoryProvider).deleteNote(noteKey);
      if (context.mounted) context.pop();
    }
  }
}

/// HTML 渲染组件（独立小部件，便于测试与复用）；字号跟随全局基准字号体系
class NoteHtmlView extends StatelessWidget {
  const NoteHtmlView({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTokens.pagePadding),
      child: HtmlWidget(
        html,
        textStyle: TextStyle(
          fontSize: context.theme.typography.body.md.fontSize ?? 14,
          height: 1.7,
        ),
      ),
    );
  }
}
