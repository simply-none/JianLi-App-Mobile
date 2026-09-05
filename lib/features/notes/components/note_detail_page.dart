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
import '../providers/note_providers.dart';

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
            onPress: () =>
                context.push('/notes/edit?noteKey=${Uri.encodeComponent(noteKey)}'),
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
          return ColoredBox(
            color: AppTokens.pageTint(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      SquircleBox(
                        size: 40,
                        radius: 12,
                        gradient: AppTokens.accentGradient(AppTokens.accent(3)),
                        alignment: Alignment.center,
                        child: Icon(FLucideIcons.notebookPen, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(note.title, style: t.typography.body.xl)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '${note.category ?? '未分类'} · 更新于 ${note.updateTime}',
                    style: t.typography.body.sm.copyWith(color: t.colors.mutedForeground),
                  ),
                ),
                const FDivider(),
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

/// HTML 渲染组件（独立小部件，便于测试与复用）
class NoteHtmlView extends StatelessWidget {
  const NoteHtmlView({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HtmlWidget(html),
    );
  }
}
