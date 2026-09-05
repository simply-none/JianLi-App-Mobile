// 笔记标签模型 —— 对齐桌面端可归类笔记的标签定义（TagSelector.vue）
//
// PC 端存储契约（分析结论，勿改契约）：
// - 标签定义：basic_info 表 key='note_tags' 行，value 为 JSON 数组
//   [{key: uuid, name, color: '#RRGGBB', createTime, updateTime, deleted?: bool}]
//   （桌面端 electron/main/module/store.ts 的 get-store/set-store 读写的就是 basic_info 表；
//   该表在双端同步白名单内，标签定义会随行同步到移动端）。
// - 每条笔记：note_book.tags 存标签 key 的 JSON 数组（如 '["<uuid>"]'）。
// - 删除语义：软删（deleted: true），笔记上已挂的 key 保留，与桌面端一致。
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

/// 笔记标签定义
class NoteTag {
  const NoteTag({
    required this.key,
    required this.name,
    this.color = defaultColor,
    this.deleted = false,
  });

  /// 标签唯一键（uuid，note_book.tags 里存的就是它）
  final String key;
  final String name;

  /// '#RRGGBB' 十六进制色（与桌面端 TagSelector 同格式）
  final String color;

  /// 软删标记（true = 已删除，不再出现在选择器，但已有笔记仍可显示）
  final bool deleted;

  /// '#RRGGBB' → Color（解析失败回落默认色）
  Color get colorValue => _parseColor(color) ?? defaultColorValue;

  factory NoteTag.fromJson(Map<String, dynamic> json) => NoteTag(
    key: json['key']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    color: json['color']?.toString() ?? defaultColor,
    deleted: json['deleted'] == true,
  );

  /// 未定义色的标签默认色（PC TagSelector 同款）
  static const String defaultColor = '#6366f1';
  static const Color defaultColorValue = Color(0xFF6366F1);
}

/// 解析 basic_info.note_tags 的 JSON 数组文本（异常/非数组一律空列表）
List<NoteTag> parseNoteTagDefs(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) NoteTag.fromJson(Map<String, dynamic>.from(item)),
    ];
  } catch (_) {
    return const [];
  }
}

/// PC 端 TagSelector 的随机取色板（新建标签时两端观感一致）
const List<String> kNoteTagPalette = [
  '#6366f1',
  '#ec4899',
  '#f59e0b',
  '#10b981',
  '#3b82f6',
  '#8b5cf6',
  '#ef4444',
  '#14b8a6',
  '#f97316',
  '#06b6d4',
];

Color? _parseColor(String raw) {
  final hex = raw.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
