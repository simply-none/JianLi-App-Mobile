// P1-6 小纸条 —— Riverpod providers
//
// 只做「实例供给 + 轻量偏好读取」，业务逻辑在 repositories / services。
// ⚠️ Riverpod 3 已移除 StateProvider（红线 #33）：一次性状态一律用最小 Notifier。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../app/di/app_providers.dart';
import '../repositories/note_slip_repository.dart';
import '../services/note_slip_client.dart';

/// 小纸条仓库
final Provider<NoteSlipRepository> noteSlipRepositoryProvider =
    Provider<NoteSlipRepository>(
  (ref) => NoteSlipRepository(ref.read(appDatabaseProvider)),
);

/// 小纸条发送端
final Provider<NoteSlipClient> noteSlipClientProvider =
    Provider<NoteSlipClient>(
  (ref) => NoteSlipClient(ref.read(appDatabaseProvider)),
);

/// 全部小纸条（时间倒序）
final StreamProvider<List<NoteSlipData>> slipListProvider =
    StreamProvider<List<NoteSlipData>>(
  (ref) => ref.watch(noteSlipRepositoryProvider).watchAll(),
);

/// 未读数（收到的且未读）
final StreamProvider<int> slipUnreadProvider = StreamProvider<int>(
  (ref) => ref.watch(noteSlipRepositoryProvider).watchUnread(),
);

/// 接收常驻开关：'1' = 冷启动常驻（不打开页面也能收）；'0'/缺省 = 仅打开小纸条页时可收。
///
/// 存 basic_info 键 `slip_always_on`（与互传/同步的偏好同存放法；**不进同步白名单传输**
/// ——note_slip 表不同步，这个开关更不该被对端覆盖）。
final AsyncNotifierProvider<SlipAlwaysOnController, bool>
    slipAlwaysOnProvider =
    AsyncNotifierProvider<SlipAlwaysOnController, bool>(
  SlipAlwaysOnController.new,
);

/// 接收常驻开关控制器
class SlipAlwaysOnController extends AsyncNotifier<bool> {
  static const String _key = 'slip_always_on';

  @override
  Future<bool> build() async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(db.basicInfo)
          ..where((t) => t.key.equals(_key)))
        .getSingleOrNull();
    return row?.value == '1';
  }

  /// 切换开关（写库 + 更新状态；实际启停由 [NoteSlipBootstrap] 执行）
  Future<void> set(bool value) async {
    final db = ref.read(appDatabaseProvider);
    await db.into(db.basicInfo).insertOnConflictUpdate(
          BasicInfoCompanion.insert(
            key: _key,
            value: Value(value ? '1' : '0'),
          ),
        );
    state = AsyncData(value);
  }
}
