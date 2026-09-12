// 卡片纹理集 —— 与画布「13 卡片纹理选型」（ardot 文件 724742991017068 节点 8:161）
// 的 01–21 序号一一对应，原图取自设计素材目录，未做任何再压缩。
//
// 校验方式：画布 IMAGE 填充的 imageHash = 源文件字节的 SHA1，可直接与本地文件比对；
// 例如首页英雄卡节点 8:160 的 imageHash `26ea92b5…` → 序号 18（pexels-tiles）。
//
// 用法：卡片底 = 品牌/强调色渐变，上面叠 `asset`（FILL 居中裁切），
// 画布统一配方：填充不透明度 0.56 × 纹理节点不透明度 0.35。
class CardTexture {
  const CardTexture({
    required this.index,
    required this.label,
    required this.asset,
  });

  /// 画布「13 卡片纹理选型」序号（01–21）
  final int index;

  /// 画布上的标签（保持与设计稿一致，便于双向核对）
  final String label;

  /// 打包资源路径
  final String asset;
}

/// 纹理集常量
abstract final class CardTextures {
  /// 首页英雄卡当前使用的纹理序号（对齐画布节点 8:160）
  static const int heroIndex = 18;

  /// 首页英雄卡纹理资源（= 序号 18 的 [CardTexture.asset]；单独抽出以便用于 const 上下文）
  static const String heroAsset =
      'assets/images/textures/pexels-tiles-1846980_1920.jpg';

  /// 序号 11 的纹理资源（画布待办页统计横幅内「纹理-卡11」节点使用；
  /// 同样单独抽出以便用于 const 上下文）
  static const String texture11 =
      'assets/images/textures/lemoonboots-texture-2351354_1920.jpg';

  /// 序号 02 的纹理资源（待办卡片/列表项背景统一使用）jianli-mobile-app\assets\images\textures\lemoonboots-texture-2351354_1920.jpg
  static const String texture02 =
      'assets/images/textures/pexels-tiles-1846980_1920.jpg';

  /// 序号 01 的纹理资源（待办卡片/列表项背景备选）
  static const String texture01 =
      'assets/images/textures/8926-background-2654852_1920.jpg';

  /// 画布配方：IMAGE 填充不透明度
  static const double fillOpacity = 0.56;

  /// 画布配方：纹理节点不透明度
  static const double nodeOpacity = 0.35;

  /// 合成后的纹理不透明度（叠在渐变底之上）
  static const double composedOpacity = fillOpacity * nodeOpacity;

  /// 全部 21 张（按画布序号升序）
  static const List<CardTexture> all = [
    CardTexture(
      index: 1,
      label: '01 8926-background',
      asset: 'assets/images/textures/8926-background-2654852_1920.jpg',
    ),
    CardTexture(
      index: 2,
      label: '02 artsybee-old',
      asset: 'assets/images/textures/artsybee-old-2228749_1920.jpg',
    ),
    CardTexture(
      index: 3,
      label: '03 ch1310-denim',
      asset: 'assets/images/textures/ch1310-denim-1039513_1920.jpg',
    ),
    CardTexture(
      index: 4,
      label: '04 ha11ok-leather',
      asset: 'assets/images/textures/ha11ok-leather-1251740_1920.jpg',
    ),
    CardTexture(
      index: 5,
      label: '05 ha11ok-leather',
      asset: 'assets/images/textures/ha11ok-leather-1251756_1920.jpg',
    ),
    CardTexture(
      index: 6,
      label: '06 ha11ok-leather',
      asset: 'assets/images/textures/ha11ok-leather-1251764_1920.jpg',
    ),
    CardTexture(
      index: 7,
      label: '07 hgdesigns-watercolor',
      asset:
          'assets/images/textures/hgdesigns-watercolor-background-7712381_1920.jpg',
    ),
    CardTexture(
      index: 8,
      label: '08 juniorxy-texture-of-tiles',
      asset:
          'assets/images/textures/juniorxy-texture-of-tiles-portuguese-4694280_1920.jpg',
    ),
    CardTexture(
      index: 9,
      label: '09 lemoonboots-scrapbook',
      asset: 'assets/images/textures/lemoonboots-scrapbook-2239941_1920.jpg',
    ),
    CardTexture(
      index: 10,
      label: '10 lemoonboots-texture-1072525',
      asset: 'assets/images/textures/lemoonboots-texture-1072525_1920.jpg',
    ),
    CardTexture(
      index: 11,
      label: '11 lemoonboots-texture-2351354',
      asset: texture11,
    ),
    CardTexture(
      index: 12,
      label: '12 louanapires-wallpaper-1192997',
      asset: 'assets/images/textures/louanapires-wallpaper-1192997_1920.jpg',
    ),
    CardTexture(
      index: 13,
      label: '13 louanapires-wallpaper-1192998',
      asset: 'assets/images/textures/louanapires-wallpaper-1192998_1920.jpg',
    ),
    CardTexture(
      index: 14,
      label: '14 misku-texture',
      asset: 'assets/images/textures/misku-texture-1033755_1920.jpg',
    ),
    CardTexture(
      index: 15,
      label: '15 mrsmary-paper',
      asset: 'assets/images/textures/mrsmary-paper-1914903_1920.jpg',
    ),
    CardTexture(
      index: 16,
      label: '16 peggy_marco-texture',
      asset: 'assets/images/textures/peggy_marco-texture-1027711_1920.jpg',
    ),
    CardTexture(
      index: 17,
      label: '17 pellissierjp-background',
      asset: 'assets/images/textures/pellissierjp-background-1874541_1920.jpg',
    ),
    CardTexture(
      index: 18,
      label: '18 pexels-tiles',
      asset: heroAsset,
    ),
    CardTexture(
      index: 19,
      label: '19 roses_street-texture',
      asset: 'assets/images/textures/roses_street-texture-4868300_1920.jpg',
    ),
    CardTexture(
      index: 20,
      label: '20 studiopratisaad0-old-paper',
      asset:
          'assets/images/textures/studiopratisaad0-old-paper-642132_1920.jpg',
    ),
    CardTexture(
      index: 21,
      label: '21 tensaisaisai-paper',
      asset: 'assets/images/textures/tensaisaisai-paper-1806467_1920.jpg',
    ),
  ];

  /// 首页英雄卡纹理（序号 [heroIndex]）
  static CardTexture get hero => all[heroIndex - 1];
}
