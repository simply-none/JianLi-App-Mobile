// 动效总开关（UI 现代化 Phase 0）
//
// 统一读取系统「减弱动态效果」，所有动效入口经此判断；时长/曲线常量收敛在
// AppTokens（避免两处定义）。组件文件继续 import material_ui，本文件只吃
// flutter/widgets，不引 flutter/material，避免与 material_ui 的平行 Material 类冲突。
import 'package:flutter/widgets.dart';

/// 动效能力判定与节律入口
class JianliMotion {
  JianliMotion._();

  /// 是否允许播放动效：系统开启「减弱动态效果」时为 false（应退化为无时长直出）。
  static bool enabled(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations;

  /// 取动画时长：减弱动效时退回零时长（直出，不报错）。
  static Duration duration(BuildContext context, Duration normal) =>
      enabled(context) ? normal : Duration.zero;
}
