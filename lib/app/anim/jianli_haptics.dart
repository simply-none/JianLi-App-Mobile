// 触感反馈（UI 现代化 Phase 0）
//
// 封装 Flutter 内置 HapticFeedback（无需额外依赖）。减弱动态效果时自动跳过，
// 与视觉降级保持一致。组件文件继续 import material_ui；本文件仅用
// flutter/services + flutter/widgets，不引 flutter/material。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'jianli_motion.dart';

/// 触感类型
enum HapticType {
  /// 轻点（卡片按压、Tab 切换）
  light,

  /// 中等（勾选完成、分段切换）
  medium,

  /// 成功（打卡达成、专注结束）
  success,
}

/// 触发触感。
///
/// [context] 可选：传入时先查 [JianliMotion.enabled]，减弱动效则跳过，
/// 保证视觉与触感降级同步；不传则直接触发。
void haptic(HapticType type, [BuildContext? context]) {
  if (context != null && !JianliMotion.enabled(context)) return;
  switch (type) {
    case HapticType.light:
      HapticFeedback.lightImpact();
    case HapticType.medium:
      HapticFeedback.mediumImpact();
    case HapticType.success:
      HapticFeedback.mediumImpact();
  }
}
