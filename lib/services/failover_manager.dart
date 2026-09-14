/// Failover 管理器 - 思谛 STDeel
///
/// 用户在设置页配置任意数量的 AI 组合（有序列表），
/// 解题时按顺序依次尝试：
///   - 某组合在 think 超时内未输出任何内容 → 自动切换下一个
///   - 请求失败（网络/鉴权等）→ 记录原因并切换下一个
///   - 全部失败 → 汇总每个组合的具体失败原因返回给 UI
///
/// 每次降级发送通知 + 记录日志。
library;

import 'dart:async';

import '../config/ai_config.dart';
import 'ai_service.dart';
import 'notification_service.dart';
import 'solve_wakelock.dart';

class FailoverLogEntry {
  FailoverLogEntry(this.timestamp, this.message);

  final DateTime timestamp;
  final String message;

  @override
  String toString() => '${timestamp.toIso8601String()} | $message';
}

/// 单个模型失败（将切换到下一个），供 UI 展示切换进度
class ModelFailed extends AiStreamEvent {
  const ModelFailed(this.modelName, this.reason, this.nextModelName);
  final String modelName;
  final String reason;
  final String nextModelName;
}

class FailoverManager {
  FailoverManager({
    required AiService aiService,
    required NotificationService notificationService,
  })  : _ai = aiService,
        _notifier = notificationService;

  final AiService _ai;
  final NotificationService _notifier;
  final List<FailoverLogEntry> logs = [];

  void _log(String msg) {
    logs.add(FailoverLogEntry(DateTime.now(), msg));
    // 限制日志规模，避免长生命周期下无界内存增长。
    const maxLogs = 200;
    if (logs.length > maxLogs) {
      logs.removeRange(0, logs.length - maxLogs);
    }
  }

  /// 按组合顺序尝试，首个成功的模型透传其事件流。
  /// 全部失败时发出携带全部原因的 [AiFailed] 终止事件。
  ///
  /// [base64Image] 不为空时发送多模态请求；为空时发送 [userPrompt] 纯文本。
  Stream<AiStreamEvent> solve({
    required List<AiModelConfig> models,
    required String? base64Image,
    int thinkTimeoutSeconds = 20,
    String userPrompt = '',
  }) {
    final controller = StreamController<AiStreamEvent>();
    _run(controller, models, base64Image, thinkTimeoutSeconds, userPrompt);
    return controller.stream;
  }

  Future<void> _run(
    StreamController<AiStreamEvent> controller,
    List<AiModelConfig> models,
    String? base64Image,
    int thinkTimeoutSeconds,
    String userPrompt,
  ) async {
    bool done = false;
    final failures = <String>[];

    // 解题期间保持设备唤醒（后台/锁屏不断流）：
    // AI 流式调用可能持续数分钟，期间用户可能按 Home / 锁屏，
    // Android Doze/App Standby 会挂起网络导致连接被切断。
    // 引用计数式锁：拆题等其他 AI 调用也共用，全部结束后才释放。
    await SolveWakelock.acquire();
    try {
      if (models.isEmpty) {
        const msg = '未配置可用的 AI 模型，请到「设置 → AI 模型组合」添加';
        _log(msg);
        controller.add(const AiFailed(msg));
        return;
      }

      for (var i = 0; i < models.length; i++) {
        final model = models[i];
        final (ok, reason) = await _trySingleStage(
          controller: controller,
          model: model,
          base64Image: base64Image,
          userPrompt: userPrompt,
          thinkTimeoutSeconds: thinkTimeoutSeconds,
          comboIndex: i,
        );
        if (ok) {
          done = true;
          break;
        }
        failures.add('${model.name}（${model.model}）：${reason ?? '无响应'}');

        if (i < models.length - 1) {
          final next = models[i + 1];
          final switchMsg = '${model.name} 失败，自动切换至 ${next.name}';
          _log('$switchMsg\n原因：$reason');
          _notifier.notifyFailover(switchMsg);
          if (!controller.isClosed) {
            controller.add(ModelFailed(model.name, reason ?? '无响应', next.name));
          }
        }
      }

      if (!done) {
        final msg =
            '所有 AI 组合均失败：\n${failures.join('\n')}';
        _log(msg);
        _notifier.notifyFailure('解题失败：所有 AI 组合均不可用');
        if (!controller.isClosed) {
          controller.add(AiFailed(msg));
        }
      }
    } catch (e) {
      final msg = 'Failover 内部错误: $e';
      _log(msg);
      _notifier.notifyFailure(msg);
      if (!controller.isClosed) {
        controller.add(AiFailed(msg));
      }
    } finally {
      await SolveWakelock.release();
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  /// 单个模型尝试：监听子流，失败（超时/请求错误）即返回原因。
  Future<(bool, String?)> _trySingleStage({
    required StreamController<AiStreamEvent> controller,
    required AiModelConfig model,
    required String? base64Image,
    required String userPrompt,
    required int thinkTimeoutSeconds,
    required int comboIndex,
  }) async {
    final subCompleter = Completer<(bool, String?)>();
    String? failureReason;
    StreamSubscription? sub;

    sub = _ai.callModelStream(
      model: model,
      base64Image: base64Image,
      userPrompt: userPrompt,
      thinkTimeoutSeconds: thinkTimeoutSeconds,
      comboIndex: comboIndex,
    ).listen(
      (event) {
        if (event is AiFailed) {
          failureReason = event.reason;
          if (!subCompleter.isCompleted) {
            subCompleter.complete((false, event.reason));
          }
          return;
        }
        if (event is AiDone) {
          // AI 返回了内容但未解析出任何有效题目结构（如 JSON 截断 / 键名不符）
          // 时，将其视为该模型失败并自动切换下一模型，避免出现"空结果被当作成功"。
          if (event.result.questions.isEmpty) {
            failureReason = '模型未返回有效题目结构（解析结果为空）';
            if (!subCompleter.isCompleted) {
              subCompleter.complete((false, failureReason));
            }
            return;
          }
          if (!controller.isClosed) controller.add(event);
          if (!subCompleter.isCompleted) subCompleter.complete((true, null));
          return;
        }
        if (!controller.isClosed) controller.add(event);
      },
      onError: (e) {
        failureReason = '$e';
        if (!subCompleter.isCompleted) {
          subCompleter.complete((false, '$e'));
        }
      },
      onDone: () {
        if (!subCompleter.isCompleted) {
          subCompleter.complete((false, failureReason ?? '连接中断'));
        }
      },
    );

    final result = await subCompleter.future;
    await sub.cancel();
    return result;
  }
}
