// 标注「颜色 / 类型」的唯一配置源（阅读器与本页各抽屉共用）
//
// 色板名称与顺序对齐 PC 端 `jianli-app/src/views/ebookReader/highlightConfig.ts` 的
// `HIGHLIGHT_COLORS`（yellow/green/blue/pink/orange/purple），跨端语义一致（存库的
// `color` 就是这些字符串）。
//
// ⚠️ **RGB 取值沿用移动端原有 `Colors.*`，不做与 PC 的颜色值对齐**：PC 用
//    `rgba(...,0.4)` 的浅色值 + SVG `fill-opacity` 控制透明度，移动端高亮本身也是
//    半透明 SVG fill，若改色值会整体改变既有划线的观感（2026-09-23 用户定案：
//    线色跟随标注 color、默认黄，但不动高亮色板）。所以本文件只统一「名称 → 颜色」的
//    映射，让高亮 fill 与下划线 stroke 取到同一个颜色。
import 'package:material_ui/material_ui.dart';

import '../providers/reader_settings.dart' show colorToHex;

/// 默认标注色（与 PC `DEFAULT_HIGHLIGHT_COLOR` 一致）
const String kDefaultAnnotationColor = 'yellow';

/// 色板：(存库色名, 中文标签)。顺序与 PC `HIGHLIGHT_COLORS` 一致。
const List<(String, String)> kAnnotationColors = [
  ('yellow', '黄'),
  ('green', '绿'),
  ('blue', '蓝'),
  ('pink', '粉'),
  ('orange', '橙'),
  ('purple', '紫'),
];

/// 色名 → 颜色（空串 / 未知色名一律回退默认色）。
///
/// ⚠️ 取值必须与阅读器旧实现（`epub_reader_page._toColor`）逐字一致，
///    否则既有划线的观感会变。
Color annotationColorOf(String? name) {
  switch ((name ?? '').trim().toLowerCase()) {
    case 'green':
      return Colors.green;
    case 'blue':
      return Colors.blue;
    case 'pink':
      return Colors.pink;
    case 'orange':
      return Colors.orange;
    case 'purple':
      return Colors.purple;
    case 'red':
      return Colors.red;
    case 'yellow':
    default:
      return Colors.yellow;
  }
}

/// 色名 → `#RRGGBB`（下划线 SVG 线色注入 JS 用）
String annotationHexOf(String? name) => colorToHex(annotationColorOf(name));

/// 色名归一化到色板内的合法值（编辑抽屉保存前用；'' / 未知 → 默认黄）
String normalizeAnnotationColor(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  for (final c in kAnnotationColors) {
    if (c.$1 == n) return n;
  }
  return kDefaultAnnotationColor;
}

/// 是否「下划线」样式 —— type 判据的唯一入口。
///
/// 与 epub.js 的标注类型对应：`underline` 走 underline 覆盖层，其余（highlight /
/// note / 未知）走高亮覆盖层。**删除时必须按本判据分派**：epub.js 把下划线存在
/// 独立的 `underlines` 字典里，用 `remove(cfi, 'highlight')` 撤不掉它。
bool isUnderlineType(String? type) => (type ?? '').trim().toLowerCase() == 'underline';

/// 是否「笔记」样式（type == note）——仅用于编辑抽屉回写时保留原分类，不是分类判据。
bool isNoteType(String? type) => (type ?? '').trim().toLowerCase() == 'note';
