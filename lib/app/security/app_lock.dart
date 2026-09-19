// P1-1 应用锁（生物识别）—— 全局开关 + 锁定状态机
//
// 与 vault 三件套的门禁（各自解锁态）是**叠加关系**：应用锁在最外层管「能不能进 App」，
// vault 门禁在内层管「能不能看明文」。偏好存 basic_info（随同步白名单外的本机键）：
//   app_lock_enabled : '1'/'0'
//   app_lock_grace   : '0'（立即，默认）/'60'/'300'（宽限期秒数）
//
// 触发时机：① 冷启动（init 时 enabled → locked）；② 切后台超过宽限期回前台
// （paused 记时间，resumed 判定）。锁定 → ref.listen 转变沿 push /app-lock 解锁页。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/db/app_database.dart' show BasicInfoCompanion;
import '../di/app_providers.dart';

/// basic_info 偏好键
const kAppLockEnabled = 'app_lock_enabled';
const kAppLockGrace = 'app_lock_grace';

/// 应用锁状态
class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    required this.graceSeconds,
    required this.biometricsAvailable,
  });

  final bool enabled;

  /// 当前是否处于锁定态（true 时根组件 push /app-lock）
  final bool locked;

  /// 宽限期秒数：0 = 切后台立即锁
  final int graceSeconds;

  /// 设备是否有可用生物识别（无则设置项置灰）
  final bool biometricsAvailable;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    int? graceSeconds,
    bool? biometricsAvailable,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      graceSeconds: graceSeconds ?? this.graceSeconds,
      biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
    );
  }
}

/// 应用锁控制器
final NotifierProvider<AppLockController, AppLockState>
appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(
      AppLockController.new,
    );

class AppLockController extends Notifier<AppLockState> {
  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _pausedAt;
  bool _loaded = false;

  @override
  AppLockState build() =>
      const AppLockState(
        enabled: false,
        locked: false,
        graceSeconds: 0,
        biometricsAvailable: false,
      );

  /// 冷启动初始化：读偏好 + 探测生物识别能力；开了锁 → 直接进入锁定态
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    var enabled = false;
    var grace = 0;
    try {
      final db = ref.read(appDatabaseProvider);
      final enabledRow = await (db.select(
        db.basicInfo,
      )..where((t) => t.key.equals(kAppLockEnabled))).getSingleOrNull();
      enabled = enabledRow?.value == '1';
      final graceRow = await (db.select(
        db.basicInfo,
      )..where((t) => t.key.equals(kAppLockGrace))).getSingleOrNull();
      grace = int.tryParse(graceRow?.value ?? '') ?? 0;
    } catch (_) {
      // 偏好读取失败按未开启处理（应用锁是增强能力，绝不因此挡启动）
    }
    var avail = false;
    try {
      // local_auth 2.x：canCheckBiometrics 是 getter（Future<bool>），不是方法
      avail =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      avail = false;
    }
    state = state.copyWith(
      enabled: enabled && avail, // 无生物识别硬件视为未开启（避免死锁在锁页）
      graceSeconds: grace,
      biometricsAvailable: avail,
      locked: enabled && avail,
    );
  }

  /// 开关（设置面板调用）。开启即刻生效但**不立即锁**——下次切后台/冷启动起作用；
  /// 关闭即解锁（避免用户关掉开关还被锁页拦着）。
  Future<void> setEnabled(bool on) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.basicInfo)
          .insertOnConflictUpdate(
            BasicInfoCompanion.insert(
              key: kAppLockEnabled,
              value: Value(on ? '1' : '0'),
            ),
          );
    } catch (_) {}
    state = state.copyWith(
      enabled: on,
      locked: on ? state.locked : false,
    );
  }

  /// 宽限期（秒）：0 立即 / 60 / 300
  Future<void> setGrace(int seconds) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db
          .into(db.basicInfo)
          .insertOnConflictUpdate(
            BasicInfoCompanion.insert(
              key: kAppLockGrace,
              value: Value('$seconds'),
            ),
          );
    } catch (_) {}
    state = state.copyWith(graceSeconds: seconds);
  }

  /// 切后台：记下时间点（是否锁由 resumed 时按宽限期判定）
  void onPaused() {
    if (!state.enabled) return;
    _pausedAt = DateTime.now();
  }

  /// 回前台：超过宽限期 → 锁定（状态沿 false→true 由根组件监听并 push 解锁页）。
  /// 宽限期 0（立即）时 elapsed 恒 ≥ 0 → 必锁。
  void onResumed() {
    if (!state.enabled || state.locked) return;
    final pausedAt = _pausedAt;
    if (pausedAt == null) return; // 冷启动 resume（init 已处理锁定态）
    final elapsed = DateTime.now().difference(pausedAt).inSeconds;
    if (elapsed >= state.graceSeconds) {
      state = state.copyWith(locked: true);
    }
    _pausedAt = null;
  }

  /// 发起生物识别验证（解锁页调用）。返回是否成功；异常安全降级为失败。
  Future<String?> unlock() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: '请验证指纹/面容以解锁渐离App',
        options: const AuthenticationOptions(
          biometricOnly: false, // 允许退回设备锁屏凭据（PIN/图案），防止生物识别录入失效被锁死
          stickyAuth: true, // 认证中途切后台再回来继续，不直接报失败
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        state = state.copyWith(locked: false);
        return null;
      }
      return '验证未通过';
    } catch (e) {
      return '$e';
    }
  }
}
