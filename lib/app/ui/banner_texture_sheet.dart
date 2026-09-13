// 横幅纹理选择器（底部抽屉）—— 列出 CardTextures.all 全部 21 张纹理缩略图，
// 选中高亮，点击即写入调用方给定的回调（即时切换全 App / 首页英雄卡纹理）。
//
// 设置面板「横幅纹理」与首页英雄卡点击切换共用此弹窗，保证两处体验一致。
// 弹窗走共享 SheetScaffold（lg 三档制 + sheetMaxHeightFull），body = 可滚动网格。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/card_textures.dart';
import 'sheet_form.dart';
import 'sheet_surface.dart';

/// 打开横幅纹理选择抽屉
/// - [currentAsset]：当前选中的纹理资源路径（用于高亮）
/// - [onPick]：点击缩略图时回传选中的纹理路径（调用方负责持久化）
Future<void> showBannerTextureSheet(
  BuildContext context, {
  required String currentAsset,
  required ValueChanged<String> onPick,
}) async {
  await showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (_) => _BannerTextureSheetContent(
      currentAsset: currentAsset,
      onPick: onPick,
    ),
  );
}

class _BannerTextureSheetContent extends StatefulWidget {
  const _BannerTextureSheetContent({
    required this.currentAsset,
    required this.onPick,
  });

  final String currentAsset;
  final ValueChanged<String> onPick;

  @override
  State<_BannerTextureSheetContent> createState() =>
      _BannerTextureSheetContentState();
}

class _BannerTextureSheetContentState extends State<_BannerTextureSheetContent> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentAsset;
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '横幅纹理',
      size: SheetSize.lg,
      body: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
        children: [
          for (final tex in CardTextures.all)
            _TextureCell(
              tex: tex,
              selected: tex.asset == _selected,
              onTap: () {
                setState(() => _selected = tex.asset);
                widget.onPick(tex.asset);
              },
            ),
        ],
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ),
      ],
    );
  }
}

/// 单张纹理缩略图（圆角 + 选中主色描边 + 右上角勾选角标）
class _TextureCell extends StatelessWidget {
  const _TextureCell({
    required this.tex,
    required this.selected,
    required this.onTap,
  });

  final CardTexture tex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected ? t.colors.primary : t.colors.border,
            width: selected ? 3 : 1,
          ),
          image: DecorationImage(
            image: AssetImage(tex.asset),
            fit: BoxFit.cover,
          ),
        ),
        child: selected
            ? Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      FLucideIcons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
