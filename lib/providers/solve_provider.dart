/// 解题状态管理 - 思谛 STDeel
///
/// Provider 模式：持有 AiService + FailoverManager + SyncService + 通知服务，
/// 暴露 [solve(imagePath)]、[retry(questionId)]、[askDetailed(questionId)]、
/// [markCorrect] / [markWrong] 等动作，并维护解题状态给 UI 监听。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../config/ai_config.dart';
import '../data/database.dart';
import '../models/solve_result.dart';
import '../services/ai_service.dart';
import '../services/backend_api.dart';
import '../services/failover_manager.dart';
import '../services/image_cache_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';


enum SolveStatus { idle, thinking, answering, done, error }

class SolveUiState {
  const SolveUiState({
    this.status = SolveStatus.idle,
    this.reasoningText = '',
    this.answerText = '',
    this.result,
    this.currentModel = '',
    this.notice,
    this.error,
  });

  final SolveStatus status;
  final String reasoningText;
  final String answerText;
  final SolveResult? result;
  final String currentModel;
  final String? notice;
  final String? error;

  SolveUiState copyWith({
    SolveStatus? status,
    String? reasoningText,
    String? answerText,
    SolveResult? result,
    String? currentModel,
    String? notice,
    String? error,
  }) =>
      SolveUiState(
        status: status ?? this.status,
        reasoningText: reasoningText ?? this.reasoningText,
        answerText: answerText ?? this.answerText,
        result: result ?? this.result,
        currentModel: currentModel ?? this.currentModel,
        notice: notice,
        error: error,
      );
}

class SolveProvider extends ChangeNotifier {
  SolveProvider({
    required FailoverManager failoverManager,
    required SyncService syncService,
    required NotificationService notificationService,
    required AppDatabase database,
    required BackendApi backendApi,
    ImageCacheService? imageCacheService,
  })  : _failover = failoverManager,
        _sync = syncService,
        _notifier = notificationService,
        _db = database,
        _api = backendApi,
        _imgCache = imageCacheService ?? ImageCacheService();

  final FailoverManager _failover;
  final SyncService _sync;
  final NotificationService _notifier;
  final AppDatabase _db;
  final BackendApi _api;
  final ImageCacheService _imgCache;

  SolveUiState _state = const SolveUiState();
  SolveUiState get state => _state;

  /// 拍照/选图后触发整轮解题（v0.9.6 起：整图直接交模型流式解答）。
  ///
  /// 0.9.0-0.9.5 的「拆图分割 → 答案库匹配 → 分组解答」两阶段管线实测拆题
  /// 成功率极低、失败后不能自动回退且徒增耗时，已整体移除：现在把原图
  /// （base64）直接交给调用链按序流式解答（Failover 语义保留）。
  Future<void> solve({
    required String imagePath,
    required List<AiModelConfig> models,
    int thinkTimeout = 20,
  }) async {
    if (models.isEmpty) {
      _state = const SolveUiState(
        status: SolveStatus.error,
        error: '未配置可用的 AI 模型，请到「设置 → AI 模型组合」配置供应商与模型',
      );
      notifyListeners();
      return;
    }

    final sw = Stopwatch()..start();
    // 先复制到持久缓存目录：临时目录的图片可能被 OS 随时清掉，
    // 重答/疑问需要从本地取回原图（含完整题干选项 / 图表）。
    final durablePath = await _imgCache.cacheImage(imagePath);
    final file = File(durablePath);
    if (!await file.exists()) {
      _state = const SolveUiState(
        status: SolveStatus.error,
        error: '图片不存在',
      );
      notifyListeners();
      return;
    }
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    _state = const SolveUiState(
      status: SolveStatus.thinking,
      currentModel: '读题解答中',
    );
    notifyListeners();

    await _solveImage(models, base64Image, thinkTimeout, sw, durablePath);
  }

  /// 整图流式解题主路径：把原图直接交给调用链按序尝试（Failover 保留），
  /// 流式事件经 [_handleStreamEvent] 驱动 UI。
  Future<void> _solveImage(
    List<AiModelConfig> models,
    String base64Image,
    int thinkTimeout,
    Stopwatch sw,
    String? durablePath,
  ) async {
    final sub = _failover
        .solve(
          models: models,
          base64Image: base64Image,
          thinkTimeoutSeconds: thinkTimeout,
        )
        .listen((event) => _handleStreamEvent(event, sw, durablePath));
    try {
      await sub.asFuture();
    } catch (_) {}
    await sub.cancel();
  }

  void _handleStreamEvent(AiStreamEvent event, Stopwatch sw, String? imagePath) {
    if (event is ThinkingStarted) {
      // 新一轮(可能是 Failover 切出的新模型)开始思考时清空上一模型的残余文本，
      // 避免不同模型的片段拼接成脏内容上屏。
      _state = _state.copyWith(
        status: SolveStatus.thinking,
        reasoningText: '',
        answerText: '',
        currentModel: event.modelName,
        notice: null,
      );
    } else if (event is ThinkingChunk) {
      _state = _state.copyWith(
        reasoningText: _state.reasoningText + event.text,
      );
    } else if (event is AnsweringStarted) {
      // 开始作答时清空旧答案，防止切换模型后文本串接。
      _state = _state.copyWith(
        status: SolveStatus.answering,
        answerText: '',
        currentModel: event.modelName,
        notice: null,
      );
    } else if (event is AnsweringChunk) {
      _state = _state.copyWith(
        answerText: _state.answerText + event.text,
      );
    } else if (event is ModelFailed) {
      _state = _state.copyWith(
        notice: '${event.modelName} 失败，切换至 ${event.nextModelName}…',
        currentModel: event.nextModelName,
      );
    } else if (event is AiDone) {
      sw.stop();
      // 兜底：AI 未给题号时，按返回顺序编号作为"当次解题题号"。
      final qs = event.result.questions;
      for (var i = 0; i < qs.length; i++) {
        if (qs[i].sessionNo <= 0) qs[i].sessionNo = i + 1;
      }
      final result = SolveResult(
        questions: qs,
        aiModel: event.result.aiModel,
        latencyMs: event.result.latencyMs,
        tokensUsed: event.result.tokensUsed,
        source: 'ai',
        imagePath: imagePath ?? '',
      );
      _state = SolveUiState(
        status: SolveStatus.done,
        result: result,
        currentModel: event.result.aiModel,
      );
      // 持久化到 drift，然后异步上传后端并标记已同步
      _persistResult(result).then((ids) {
        _sync.uploadSolveResult(result, recordIds: ids);
      });
      // 通知
      _notifier.notifySuccess(
        questionCount: result.questions.length,
        elapsed: Duration(milliseconds: result.latencyMs),
      );
    } else if (event is AiFailed) {
      _state = _state.copyWith(
        status: SolveStatus.error,
        error: event.reason,
      );
    }
    notifyListeners();
  }

  /// 写入 drift（每题一行），返回插入的记录 ID 列表。
  /// 同时把数据库主键写回 [QuestionResult.id]，使后续重答/疑问/反馈能命中同一历史记录。
  Future<List<int>> _persistResult(SolveResult result) async {
    final ids = <int>[];
    for (final q in result.questions) {
      final id = await _db.solveRecordDao.insert(
        SolveRecordsCompanion.insert(
          questionText: q.content,
          answer: Value(q.answer),
          solution: Value(q.solution),
          knowledgePoints: Value(jsonEncode(q.knowledgePoints)),
          subject: Value(q.subject),
          aiModel: Value(result.aiModel),
          latencyMs: Value(result.latencyMs),
          tokensUsed: Value(result.tokensUsed),
          matched: const Value(false),
          userFeedback: const Value('none'),
          actionType: const Value('solve'),
          imagePath: Value(result.imagePath),
        ),
      );
      q.id = id; // 写回主键
      ids.add(id);
    }
    return ids;
  }

  /// 标准答案库三层匹配：
  /// 1) 本地 drift hash 精确
  /// 2) 后端 FTS5
  /// 3) 不命中 → 走 AI（上层调用 [solve]）
  Future<QuestionResult?> tryMatchLibrary({
    required String questionText,
    required String questionHash,
  }) async {
    // 1. 本地精确
    final local = await _db.answerLibraryDao.matchByHash(questionHash);
    if (local != null) {
      return QuestionResult(
        id: local.id,
        content: local.questionText,
        knowledgePoints: _decodeKp(local.knowledgePoints),
        answer: local.answer,
        solution: local.solution,
        subject: local.subject,
      );
    }
    // 2. 后端匹配
    try {
      final resp = await _api.matchAnswer(
        questionText: questionText,
        questionHash: questionHash,
      );
      final sim = (resp['similarity'] as num?)?.toDouble() ?? 0.0;
      if (sim >= 0.85 && resp['hit'] == true) {
        final data = Map<String, dynamic>.from(resp['answer'] as Map);
        return QuestionResult(
          id: 0,
          content: questionText,
          knowledgePoints: _decodeKp((data['knowledge_points'] ?? '[]').toString()),
          answer: (data['answer'] ?? '').toString(),
          solution: (data['solution'] ?? '').toString(),
          subject: data['subject']?.toString().trim().isNotEmpty == true
              ? data['subject'].toString().trim()
              : '未分类',
        );
      }
    } catch (_) {
      // 静默
    }
    return null;
  }

  List<String> _decodeKp(String raw) {
    try {
      final l = jsonDecode(raw);
      if (l is List) return l.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  /// "正确"按钮
  Future<void> markCorrect({
    required int questionId,
    required List<String> knowledgePoints,
    String subject = '未分类',
  }) async {
    await _db.solveRecordDao.updateFeedback(questionId, 'correct');
    for (final kp in knowledgePoints) {
      await _db.knowledgeDao.upsert(
        knowledgePoint: kp,
        subject: subject,
        deltaCorrect: 1,
      );
    }
    await _sync.uploadFeedback(questionId, 'correct');
    notifyListeners();
  }

  /// "错误"按钮
  Future<void> markWrong({
    required int questionId,
    required List<String> knowledgePoints,
    String subject = '未分类',
  }) async {
    await _db.solveRecordDao.updateFeedback(questionId, 'wrong');
    for (final kp in knowledgePoints) {
      await _db.knowledgeDao.upsert(
        knowledgePoint: kp,
        subject: subject,
        deltaWrong: 1,
      );
    }
    await _sync.uploadFeedback(questionId, 'wrong');
    notifyListeners();
  }

  /// 纯文本调 AI（重答 / 疑问 / 举一反三共用）。
  ///
  /// 为修复「重答丢失题干选项 / 图表」的产品级问题：
  /// 传入 [imagePath] 时会把原图一并（base64）交给 AI；若未传入，则按
  /// [questionId] 从本地记录取回其缓存图片，尽量保证与首次解题一致的信息量。
  Future<void> _solveText({
    required String userPrompt,
    required int questionId,
    required List<AiModelConfig> models,
    required int thinkTimeout,
    required String startLabel,
    String actionType = 'retry',
    bool overwriteRecord = true,
    String? imagePath,
    bool attachImage = true,
    int sessionNoOverride = 0,
    bool commitAll = false,
  }) async {
    if (models.isEmpty) {
      _state = const SolveUiState(
        status: SolveStatus.error,
        error: '未配置可用的 AI 模型，请到「设置 → AI 模型组合」填写 API Key',
      );
      notifyListeners();
      return;
    }
    _state = SolveUiState(
      status: SolveStatus.thinking,
      currentModel: startLabel,
    );
    notifyListeners();

    // 解析要携带的图片：仅当 attachImage 为 true 时才发送图片。
    // 重答场景不再整图重发，以避免含多题的图片被 AI 全部重答。
    String? base64Image;
    if (attachImage) {
      var imagePathToUse = imagePath;
      final plain = File(imagePathToUse ?? '');
      if (imagePathToUse != null &&
          imagePathToUse.isNotEmpty &&
          await plain.exists()) {
        final bytes = await plain.readAsBytes();
        base64Image = base64Encode(bytes);
      } else if (questionId > 0) {
        final rec = await _db.solveRecordDao.getById(questionId);
        if (rec != null && rec.imagePath.isNotEmpty) {
          final f = File(rec.imagePath);
          if (await f.exists()) {
            imagePathToUse = rec.imagePath;
            base64Image = base64Encode(await f.readAsBytes());
          }
        }
      }
    }

    final sub = _failover
        .solve(
          models: models,
          base64Image: base64Image,
          userPrompt: userPrompt,
          thinkTimeoutSeconds: thinkTimeout,
        )
        .listen((event) async {
      if (event is AiDone) {
        final qs = event.result.questions;
        _state = SolveUiState(
          status: SolveStatus.done,
          result: event.result,
          currentModel: event.result.aiModel,
        );
        if (commitAll) {
          // 举一反三等"生成新题"场景：AI 返回多道变式题，全部各自新建记录，
          // 不得覆盖任何既有历史记录。
          for (final q in qs) {
            if (sessionNoOverride > 0) q.sessionNo = sessionNoOverride;
            await _commitTextResult(
              q,
              event.result,
              dbId: 0,
              actionType: actionType,
            );
          }
        } else {
          final q = qs.isNotEmpty ? qs.first : null;
          if (q != null) {
            // 重答/疑问等单题结果：沿用原题号，保证"当次解题题号"不丢失
            if (sessionNoOverride > 0) q.sessionNo = sessionNoOverride;
            if (overwriteRecord) {
              // 仅当调用方显式给定 questionId 时才覆盖既有记录；
              // 否则一律新建，避免把 AI 返回的题号误当本地主键覆盖历史记录。
              final effectiveId = questionId > 0 ? questionId : 0;
              await _commitTextResult(
                q,
                event.result,
                dbId: effectiveId,
                actionType: actionType,
              );
            }
          }
        }
        notifyListeners();
        return;
      }
      _handleStreamEvent(event, Stopwatch(), null);
    });
    try {
      await sub.asFuture();
    } catch (_) {}
    await sub.cancel();
  }

  /// 重答/疑问结果落库：已有记录则覆盖，否则新建一条，确保能进入历史记录；
  /// 并把最终主键写回 [QuestionResult.id]。
  Future<void> _commitTextResult(
    QuestionResult q,
    SolveResult result, {
    required int dbId,
    required String actionType,
  }) async {
    if (dbId > 0) {
      await _db.solveRecordDao.overwriteAnswer(
        id: dbId,
        answer: q.answer,
        solution: q.solution,
        aiModel: result.aiModel,
        latencyMs: result.latencyMs,
        tokensUsed: result.tokensUsed,
        knowledgePoints: jsonEncode(q.knowledgePoints),
        actionType: actionType,
        subject: q.subject,
      );
      q.id = dbId;
    } else {
      final newId = await _db.solveRecordDao.insert(
        SolveRecordsCompanion.insert(
          questionText: q.content,
          answer: Value(q.answer),
          solution: Value(q.solution),
          knowledgePoints: Value(jsonEncode(q.knowledgePoints)),
          subject: Value(q.subject),
          aiModel: Value(result.aiModel),
          latencyMs: Value(result.latencyMs),
          tokensUsed: Value(result.tokensUsed),
          matched: const Value(false),
          userFeedback: const Value('none'),
          actionType: Value(actionType),
          imagePath: const Value(''),
        ),
      );
      q.id = newId;
    }
  }

  /// "重答"按钮：仅针对该道题用纯文本重调 AI 覆盖答案，不重发整张图片，
  /// 避免含多题的图片被 AI 全部重答。
  Future<void> retry({
    required int questionId,
    required String questionText,
    required List<AiModelConfig> models,
    int thinkTimeout = 20,
    String? imagePath,
    int sessionNoOverride = 0,
  }) =>
      _solveText(
        // 不再整图重发：仅针对这一道题重新解答，明确要求只输出该题结果，
        // 避免图片含多题时 AI 把所有题目全部重答一遍。
        userPrompt:
            '请仅仅针对下面这一道题重新解答，给出新的答案与详细解答。'
            '只输出这一道题的结果，把该题单独放入 questions 数组返回；'
            '不要尝试解答、也不要返回该题所属试卷/图片中的其他任何题目。\n\n'
            '题目如下：\n$questionText',
        questionId: questionId,
        models: models,
        thinkTimeout: thinkTimeout,
        startLabel: '重答中',
        actionType: 'retry',
        attachImage: false,
        sessionNoOverride: sessionNoOverride,
      );

  /// "疑问"按钮：附加详细分步指令；同样携带原图。
  ///
  /// [commitAll] 为 true 时（知识点页"举一反三"等生成新题场景），
  /// AI 返回的每一道题都各自新建一条记录，不覆盖既有历史记录。
  Future<void> askDetailed({
    required int questionId,
    required String questionText,
    required List<AiModelConfig> models,
    int thinkTimeout = 20,
    String? imagePath,
    int sessionNoOverride = 0,
    bool commitAll = false,
  }) =>
      _solveText(
        userPrompt: '$questionText${AiConfig.detailedSolutionSuffix}',
        questionId: questionId,
        models: models,
        thinkTimeout: thinkTimeout,
        startLabel: '解答中',
        actionType: 'detail',
        imagePath: imagePath,
        sessionNoOverride: sessionNoOverride,
        commitAll: commitAll,
      );

  /// 计算题目哈希（与本地答案库一致）
  String hashOf(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
