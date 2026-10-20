/// drift 数据库定义 - 思谛 STDeel
///
/// 使用 LazyDatabase + sqlite3_flutter_libs 在移动端打开 SQLite。
/// 通过 [AppDatabase.instance] 单例访问。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'daos/answer_library_dao.dart';
import 'daos/answer_paper_dao.dart';
import 'daos/app_settings_dao.dart';
import 'daos/knowledge_dao.dart';
import 'daos/pending_delete_dao.dart';
import 'daos/solve_record_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    SolveRecords,
    AnswerLibrary,
    AnswerPapers,
    KnowledgeMastery,
    PendingDeletes,
    AppSettings,
  ],
  daos: [
    SolveRecordDao,
    AnswerLibraryDao,
    AnswerPaperDao,
    KnowledgeDao,
    PendingDeleteDao,
    AppSettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_open());
  AppDatabase.forTesting(super.e);

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // 创建 questionHash 索引，加速精确匹配
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_answer_hash ON answer_library(question_hash)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_solve_feedback ON solve_records(user_feedback)',
          );
          // 待删除队列（本地已删、后端待删的墓碑记录）
          await m.create(pendingDeletes);
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2：为四色状态标记新增 actionType 字段
          if (from < 2) {
            await m.addColumn(
              solveRecords,
              solveRecords.actionType,
            );
          }
          // v2 -> v3：下拉同步用后端主键 remoteId（幂等去重）
          if (from < 3) {
            await m.addColumn(
              solveRecords,
              solveRecords.remoteId,
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_solve_remote ON solve_records(remote_id)',
            );
          }
          // v3 -> v4：知识点分学科（subject 列，默认"未分类"）
          if (from < 4) {
            await m.addColumn(
              knowledgeMastery,
              knowledgeMastery.subject,
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_knowledge_subject ON knowledge_mastery(subject)',
            );
          }
          // v4 -> v5：解题记录与答案库新增 subject 列（AI 自动按学科归类知识点）
          if (from < 5) {
            await m.addColumn(solveRecords, solveRecords.subject);
            await m.addColumn(answerLibrary, answerLibrary.subject);
          }
          // v5 -> v6：新增待删除队列（删除墓碑，防止删除后下拉回写）
          if (from < 6) {
            await m.create(pendingDeletes);
          }
          // v6 -> v7：答案库支持"卷次+题号"认领（多套答案混合做题场景）
          if (from < 7) {
            await m.create(answerPapers);
            await m.addColumn(answerLibrary, answerLibrary.paperId);
            await m.addColumn(answerLibrary, answerLibrary.questionNo);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_ans_paper_no '
              'ON answer_library(paper_id, question_no)',
            );
          }
          // v7 -> v8：关键设置迁入 SQLite（应用设置键值表；数据完整性关键，
          // 替代不保证落盘的 SharedPreferences）。表已存在时忽略。
          if (from < 8) {
            try {
              await m.create(appSettings);
            } catch (_) {/* 表已存在（异常重试路径）时忽略 */}
          }
        },
      );
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'stdeel.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(
      file,
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  });
}
