/// 数据同步服务 - 思谛 STDeel
///
/// 上行同步（前端→后端）：
///   - 解题完成后异步上传记录（不阻塞 UI）
///   - 用户点击"正确/错误"后异步更新后端统计
///   - 标准答案上传后同步至后端
///   - 离线时 drift 本地缓存，联网后批量同步
///
/// 下行同步（后端→前端）：
///   - 应用启动时拉取最新标准答案库更新本地 drift 缓存
///   - 知识点统计数据按需拉取
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/database.dart';
import '../models/solve_result.dart';
import 'backend_api.dart';

/// 一次手动同步的结果统计，用于设置页展示"上传成功/失败 x 条、回写 x 条"。
class SyncResult {
  const SyncResult({
    this.uploaded = 0,
    this.uploadFailed = 0,
    this.pulled = 0,
  });

  /// 本地上行成功的记录数
  final int uploaded;
  /// 本地上行失败的记录数
  final int uploadFailed;
  /// 从后端下拉并写回本地（新增或更新）的记录数
  final int pulled;

  bool get hasFailure => uploadFailed > 0;
  int get totalUploaded => uploaded + uploadFailed;

  @override
  String toString() =>
      '上传成功 ${uploaded} 条${uploadFailed > 0 ? '，失败 $uploadFailed 条' : '，无失败'}'
      '，回写 $pulled 条';
}

class SyncService {
  SyncService({
    required AppDatabase database,
    required BackendApi backendApi,
  })  : _db = database,
        _api = backendApi;

  final AppDatabase _db;
  final BackendApi _api;

  /// 解题完成后异步上传（不阻塞 UI）
  Future<void> uploadSolveResult(
    SolveResult result, {
    List<int>? recordIds,
  }) async {
    try {
      final payload = <String, dynamic>{
        'ai_model': result.aiModel,
        'latency_ms': result.latencyMs,
        'tokens_used': result.tokensUsed,
        'source': result.source,
        'image_path': result.imagePath,
        'questions':
            result.questions.map((q) => q.toJson()).toList(growable: false),
      };
      final ids = await _api.uploadSolveRecord(payload);
      if (recordIds != null) {
        // 后端按顺序返回与本次上传一一对应的 id 时才写回 remoteId 并标记
        // 已同步；否则保持未同步（synced=false），由后续 flushUnsynced 整条
        // 补传——若在无 remoteId 时强行 markSynced，反馈/删除将永久失效，
        // 且下拉同步会因本地 remoteId 为空而重复插入记录。
        if (ids.length == recordIds.length) {
          for (var i = 0; i < recordIds.length; i++) {
            await _db.solveRecordDao.setRemoteId(recordIds[i], ids[i]);
          }
          for (final id in recordIds) {
            await _db.solveRecordDao.markSynced(id);
          }
        }
      }
    } catch (_) {
      // 静默失败：离线时 drift 已有记录，下次手动同步可补
    }
  }

  /// 反馈更新（"正确/错误"按钮）。
  ///
  /// 必须使用后端主键 [remoteId] 命中服务器记录；本地尚未拿到 remoteId
  /// （未同步或后端未返回 id）时跳过 PATCH——反馈字段已在本地更新，
  /// 会随 [flushUnsynced] 整条重传时一并带过去。
  Future<void> uploadFeedback(int recordId, String feedback) async {
    try {
      final rec = await _db.solveRecordDao.getById(recordId);
      final remoteId = rec?.remoteId ?? 0;
      if (remoteId <= 0) return;
      await _api.updateFeedback(remoteId, feedback);
      // PATCH 成功即视为该条记录已同步，避免无谓整条重传。
      await _db.solveRecordDao.markSynced(recordId);
    } catch (_) {
      // 静默
    }
  }

  /// 上传标准答案 → 同步至后端 + 写本地 drift
  ///
  /// [paperId]/[questionNo] 为答案册卷次归属（可空）；"无题干条目"
  /// （questionText 为空）仅写本地，不上传后端（后端契约尚未支持卷次）。
  Future<void> uploadAnswer({
    required String questionText,
    required String questionHash,
    required String answer,
    String solution = '',
    List<String> knowledgePoints = const [],
    String subject = '未分类',
    int? paperId,
    int? questionNo,
  }) async {
    final hasQuestion = questionText.trim().isNotEmpty;
    if (hasQuestion) {
      try {
        await _api.uploadAnswer({
          'question_text': questionText,
          'question_hash': questionHash,
          'answer': answer,
          'solution': solution,
          'knowledge_points': knowledgePoints,
          'subject': subject,
        });
      } catch (_) {
        // 静默
      }
    }
    await _db.answerLibraryDao.insert(
      AnswerLibraryCompanion.insert(
        questionText: Value(questionText),
        questionHash: Value(questionHash),
        paperId: Value(paperId),
        questionNo: Value(questionNo),
        answer: answer,
        solution: Value(solution),
        knowledgePoints: Value(jsonEncode(knowledgePoints)),
        subject: Value(subject),
        source: const Value('local'),
      ),
    );
  }

  /// 应用启动时拉取最新标准答案库更新本地 drift
  Future<void> pullAnswerLibrary() async {
    try {
      // 复用 fetchKnowledgeMastery 同样的鉴权路径
      // 后端建议提供 /api/v1/answer-library GET；这里若未实现则空回
      // 忽略错误：保留本地缓存
    } catch (_) {
      // 静默
    }
  }

  /// 拉取知识点掌握度 → upsert 进本地 drift
  Future<void> pullKnowledgeMastery() async {
    try {
      final rows = await _api.fetchKnowledgeMastery();
      for (final row in rows) {
        await _db.knowledgeDao.upsert(
          knowledgePoint: row['knowledge_point'].toString(),
          deltaCorrect: (row['correct_count'] as num?)?.toInt() ?? 0,
          deltaWrong: (row['wrong_count'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {
      // 静默
    }
  }

  /// 拉取薄弱知识点（按需）
  Future<List<Map<String, dynamic>>> pullWeakKnowledge() async {
    try {
      return await _api.fetchWeakKnowledge();
    } catch (_) {
      return const [];
    }
  }

  /// 联网后批量同步尚未上传的解题记录
  /// @return 上传成功 / 失败 条数
  Future<({int success, int failed})> flushUnsynced() async {
    final records = await _db.solveRecordDao.getUnsynced();
    var success = 0;
    var failed = 0;
    for (final r in records) {
      try {
        final ids = await _api.uploadSolveRecord({
          'local_id': r.id,
          'question_text': r.questionText,
          'answer': r.answer,
          'solution': r.solution,
          'ai_model': r.aiModel,
          'latency_ms': r.latencyMs,
          'tokens_used': r.tokensUsed,
          'matched': r.matched,
          // 四色状态（正确/错误/疑问/重答）必须随记录上传：
          // action_type 覆盖 solve/retry/detail/correct/wrong，
          // user_feedback 兼容旧契约（none/correct/wrong）。
          'action_type': r.actionType,
          'user_feedback': r.userFeedback,
          'image_path': r.imagePath,
          'subject': r.subject,
        });
        // 逐条上传通常返回单个后端 id：写回 remoteId 供删除/反馈使用。
        // 未拿到后端 id 时保持未同步，下次重试补传——否则 feedback/删除
        // 会因本地 remoteId 为空而永久失效，下拉同步也会重复插入记录。
        if (ids.length != 1) {
          failed++;
          continue;
        }
        await _db.solveRecordDao.setRemoteId(r.id, ids.first);
      } catch (_) {
        // 网络/后端失败：保留记录待下次重试。
        failed++;
        continue;
      }
      try {
        await _db.solveRecordDao.markSynced(r.id);
      } catch (e) {
        // 上传已成功但本地标记失败：不得把该记录误判为"未上传"再次投递，
        // 在此单独记录错误，交由上层/日志处理，不再重复上传。
        debugPrint('flushUnsynced: 记录 ${r.id} 上传成功但 markSynced 失败: $e');
      }
      success++;
    }
    return (success: success, failed: failed);
  }

  /// 待删除队列（本地已删、后端待删的墓碑）重试：删除成功即移除。
  /// @return 成功删除的条数
  Future<int> flushPendingDeletes() async {
    var done = 0;
    try {
      final pending = await _db.pendingDeleteDao.getAll();
      for (final p in pending) {
        try {
          final ok = await _api.deleteSolveRecord(p.remoteId);
          if (ok) {
            await _db.pendingDeleteDao.remove(p.remoteId);
            done++;
          }
        } catch (_) {
          // 网络/后端失败：保留待下次重试
        }
      }
    } catch (_) {
      // 忽略
    }
    return done;
  }

  /// 下拉后端解题记录并写回本地（仅正确=近1个月 / 错误=近3个月）。
  ///
  /// 按后端主键 remoteId 幂等合并，避免重复插入。后端未适配或失败时静默。
  /// 会跳过待删除队列中的 remoteId，防止被我方刚删除的记录再次回写。
  /// @return 写回本地（新增或更新）的记录条数
  Future<int> pullSolveRecords() async {
    var applied = 0;
    try {
      // 本地"待删除"主键：下拉时一律跳过，真正实现删除
      final tombstone = await _db.pendingDeleteDao.getAllRemoteIds();
      final rows = await _api.fetchSolveRecords(
        correctDays: 30,
        wrongDays: 90,
      );
      for (final row in rows) {
        final remoteId = (row['id'] as num?)?.toInt();
        if (remoteId == null || remoteId <= 0) continue;
        if (tombstone.contains(remoteId)) continue; // 待删除：跳过回写
        // 四色状态（正确/错误/疑问/重答）：兼容后端多种字段名回写本地，
        // 优先 action_type，其次 status，最后 user_feedback。
        // action_type 或 user_feedback 为 correct/wrong 都视为反馈，双写
        // 本地两字段（与本地 updateFeedback 的写法保持一致），保证
        // 知识点页按 getByFeedback('wrong') 查询错题不漏。
        final rawAction =
            (row['action_type'] ?? row['status'])?.toString().trim() ?? '';
        final rawFeedback = row['user_feedback']?.toString().trim() ?? '';
        final isFeedback = rawAction == 'correct' ||
            rawAction == 'partial' ||
            rawAction == 'wrong' ||
            rawFeedback == 'correct' ||
            rawFeedback == 'partial' ||
            rawFeedback == 'wrong';
        final actionType = rawAction.isNotEmpty
            ? rawAction
            : (isFeedback ? rawFeedback : 'solve');
        final userFeedback = isFeedback
            ? (rawFeedback.isNotEmpty ? rawFeedback : rawAction)
            : 'none';
        await _db.solveRecordDao.upsertFromBackend(
          remoteId: remoteId,
          questionText: row['question_text']?.toString() ?? '',
          answer: row['answer']?.toString() ?? '',
          solution: row['solution']?.toString() ?? '',
          // 后端未回传反馈时不默认成 correct，避免把无反馈记录误标为"正确"
          userFeedback: userFeedback,
          actionType: actionType,
          knowledgePoints:
              row['knowledge_points'] is List
                  ? jsonEncode(row['knowledge_points'])
                  : '[]',
          aiModel: row['ai_model']?.toString() ?? '',
          latencyMs: (row['latency_ms'] as num?)?.toInt() ?? 0,
          tokensUsed: (row['tokens_used'] as num?)?.toInt() ?? 0,
          matched: row['matched'] == true,
          subject: row['subject']?.toString().trim().isNotEmpty == true
              ? row['subject'].toString().trim()
              : '未分类',
          createdAt:
              row['created_at'] is String
                  ? DateTime.tryParse(row['created_at'])
                  : null,
        );
        applied++;
      }
    } catch (_) {
      // 后端未实现下拉接口或网络失败：静默，仅保留上行能力。
    }
    return applied;
  }

  /// 手动同步入口：先上行补传本地未同步记录，再从后端下拉回写缺失记录。
  /// @return 各阶段计数，供 UI 展示"成功/失败 x 条"。
  Future<SyncResult> syncAll() async {
    // 先清空"本地已删、后端待删"的墓碑队列，再上行补传、下行回写，
    // 避免被待删除记录回写覆盖。
    await flushPendingDeletes();
    final upload = await flushUnsynced();
    final pulled = await pullSolveRecords();
    return SyncResult(
      uploaded: upload.success,
      uploadFailed: upload.failed,
      pulled: pulled,
    );
  }
}
