/// 解题记录 DAO - 思谛 STDeel
library;

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'solve_record_dao.g.dart';

@DriftAccessor(tables: [SolveRecords])
class SolveRecordDao extends DatabaseAccessor<AppDatabase>
    with _$SolveRecordDaoMixin {
  SolveRecordDao(super.db);

  Future<int> insert(SolveRecordsCompanion entry) =>
      into(solveRecords).insert(entry);

  /// 删除单条记录（本地删除；删除前的 remoteId 由调用方读取用于同步后端）
  Future<int> deleteById(int id) =>
      (delete(solveRecords)..where((t) => t.id.equals(id))).go();

  Future<List<SolveRecordEntity>> getAll() =>
      (select(solveRecords)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// 按本地主键取单条记录（重答/疑问取原图用）
  Future<SolveRecordEntity?> getById(int id) =>
      (select(solveRecords)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 获取所有标记为某反馈（correct / wrong）的记录
  Future<List<SolveRecordEntity>> getByFeedback(String feedback) =>
      (select(solveRecords)
            ..where((t) => t.userFeedback.equals(feedback))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// 更新单条记录的反馈（同时标记为未同步，并记录最近动作类型用于四色标记）
  Future<int> updateFeedback(int id, String feedback) =>
      (update(solveRecords)..where((t) => t.id.equals(id)))
          .write(SolveRecordsCompanion(
        userFeedback: Value(feedback),
        actionType: Value(feedback),
        synced: const Value(false),
      ));

  /// 按 id 覆盖答案/解答/模型等字段（重答/疑问场景），同时标记为未同步
  Future<int> overwriteAnswer({
    required int id,
    required String answer,
    required String solution,
    required String aiModel,
    required int latencyMs,
    required int tokensUsed,
    String? knowledgePoints,
    String actionType = 'retry',
    String? subject,
  }) =>
      (update(solveRecords)..where((t) => t.id.equals(id))).write(
        SolveRecordsCompanion(
          answer: Value(answer),
          solution: Value(solution),
          aiModel: Value(aiModel),
          latencyMs: Value(latencyMs),
          tokensUsed: Value(tokensUsed),
          knowledgePoints:
              knowledgePoints == null ? const Value.absent() : Value(knowledgePoints),
          subject: subject == null ? const Value.absent() : Value(subject),
          matched: const Value(false),
          userFeedback: const Value('none'),
          actionType: Value(actionType),
          synced: const Value(false),
        ),
      );

  /// 取尚未同步至后端的记录
  Future<List<SolveRecordEntity>> getUnsynced() =>
      (select(solveRecords)..where((t) => t.synced.equals(false))).get();

  /// 标记单条记录为已同步
  Future<int> markSynced(int id) =>
      (update(solveRecords)..where((t) => t.id.equals(id)))
          .write(const SolveRecordsCompanion(synced: Value(true)));

  /// 写回后端主键 remoteId（上传成功后由同步服务调用），
  /// 使删除 / 反馈等后续操作能命中正确的服务器记录。
  Future<int> setRemoteId(int id, int remoteId) =>
      (update(solveRecords)..where((t) => t.id.equals(id)))
          .write(SolveRecordsCompanion(remoteId: Value(remoteId)));

  /// 按后端 remoteId 幂等写回（下拉同步用）。
  ///
  /// 该 remoteId 已存在则更新字段；不存在则插入一条新记录。
  /// @return 写入的本地自增 id
  Future<int> upsertFromBackend({
    required int remoteId,
    required String questionText,
    required String answer,
    required String solution,
    required String userFeedback,
    String actionType = 'solve',
    String knowledgePoints = '[]',
    String aiModel = '',
    int latencyMs = 0,
    int tokensUsed = 0,
    bool matched = false,
    String subject = '未分类',
    DateTime? createdAt,
  }) async {
    final rec = await (select(solveRecords)
          ..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
    final baseFields = SolveRecordsCompanion(
      questionText: Value(questionText),
      answer: Value(answer),
      solution: Value(solution),
      knowledgePoints: Value(knowledgePoints),
      subject: Value(subject),
      aiModel: Value(aiModel),
      latencyMs: Value(latencyMs),
      tokensUsed: Value(tokensUsed),
      matched: Value(matched),
      userFeedback: Value(userFeedback),
      actionType: Value(actionType),
      synced: const Value(true),
      remoteId: Value(remoteId),
      createdAt: Value(createdAt ?? DateTime.now()),
    );
    if (rec != null) {
      await (update(solveRecords)..where((t) => t.remoteId.equals(remoteId)))
          .write(baseFields);
      return rec.id;
    }
    return into(solveRecords).insert(
      SolveRecordsCompanion.insert(
        questionText: questionText,
        answer: Value(answer),
        solution: Value(solution),
        knowledgePoints: Value(knowledgePoints),
        subject: Value(subject),
        aiModel: Value(aiModel),
        latencyMs: Value(latencyMs),
        tokensUsed: Value(tokensUsed),
        matched: Value(matched),
        userFeedback: Value(userFeedback),
        actionType: Value(actionType),
        synced: const Value(true),
        remoteId: Value(remoteId),
        createdAt: Value(createdAt ?? DateTime.now()),
      ),
    );
  }

  /// 取所有已同步（存在后端 id）的记录
  Future<List<SolveRecordEntity>> getAllSynced() =>
      (select(solveRecords)
            ..where((t) => t.remoteId.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// 备份导入的去重：同一题干 + 同一创建时间（±1 秒内）视为已存在，避免重复导入。
  Future<bool> existsBySourceKey(String questionText, int createdAtEpochMs) async {
    final target = DateTime.fromMillisecondsSinceEpoch(createdAtEpochMs);
    final recs = await (select(solveRecords)
          ..where((t) => t.questionText.equals(questionText))
          ..limit(50))
        .get();
    return recs
        .any((r) => r.createdAt.difference(target).inSeconds.abs() < 1);
  }

  /// 从备份还原一条解题记录（保留全部字段；synced 按备份原值）。
  Future<int> insertFromBackup(SolveRecordEntity e) =>
      into(solveRecords).insert(
        SolveRecordsCompanion.insert(
          questionText: e.questionText,
          answer: Value(e.answer),
          solution: Value(e.solution),
          knowledgePoints: Value(e.knowledgePoints),
          subject: Value(e.subject),
          aiModel: Value(e.aiModel),
          latencyMs: Value(e.latencyMs),
          tokensUsed: Value(e.tokensUsed),
          matched: Value(e.matched),
          userFeedback: Value(e.userFeedback),
          actionType: Value(e.actionType),
          synced: Value(e.synced),
          remoteId: Value(e.remoteId),
          imagePath: Value(e.imagePath),
          createdAt: Value(e.createdAt),
        ),
      );
}
