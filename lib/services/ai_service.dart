/// AI 调用服务 - 思谛 STDeel
///
/// 前端直连 AI API（OpenAI 兼容），通过 Dio 发起流式请求，
/// 手动解析 SSE 流并检测 `reasoning_content` 字段（think 检测）。
///
/// 关键逻辑：
///   1. POST /chat/completions，body 中 `stream: true`
///   2. 逐行读取 `data:` 前缀的 SSE 帧
///   3. think 超时计时从【发起请求】开始：
///      - 在 thinkTimeout 内收到首个 reasoning_content 或 content 块 → 取消计时
///      - 到点仍无任何内容 → 取消请求并抛 AiFailed（触发 Failover）
///   4. [DONE] 后解析完整 JSON 得到 [QuestionResult]
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/ai_config.dart';
import '../models/solve_result.dart';
import 'fault_log_service.dart';

/// 流式事件，供 UI 与 FailoverManager 消费
abstract class AiStreamEvent {
  const AiStreamEvent();
}

class ThinkingStarted extends AiStreamEvent {
  const ThinkingStarted(this.modelName);
  final String modelName;
}

class ThinkingChunk extends AiStreamEvent {
  const ThinkingChunk(this.text);
  final String text;
}

class AnsweringStarted extends AiStreamEvent {
  const AnsweringStarted(this.modelName);
  final String modelName;
}

class AnsweringChunk extends AiStreamEvent {
  const AnsweringChunk(this.text);
  final String text;
}

class AiDone extends AiStreamEvent {
  const AiDone(this.result);
  final SolveResult result;
}

class AiFailed extends AiStreamEvent {
  const AiFailed(this.reason);
  final String reason;
}

class ThinkTimeoutException implements Exception {
  const ThinkTimeoutException(this.model, this.seconds);
  final String model;
  final int seconds;

  @override
  String toString() => '$model 在 ${seconds}s 内未输出任何内容';
}

class AiService {
  AiService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  void _safeAdd(StreamController<AiStreamEvent> c, AiStreamEvent e) {
    if (!c.isClosed) c.add(e);
  }

  /// 对单个模型发起流式调用，返回事件流。
  Stream<AiStreamEvent> callModelStream({
    required AiModelConfig model,
    required String? base64Image,
    String userPrompt = '',
    int thinkTimeoutSeconds = 20,
    int comboIndex = 0,
  }) {
    final controller = StreamController<AiStreamEvent>();
    final stopWatch = Stopwatch()..start();

    _runStream(
      controller: controller,
      model: model,
      base64Image: base64Image,
      userPrompt: userPrompt,
      thinkTimeoutSeconds: thinkTimeoutSeconds,
      stopWatch: stopWatch,
      comboIndex: comboIndex,
    ).whenComplete(() {
      if (!controller.isClosed) controller.close();
    });

    return controller.stream;
  }

  Future<void> _runStream({
    required StreamController<AiStreamEvent> controller,
    required AiModelConfig model,
    required String? base64Image,
    required String userPrompt,
    required int thinkTimeoutSeconds,
    required Stopwatch stopWatch,
    int comboIndex = 0,
  }) async {
    final url = '${model.endpoint}/chat/completions';
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': AiConfig.systemPrompt},
    ];

    if (base64Image != null && base64Image.isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userPrompt.isEmpty ? '请解题' : userPrompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
          },
        ],
      });
    } else {
      messages.add({
        'role': 'user',
        'content': userPrompt.isEmpty ? '请解题' : userPrompt,
      });
    }

    final body = <String, dynamic>{
      'model': model.model,
      'messages': messages,
      'stream': true,
    };

    // 用 CancelToken 让 think 超时能真正取消 HTTP 请求
    final cancelToken = CancelToken();
    final completer = Completer<void>();

    /// 只发送一次失败事件
    void fail(String reason) {
      if (!completer.isCompleted) {
        completer.complete();
        _safeAdd(controller, AiFailed(reason));
      }
    }

    /// 流被异常切断（未收到 [DONE]）时的收尾尝试：
    /// 若已收齐能解析出题目的回答内容，则按成功收尾返回 true；
    /// 否则返回 false（交由调用方决定重连或报失败）。
    bool _tryFinishPartial(String reasoningContent, String answerContent) {
      if (answerContent.isEmpty) return false;
      final questions = _parseAnswer(answerContent);
      if (questions.isEmpty) return false;
      _safeAdd(
        controller,
        AiDone(SolveResult(
          questions: questions,
          aiModel: model.name,
          latencyMs: stopWatch.elapsedMilliseconds,
          tokensUsed: _estimateTokens(reasoningContent, answerContent),
          source: 'ai',
        )),
      );
      if (!completer.isCompleted) completer.complete();
      return true;
    }

    /// 重置 think 计时（同模型重连后，重新等待模型首字输出）
    /// 注意：必须用可空 Timer，首次 resetThinkTimer() 时 thinkTimer 尚未赋值，
    /// 若用 `late` 无初始化器变量，`thinkTimer?.cancel()` 读取会抛
    /// LateInitializationError，导致整个 _runStream 崩溃（v0.7.5 回归）。
    Timer? thinkTimer;
    void resetThinkTimer() {
      thinkTimer?.cancel();
      thinkTimer = Timer(Duration(seconds: thinkTimeoutSeconds), () {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('think 超时');
        }
        fail('${model.name}（${model.model}）在 ${thinkTimeoutSeconds}s 内'
            '未输出任何内容，已自动切换下一模型');
      });
    }
    resetThinkTimer();

    // 允许一次同模型自动重连：应用在后台/锁屏时 Android 会挂起网络
    // （Doze/App Standby），流式连接被系统切断（Dio 报 unknown 或连接重置）。
    // 此时若尚未产生任何回答内容，重连一次往往能直接恢复，避免误报失败。
    var canRetry = true;

    /// 一次完整的「发起请求 + 消费流」尝试。
    /// 返回 true 表示已终局（成功/失败/超时）；false 表示需要同模型重连。
    Future<bool> attemptOnce() async {
      Response<ResponseBody> response;
      try {
        response = await _dio.post<ResponseBody>(
          url,
          data: body,
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${model.apiKey}',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            },
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(minutes: 5),
          ),
        );
      } on DioException catch (e) {
        thinkTimer?.cancel();
        if (completer.isCompleted) return true; // think 超时已处理
        if (canRetry && _isRetriableDioError(e)) return false;
        fail('请求失败（${model.name}）: '
            '${await _dioErrorText(e,
                source: 'AI 调用 · 解题', comboIndex: comboIndex, model: model)}');
        return true;
      } catch (e) {
        thinkTimer?.cancel();
        if (completer.isCompleted) return true;
        if (canRetry) return false;
        fail('请求失败（${model.name}）: $e');
        return true;
      }

      if (response.data == null) {
        thinkTimer?.cancel();
        fail('响应体为空（${model.name}）');
        return true;
      }

      final stream = response.data!.stream.cast<List<int>>().transform(
        utf8.decoder,
      );
      final buffer = StringBuffer();
      bool thinkingStarted = false;
      bool answeringStarted = false;
      String reasoningContent = '';
      String answerContent = '';

      try {
        await for (final chunk in stream) {
          if (completer.isCompleted) break;

          buffer.write(chunk);

          // 按行拆分，最后一行可能不完整，需保留在 buffer
          final raw = buffer.toString();
          final lines = raw.split('\n');
          buffer.clear();
          buffer.write(lines.removeLast());

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (!trimmed.startsWith('data:')) continue;

            // 'data: ' 或 'data:'
            var data = trimmed.substring(5);
            if (data.startsWith(' ')) data = data.substring(1);

            if (data.trim() == '[DONE]') {
              thinkTimer?.cancel();
              final questions = _parseAnswer(answerContent);
              _safeAdd(
                controller,
                AiDone(SolveResult(
                  questions: questions,
                  aiModel: model.name,
                  latencyMs: stopWatch.elapsedMilliseconds,
                  tokensUsed: _estimateTokens(reasoningContent, answerContent),
                  source: 'ai',
                )),
              );
              if (!completer.isCompleted) completer.complete();
              return true;
            }

            Map<String, dynamic> json;
            try {
              json = jsonDecode(data) as Map<String, dynamic>;
            } catch (_) {
              continue;
            }

            final choices = json['choices'] as List<dynamic>?;
            if (choices == null || choices.isEmpty) continue;
            final delta = (choices[0] as Map<String, dynamic>)['delta']
                as Map<String, dynamic>?;

            if (delta == null) continue;

            final reasoning = delta['reasoning_content'] as String?;
            final content = delta['content'] as String?;
            final hasReasoning = reasoning != null && reasoning.isNotEmpty;
            final hasContent = content != null && content.isNotEmpty;

            // 只要模型开始输出（无论思考还是回答），think 计时即结束
            if (hasReasoning || hasContent) {
              thinkTimer?.cancel();
            }

            if (hasReasoning) {
              if (!thinkingStarted) {
                thinkingStarted = true;
                _safeAdd(controller, ThinkingStarted(model.name));
              }
              reasoningContent += reasoning;
              _safeAdd(controller, ThinkingChunk(reasoning));
            }

            if (hasContent) {
              if (!answeringStarted) {
                answeringStarted = true;
                _safeAdd(controller, AnsweringStarted(model.name));
              }
              answerContent += content;
              _safeAdd(controller, AnsweringChunk(content));
            }
          }
        }
      } catch (e) {
        // 取消触发的异常：completer 已由计时器完成，忽略
        if (!completer.isCompleted) {
          // 网络中断（含后台挂起后连接被切断）：
          //   - 已收齐可解析的完整回答 → 直接收尾（不误报失败/不误切模型）；
          //   - 回答被截断（JSON 不完整）→ 还有重连机会则重发请求，
          //     让同模型重新完整作答，避免展示截断答案或切到下一个模型后
          //     从头再来（v0.7.9 后台解题修复的兜底逻辑）。
          if (_tryFinishPartial(reasoningContent, answerContent)) return true;
          if (canRetry) return false;
          fail('流解析异常（${model.name}）: $e');
        }
        return true;
      }

      thinkTimer?.cancel();
      // 流自然结束但未收到 [DONE]：连接被异常切断（后台挂起/服务器断开）。
      if (completer.isCompleted) return true;
      if (_tryFinishPartial(reasoningContent, answerContent)) return true;
      if (canRetry) return false;
      fail('${model.name} 连接已断开且未返回内容');
      return true;
    }

    // 主循环：最多尝试 2 次（初始 + 1 次同模型重连）
    while (true) {
      final finished = await attemptOnce();
      if (finished) return;
      canRetry = false;
      resetThinkTimer();
      FaultLogService.instance.record(
        source: 'AI 调用 · 解题',
        code: '重连',
        summary: '${model.name} 网络中断，自动重连一次',
        detail: '应用在后台/锁屏或弱网时流式连接被切断（Dio unknown / 连接重置），'
            '已自动重连继续解题。模型：${model.model}',
      );
    }
  }

  /// 判断 DioException 是否值得同模型重连（网络层故障，非业务错误）。
  bool _isRetriableDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        // 后台挂起/弱网抖动多为 connectionError / unknown / 超时
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  /// 从 DioException 中提取可读的错误信息（含 HTTP 状态码与响应体）。
  /// 始终返回中文文案；同时记录一条故障码到 [FaultLogService]：
  ///  - [summary]：中文概要（列表展示，保持简洁）
  ///  - [detail]：原始故障返回信息（API 英文原文 + 模型组合上下文），
  ///    设置页点击单条或复制时使用，便于真正定位问题。
  /// [source] 标明功能界面，如 `AI 调用 · 知识点整理`。
  Future<String> _dioErrorText(
    DioException e, {
    String source = 'AI 调用',
    int comboIndex = 0,
    AiModelConfig? model,
  }) async {
    final resp = e.response;
    if (resp != null) {
      var raw = ''; // API 原始英文错误信息
      final data = resp.data;
      if (data is ResponseBody) {
        try {
          final chunks = await data.stream.toList();
          final text = utf8.decode(
            chunks.expand((c) => c).toList(growable: false),
          );
          final err = _extractApiError(text);
          if (err != null && err.isNotEmpty) raw = err;
        } catch (_) {/* 忽略读取失败 */}
      } else if (data is Map && data['error'] is Map) {
        final m = (data['error'] as Map)['message'];
        if (m != null) raw = '$m';
      } else if (data is Map && data['error'] is String) {
        // 兼容部分供应商/反代返回的 {"error": "..."} 形状
        raw = data['error'] as String;
      } else if (data is Map && data['message'] is String) {
        raw = data['message'] as String;
      }
      final statusCode = resp.statusCode ?? 0;
      final base = _zhHttpMessage(statusCode);
      // 把 API 原始英文错误翻译成中文概要（如 temperature 报错 → 中文说明）
      final apiCn = _zhApiError(raw);
      final comboContext = _comboContext(comboIndex: comboIndex, model: model);
      final summary = _trimCn(base +
          (apiCn.isNotEmpty ? '：$apiCn' : '') +
          (statusCode == 429 && comboContext.isNotEmpty
              ? '（$comboContext）'
              : ''));
      // 详细：原始返回信息 + 模型组合上下文（复制/点击时展示）
      final detail = _trimCn([
        if (raw.isNotEmpty) '原始返回：$raw',
        if (comboContext.isNotEmpty) comboContext,
      ].join('\n'));
      FaultLogService.instance.record(
        source: source,
        code: '$statusCode',
        summary: summary,
        detail: detail,
      );
      return 'HTTP $statusCode $summary';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        FaultLogService.instance.record(
            source: source, code: '超时', summary: '网络连接超时', detail: '连接超时');
        return '连接超时';
      case DioExceptionType.connectionError:
        FaultLogService.instance.record(
            source: source,
            code: '网络',
            summary: '无法连接服务器',
            detail: '无法连接服务器（请检查网络或 Base URL）');
        return '无法连接服务器（请检查网络或 Base URL）';
      case DioExceptionType.badCertificate:
        FaultLogService.instance.record(
            source: source, code: '证书', summary: '证书校验失败', detail: '证书校验失败');
        return '证书校验失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        // unknown 多为连接被重置/后台挂起/代理切断等底层网络故障，
        // 单凭 e.message 常是空串，必须把异常类型、底层 error、请求信息
        // 全部写进 detail，供用户复制反馈时真正定位问题（debug log）。
        final detail = [
          'DioException 类型：${e.type.name}',
          if (e.message != null && e.message!.isNotEmpty) 'message：${e.message}',
          if (e.error != null) '底层 error：${e.error}',
          if (e.response != null)
            'response：${e.response?.statusCode} ${e.response?.statusMessage}',
          '请求：${e.requestOptions.method} ${e.requestOptions.uri}',
          if (e.stackTrace != null)
            '堆栈：${e.stackTrace.toString().split('\n').take(6).join('\n')}',
        ].join('\n');
        FaultLogService.instance.record(
            source: source,
            code: '未知',
            summary: '${e.message ?? e.type.name}（连接被重置/后台挂起？）',
            detail: detail);
        return '网络请求异常（${e.message ?? e.type.name}）';
    }
  }

  /// 把 API 返回的常见英文错误翻译成中文概要；无法识别的返回空串
  /// （此时概要只显示 HTTP 状态码中文，原文保留在 detail 中）。
  String _zhApiError(String raw) {
    final s = raw.toLowerCase();
    if (s.isEmpty) return '';
    if (s.contains('temperature')) return 'temperature 参数不被该模型支持（仅允许默认值）';
    if (s.contains('insufficient_quota') || s.contains('quota')) return '账户额度不足';
    if (s.contains('invalid api key') ||
        s.contains('unauthorized') ||
        s.contains('authentication') ||
        s.contains('apikey')) {
      return 'API Key 无效或认证失败';
    }
    if (s.contains('rate limit') || s.contains('too many requests')) {
      return '触发限流';
    }
    if (s.contains('context length') ||
        s.contains('maximum context') ||
        s.contains('context_window') ||
        s.contains('tokens')) {
      return '超出上下文长度限制';
    }
    if (s.contains('model') &&
        (s.contains('not exist') ||
            s.contains('not found') ||
            s.contains('does not exist') ||
            s.contains('not support'))) {
      return '模型不存在或无权访问';
    }
    if (s.contains('content filter') || s.contains('safety')) {
      return '内容被安全策略拦截';
    }
    if (s.contains('server error') || s.contains('internal error')) {
      return '服务器内部错误';
    }
    return '';
  }

  /// HTTP 状态码 → 中文说明（故障展示统一中文）
  String _zhHttpMessage(int? code) {
    switch (code) {
      case 400:
        return '请求参数有误';
      case 401:
        return '认证失败（API Key 无效或权限不足）';
      case 403:
        return '访问被拒绝（禁止访问，可能是限流或权限不足）';
      case 404:
        return '请求的资源不存在';
      case 405:
        return '请求方法不允许';
      case 408:
        return '请求超时';
      case 409:
        return '资源冲突';
      case 422:
        return '请求内容校验失败';
      case 429:
        return '请求过于频繁，已触发限流，请稍后再试';
      case 500:
        return '服务器内部错误';
      case 502:
        return '网关错误';
      case 503:
        return '服务暂不可用';
      case 504:
        return '网关超时';
      default:
        return code == null ? '未知错误' : 'HTTP 错误（$code）';
    }
  }

  String _trimCn(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// 构造 429 限流记录中的"模型组合"说明，便于用户在故障码记录中直观
  /// 看到是哪家供应商的哪个模型限流。model 为空（非组合流式调用）时返回
  /// 空串，不影响其他来源的故障码记录。
  String _comboContext({required int comboIndex, AiModelConfig? model}) {
    if (model == null) return '';
    final idx = comboIndex + 1;
    String host;
    try {
      final u = Uri.parse(model.endpoint);
      host = u.host.isNotEmpty ? u.host : model.endpoint;
    } catch (_) {
      host = model.endpoint;
    }
    return '模型组合$idx：$host · ${model.model}';
  }

  /// 尝试从响应体文本中提取 error.message
  String? _extractApiError(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] != null) {
          return err['message'].toString();
        }
        if (decoded['message'] != null) return decoded['message'].toString();
      }
    } catch (_) {
      if (text.length <= 160) return text;
    }
    return null;
  }

  /// 解析 AI 返回的内容 → [QuestionResult]
  ///
  /// 优先解析 `{questions: [...]}` 结构；同时兼容模型直接返回单题对象
  /// 或纯数组的情况，尽量降低"解析失败→空结果→误切换"的概率。
  /// 容忍 markdown ```json 围栏。
  List<QuestionResult> _parseAnswer(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```(?:json)?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');

    // 顶层可能直接是数组 [ {...}, {...} ]
    if ((start < 0 || end < 0) && text.startsWith('[')) {
      final a = text.indexOf('[');
      final z = text.lastIndexOf(']');
      if (a >= 0 && z > a) {
        final slice = text.substring(a, z + 1);
        try {
          final list = jsonDecode(slice) as List<dynamic>;
          return list
              .map((e) => QuestionResult.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          return [];
        }
      }
    }
    if (start < 0 || end < 0 || end <= start) return [];
    final slice = text.substring(start, end + 1);
    try {
      final decoded = jsonDecode(slice) as Map<String, dynamic>;
      final list = decoded['questions'] as List<dynamic>?;
      if (list != null) {
        return list
            .map((e) => QuestionResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      // 直接返回单题对象 { content, answer, ... }
      if (decoded['content'] != null || decoded['answer'] != null) {
        return [QuestionResult.fromJson(Map<String, dynamic>.from(decoded))];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  int _estimateTokens(String reasoning, String content) =>
      ((reasoning.length + content.length) / 4).ceil();

  /// 一次性（非流式）生成：把一段文本/若干图片发给单个模型，返回完整文本。
  ///
  /// 用于答案库文档拆分等场景：优先由多模态模型读图/文并输出结构化 JSON。
  /// 失败时抛字符串异常（可读原因）。
  Future<String> generateRaw({
    required AiModelConfig model,
    required String userText,
    List<String> imageDataUrls = const [],
    // null = 不发送 temperature，让 API 使用自身默认值（同解题流式做法），
    // 避免部分模型（如只允许 temperature=1 的推理模型）报 400。
    double? temperature,
    int timeoutSeconds = 180,
    // 故障码记录来源（功能界面），如 `AI 调用 · 知识点整理`
    String source = 'AI 调用',
  }) async {
    final url = '${model.endpoint}/chat/completions';
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': AiConfig.documentSplitPrompt},
    ];
    if (imageDataUrls.isEmpty) {
      messages.add({'role': 'user', 'content': userText});
    } else {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userText},
          for (final du in imageDataUrls)
            {
              'type': 'image_url',
              'image_url': {'url': du},
            },
        ],
      });
    }
    final body = <String, dynamic>{
      'model': model.model,
      'messages': messages,
      'stream': false,
      if (temperature != null) 'temperature': temperature,
    };
    try {
      final resp = await _dio.post<dynamic>(
        url,
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${model.apiKey}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: Duration(seconds: timeoutSeconds),
        ),
      );
      final data = resp.data;
      String? content;
      if (data is Map) {
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final m = (choices[0] as Map)['message'] as Map?;
          final c = m?['content'];
          if (c is String) {
            content = c;
          } else if (c is List) {
            // 兼容 OpenAI 多模态分段的 content（parts 数组）：
            // 逐段取出 text 拼成纯文本，避免误判"模型未返回内容"。
            content = c
                .map((p) =>
                    p is Map ? (p['text'] ?? '').toString() : p.toString())
                .join();
          }
        }
      }
      final text = content?.trim() ?? '';
      if (text.isEmpty) throw '模型未返回内容';
      return text;
    } on DioException catch (e) {
      throw await _dioErrorText(e, source: source, model: model);
    }
  }

  /// 获取模型列表：GET {baseUrl}/models
  ///
  /// 返回按字母排序的模型 ID 列表；失败抛异常（含原因）。
  Future<List<String>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final url = '$baseUrl/models';
    try {
      final resp = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final data = resp.data;
      List<dynamic>? rawList;
      if (data is Map) {
        rawList = data['data'] as List<dynamic>?;
      }
      if (rawList == null) {
        throw '响应格式异常：未找到 data 数组';
      }
      final ids = rawList
          .map((e) {
            if (e is Map && e['id'] != null) return e['id'].toString();
            return e.toString();
          })
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      ids.sort();
      return ids;
    } on DioException catch (e) {
      throw await _dioErrorText(e, source: 'AI 调用 · 获取模型列表');
    }
  }

  /// 连通性测试：向 {baseUrl}/chat/completions 发送一条极小请求。
  ///
  /// 返回 (成功与否, 耗时ms, 详细信息)。
  Future<({bool ok, int latencyMs, String message})> testConnection({
    required String baseUrl,
    required String apiKey,
    required String modelId,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final resp = await _dio.post<dynamic>(
        '$baseUrl/chat/completions',
        data: {
          'model': modelId,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 4,
          'stream': false,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      sw.stop();
      if (resp.statusCode == 200) {
        return (
          ok: true,
          latencyMs: sw.elapsedMilliseconds,
          message: '连接成功，延迟 ${sw.elapsedMilliseconds}ms',
        );
      }
      return (
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        message: 'HTTP ${resp.statusCode}',
      );
    } on DioException catch (e) {
      sw.stop();
      return (
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        message: await _dioErrorText(e, source: 'AI 调用 · 连通性测试'),
      );
    } catch (e) {
      sw.stop();
      return (ok: false, latencyMs: sw.elapsedMilliseconds, message: '$e');
    }
  }
}
