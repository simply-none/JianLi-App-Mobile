// 二维码历史仓库 —— 对齐桌面端 qr_history 表（key TEXT PK + source 列）
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/db/app_database.dart';

/// 移动端来源标识（与桌面端 'qrCode' 区分）
const String kQrSourceMobile = 'qrMobile';

/// 二维码历史仓库
class QrHistoryRepository {
  QrHistoryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 历史流（新→旧）
  Stream<List<QrHistoryData>> watchAll() {
    return (_db.select(
      _db.qrHistory,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// 追加历史（style 暂不传，移动端样式定制列 P2）
  Future<void> add({required String type, required String content}) {
    return _db
        .into(_db.qrHistory)
        .insert(
          QrHistoryCompanion.insert(
            key: _uuid.v4(),
            source: const Value(kQrSourceMobile),
            type: Value(type),
            content: Value(content),
            createdAt: Value(_now()),
          ),
        );
  }

  /// 删除单条
  Future<void> delete(String key) =>
      (_db.delete(_db.qrHistory)..where((t) => t.key.equals(key))).go();

  /// 清空本机来源历史
  Future<void> clearMobile() => (_db.delete(
    _db.qrHistory,
  )..where((t) => t.source.equals(kQrSourceMobile))).go();

  String _now() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}

/// 历史仓库 provider
final Provider<QrHistoryRepository> qrHistoryRepositoryProvider =
    Provider<QrHistoryRepository>((ref) {
      return QrHistoryRepository(ref.watch(appDatabaseProvider));
    });

/// 历史流 provider
final StreamProvider<List<QrHistoryData>> qrHistoryProvider =
    StreamProvider<List<QrHistoryData>>(
      (ref) => ref.watch(qrHistoryRepositoryProvider).watchAll(),
    );

/// 解析历史行里 style JSON（桌面端存 QrStyleOptions，移动端暂只读展示用）
Map<String, dynamic>? parseQrStyle(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final v = jsonDecode(raw);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}
