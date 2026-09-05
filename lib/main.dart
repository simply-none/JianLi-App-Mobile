// 应用入口：初始化 Riverpod 容器并挂载根组件
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: JianliApp(),
    ),
  );
}
