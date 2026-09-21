/// 解题唤醒锁 - 思谛 STDeel
///
/// 修复「应用放入后台 / 锁屏后 AI 流式请求必断」的 t0 级问题：
/// Android 在应用进入后台（按 Home、切应用）后，若设备进入 Doze /
/// App Standby，会挂起应用的网络连接，导致正在进行的流式解题连接被
/// 系统切断（Dio 报 unknown / 连接重置）；国产 ROM（荣耀/鸿蒙等）
/// 更会对后台应用直接冻结进程。
///
/// 在解题期间通过 [acquire] 保持设备唤醒（屏幕常亮 + CPU 唤醒锁）并
/// 启动 Android 前台服务（进程提升为前台优先级，不被冻结），
/// 系统不会进入 Doze / 冻结进程，从而保证 AI 流在后台不被切断；
/// 解题结束（成功/失败/取消）后通过 [release] 释放，恢复正常省电策略。
///
/// 使用引用计数：嵌套的 AI 调用（拆题 → 流式解题）共用同一把锁，
/// 只有全部释放后才会真正关闭，避免内层释放把外层锁提前关掉。
library;

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SolveWakelock {
  SolveWakelock._();

  static int _refCount = 0;

  static const MethodChannel _solveChannel =
      MethodChannel('stdeel/solve_service');

  /// 获取唤醒锁（引用计数 +1）。首次获取时才真正启用。
  static Future<void> acquire() async {
    _refCount++;
    if (_refCount == 1) {
      // 1) 屏幕常亮（应用在前台时保持亮屏，防锁屏断网）
      try {
        await WakelockPlus.enable();
      } catch (_) {
        // 平台不支持（如 Web 受限环境）时静默降级，不阻断解题。
      }
      // 2) Android 前台服务 + CPU 唤醒锁：应用切后台也不冻结/不挂起网络。
      //    非 Android 平台（Windows/Web）无此通道，MissingPluginException 静默忽略。
      try {
        await _solveChannel.invokeMethod<void>('start', <String, String>{
          'title': '思谛正在解题',
          'text': 'AI 正在后台思考，请稍候…',
        });
      } catch (_) {
        // 平台不支持 / 通道未注册时静默降级。
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
      try {
        await _solveChannel.invokeMethod<void>('stop');
      } catch (_) {
        // 同上，静默降级。
      }
    }
  }

  /// 是否仍持有唤醒锁（供日志/诊断）。
  static bool get isHeld => _refCount > 0;
}
