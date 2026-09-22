// 屏幕常亮守卫（阅读器 / 二维码展示等「用户正盯着屏幕」的场景）
//
// 用法：进页 `unawaited(acquireScreenAwake())`、离页 `unawaited(releaseScreenAwake())`。
//
// ⚠️ 为什么不直接调 `WakelockPlus`：`wakelock_plus` 在原生侧是**单个全局开关**
//    （Android 即 Activity 的 `FLAG_KEEP_SCREEN_ON`），**没有引用计数**。若「进页
//    enable / 离页 disable」直连，离页时会**无条件关掉别人正在持有的常亮** —— 典型
//    冲突是文件互传（`TransferClient` 的 #19 后台保活：发送全程持锁）：传大文件时
//    开一次阅读器再退出，传输的常亮就被顺手关掉，息屏后传输可能被系统掐断。
//    故本封装做两件事：
//      ① **引用计数**：多个持有者叠加，最后一个释放才真正关（互传 + 阅读器可共存）；
//      ② **进页前状态快照**：acquire 时若常亮**本来就是开的**（别人持有），只记
//         「不是我开的」，release 时原样不动。
//
// 补充：Android 的 `FLAG_KEEP_SCREEN_ON` 是**窗口级**的 —— App 切后台 / 窗口不可见时
// 由系统自动失效，不存在「后台常亮耗电」，故无需额外做生命周期处理；用户手动按电源键
// 熄屏也照旧（常亮只挡系统自动休眠，不挡用户主动熄屏）。
import 'package:wakelock_plus/wakelock_plus.dart';

/// 当前持有者数量（引用计数）
int _holders = 0;

/// 第一个持有者进页前，常亮是否已由别人（如文件互传）打开
bool _wasOnBefore = false;

/// 申请屏幕常亮（可重入，按引用计数；平台不支持时静默忽略）
Future<void> acquireScreenAwake() async {
  _holders++;
  if (_holders > 1) return;
  _wasOnBefore = false;
  try {
    // 先看原状态：别人已开就只做记录，避免离页时误关
    final wasOn = await WakelockPlus.enabled;
    // ⚠️ 等原生返回期间持有者可能已全部释放（极快的开→关）——此时绝不能再开，
    //    否则会留下「没人持有却常亮」的永久耗电。
    if (_holders == 0) return;
    _wasOnBefore = wasOn;
    if (!wasOn) await WakelockPlus.enable();
  } catch (_) {
    // 平台不支持（桌面 / 单测环境）时忽略：常亮只是体验增强，不该阻断业务
  }
}

/// 释放屏幕常亮（最后一个持有者才真正关，且不误关别人开的）
Future<void> releaseScreenAwake() async {
  if (_holders == 0) return;
  _holders--;
  if (_holders > 0) return;
  final wasOnBefore = _wasOnBefore;
  _wasOnBefore = false;
  if (wasOnBefore) return;
  try {
    await WakelockPlus.disable();
  } catch (_) {
    // 忽略释放失败
  }
}
