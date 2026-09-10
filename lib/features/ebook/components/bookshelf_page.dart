// 书架页 —— 导入 + 网格封面列表（对标主流阅读 App 书架），forui 化
//
// 数据经顶层 bookshelfStreamProvider（⚠️ 禁止 build 内联 StreamProvider——
// 每次重建都是新 provider，页面永远 loading，实踩见 ebook_providers.dart 头注释）。
// 导入入口在顶栏 +；删除 = 长按书格 → 底部抽屉二次确认（全局弹窗规范）。
// 分类（2026-09-09）：顶栏「标签」管理分类与给书打标签；顶部 chips 按分类筛选。
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/page_banner.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_surface.dart';
import '../../../app/ui/ui_atoms.dart';
import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_discovery.dart';
import '../providers/ebook_providers.dart';
import '../repositories/ebook_repository.dart';
import '../services/ebook_transfer.dart';
import 'book_cell.dart';

/// 书架页
class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  /// 当前选中的分类筛选（null = 全部）
  int? _selectedCat;

  @override
  Widget build(BuildContext context) {
    // 进入书架即注册 /ebook/* 接收路由（否则电脑端主动来拉时手机还没挂上端点）
    ref.watch(ebookTransferProvider);
    final shelfAsync = ref.watch(bookshelfStreamProvider);
    final catsAsync = ref.watch(categoriesStreamProvider);
    final bookCatsAsync = ref.watch(bookCategoriesStreamProvider);

    // book_path -> categoryIds
    final bookToCats = <String, Set<int>>{};
    for (final bc in bookCatsAsync.value ?? <EbookBookCategoryData>[]) {
      bookToCats.putIfAbsent(bc.bookPath, () => <int>{}).add(bc.categoryId);
    }
    // id -> category
    final catMap = <int, EbookCategoryData>{};
    for (final c in catsAsync.value ?? <EbookCategoryData>[]) {
      catMap[c.id] = c;
    }

    return FScaffold(
      header: FHeader.nested(
        title: const Text('电子书'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.arrowLeftRight),
            onPress: () => _showTransferSheet(),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.tags),
            onPress: () => _showCategoryManager(),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () => _import(context, ref),
          ),
        ],
      ),
      child: ColoredBox(
        color: AppTokens.pageTint(context),
        child: shelfAsync.when(
          loading: () => const Center(child: FCircularProgress()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (books) {
            if (books.isEmpty) {
              return const EmptyState(
                icon: FLucideIcons.bookOpenText,
                title: '书架空空',
                subtitle: '支持 EPUB / TXT（PDF 列 P2）',
              );
            }
            // 按选中分类筛选
            final filtered =
                _selectedCat == null
                    ? books
                    : books
                        .where(
                          (b) =>
                              (bookToCats[b.filePath] ?? {}).contains(
                                _selectedCat,
                              ),
                        )
                        .toList();

            // 分类筛选 chips（有分类才显示；始终用 SliverToBoxAdapter 包裹，
            // 无分类时内部退化为空 SizedBox，避免条件元素触发 lint）
            final catChips =
                catsAsync.value == null || catsAsync.value!.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTokens.pagePadding,
                            ),
                            child: Row(
                              spacing: 8,
                              children: [
                                _catChip('全部', _selectedCat == null, () {
                                  setState(() => _selectedCat = null);
                                }),
                                for (final c in catsAsync.value!)
                                  _catChip(c.name, _selectedCat == c.id, () {
                                    setState(() => _selectedCat = c.id);
                                  }),
                              ],
                            ),
                          ),
                        ],
                      );
            final catSliver = SliverToBoxAdapter(child: catChips);

            if (filtered.isEmpty) {
              return Center(
                child: Text(
                  '该分类下暂无书籍',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              );
            }

            // 页面专属青渐变横幅 + 封面网格（Sliver 组合，横幅随页面滚动）
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PageBanner(
                    icon: FLucideIcons.bookOpenText,
                    title: '电子书',
                    subtitle: 'EPUB / TXT 随身阅读',
                    accentIndex: 5,
                    stats: [('${books.length}', '本藏书')],
                  ),
                ),
                catSliver,
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.pagePadding,
                    12,
                    AppTokens.pagePadding,
                    24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.62,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final book = filtered[i];
                      final labels =
                          (bookToCats[book.filePath] ?? {})
                              .map((id) => catMap[id]?.name ?? '')
                              .where((n) => n.isNotEmpty)
                              .toList();
                      return BookCell(
                        book: book,
                        categoryLabels: labels,
                        onOpen: () => _openBook(book),
                        onRemove: () => _confirmRemove(context, ref, book),
                      );
                    }, childCount: filtered.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 打开一本书；同步过来的对端记录其 file_path 是对方路径、本机并无文件，
  /// 此时提示用「传书」拉取，避免打开一个空阅读页。
  void _openBook(EbookBookshelfData book) {
    if (!File(book.filePath).existsSync()) {
      showFToast(
        context: context,
        title: const Text('该书文件不在本机，请用「传书」从电脑导入'),
      );
      return;
    }
    context.push(
      '/ebook/reader?path=${Uri.encodeComponent(book.filePath)}',
    );
  }

  /// 分类筛选 chip
  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    return FButton(
      variant: selected ? FButtonVariant.primary : FButtonVariant.outline,
      onPress: onTap,
      child: Text(label),
    );
  }

  /// 导入书籍（file_picker 12.x 静态方法，用户取消时返回空列表）
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'txt'],
      );
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path == null) return;
      final book = await ref.read(ebookRepositoryProvider).importBook(path);
      // 此处 context 是入参（非 State.context），守卫必须用 context.mounted
      if (context.mounted) {
        showFToast(
          context: context,
          title: Text(
            book == null
                ? '仅支持 EPUB / TXT'
                : '已导入《${book.title ?? book.name}》',
          ),
        );
      }
    } catch (e) {
      // 显式暴露导入失败真因（便于定位「导入都报错」根因，而非静默崩溃/被 Future 吞掉）
      if (context.mounted) {
        showFToast(context: context, title: Text('导入失败：$e'));
      }
    }
  }

  /// 删除确认（底部抽屉二次确认；仅删书架引用不删内容）
  ///
  /// ⚠️ 全局规范：所有弹出窗一律走底部抽屉（showFSheet + SheetSurface），
  /// 不使用居中 FDialog —— 见项目级技能「弹窗统一底部抽屉」条例。
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    EbookBookshelfData book,
  ) async {
    final confirmed = await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          12,
          AppTokens.pagePadding,
          12,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将《${book.title ?? book.name}》移出书架？',
                style: c.theme.typography.body.lg,
              ),
              const SizedBox(height: 8),
              Text(
                '将同时删除本地文件副本；阅读进度按内容哈希保留，重新导入可恢复',
                style: c.theme.typography.body.sm.copyWith(
                  color: c.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () => Navigator.pop(c, false),
                      child: const Text('取消'),
                    ),
                  ),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.destructive,
                      onPress: () => Navigator.pop(c, true),
                      child: const Text('移出'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(ebookRepositoryProvider).removeBook(book);
    }
  }

  /// 分类管理：新建分类 + 给书打标签
  void _showCategoryManager() {
    showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (context) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSt) {
              var newName = '';
              final cats = ref.watch(categoriesStreamProvider);
              final bookCatsAsync = ref.watch(bookCategoriesStreamProvider);
              final shelf = ref.watch(bookshelfStreamProvider);
              final allCats = cats.value ?? const <EbookCategoryData>[];
              // id -> category（从实时数据重建，避免传参过期）
              final sheetCatMap = <int, EbookCategoryData>{};
              for (final c in allCats) {
                sheetCatMap[c.id] = c;
              }
              final bookToCats = <String, Set<int>>{};
              for (final bc
                  in bookCatsAsync.value ?? const <EbookBookCategoryData>[]) {
                bookToCats.putIfAbsent(bc.bookPath, () => <int>{}).add(
                  bc.categoryId,
                );
              }
              final books = shelf.value ?? const <EbookBookshelfData>[];

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text(
                      '分类管理',
                      style: context.theme.typography.body.lg,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTokens.pagePadding),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: FTextField(
                            label: const Text('新建分类'),
                            control: FTextFieldControl.managed(
                              onChange: (v) =>
                                  setSt(() => newName = v.text.trim()),
                            ),
                          ),
                        ),
                        FButton(
                          onPress: () async {
                            if (newName.isEmpty) return;
                            await ref
                                .read(ebookRepositoryProvider)
                                .addCategory(newName);
                            newName = '';
                            setSt(() {});
                          },
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  const FDivider(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        FTileGroup(
                          divider: FItemDivider.none,
                          children: [
                            for (final c in allCats)
                              FTile(
                                title: Text(c.name),
                                suffix: FButton(
                                  variant: FButtonVariant.destructive,
                                  onPress: () async {
                                    await ref
                                        .read(ebookRepositoryProvider)
                                        .removeCategory(c.id);
                                  },
                                  child: const Icon(FLucideIcons.tagX),
                                ),
                              ),
                            for (final b in books)
                              FTile(
                                title: Text(
                                  b.title ?? b.name ?? '未命名',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _catNames(
                                    bookToCats[b.filePath] ?? {},
                                    sheetCatMap,
                                  ),
                                ),
                                onPress: () => _editBookCategories(
                                  b,
                                  bookToCats[b.filePath] ?? {},
                                  allCats,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 跨端传书抽屉：扫描设备 → 选设备 → 选方向（从电脑导入 / 导入到电脑）
  /// → 勾选多本 → 底部「传输选中(N)」一键批量传输。
  ///
  /// ⚠️ 表单/流程状态全部放在本方法作用域（StatefulBuilder 的 builder 闭包内变量
  /// 每次 setSt 重建都会被重置，见 SKILL 红线）。勾选集合用 `checked` 存书的 filePath
  /// （双端 filePath 唯一），切换方向/设备时清空，避免跨端混选。
  Future<void> _showTransferSheet() async {
    final discovery = SyncDiscovery();
    var peers = <PeerDevice>[];
    var selectedIndex = -1;
    var direction = 0; // 0=从电脑导入（拉），1=导入到电脑（推）
    var remoteBooks = <RemoteBook>[];
    var scanning = false;
    var loading = false;
    var manualIp = '';
    var checked = <String>{}; // 已勾选书的 filePath
    var transferring = false;
    var progressText = '';
    // 传书记录日志：逐本记录成功/失败及原因，便于排查失败（不持久化，关抽屉即清空）
    var transferLog = <({bool ok, String line})>[];

    // 申请公共 Download 写权限（系统文件管理器可见的保存目录）；未授权 booksDir 自动回退沙盒
    await EbookRepository.ensurePublicDownloadsPermission();

    // 固定保存目录：一次性算出，传书页常显，方便用户在文件管理器定位
    var saveDirPath = '';
    var saveDirFallback = false;
    try {
      saveDirPath = (await EbookRepository.booksDir).path;
      saveDirFallback = !await EbookRepository.hasPublicDownloadsAccess();
    } catch (_) {
      // 取不到目录就隐藏保存目录行（不影响导入）
    }

    Future<void> loadRemote(PeerDevice peer, void Function(void Function()) setSt) async {
      setSt(() => loading = true);
      final books = await ref.read(ebookTransferProvider).fetchRemoteBooks(peer);
      setSt(() {
        remoteBooks = books;
        loading = false;
      });
    }

    void toggle(String key, void Function(void Function()) setSt) {
      if (transferring) return;
      setSt(() {
        if (checked.contains(key)) {
          checked.remove(key);
        } else {
          checked.add(key);
        }
      });
    }

    Future<void> transferSelected(
      PeerDevice peer,
      void Function(void Function()) setSt,
    ) async {
      final items = direction == 0
          ? remoteBooks.where((b) => checked.contains(b.filePath)).toList()
          : localBooksForChecked(checked);
      final total = items.length;
      if (total == 0) return;
      setSt(() {
        transferring = true;
        transferLog.clear();
      });
      var okCount = 0;
      var failCount = 0;
      final dirLabel = direction == 0 ? '←导入' : '→传出';
      for (var i = 0; i < total; i++) {
        final item = items[i];
        final String name;
        if (direction == 0) {
          name = (item as RemoteBook).display;
        } else {
          final b = item as EbookBookshelfData;
          name = b.title ?? b.name ?? '未命名';
        }
        setSt(() => progressText = '传输中 ${i + 1}/$total · $name');
        final r = direction == 0
            ? await ref
                .read(ebookTransferProvider)
                .downloadBook(peer, item as RemoteBook)
            : await ref
                .read(ebookTransferProvider)
                .uploadBook(peer, item as EbookBookshelfData);
        if (r.ok) {
          okCount++;
        } else {
          failCount++;
        }
        // 逐本记录结果 + 失败原因，供下方「传书记录」日志排查
        final time = DateTime.now().toIso8601String().substring(11, 19);
        transferLog.add((
          ok: r.ok,
          line: '[$time] $dirLabel $name · ${r.ok ? '成功' : '失败：${r.message}'}',
        ));
        setSt(() {}); // 刷新传书记录日志（逐本实时显示）
      }
      setSt(() {
        transferring = false;
        checked.clear();
        progressText = '';
      });
      if (mounted) {
        showFToast(
          context: context,
          title: Text(
            '已传输 $okCount 本${failCount > 0 ? '，$failCount 本失败' : ''}',
          ),
        );
      }
    }

    if (!mounted) return;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (ctx) => SheetSurface(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              final t = ctx.theme;
              final shelf = ref.watch(bookshelfStreamProvider);
              final localBooks = shelf.value ?? const <EbookBookshelfData>[];
              final peer = selectedIndex >= 0 && selectedIndex < peers.length
                  ? peers[selectedIndex]
                  : null;

              // 当前方向下的书目 filePath 列表（用于全选判定）
              final currentKeys = direction == 0
                  ? remoteBooks.map((b) => b.filePath).toList()
                  : localBooks.map((b) => b.filePath).toList();
              final selCount =
                  currentKeys.where((k) => checked.contains(k)).length;
              final allSelected =
                  currentKeys.isNotEmpty && selCount == currentKeys.length;

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.pagePadding,
                      12,
                      AppTokens.pagePadding,
                      8,
                    ),
                    child: Text('传书', style: t.typography.body.lg),
                  ),
                  // 固定保存目录：让用户随时知道导入的书落在哪（文件管理器可定位）
                  if (saveDirPath.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        0,
                        AppTokens.pagePadding,
                        8,
                      ),
                      child: Row(
                        spacing: 6,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              FLucideIcons.folderOpen,
                              size: 14,
                              color: t.colors.mutedForeground,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              saveDirFallback
                                  ? '保存目录（未授权，暂存沙盒）：$saveDirPath'
                                  : '保存目录：$saveDirPath',
                              style: t.typography.body.xs.copyWith(
                                color: t.colors.mutedForeground,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FButton(
                            variant: FButtonVariant.outline,
                            onPress: () {
                              Clipboard.setData(ClipboardData(text: saveDirPath));
                              if (mounted) {
                                showFToast(
                                  context: context,
                                  title: const Text('已复制保存目录'),
                                );
                              }
                            },
                            child: const Text('复制'),
                          ),
                        ],
                      ),
                    ),
                  // 顶部：扫描 + 手动 IP（局域网广播常被 NAT 拦，保留手填入口）
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTokens.pagePadding,
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: FTextField(
                            label: const Text('设备 IP（可手填）'),
                            control: FTextFieldControl.managed(
                              onChange: (v) => setSt(() => manualIp = v.text.trim()),
                            ),
                          ),
                        ),
                        FButton(
                          onPress: manualIp.isEmpty
                              ? null
                              : () => setSt(() {
                                  peers = [
                                    ...peers,
                                    PeerDevice(
                                      ip: manualIp,
                                      name: '手动设备 $manualIp',
                                      id: manualIp,
                                      platform: 'unknown',
                                    ),
                                  ];
                                  selectedIndex = peers.length - 1;
                                  checked.clear();
                                }),
                          child: const Text('添加'),
                        ),
                        FButton(
                          variant: FButtonVariant.outline,
                          onPress: scanning
                              ? null
                              : () async {
                                  setSt(() => scanning = true);
                                  final found = await discovery.scan();
                                  setSt(() {
                                    peers = found.values.toList();
                                    scanning = false;
                                  });
                                },
                          child: Text(scanning ? '扫描中…' : '扫描'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (peer != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTokens.pagePadding,
                      ),
                      child: JianliSegmented(
                        items: const [
                          (FLucideIcons.download, '从这台导入'),
                          (FLucideIcons.upload, '传到这台'),
                        ],
                        selected: direction,
                        onSelect: (i) {
                          setSt(() {
                            direction = i;
                            checked.clear();
                          });
                          if (i == 0) loadRemote(peer, setSt);
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  // 已选计数 + 全选/取消全选
                  if (peer != null && currentKeys.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTokens.pagePadding,
                      ),
                      child: Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: Text(
                              transferring
                                  ? progressText
                                  : '已选 $selCount 本',
                              style: t.typography.body.sm.copyWith(
                                color: t.colors.mutedForeground,
                              ),
                            ),
                          ),
                          FButton(
                            variant: FButtonVariant.outline,
                            onPress: transferring
                                ? null
                                : () => setSt(() {
                                    if (allSelected) {
                                      checked.removeAll(currentKeys);
                                    } else {
                                      checked.addAll(currentKeys);
                                    }
                                  }),
                            child: Text(allSelected ? '取消全选' : '全选'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(child: FCircularProgress())
                        : peer == null
                        ? ListView(
                            padding: const EdgeInsets.only(bottom: 12),
                            children: [
                              if (peers.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text('未发现设备，可扫描或手填 IP'),
                                  ),
                                ),
                              FTileGroup(
                                divider: FItemDivider.none,
                                children: [
                                  for (var i = 0; i < peers.length; i++)
                                    FTile(
                                      title: Text(peers[i].name),
                                      subtitle: Text(peers[i].ip),
                                      onPress: () {
                                        setSt(() {
                                          selectedIndex = i;
                                          checked.clear();
                                        });
                                        if (direction == 0) {
                                          loadRemote(peers[i], setSt);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 12),
                            children: [
                              FTileGroup(
                                divider: FItemDivider.none,
                                children: [
                                  if (direction == 0)
                                    for (final b in remoteBooks)
                                      FTile(
                                        selected: checked.contains(b.filePath),
                                        prefix: FCheckbox(
                                          value: checked.contains(b.filePath),
                                          onChange: (_) => toggle(b.filePath, setSt),
                                        ),
                                        title: GestureDetector(
                                          onTap: () => toggle(b.filePath, setSt),
                                          child: Text(
                                            b.display,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        subtitle: GestureDetector(
                                          onTap: () => toggle(b.filePath, setSt),
                                          child: Text(
                                            b.size == null
                                                ? b.format
                                                : '${b.format} · ${(b.size! / 1024 / 1024).toStringAsFixed(1)}MB',
                                          ),
                                        ),
                                      ),
                                  if (direction == 1)
                                    for (final b in localBooks)
                                      FTile(
                                        selected: checked.contains(b.filePath),
                                        prefix: FCheckbox(
                                          value: checked.contains(b.filePath),
                                          onChange: (_) => toggle(b.filePath, setSt),
                                        ),
                                        title: GestureDetector(
                                          onTap: () => toggle(b.filePath, setSt),
                                          child: Text(
                                            b.title ?? b.name ?? '未命名',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        subtitle: GestureDetector(
                                          onTap: () => toggle(b.filePath, setSt),
                                          child: Text(b.format ?? ''),
                                        ),
                                      ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  // 传书记录日志：逐本显示成功/失败及原因，便于分析失败（有记录才显示）
                  if (transferLog.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      margin: const EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        4,
                        AppTokens.pagePadding,
                        4,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.colors.card,
                        border: Border.all(color: t.colors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '传书记录',
                                  style: t.typography.body.sm.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: transferLog
                                          .map((e) => e.line)
                                          .join('\n'),
                                    ),
                                  );
                                  if (mounted) {
                                    showFToast(
                                      context: context,
                                      title: const Text('已复制传书记录'),
                                    );
                                  }
                                },
                                child: Text(
                                  '复制',
                                  style: t.typography.body.xs.copyWith(
                                    color: t.colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () => setSt(() => transferLog.clear()),
                                child: Text(
                                  '清空',
                                  style: t.typography.body.xs.copyWith(
                                    color: t.colors.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView(
                              children: [
                                for (final e in transferLog)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      e.line,
                                      style: t.typography.body.xs.copyWith(
                                        color: e.ok
                                            ? t.colors.mutedForeground
                                            : t.colors.destructive,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 底部：一键批量传输
                  if (peer != null && selCount > 0)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTokens.pagePadding,
                        8,
                        AppTokens.pagePadding,
                        4,
                      ),
                      child: FButton(
                        onPress: transferring
                            ? null
                            : () => transferSelected(peer, setSt),
                        child: Text(
                          transferring ? '传输中…' : '传输选中 ($selCount)',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 取勾选的本地书（按 filePath 命中），用于批量上传
  List<EbookBookshelfData> localBooksForChecked(Set<String> checked) {
    // 需要实时书架数据；借由 provider 读一次快照
    final localBooks =
        ref.read(bookshelfStreamProvider).value ?? const <EbookBookshelfData>[];
    return localBooks.where((b) => checked.contains(b.filePath)).toList();
  }

  /// 分类 id 集合转可读名称（无则「未分类」）
  String _catNames(Set<int> ids, Map<int, EbookCategoryData> map) {    final names = ids
        .map((id) => map[id]?.name ?? '')
        .where((n) => n.isNotEmpty)
        .join('、');
    return names.isEmpty ? '未分类' : names;
  }

  /// 给单本书勾选分类（底部抽屉内即时切换并落库）
  Future<void> _editBookCategories(
    EbookBookshelfData book,
    Set<int> assigned,
    List<EbookCategoryData> allCats,
  ) async {
    final repo = ref.read(ebookRepositoryProvider);
    final current = <int>{...assigned};
    await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (c) => SheetSurface(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          12,
          AppTokens.pagePadding,
          12,
        ),
        child: SafeArea(
          // ⚠️ 表单状态（current）必须提到 builder 之外，StatefulBuilder 闭包内的
          // 局部 var 每次 setSt 重建都会被重置（SKILL 红线）
          child: StatefulBuilder(
            builder: (c, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '为《${book.title ?? book.name}》选择分类',
                  style: c.theme.typography.body.lg,
                ),
                const SizedBox(height: 12),
                if (allCats.isEmpty)
                  Text(
                    '还没有分类，先在分类管理里新建',
                    style: c.theme.typography.body.sm.copyWith(
                      color: c.theme.colors.mutedForeground,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in allCats)
                        FButton(
                          variant: current.contains(cat.id)
                              ? FButtonVariant.primary
                              : FButtonVariant.outline,
                          onPress: () => setSt(() {
                            if (current.contains(cat.id)) {
                              current.remove(cat.id);
                            } else {
                              current.add(cat.id);
                            }
                          }),
                          child: Text(cat.name),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: () => Navigator.pop(c, false),
                        child: const Text('取消'),
                      ),
                    ),
                    Expanded(
                      child: FButton(
                        onPress: () async {
                          for (final id in current.where(
                            (id) => !assigned.contains(id),
                          )) {
                            await repo.assignCategory(book.filePath, id);
                          }
                          for (final id in assigned.where(
                            (id) => !current.contains(id),
                          )) {
                            await repo.unassignCategory(book.filePath, id);
                          }
                          if (c.mounted) Navigator.pop(c, true);
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
