// 文件互传顶层 providers（顶层声明，页面订阅；禁 build 内联——雷区 #9）
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../repositories/transfer_repository.dart';

/// 文件互传历史流（新→旧）；写入后自动推送到页面记录列表
final StreamProvider<List<FileTransferData>> transferHistoryProvider =
    StreamProvider<List<FileTransferData>>(
      (ref) => ref.watch(transferRepositoryProvider).watchAll(),
    );
