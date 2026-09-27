/// 知识点 DAO - 思谛 STDeel
library;

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'knowledge_dao.g.dart';

@DriftAccessor(tables: [KnowledgeMastery])
class KnowledgeDao extends DatabaseAccessor<AppDatabase>
    with _$KnowledgeDaoMixin {
  KnowledgeDao(super.db);

  /// upsert：知识点已存在则累加，否则插入。
  ///
  /// 归并时以知识点名称为键；[subject] 仅在建新知识点时生效，
  /// 已有知识点忽略传入的 subject（学科归属由用户在知识点管理页维护）。
  Future<void> upsert({
    required String knowledgePoint,
    String subject = '未分类',
    int deltaCorrect = 0,
    int deltaWrong = 0,
  }) async {
    final existing = await (select(knowledgeMastery)
          ..where((t) => t.knowledgePoint.equals(knowledgePoint))
          ..limit(1))
        .getSingleOrNull();

    if (existing == null) {
      await into(knowledgeMastery).insert(KnowledgeMasteryCompanion.insert(
        knowledgePoint: knowledgePoint,
        subject: Value(subject),
        correctCount: Value(deltaCorrect),
        wrongCount: Value(deltaWrong),
      ));
    } else {
      await (update(knowledgeMastery)
            ..where((t) => t.id.equals(existing.id)))
          .write(KnowledgeMasteryCompanion(
        correctCount: Value(existing.correctCount + deltaCorrect),
        wrongCount: Value(existing.wrongCount + deltaWrong),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// 给指定知识点重设学科归属（知识点管理分学科）
  Future<void> setSubject(String knowledgePoint, String subject) async {
    final existing = await (select(knowledgeMastery)
          ..where((t) => t.knowledgePoint.equals(knowledgePoint))
          ..limit(1))
        .getSingleOrNull();
    if (existing == null) return;
    await (update(knowledgeMastery)
          ..where((t) => t.id.equals(existing.id)))
        .write(KnowledgeMasteryCompanion(
      subject: Value(subject.trim().isEmpty ? '未分类' : subject.trim()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 某个学科下的知识点列表
  Future<List<KnowledgeMasteryEntity>> getBySubject(String subject) =>
      (select(knowledgeMastery)
            ..where((t) => t.subject.equals(subject))
            ..orderBy([(t) => OrderingTerm.desc(t.correctCount)]))
          .get();

  /// 所有学科集合（用于顶部分学科筛选）
  Future<List<String>> getAllSubjects() async {
    final rows = await select(knowledgeMastery).get();
    final subjects = rows
        .map((r) => r.subject)
        .where((s) => s.trim().isNotEmpty)
        .toSet();
    return subjects.toList();
  }

  Future<List<KnowledgeMasteryEntity>> getAll() =>
      select(knowledgeMastery).get();

  /// 错误率 > 50% 视为薄弱
  Future<List<KnowledgeMasteryEntity>> getWeakPoints() {
    final query = select(knowledgeMastery);
    query.where((t) =>
        t.wrongCount.isBiggerThanValue(0) &
        // wrongCount / (correct+wrong) > 0.5  ⟺  wrongCount > correctCount
        t.wrongCount.isBiggerThan(t.correctCount));
    query.orderBy([(t) => OrderingTerm.desc(t.wrongCount)]);
    return query.get().then((rows) => rows.where((r) {
      final total = r.correctCount + r.wrongCount;
      if (total == 0) return false;
      return (r.wrongCount / total) > 0.5;
    }).toList());
  }

  /// 备份导入：以绝对计数写入（无则新建，有则覆盖正确/错误计数并更新学科归属）。
  Future<void> importAbsolute({
    required String knowledgePoint,
    required String subject,
    required int correctCount,
    required int wrongCount,
  }) async {
    final existing = await (select(knowledgeMastery)
          ..where((t) => t.knowledgePoint.equals(knowledgePoint))
          ..limit(1))
        .getSingleOrNull();
    if (existing == null) {
      await into(knowledgeMastery).insert(KnowledgeMasteryCompanion.insert(
        knowledgePoint: knowledgePoint,
        subject: Value(subject),
        correctCount: Value(correctCount),
        wrongCount: Value(wrongCount),
      ));
    } else {
      await (update(knowledgeMastery)
            ..where((t) => t.id.equals(existing.id)))
          .write(KnowledgeMasteryCompanion(
        subject: Value(subject),
        correctCount: Value(correctCount),
        wrongCount: Value(wrongCount),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }
}
