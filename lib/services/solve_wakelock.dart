/// 解题唤醒锁 - 思谛 STDeel
///
/// 修复「应用放入后台 / 锁屏后 AI 流式请求必断」的 t0 级问题：
/// Android 在应用进入后台（按 Home、切应用）后，若设备进入 Doze /
/// App Standby，会挂起应用的网络连接，导致正在进行的流式解题连接被
/// 系统切断（Dio 报 unknown / 连接重置）。
///
/// 在解题期间通过 [acquire] 保持设备唤醒（屏幕常亮 + CPU 唤醒），
/// 系统不会进入 Doze，从而保证 AI 流在后台不被切断；
/// 解题结束（成功/失败/取消）后通过 [release] 释放，恢复正常省电策略。
///
/// 使用引用计数：嵌套的 AI 调用（拆题 → 流式解题）共用同一把锁，
/// 只有全部释放后才会真正关闭，避免内层释放把外层锁提前关掉。
library;

import 'package:wakelock_plus/wakelock_plus.dart';

class SolveWakelock {
  SolveWakelock._();

  static int _refCount = 0;

  /// 获取唤醒锁（引用计数 +1）。首次获取时才真正启用。
  static Future<void> acquire() async {
    _refCount++;
    if (_refCount == 1) {
      try {
        await WakelockPlus.enable();
      } catch (_) {
        // 平台不支持（如 Web 受限环境）时静默降级，不阻断解题。
      }
    }
  }

  /// 释放唤醒锁（引用计数 -1）。全部释放后才真正关闭。
  static Future<void> release() async {
    if (_refCount > 0) _refCount--;
    if (_refCount == 0) {
      try {
        await WakelockPlus.disable();
      } catch (_) {
        // 同上，静默降级。
      }
    }
  }

  /// 是否仍持有唤醒锁（供日志/诊断）。
  static bool get isHeld => _refCount > 0;
}
