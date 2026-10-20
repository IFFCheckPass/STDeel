/// drift 表定义 - 思谛 STDeel
///
/// 三张核心表：
/// - SolveRecords：解题记录
/// - AnswerLibrary：本地答案库缓存
/// - KnowledgeMastery：知识点掌握度
library;

import 'package:drift/drift.dart';

/// 解题记录表
///
/// 每次解题（无论成功/失败/匹配命中）写入一行；
/// 同一图片的多道题分别记录。
@DataClassName('SolveRecordEntity')
class SolveRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionText => text()();
  TextColumn get answer => text().withDefault(const Constant(''))();
  TextColumn get solution => text().withDefault(const Constant(''))();
  TextColumn get knowledgePoints =>
      text().withDefault(const Constant('[]'))(); // JSON 数组字符串
  TextColumn get subject =>
      text().withDefault(const Constant('未分类'))(); // 所属学科（AI 自动归类）
  TextColumn get aiModel => text().withDefault(const Constant(''))();
  IntColumn get latencyMs => integer().withDefault(const Constant(0))();
  IntColumn get tokensUsed => integer().withDefault(const Constant(0))();
  BoolColumn get matched =>
      boolean().withDefault(const Constant(false))(); // 是否本地/后端答案库命中
  TextColumn get userFeedback => text().withDefault(
    const Constant('none'),
  )(); // none | correct | wrong
  // 最近一次动作类型（按题目状态四色标记）：
  // solve（初始解题,中性）/ retry（重答,蓝）/ detail（疑问,黄）/ correct（正确,绿）/ wrong（错误,红）
  TextColumn get actionType => text().withDefault(
    const Constant('solve'),
  )();
  BoolColumn get synced =>
      boolean().withDefault(const Constant(false))(); // 是否已同步至后端
  // 后端主键 id（下拉同步时用于幂等去重；未同步/仅本地时为 null）
  IntColumn get remoteId => integer().nullable()();
  TextColumn get imagePath => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 本地答案库缓存表
///
/// 同步自后端答案库；新上传的标准答案也写入本地。
/// 支持两类条目：
///   - 完整条目：questionText + questionHash 非空，供题干精确匹配；
///   - 无题干条目：questionText / questionHash 为空，仅含 [paperId] + [questionNo]
///     （教辅/往年卷答案册通常只有题号+答案，无原题），供"卷次+题号"认领匹配。
///     命中反哺后会补全 questionText / questionHash，升级为完整条目。
@DataClassName('AnswerLibraryEntity')
class AnswerLibrary extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionText =>
      text().withDefault(const Constant(''))(); // 题干，无题干条目为空
  TextColumn get questionHash =>
      text().withDefault(const Constant(''))(); // sha256，精确匹配用；无题干条目为空
  IntColumn get paperId => integer().nullable()(); // 所属卷次（可空）
  IntColumn get questionNo => integer().nullable()(); // 卷内题号（可空）
  TextColumn get answer => text()();
  TextColumn get solution => text().withDefault(const Constant(''))();
  TextColumn get knowledgePoints =>
      text().withDefault(const Constant('[]'))();
  TextColumn get subject =>
      text().withDefault(const Constant('未分类'))(); // 题目所属学科
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 卷次表（答案册/试卷来源）
///
/// 用户导入一份答案册时创建一个卷次并命名（如"2024海淀一模数学"），
/// 该卷的所有答案条目通过 [AnswerLibrary.paperId] 归属卷次。
/// 多套答案混合做题时，靠卷次 + 题号唯一锁定，避免跨卷错配。
@DataClassName('AnswerPaperEntity')
class AnswerPapers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // 卷次名称（用户命名）
  TextColumn get subject => text().withDefault(const Constant('未分类'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 知识点掌握度表
///
/// 同步自后端 /api/v1/knowledge/mastery；离线时本地累计。
/// 每个知识点归属一个学科（默认"未分类"），用于知识点管理分学科展示。
@DataClassName('KnowledgeMasteryEntity')
class KnowledgeMastery extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get knowledgePoint => text()();
  TextColumn get subject => text().withDefault(const Constant('未分类'))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 待删除队列（删除墓碑）
///
/// 本地删除某条解题记录时，若后端删除失败（含记录已无本地副本），
/// 先把其 [remoteId] 记入本表；下次手动/启动同步时重试删除服务端记录，
/// 成功后再移除条目。下拉同步时必须跳过这些 remoteId，避免"服务器残留 + 本地消失
/// 后又被下拉回写"，从而真正实现删除。
@DataClassName('PendingDeleteEntity')
class PendingDeletes extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 后端主键 id，用于 DELETE /solve-records/{id}
  IntColumn get remoteId => integer()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 应用设置键值表（v0.9.9 新增，数据完整性关键）
///
/// **为何不用 SharedPreferences**：其官方文档明确声明"不保证写入落盘、
/// 不得用于关键数据"（`must not be used for storing critical data`），
/// 且 v0.9.x 实测出现过插件 API 不匹配（NoSuchMethodError）导致 prefs 整体
/// 读写失效、大退后模型配置/账号绑定丢失的 T0 事故。
/// 因此把全部关键设置（模型配置含 API Key、账号绑定、后端 URL、主题、超时、
/// 故障日志、完整性快照）统一持久化到本表——SQLite 事务写入有落盘保证。
///
/// 兼容：首次启动若本表为空而旧的 SharedPreferences 有数据，会自动迁移过来。
@DataClassName('AppSettingEntity')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

