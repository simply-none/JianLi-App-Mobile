// 应用入口：初始化 Riverpod 容器并挂载根组件
// Material 导入统一用 material_ui（forui 建于其上，勿与 flutter/material 混用，见 SKILL.md）
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: JianliApp(),
    ),
  );
}
