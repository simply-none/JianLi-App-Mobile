// 书签页（/browser/bookmarks）—— 文件夹树 + 长按操作
//
// 数据形态：drift 单表扁平返回（`is_folder` + `parent_key`），**树形结构在 UI 组**。
// 导航模型：页面内维护「当前文件夹」，不每层压一个路由 —— 好处是返回键语义简单、
// 面包屑可任意跳级；代价是关掉页面会回到根（可接受）。
//
// 单击 = 打开（书签）/ 进入（文件夹）；长按 = 操作单（加入固定标签 / 重命名 / 复制链接 / 删除）。
// ⚠️ 打开书签的做法是 `pop(url)`：由浏览器主壳接住返回值再导航（见 browser_page.dart），
//    这样书签页不需要知道 WebView 的存在。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../components/browser_prompt.dart';
import '../components/browser_site_actions.dart';
import '../components/browser_site_tile.dart';
import '../components/browser_subpage.dart';
import '../models/browser_models.dart';
import '../providers/browser_providers.dart';

/// 文件夹长按可执行的动作
enum _FolderAction { pin, rename, delete }

class BrowserBookmarksPage extends ConsumerStatefulWidget {
  const BrowserBookmarksPage({super.key});

  @override
  ConsumerState<BrowserBookmarksPage> createState() =>
      _BrowserBookmarksPageState();
}

class _BrowserBookmarksPageState extends ConsumerState<BrowserBookmarksPage> {
  /// 当前文件夹（null = 根）
  String? _folderKey;

  /// 从根到当前的文件夹 key 路径（面包屑用）
  final List<String> _path = <String>[];

  void _enter(String key) {
    setState(() {
      _path.add(key);
      _folderKey = key;
    });
  }

  /// 返回上一级；[toIndex] 为 -1 时回到根
  void _goUp({int? toIndex}) {
    setState(() {
      final target = toIndex ?? _path.length - 2;
      if (target < 0) {
        _path.clear();
        _folderKey = null;
      } else {
        _path.removeRange(target + 1, _path.length);
        _folderKey = _path[target];
      }
    });
  }

  // ————————————————— 动作 —————————————————

  Future<void> _newFolder() async {
    final name = await showBrowserPrompt(
      context,
      title: '新建文件夹',
      hint: '文件夹名称',
      confirmLabel: '创建',
    );
    if (name == null || !mounted) return;
    await ref
        .read(browserRepositoryProvider)
        .addBookmarkFolder(name, parentKey: _folderKey);
  }

  Future<void> _rename(BrowserBookmark row) async {
    final name = await showBrowserPrompt(
      context,
      title: '重命名',
      initial: row.title ?? '',
      hint: '名称',
      confirmLabel: '保存',
    );
    if (name == null || !mounted) return;
    await ref.read(browserRepositoryProvider).renameBookmark(row.key, name);
  }

  Future<void> _delete(BrowserBookmark row) async {
    final isFolder = row.isFolder == '1';
    final ok = await showSheetConfirm(
      context,
      title: isFolder ? '删除文件夹' : '删除书签',
      message: isFolder
          ? '「${row.title ?? ''}」及其中的所有书签都会被删除，且不可恢复。'
          : '「${row.title ?? row.url ?? ''}」将被删除，不可恢复。',
    );
    if (!ok || !mounted) return;
    await ref.read(browserRepositoryProvider).deleteBookmark(row.key);
  }

  Future<void> _bookmarkMenu(BrowserBookmark row) async {
    final url = (row.url ?? '').trim();
    final action = await showBrowserSiteActionMenu(
      context,
      title: row.title ?? '',
      url: url,
      canRename: true,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case BrowserSiteAction.pin:
        await addSiteToPinned(
          context,
          ref,
          title: row.title ?? hostOf(url),
          url: url,
        );
      case BrowserSiteAction.rename:
        await _rename(row);
      case BrowserSiteAction.copy:
        await copyLink(context, url);
      case BrowserSiteAction.delete:
        await _delete(row);
    }
  }

  Future<void> _folderMenu(
    BrowserBookmark row,
    List<BrowserBookmark> all,
  ) async {
    final action = await showSheetActionMenu<_FolderAction>(
      context,
      title: row.title ?? '文件夹',
      actions: const [
        SheetAction(
          _FolderAction.pin,
          '加入固定标签页',
          icon: FLucideIcons.pin,
        ),
        SheetAction(_FolderAction.rename, '重命名', icon: FLucideIcons.pencil),
        SheetAction(
          _FolderAction.delete,
          '删除',
          icon: FLucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _FolderAction.pin:
        // 文件夹本身没有地址 —— 取它**第一个**含地址的书签作为固定目标。
        // 空文件夹无地址可固定，明确提示而不是静默失败。
        BrowserBookmark? first;
        for (final e in all) {
          if (e.parentKey == row.key && (e.url ?? '').trim().isNotEmpty) {
            first = e;
            break;
          }
        }
        final url = (first?.url ?? '').trim();
        if (url.isEmpty) {
          showFToast(
            context: context,
            title: const Text('文件夹内没有可固定的地址'),
          );
          return;
        }
        await addSiteToPinned(
          context,
          ref,
          title: first?.title ?? hostOf(url),
          url: url,
        );
      case _FolderAction.rename:
        await _rename(row);
      case _FolderAction.delete:
        await _delete(row);
    }
  }

  // ————————————————— UI —————————————————

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    final async = ref.watch(browserBookmarksProvider);
    return BrowserSubPage(
      title: '书签',
      actions: [
        BrowserHeaderAction(
          icon: FLucideIcons.folderPlus,
          tooltip: '新建文件夹',
          onTap: _newFolder,
        ),
      ],
      child: async.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => Center(
          child: Text(
            '读取书签失败：$e',
            style: t.typography.body.sm.copyWith(
              color: t.colors.mutedForeground,
            ),
          ),
        ),
        data: (all) {
          // 面包屑标题（按 key 从列表里找名字，找不到时兜底「文件夹」）
          final crumbs = <String>[];
          for (final key in _path) {
            var name = '文件夹';
            for (final e in all) {
              if (e.key == key) {
                name = e.title ?? '文件夹';
                break;
              }
            }
            crumbs.add(name);
          }
          // 当前层直接子项（仓库已按「文件夹优先 + position」排序）
          final rows = all
              .where((e) => (e.parentKey ?? '') == (_folderKey ?? ''))
              .toList();
          final childCountOf = <String, int>{};
          for (final e in all) {
            final parent = e.parentKey;
            if (parent == null) continue;
            childCountOf[parent] = (childCountOf[parent] ?? 0) + 1;
          }
          return Column(
            children: [
              if (_path.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    0,
                    AppTokens.pagePadding,
                    6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _goUp(toIndex: -1),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '全部书签${crumbs.map((c) => ' / $c').join()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.typography.body.xs.copyWith(
                              fontSize: 12,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _goUp,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            '上一级',
                            style: t.typography.body.xs.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: rows.isEmpty
                    ? const EmptyState(
                        icon: FLucideIcons.bookmark,
                        title: '这里还没有书签',
                        subtitle: '浏览网页时点菜单里的「加入书签」，或在右上角新建文件夹',
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.pagePadding,
                          4,
                          AppTokens.pagePadding,
                          AppTokens.pageBottomGapOf(context),
                        ),
                        itemCount: rows.length,
                        itemBuilder: (c, i) {
                          final row = rows[i];
                          if (row.isFolder == '1') {
                            return BrowserFolderCard(
                              title: row.title ?? '文件夹',
                              childCount: childCountOf[row.key] ?? 0,
                              onTap: () => _enter(row.key),
                              onLongPress: () => _folderMenu(row, all),
                            );
                          }
                          final url = (row.url ?? '').trim();
                          return BrowserSiteCard(
                            title: row.title ?? hostOf(url),
                            url: url,
                            subtitle: displayUrl(url),
                            onTap: () {
                              requestBrowserNavigation(ref, url);
                              context.pop();
                            },
                            onLongPress: () => _bookmarkMenu(row),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
