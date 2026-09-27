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
    required AiService aiService,
    required FailoverManager failoverManager,
    required SyncService syncService,
    required NotificationService notificationService,
    required AppDatabase database,
    required BackendApi backendApi,
    ImageCacheService? imageCacheService,
  })  : _ai = aiService,
        _failover = failoverManager,
        _sync = syncService,
        _notifier = notificationService,
        _db = database,
        _api = backendApi,
        _imgCache = imageCacheService ?? ImageCacheService();

  final AiService _ai;
  final FailoverManager _failover;
  final SyncService _sync;
  final NotificationService _notifier;
  final AppDatabase _db;
  final BackendApi _api;
  final ImageCacheService _imgCache;

  /// 多候选卷次暂停期间暂存的拆题结果与上下文（UI 弹窗选择后 resume）
  List<QuestionResult>? _pendingExtracted;
  List<AnswerPaperEntity>? _pendingPapers;
  List<AiModelConfig>? _pendingSplitModels;
  List<AiModelConfig>? _pendingPlainModels;
  List<AiModelConfig>? _pendingMultimodalModels;
  int? _pendingThinkTimeout;
  Stopwatch? _pendingSw;
  String? _pendingDurablePath;

  /// 当前是否有"多候选卷次"待用户选择
  bool get hasPaperChoice => _pendingExtracted != null;

  /// 待用户选择的候选卷次（弹窗展示用）
  List<AnswerPaperEntity>? get pendingPapers => _pendingPapers;

  SolveUiState _state = const SolveUiState();
  SolveUiState get state => _state;

  /// 拍照/选图后触发整轮解题（v0.9.0 两阶段管线）：
  /// Stage A 拆图分割（多模态提取题目，无法转文字的标记 needsMultimodal）
  /// → 答案库匹配（命中直出）
  /// → Stage B 读题解答（未标记题优先非多模态省经费；标记题/失败回退多模态；
  ///   命中答案库直接出答案；多模态与非多模态来自不同供应商时并行）。
  ///
  /// [splitModels]：拆图分割阶段的多模态链；[plainModels]/[multimodalModels]：
  /// 读题解答阶段的非多模态/多模态链。
  Future<void> solve({
    required String imagePath,
    required List<AiModelConfig> splitModels,
    required List<AiModelConfig> plainModels,
    required List<AiModelConfig> multimodalModels,
    int thinkTimeout = 20,
  }) async {
    final solveChain = [...plainModels, ...multimodalModels];
    if (splitModels.isEmpty && solveChain.isEmpty) {
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
      currentModel: '拆图识别中',
    );
    notifyListeners();

    // Stage A：拆图分割（仅多模态链；无多模态则直接整图解题）
    List<QuestionResult> extracted;
    if (splitModels.isEmpty) {
      extracted = const [];
    } else {
      extracted = await _trySplitImage(splitModels, base64Image);
    }

    // 拆图失败/无题：回退整图解题（原单阶段路径，streaming 保留）
    if (extracted.isEmpty) {
      await _fallbackSolve(
          solveChain, base64Image, thinkTimeout, sw, durablePath, const []);
      return;
    }

    // Stage B 第一步：答案库匹配（含卷次+题号认领）
    final match = await _matchFromLibrary(extracted);
    if (match.paperChoice != null && match.paperChoice!.isNotEmpty) {
      // 多个卷次候选：暂停，等待 UI 弹窗选择后再继续
      _pendingExtracted = extracted;
      _pendingPapers = match.paperChoice;
      _pendingSplitModels = splitModels;
      _pendingPlainModels = plainModels;
      _pendingMultimodalModels = multimodalModels;
      _pendingThinkTimeout = thinkTimeout;
      _pendingSw = sw;
      _pendingDurablePath = durablePath;
      _state = _state.copyWith(
        status: SolveStatus.thinking,
        currentModel: '选择卷次',
        notice: '检测到多套答案册可能包含本页题目，请选择当前卷次',
      );
      notifyListeners();
      return;
    }

    await _finishMatch(
      extracted,
      match.hits,
      splitModels,
      plainModels,
      multimodalModels,
      thinkTimeout,
      sw,
      durablePath,
    );
  }

  /// 用户在多候选卷次弹窗中选择后，以该卷逐题认领并收尾
  Future<void> resumeWithPaper(int paperId) async {
    final extracted = _pendingExtracted;
    _clearPendingChoice();
    final splitModels = _pendingSplitModels ?? const [];
    final plainModels = _pendingPlainModels ?? const [];
    final multimodalModels = _pendingMultimodalModels ?? const [];
    final thinkTimeout = _pendingThinkTimeout ?? 20;
    final sw = _pendingSw ?? Stopwatch();
    final durablePath = _pendingDurablePath;
    _pendingSplitModels = null;
    _pendingPlainModels = null;
    _pendingMultimodalModels = null;
    _pendingThinkTimeout = null;
    _pendingSw = null;
    _pendingDurablePath = null;
    if (extracted == null || extracted.isEmpty) return;

    _state = _state.copyWith(
      status: SolveStatus.thinking,
      currentModel: '匹配答案中',
      notice: null,
    );
    notifyListeners();

    final hits = <QuestionResult>[];
    for (final q in extracted) {
      if (q.questionNo <= 0) continue;
      final entry =
          await _db.answerLibraryDao.findByPaperAndNo(paperId, q.questionNo);
      if (entry != null) {
        hits.add(await _materializeMatch(entry, q));
      }
    }
    await _finishMatch(
      extracted,
      hits,
      splitModels,
      plainModels,
      multimodalModels,
      thinkTimeout,
      sw,
      durablePath,
    );
  }

  /// 用户取消卷次选择：清空暂存，并以整图流式解题回退
  Future<void> cancelPaperChoice() async {
    final extracted = _pendingExtracted;
    final plainModels = _pendingPlainModels ?? const [];
    final multimodalModels = _pendingMultimodalModels ?? const [];
    final thinkTimeout = _pendingThinkTimeout ?? 20;
    final sw = _pendingSw ?? Stopwatch();
    final durablePath = _pendingDurablePath;
    _clearPendingChoice();
    _pendingSplitModels = null;
    _pendingPlainModels = null;
    _pendingMultimodalModels = null;
    _pendingThinkTimeout = null;
    _pendingSw = null;
    _pendingDurablePath = null;
    _state = _state.copyWith(notice: null);
    notifyListeners();
    if (extracted == null || durablePath == null) return;
    final bytes = await File(durablePath).readAsBytes();
    await _fallbackSolve(
      [...plainModels, ...multimodalModels],
      base64Encode(bytes),
      thinkTimeout,
      sw,
      durablePath,
      const [],
    );
  }

  void _clearPendingChoice() {
    _pendingExtracted = null;
    _pendingPapers = null;
  }

  /// 收尾：全部命中直接出结果；否则按「未标记/已标记」分组读题解答
  Future<void> _finishMatch(
    List<QuestionResult> extracted,
    List<QuestionResult> hits,
    List<AiModelConfig> splitModels,
    List<AiModelConfig> plainModels,
    List<AiModelConfig> multimodalModels,
    int thinkTimeout,
    Stopwatch sw,
    String? durablePath,
  ) async {
    if (hits.length == extracted.length && extracted.isNotEmpty) {
      // 全部命中：直接出结果，不调用解题 AI
      for (var i = 0; i < hits.length; i++) {
        hits[i].sessionNo = i + 1;
      }
      final result = SolveResult(
        questions: hits,
        aiModel: '答案库',
        latencyMs: sw.elapsedMilliseconds,
        tokensUsed: 0,
        source: 'answer_library',
        imagePath: durablePath ?? '',
      );
      _state = SolveUiState(
        status: SolveStatus.done,
        result: result,
        currentModel: '答案库',
      );
      _persistMatchedResult(result);
    _notifier.notifySuccess(
        questionCount: result.questions.length,
        elapsed: Duration(milliseconds: result.latencyMs),
      );
      notifyListeners();
      return;
    }

    // 有未命中：取未命中题目，进入读题解答阶段
    if (durablePath == null) {
      _state = _state.copyWith(
        status: SolveStatus.error,
        error: '图片读取失败，请重试',
      );
      notifyListeners();
      return;
    }
    final bytes = await File(durablePath).readAsBytes();
    await _solveStageB(
      extracted: extracted,
      hits: hits,
      plainModels: plainModels,
      multimodalModels: multimodalModels,
      thinkTimeout: thinkTimeout,
      sw: sw,
      durablePath: durablePath,
      base64Image: base64Encode(bytes),
    );
  }

  /// 读题解答阶段（Stage B）：
  /// - 命中答案库的题直接出答案；
  /// - 未命中中「已标记需多模态」的题 → 多模态链（带原图）；
  /// - 未命中中「未标记」且非多模态链可用的题 → 非多模态链（省经费）；
  /// - 当「已标记多模态组」与「未标记普通组」来自不同供应商（Base URL+API Key 不同）
  ///   且两者都需解题时，并行发送两组请求再合并。
  Future<void> _solveStageB({
    required List<QuestionResult> extracted,
    required List<QuestionResult> hits,
    required List<AiModelConfig> plainModels,
    required List<AiModelConfig> multimodalModels,
    required int thinkTimeout,
    required Stopwatch sw,
    String? durablePath,
    required String base64Image,
  }) async {
    // 未命中题干集合（hits 的 content 视为已解决）
    final hitContents = hits.map((h) => h.content.trim()).where((c) => c.isNotEmpty).toSet();
    final remaining = extracted
        .where((q) => !hitContents.contains(q.content.trim()))
        .toList();
    if (remaining.isEmpty) {
      // 全部命中已在前面处理；这里理论上不会进入
      return;
    }

    final marked = remaining.where((q) => q.needsMultimodal).toList();
    final normal = remaining.where((q) => !q.needsMultimodal).toList();

    final plainNonEmpty = plainModels.isNotEmpty;
    final multiNonEmpty = multimodalModels.isNotEmpty;
    final differentProvider = plainModels.isNotEmpty &&
        multimodalModels.isNotEmpty &&
        !_sameProvider(plainModels.first, multimodalModels.first);
    final canParallel = marked.isNotEmpty &&
        normal.isNotEmpty &&
        differentProvider &&
        plainNonEmpty &&
        multiNonEmpty;

    _state = _state.copyWith(
      status: SolveStatus.thinking,
      currentModel: canParallel ? '并行解答中' : '读题解答中',
      reasoningText: '',
      answerText: '',
      notice: null,
    );
    notifyListeners();

    if (canParallel) {
      // 并行：已标记→多模态（带原图），未标记→非多模态（纯文本）
      final f1 = _streamSolveGroup(
        group: marked,
        chain: multimodalModels,
        base64Image: base64Image,
        thinkTimeout: thinkTimeout,
      );
      final f2 = _streamSolveGroup(
        group: normal,
        chain: plainModels,
        base64Image: null,
        thinkTimeout: thinkTimeout,
      );
      final r1 = await f1;
      final r2 = await f2;
      final merged = <QuestionResult>[
        ...?r1,
        ...?r2,
      ];
      if (merged.isEmpty) {
        _state = _state.copyWith(
          status: SolveStatus.error,
          error: '所有 AI 模型均未返回有效结果',
        );
        notifyListeners();
        return;
      }
      _emitDone(merged, sw, durablePath);
      return;
    }

    // 单一路径（最常用）：优先非多模态（成本优先），失败自动切多模态。
    // 带原图，使标记题（图形/绘图）可由多模态模型正确识别。
    final chain = [...plainModels, ...multimodalModels];
    await _fallbackSolve(chain, base64Image, thinkTimeout, sw, durablePath, remaining);
  }

  /// 判断两组模型是否属同一供应商（Base URL + API Key 均相同则视为同一家）。
  bool _sameProvider(AiModelConfig a, AiModelConfig b) =>
      a.endpoint == b.endpoint && a.apiKey == b.apiKey;

  /// 非流式收集单组解答结果（用于跨供应商并行分支）。
  /// 返回 null 表示该组无有效结果。
  Future<List<QuestionResult>?> _streamSolveGroup({
    required List<QuestionResult> group,
    required List<AiModelConfig> chain,
    String? base64Image,
    required int thinkTimeout,
  }) async {
    if (chain.isEmpty || group.isEmpty) return null;
    // 纯文本模式：把本组题目拼进 userPrompt；带图模式由模型自己读图。
    final userPrompt = base64Image == null
        ? '请解答以下题目，仅返回这些题的 JSON：\n'
            '${group.map((q) => '题号 ${q.questionNo > 0 ? q.questionNo : ''}：${q.content}').join('\n')}'
        : '';
    final collected = <QuestionResult>[];
    final sub = _failover
        .solve(
          models: chain,
          base64Image: base64Image,
          userPrompt: userPrompt,
          thinkTimeoutSeconds: thinkTimeout,
        )
        .listen((event) {
          if (event is AiDone) collected.addAll(event.result.questions);
        });
    try {
      await sub.asFuture();
    } catch (_) {}
    await sub.cancel();
    return collected.isEmpty ? null : collected;
  }

  /// 并行分支合并结果后统一收尾（完成态 + 落库 + 通知）。
  void _emitDone(List<QuestionResult> questions, Stopwatch sw, String? imagePath) {
    sw.stop();
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].sessionNo <= 0) questions[i].sessionNo = i + 1;
    }
    final result = SolveResult(
      questions: questions,
      aiModel: 'AI',
      latencyMs: sw.elapsedMilliseconds,
      tokensUsed: questions.fold(0, (s, q) => s + q.content.length ~/ 4),
      source: 'ai',
      imagePath: imagePath ?? '',
    );
    _state = SolveUiState(
      status: SolveStatus.done,
      result: result,
      currentModel: 'AI',
    );
    _persistResult(result).then((ids) {
      _sync.uploadSolveResult(result, recordIds: ids);
    });
    _notifier.notifySuccess(
      questionCount: result.questions.length,
      elapsed: Duration(milliseconds: result.latencyMs),
    );
    notifyListeners();
  }

  /// 回退路径：整图流式解题（保留 streaming UX）
  Future<void> _fallbackSolve(
    List<AiModelConfig> models,
    String base64Image,
    int thinkTimeout,
    Stopwatch sw,
    String? durablePath,
    List<QuestionResult>? scope,
  ) async {
    final sub = _failover
        .solve(
          models: models,
          base64Image: base64Image,
          thinkTimeoutSeconds: thinkTimeout,
        )
        .listen((event) => _handleStreamEvent(event, sw, durablePath));
    await sub.asFuture();
    await sub.cancel();
  }

  /// Stage A 拆图分割：按拆图分割链（多模态）逐个尝试，AI 提取题目并标记
  /// 无法转文字的题（needsMultimodal）。全部失败或未解析出题目返回空列表，
  /// 由调用方回退整图解题。
  Future<List<QuestionResult>> _trySplitImage(
    List<AiModelConfig> splitModels,
    String base64Image,
  ) async {
    final dataUrl = 'data:image/jpeg;base64,$base64Image';
    for (final m in splitModels) {
      try {
        final raw = await _ai.generateRaw(
          model: m,
          userText: '请按提示词拆图分割。',
          imageDataUrls: [dataUrl],
          timeoutSeconds: 90,
          source: 'AI 调用 · 拆图分割',
          systemPrompt: AiConfig.imageSplitPrompt,
        );
        final qs = _parseExtracted(raw);
        if (qs.isNotEmpty) return qs;
      } catch (_) {
        // 该模型失败：尝试下一个拆图分割模型
      }
    }
    return const [];
  }

  /// 解析拆题 JSON（容忍 markdown 围栏 / 前导说明文字）
  List<QuestionResult> _parseExtracted(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```(?:json)?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return const [];
    try {
      final decoded = jsonDecode(text.substring(start, end + 1))
          as Map<String, dynamic>;
      final list = decoded['questions'] as List<dynamic>? ?? const [];
      return list
          .map((e) => QuestionResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 答案库匹配：先题干 hash 精确，再卷次+题号认领（无题干条目）。
  /// 返回命中列表与（若有）需用户确认的多候选卷次。
  Future<({List<QuestionResult> hits, List<AnswerPaperEntity>? paperChoice})>
      _matchFromLibrary(List<QuestionResult> extracted) async {
    final hits = <QuestionResult>[];
    final rest = <QuestionResult>[];

    // ① 题干 hash 精确匹配（已反哺的完整条目）
    for (final q in extracted) {
      if (q.content.trim().isEmpty) {
        rest.add(q);
        continue;
      }
      final local = await _db.answerLibraryDao.matchByHash(hashOf(q.content));
      if (local != null && local.questionText.isNotEmpty) {
        hits.add(_fromLibrary(local, q));
      } else {
        rest.add(q);
      }
    }

    // ② 卷次+题号认领（无题干条目）
    final nos = rest.map((q) => q.questionNo).where((n) => n > 0).toSet();
    if (nos.isNotEmpty) {
      final candidates = await _db.answerLibraryDao.findByNos(nos);
      final papers = await _candidatePapers(candidates);
      if (papers.length == 1) {
        final pid = papers.single.id;
        for (final q in rest) {
          if (q.questionNo <= 0) continue;
          final entry =
              await _db.answerLibraryDao.findByPaperAndNo(pid, q.questionNo);
          if (entry != null) {
            hits.add(await _materializeMatch(entry, q));
          }
        }
      } else if (papers.length > 1) {
        // 多候选卷次：交由 UI 弹窗选择
        return (hits: hits, paperChoice: papers);
      }
    }
    return (hits: hits, paperChoice: null);
  }

  /// 从候选条目中找出"命中题号数最多"的卷次；
  /// 并列第一（多套卷命中数相同）时返回全部并列卷次，交由用户确认。
  Future<List<AnswerPaperEntity>> _candidatePapers(
    List<AnswerLibraryEntity> candidates,
  ) async {
    final byPaper = <int, List<AnswerLibraryEntity>>{};
    for (final c in candidates) {
      final pid = c.paperId;
      if (pid == null) continue;
      byPaper.putIfAbsent(pid, () => []).add(c);
    }
    if (byPaper.isEmpty) return const [];
    final sorted = byPaper.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final best = sorted.first.value.length;
    final bestPapers =
        sorted.where((e) => e.value.length == best).toList(growable: false);
    final papers = <AnswerPaperEntity>[];
    for (final e in bestPapers) {
      final p = await _db.answerPaperDao.getById(e.key);
      if (p != null) papers.add(p);
    }
    return papers;
  }

  /// 把答案库条目转为解题结果；"无题干条目"顺带用拆题题干反哺补全
  Future<QuestionResult> _materializeMatch(
    AnswerLibraryEntity entry,
    QuestionResult q,
  ) async {
    if (q.content.trim().isNotEmpty && entry.questionHash.isEmpty) {
      await _db.answerLibraryDao.enrichContent(
        entry.id,
        questionText: q.content,
        questionHash: hashOf(q.content),
        subject: entry.subject,
      );
    }
    return _fromLibrary(entry, q);
  }

  /// 答案库条目 → 解题结果
  QuestionResult _fromLibrary(AnswerLibraryEntity entry, QuestionResult q) {
    final content = q.content.isNotEmpty ? q.content : entry.questionText;
    return QuestionResult(
      id: 0,
      sessionNo: q.sessionNo > 0 ? q.sessionNo : q.questionNo,
      content: content,
      knowledgePoints: _decodeKp(entry.knowledgePoints),
      answer: entry.answer,
      solution: entry.solution,
      subject: entry.subject,
      questionNo: q.questionNo,
    );
  }

  /// 全部命中答案库的结果落库（matched=true，不上传后端）
  Future<void> _persistMatchedResult(SolveResult result) async {
    for (final q in result.questions) {
      final id = await _db.solveRecordDao.insert(
        SolveRecordsCompanion.insert(
          questionText: q.content,
          answer: Value(q.answer),
          solution: Value(q.solution),
          knowledgePoints: Value(jsonEncode(q.knowledgePoints)),
          subject: Value(q.subject),
          aiModel: const Value('答案库'),
          latencyMs: Value(result.latencyMs),
          tokensUsed: const Value(0),
          matched: const Value(true),
          // 答案库命中仅为本地记录：直接标记已同步，避免 flushUnsynced
          // 整条上传到后端（与上方注释"不上传后端"的意图一致）。
          synced: const Value(true),
          userFeedback: const Value('none'),
          actionType: const Value('solve'),
          imagePath: Value(result.imagePath),
        ),
      );
      q.id = id;
    }
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
