// 全局依赖注入（Riverpod）—— 对应桌面端 Pinia store 的获取入口习惯
//
// 约定：全局单例（数据库、通知服务等）在这里注册；
// feature 内部状态用各自目录下的 notifier/provider，不集中堆放。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';

/// 全局数据库实例（App 生命周期内单例）
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
