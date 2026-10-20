// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SolveRecordsTable extends SolveRecords
    with TableInfo<$SolveRecordsTable, SolveRecordEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SolveRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _questionTextMeta =
      const VerificationMeta('questionText');
  @override
  late final GeneratedColumn<String> questionText = GeneratedColumn<String>(
      'question_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
      'answer', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _solutionMeta =
      const VerificationMeta('solution');
  @override
  late final GeneratedColumn<String> solution = GeneratedColumn<String>(
      'solution', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _knowledgePointsMeta =
      const VerificationMeta('knowledgePoints');
  @override
  late final GeneratedColumn<String> knowledgePoints = GeneratedColumn<String>(
      'knowledge_points', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('未分类'));
  static const VerificationMeta _aiModelMeta =
      const VerificationMeta('aiModel');
  @override
  late final GeneratedColumn<String> aiModel = GeneratedColumn<String>(
      'ai_model', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _latencyMsMeta =
      const VerificationMeta('latencyMs');
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
      'latency_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tokensUsedMeta =
      const VerificationMeta('tokensUsed');
  @override
  late final GeneratedColumn<int> tokensUsed = GeneratedColumn<int>(
      'tokens_used', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _matchedMeta =
      const VerificationMeta('matched');
  @override
  late final GeneratedColumn<bool> matched = GeneratedColumn<bool>(
      'matched', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("matched" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _userFeedbackMeta =
      const VerificationMeta('userFeedback');
  @override
  late final GeneratedColumn<String> userFeedback = GeneratedColumn<String>(
      'user_feedback', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('none'));
  static const VerificationMeta _actionTypeMeta =
      const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
      'action_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('solve'));
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        questionText,
        answer,
        solution,
        knowledgePoints,
        subject,
        aiModel,
        latencyMs,
        tokensUsed,
        matched,
        userFeedback,
        actionType,
        synced,
        remoteId,
        imagePath,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'solve_records';
  @override
  VerificationContext validateIntegrity(Insertable<SolveRecordEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_text')) {
      context.handle(
          _questionTextMeta,
          questionText.isAcceptableOrUnknown(
              data['question_text']!, _questionTextMeta));
    } else if (isInserting) {
      context.missing(_questionTextMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(_answerMeta,
          answer.isAcceptableOrUnknown(data['answer']!, _answerMeta));
    }
    if (data.containsKey('solution')) {
      context.handle(_solutionMeta,
          solution.isAcceptableOrUnknown(data['solution']!, _solutionMeta));
    }
    if (data.containsKey('knowledge_points')) {
      context.handle(
          _knowledgePointsMeta,
          knowledgePoints.isAcceptableOrUnknown(
              data['knowledge_points']!, _knowledgePointsMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('ai_model')) {
      context.handle(_aiModelMeta,
          aiModel.isAcceptableOrUnknown(data['ai_model']!, _aiModelMeta));
    }
    if (data.containsKey('latency_ms')) {
      context.handle(_latencyMsMeta,
          latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta));
    }
    if (data.containsKey('tokens_used')) {
      context.handle(
          _tokensUsedMeta,
          tokensUsed.isAcceptableOrUnknown(
              data['tokens_used']!, _tokensUsedMeta));
    }
    if (data.containsKey('matched')) {
      context.handle(_matchedMeta,
          matched.isAcceptableOrUnknown(data['matched']!, _matchedMeta));
    }
    if (data.containsKey('user_feedback')) {
      context.handle(
          _userFeedbackMeta,
          userFeedback.isAcceptableOrUnknown(
              data['user_feedback']!, _userFeedbackMeta));
    }
    if (data.containsKey('action_type')) {
      context.handle(
          _actionTypeMeta,
          actionType.isAcceptableOrUnknown(
              data['action_type']!, _actionTypeMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SolveRecordEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SolveRecordEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      questionText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question_text'])!,
      answer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}answer'])!,
      solution: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}solution'])!,
      knowledgePoints: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}knowledge_points'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      aiModel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ai_model'])!,
      latencyMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}latency_ms'])!,
      tokensUsed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tokens_used'])!,
      matched: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}matched'])!,
      userFeedback: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_feedback'])!,
      actionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action_type'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SolveRecordsTable createAlias(String alias) {
    return $SolveRecordsTable(attachedDatabase, alias);
  }
}

class SolveRecordEntity extends DataClass
    implements Insertable<SolveRecordEntity> {
  final int id;
  final String questionText;
  final String answer;
  final String solution;
  final String knowledgePoints;
  final String subject;
  final String aiModel;
  final int latencyMs;
  final int tokensUsed;
  final bool matched;
  final String userFeedback;
  final String actionType;
  final bool synced;
  final int? remoteId;
  final String imagePath;
  final DateTime createdAt;
  const SolveRecordEntity(
      {required this.id,
      required this.questionText,
      required this.answer,
      required this.solution,
      required this.knowledgePoints,
      required this.subject,
      required this.aiModel,
      required this.latencyMs,
      required this.tokensUsed,
      required this.matched,
      required this.userFeedback,
      required this.actionType,
      required this.synced,
      this.remoteId,
      required this.imagePath,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_text'] = Variable<String>(questionText);
    map['answer'] = Variable<String>(answer);
    map['solution'] = Variable<String>(solution);
    map['knowledge_points'] = Variable<String>(knowledgePoints);
    map['subject'] = Variable<String>(subject);
    map['ai_model'] = Variable<String>(aiModel);
    map['latency_ms'] = Variable<int>(latencyMs);
    map['tokens_used'] = Variable<int>(tokensUsed);
    map['matched'] = Variable<bool>(matched);
    map['user_feedback'] = Variable<String>(userFeedback);
    map['action_type'] = Variable<String>(actionType);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['image_path'] = Variable<String>(imagePath);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SolveRecordsCompanion toCompanion(bool nullToAbsent) {
    return SolveRecordsCompanion(
      id: Value(id),
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
      synced: Value(synced),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      imagePath: Value(imagePath),
      createdAt: Value(createdAt),
    );
  }

  factory SolveRecordEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SolveRecordEntity(
      id: serializer.fromJson<int>(json['id']),
      questionText: serializer.fromJson<String>(json['questionText']),
      answer: serializer.fromJson<String>(json['answer']),
      solution: serializer.fromJson<String>(json['solution']),
      knowledgePoints: serializer.fromJson<String>(json['knowledgePoints']),
      subject: serializer.fromJson<String>(json['subject']),
      aiModel: serializer.fromJson<String>(json['aiModel']),
      latencyMs: serializer.fromJson<int>(json['latencyMs']),
      tokensUsed: serializer.fromJson<int>(json['tokensUsed']),
      matched: serializer.fromJson<bool>(json['matched']),
      userFeedback: serializer.fromJson<String>(json['userFeedback']),
      actionType: serializer.fromJson<String>(json['actionType']),
      synced: serializer.fromJson<bool>(json['synced']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionText': serializer.toJson<String>(questionText),
      'answer': serializer.toJson<String>(answer),
      'solution': serializer.toJson<String>(solution),
      'knowledgePoints': serializer.toJson<String>(knowledgePoints),
      'subject': serializer.toJson<String>(subject),
      'aiModel': serializer.toJson<String>(aiModel),
      'latencyMs': serializer.toJson<int>(latencyMs),
      'tokensUsed': serializer.toJson<int>(tokensUsed),
      'matched': serializer.toJson<bool>(matched),
      'userFeedback': serializer.toJson<String>(userFeedback),
      'actionType': serializer.toJson<String>(actionType),
      'synced': serializer.toJson<bool>(synced),
      'remoteId': serializer.toJson<int?>(remoteId),
      'imagePath': serializer.toJson<String>(imagePath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SolveRecordEntity copyWith(
          {int? id,
          String? questionText,
          String? answer,
          String? solution,
          String? knowledgePoints,
          String? subject,
          String? aiModel,
          int? latencyMs,
          int? tokensUsed,
          bool? matched,
          String? userFeedback,
          String? actionType,
          bool? synced,
          Value<int?> remoteId = const Value.absent(),
          String? imagePath,
          DateTime? createdAt}) =>
      SolveRecordEntity(
        id: id ?? this.id,
        questionText: questionText ?? this.questionText,
        answer: answer ?? this.answer,
        solution: solution ?? this.solution,
        knowledgePoints: knowledgePoints ?? this.knowledgePoints,
        subject: subject ?? this.subject,
        aiModel: aiModel ?? this.aiModel,
        latencyMs: latencyMs ?? this.latencyMs,
        tokensUsed: tokensUsed ?? this.tokensUsed,
        matched: matched ?? this.matched,
        userFeedback: userFeedback ?? this.userFeedback,
        actionType: actionType ?? this.actionType,
        synced: synced ?? this.synced,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        imagePath: imagePath ?? this.imagePath,
        createdAt: createdAt ?? this.createdAt,
      );
  SolveRecordEntity copyWithCompanion(SolveRecordsCompanion data) {
    return SolveRecordEntity(
      id: data.id.present ? data.id.value : this.id,
      questionText: data.questionText.present
          ? data.questionText.value
          : this.questionText,
      answer: data.answer.present ? data.answer.value : this.answer,
      solution: data.solution.present ? data.solution.value : this.solution,
      knowledgePoints: data.knowledgePoints.present
          ? data.knowledgePoints.value
          : this.knowledgePoints,
      subject: data.subject.present ? data.subject.value : this.subject,
      aiModel: data.aiModel.present ? data.aiModel.value : this.aiModel,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      tokensUsed:
          data.tokensUsed.present ? data.tokensUsed.value : this.tokensUsed,
      matched: data.matched.present ? data.matched.value : this.matched,
      userFeedback: data.userFeedback.present
          ? data.userFeedback.value
          : this.userFeedback,
      actionType:
          data.actionType.present ? data.actionType.value : this.actionType,
      synced: data.synced.present ? data.synced.value : this.synced,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SolveRecordEntity(')
          ..write('id: $id, ')
          ..write('questionText: $questionText, ')
          ..write('answer: $answer, ')
          ..write('solution: $solution, ')
          ..write('knowledgePoints: $knowledgePoints, ')
          ..write('subject: $subject, ')
          ..write('aiModel: $aiModel, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('tokensUsed: $tokensUsed, ')
          ..write('matched: $matched, ')
          ..write('userFeedback: $userFeedback, ')
          ..write('actionType: $actionType, ')
          ..write('synced: $synced, ')
          ..write('remoteId: $remoteId, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      questionText,
      answer,
      solution,
      knowledgePoints,
      subject,
      aiModel,
      latencyMs,
      tokensUsed,
      matched,
      userFeedback,
      actionType,
      synced,
      remoteId,
      imagePath,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SolveRecordEntity &&
          other.id == this.id &&
          other.questionText == this.questionText &&
          other.answer == this.answer &&
          other.solution == this.solution &&
          other.knowledgePoints == this.knowledgePoints &&
          other.subject == this.subject &&
          other.aiModel == this.aiModel &&
          other.latencyMs == this.latencyMs &&
          other.tokensUsed == this.tokensUsed &&
          other.matched == this.matched &&
          other.userFeedback == this.userFeedback &&
          other.actionType == this.actionType &&
          other.synced == this.synced &&
          other.remoteId == this.remoteId &&
          other.imagePath == this.imagePath &&
          other.createdAt == this.createdAt);
}

class SolveRecordsCompanion extends UpdateCompanion<SolveRecordEntity> {
  final Value<int> id;
  final Value<String> questionText;
  final Value<String> answer;
  final Value<String> solution;
  final Value<String> knowledgePoints;
  final Value<String> subject;
  final Value<String> aiModel;
  final Value<int> latencyMs;
  final Value<int> tokensUsed;
  final Value<bool> matched;
  final Value<String> userFeedback;
  final Value<String> actionType;
  final Value<bool> synced;
  final Value<int?> remoteId;
  final Value<String> imagePath;
  final Value<DateTime> createdAt;
  const SolveRecordsCompanion({
    this.id = const Value.absent(),
    this.questionText = const Value.absent(),
    this.answer = const Value.absent(),
    this.solution = const Value.absent(),
    this.knowledgePoints = const Value.absent(),
    this.subject = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.tokensUsed = const Value.absent(),
    this.matched = const Value.absent(),
    this.userFeedback = const Value.absent(),
    this.actionType = const Value.absent(),
    this.synced = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SolveRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String questionText,
    this.answer = const Value.absent(),
    this.solution = const Value.absent(),
    this.knowledgePoints = const Value.absent(),
    this.subject = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.tokensUsed = const Value.absent(),
    this.matched = const Value.absent(),
    this.userFeedback = const Value.absent(),
    this.actionType = const Value.absent(),
    this.synced = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : questionText = Value(questionText);
  static Insertable<SolveRecordEntity> custom({
    Expression<int>? id,
    Expression<String>? questionText,
    Expression<String>? answer,
    Expression<String>? solution,
    Expression<String>? knowledgePoints,
    Expression<String>? subject,
    Expression<String>? aiModel,
    Expression<int>? latencyMs,
    Expression<int>? tokensUsed,
    Expression<bool>? matched,
    Expression<String>? userFeedback,
    Expression<String>? actionType,
    Expression<bool>? synced,
    Expression<int>? remoteId,
    Expression<String>? imagePath,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionText != null) 'question_text': questionText,
      if (answer != null) 'answer': answer,
      if (solution != null) 'solution': solution,
      if (knowledgePoints != null) 'knowledge_points': knowledgePoints,
      if (subject != null) 'subject': subject,
      if (aiModel != null) 'ai_model': aiModel,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (tokensUsed != null) 'tokens_used': tokensUsed,
      if (matched != null) 'matched': matched,
      if (userFeedback != null) 'user_feedback': userFeedback,
      if (actionType != null) 'action_type': actionType,
      if (synced != null) 'synced': synced,
      if (remoteId != null) 'remote_id': remoteId,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SolveRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? questionText,
      Value<String>? answer,
      Value<String>? solution,
      Value<String>? knowledgePoints,
      Value<String>? subject,
      Value<String>? aiModel,
      Value<int>? latencyMs,
      Value<int>? tokensUsed,
      Value<bool>? matched,
      Value<String>? userFeedback,
      Value<String>? actionType,
      Value<bool>? synced,
      Value<int?>? remoteId,
      Value<String>? imagePath,
      Value<DateTime>? createdAt}) {
    return SolveRecordsCompanion(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      answer: answer ?? this.answer,
      solution: solution ?? this.solution,
      knowledgePoints: knowledgePoints ?? this.knowledgePoints,
      subject: subject ?? this.subject,
      aiModel: aiModel ?? this.aiModel,
      latencyMs: latencyMs ?? this.latencyMs,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      matched: matched ?? this.matched,
      userFeedback: userFeedback ?? this.userFeedback,
      actionType: actionType ?? this.actionType,
      synced: synced ?? this.synced,
      remoteId: remoteId ?? this.remoteId,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionText.present) {
      map['question_text'] = Variable<String>(questionText.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (solution.present) {
      map['solution'] = Variable<String>(solution.value);
    }
    if (knowledgePoints.present) {
      map['knowledge_points'] = Variable<String>(knowledgePoints.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (aiModel.present) {
      map['ai_model'] = Variable<String>(aiModel.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (tokensUsed.present) {
      map['tokens_used'] = Variable<int>(tokensUsed.value);
    }
    if (matched.present) {
      map['matched'] = Variable<bool>(matched.value);
    }
    if (userFeedback.present) {
      map['user_feedback'] = Variable<String>(userFeedback.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SolveRecordsCompanion(')
          ..write('id: $id, ')
          ..write('questionText: $questionText, ')
          ..write('answer: $answer, ')
          ..write('solution: $solution, ')
          ..write('knowledgePoints: $knowledgePoints, ')
          ..write('subject: $subject, ')
          ..write('aiModel: $aiModel, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('tokensUsed: $tokensUsed, ')
          ..write('matched: $matched, ')
          ..write('userFeedback: $userFeedback, ')
          ..write('actionType: $actionType, ')
          ..write('synced: $synced, ')
          ..write('remoteId: $remoteId, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AnswerLibraryTable extends AnswerLibrary
    with TableInfo<$AnswerLibraryTable, AnswerLibraryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnswerLibraryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _questionTextMeta =
      const VerificationMeta('questionText');
  @override
  late final GeneratedColumn<String> questionText = GeneratedColumn<String>(
      'question_text', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _questionHashMeta =
      const VerificationMeta('questionHash');
  @override
  late final GeneratedColumn<String> questionHash = GeneratedColumn<String>(
      'question_hash', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _paperIdMeta =
      const VerificationMeta('paperId');
  @override
  late final GeneratedColumn<int> paperId = GeneratedColumn<int>(
      'paper_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _questionNoMeta =
      const VerificationMeta('questionNo');
  @override
  late final GeneratedColumn<int> questionNo = GeneratedColumn<int>(
      'question_no', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
      'answer', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _solutionMeta =
      const VerificationMeta('solution');
  @override
  late final GeneratedColumn<String> solution = GeneratedColumn<String>(
      'solution', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _knowledgePointsMeta =
      const VerificationMeta('knowledgePoints');
  @override
  late final GeneratedColumn<String> knowledgePoints = GeneratedColumn<String>(
      'knowledge_points', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('未分类'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('local'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        questionText,
        questionHash,
        paperId,
        questionNo,
        answer,
        solution,
        knowledgePoints,
        subject,
        source,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'answer_library';
  @override
  VerificationContext validateIntegrity(
      Insertable<AnswerLibraryEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_text')) {
      context.handle(
          _questionTextMeta,
          questionText.isAcceptableOrUnknown(
              data['question_text']!, _questionTextMeta));
    }
    if (data.containsKey('question_hash')) {
      context.handle(
          _questionHashMeta,
          questionHash.isAcceptableOrUnknown(
              data['question_hash']!, _questionHashMeta));
    }
    if (data.containsKey('paper_id')) {
      context.handle(_paperIdMeta,
          paperId.isAcceptableOrUnknown(data['paper_id']!, _paperIdMeta));
    }
    if (data.containsKey('question_no')) {
      context.handle(
          _questionNoMeta,
          questionNo.isAcceptableOrUnknown(
              data['question_no']!, _questionNoMeta));
    }
    if (data.containsKey('answer')) {
      context.handle(_answerMeta,
          answer.isAcceptableOrUnknown(data['answer']!, _answerMeta));
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('solution')) {
      context.handle(_solutionMeta,
          solution.isAcceptableOrUnknown(data['solution']!, _solutionMeta));
    }
    if (data.containsKey('knowledge_points')) {
      context.handle(
          _knowledgePointsMeta,
          knowledgePoints.isAcceptableOrUnknown(
              data['knowledge_points']!, _knowledgePointsMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnswerLibraryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnswerLibraryEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      questionText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question_text'])!,
      questionHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}question_hash'])!,
      paperId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paper_id']),
      questionNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}question_no']),
      answer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}answer'])!,
      solution: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}solution'])!,
      knowledgePoints: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}knowledge_points'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AnswerLibraryTable createAlias(String alias) {
    return $AnswerLibraryTable(attachedDatabase, alias);
  }
}

class AnswerLibraryEntity extends DataClass
    implements Insertable<AnswerLibraryEntity> {
  final int id;
  final String questionText;
  final String questionHash;
  final int? paperId;
  final int? questionNo;
  final String answer;
  final String solution;
  final String knowledgePoints;
  final String subject;
  final String source;
  final DateTime createdAt;
  const AnswerLibraryEntity(
      {required this.id,
      required this.questionText,
      required this.questionHash,
      this.paperId,
      this.questionNo,
      required this.answer,
      required this.solution,
      required this.knowledgePoints,
      required this.subject,
      required this.source,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_text'] = Variable<String>(questionText);
    map['question_hash'] = Variable<String>(questionHash);
    if (!nullToAbsent || paperId != null) {
      map['paper_id'] = Variable<int>(paperId);
    }
    if (!nullToAbsent || questionNo != null) {
      map['question_no'] = Variable<int>(questionNo);
    }
    map['answer'] = Variable<String>(answer);
    map['solution'] = Variable<String>(solution);
    map['knowledge_points'] = Variable<String>(knowledgePoints);
    map['subject'] = Variable<String>(subject);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnswerLibraryCompanion toCompanion(bool nullToAbsent) {
    return AnswerLibraryCompanion(
      id: Value(id),
      questionText: Value(questionText),
      questionHash: Value(questionHash),
      paperId: paperId == null && nullToAbsent
          ? const Value.absent()
          : Value(paperId),
      questionNo: questionNo == null && nullToAbsent
          ? const Value.absent()
          : Value(questionNo),
      answer: Value(answer),
      solution: Value(solution),
      knowledgePoints: Value(knowledgePoints),
      subject: Value(subject),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory AnswerLibraryEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnswerLibraryEntity(
      id: serializer.fromJson<int>(json['id']),
      questionText: serializer.fromJson<String>(json['questionText']),
      questionHash: serializer.fromJson<String>(json['questionHash']),
      paperId: serializer.fromJson<int?>(json['paperId']),
      questionNo: serializer.fromJson<int?>(json['questionNo']),
      answer: serializer.fromJson<String>(json['answer']),
      solution: serializer.fromJson<String>(json['solution']),
      knowledgePoints: serializer.fromJson<String>(json['knowledgePoints']),
      subject: serializer.fromJson<String>(json['subject']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionText': serializer.toJson<String>(questionText),
      'questionHash': serializer.toJson<String>(questionHash),
      'paperId': serializer.toJson<int?>(paperId),
      'questionNo': serializer.toJson<int?>(questionNo),
      'answer': serializer.toJson<String>(answer),
      'solution': serializer.toJson<String>(solution),
      'knowledgePoints': serializer.toJson<String>(knowledgePoints),
      'subject': serializer.toJson<String>(subject),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnswerLibraryEntity copyWith(
          {int? id,
          String? questionText,
          String? questionHash,
          Value<int?> paperId = const Value.absent(),
          Value<int?> questionNo = const Value.absent(),
          String? answer,
          String? solution,
          String? knowledgePoints,
          String? subject,
          String? source,
          DateTime? createdAt}) =>
      AnswerLibraryEntity(
        id: id ?? this.id,
        questionText: questionText ?? this.questionText,
        questionHash: questionHash ?? this.questionHash,
        paperId: paperId.present ? paperId.value : this.paperId,
        questionNo: questionNo.present ? questionNo.value : this.questionNo,
        answer: answer ?? this.answer,
        solution: solution ?? this.solution,
        knowledgePoints: knowledgePoints ?? this.knowledgePoints,
        subject: subject ?? this.subject,
        source: source ?? this.source,
        createdAt: createdAt ?? this.createdAt,
      );
  AnswerLibraryEntity copyWithCompanion(AnswerLibraryCompanion data) {
    return AnswerLibraryEntity(
      id: data.id.present ? data.id.value : this.id,
      questionText: data.questionText.present
          ? data.questionText.value
          : this.questionText,
      questionHash: data.questionHash.present
          ? data.questionHash.value
          : this.questionHash,
      paperId: data.paperId.present ? data.paperId.value : this.paperId,
      questionNo:
          data.questionNo.present ? data.questionNo.value : this.questionNo,
      answer: data.answer.present ? data.answer.value : this.answer,
      solution: data.solution.present ? data.solution.value : this.solution,
      knowledgePoints: data.knowledgePoints.present
          ? data.knowledgePoints.value
          : this.knowledgePoints,
      subject: data.subject.present ? data.subject.value : this.subject,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnswerLibraryEntity(')
          ..write('id: $id, ')
          ..write('questionText: $questionText, ')
          ..write('questionHash: $questionHash, ')
          ..write('paperId: $paperId, ')
          ..write('questionNo: $questionNo, ')
          ..write('answer: $answer, ')
          ..write('solution: $solution, ')
          ..write('knowledgePoints: $knowledgePoints, ')
          ..write('subject: $subject, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      questionText,
      questionHash,
      paperId,
      questionNo,
      answer,
      solution,
      knowledgePoints,
      subject,
      source,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnswerLibraryEntity &&
          other.id == this.id &&
          other.questionText == this.questionText &&
          other.questionHash == this.questionHash &&
          other.paperId == this.paperId &&
          other.questionNo == this.questionNo &&
          other.answer == this.answer &&
          other.solution == this.solution &&
          other.knowledgePoints == this.knowledgePoints &&
          other.subject == this.subject &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class AnswerLibraryCompanion extends UpdateCompanion<AnswerLibraryEntity> {
  final Value<int> id;
  final Value<String> questionText;
  final Value<String> questionHash;
  final Value<int?> paperId;
  final Value<int?> questionNo;
  final Value<String> answer;
  final Value<String> solution;
  final Value<String> knowledgePoints;
  final Value<String> subject;
  final Value<String> source;
  final Value<DateTime> createdAt;
  const AnswerLibraryCompanion({
    this.id = const Value.absent(),
    this.questionText = const Value.absent(),
    this.questionHash = const Value.absent(),
    this.paperId = const Value.absent(),
    this.questionNo = const Value.absent(),
    this.answer = const Value.absent(),
    this.solution = const Value.absent(),
    this.knowledgePoints = const Value.absent(),
    this.subject = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AnswerLibraryCompanion.insert({
    this.id = const Value.absent(),
    this.questionText = const Value.absent(),
    this.questionHash = const Value.absent(),
    this.paperId = const Value.absent(),
    this.questionNo = const Value.absent(),
    required String answer,
    this.solution = const Value.absent(),
    this.knowledgePoints = const Value.absent(),
    this.subject = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : answer = Value(answer);
  static Insertable<AnswerLibraryEntity> custom({
    Expression<int>? id,
    Expression<String>? questionText,
    Expression<String>? questionHash,
    Expression<int>? paperId,
    Expression<int>? questionNo,
    Expression<String>? answer,
    Expression<String>? solution,
    Expression<String>? knowledgePoints,
    Expression<String>? subject,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionText != null) 'question_text': questionText,
      if (questionHash != null) 'question_hash': questionHash,
      if (paperId != null) 'paper_id': paperId,
      if (questionNo != null) 'question_no': questionNo,
      if (answer != null) 'answer': answer,
      if (solution != null) 'solution': solution,
      if (knowledgePoints != null) 'knowledge_points': knowledgePoints,
      if (subject != null) 'subject': subject,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AnswerLibraryCompanion copyWith(
      {Value<int>? id,
      Value<String>? questionText,
      Value<String>? questionHash,
      Value<int?>? paperId,
      Value<int?>? questionNo,
      Value<String>? answer,
      Value<String>? solution,
      Value<String>? knowledgePoints,
      Value<String>? subject,
      Value<String>? source,
      Value<DateTime>? createdAt}) {
    return AnswerLibraryCompanion(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      questionHash: questionHash ?? this.questionHash,
      paperId: paperId ?? this.paperId,
      questionNo: questionNo ?? this.questionNo,
      answer: answer ?? this.answer,
      solution: solution ?? this.solution,
      knowledgePoints: knowledgePoints ?? this.knowledgePoints,
      subject: subject ?? this.subject,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionText.present) {
      map['question_text'] = Variable<String>(questionText.value);
    }
    if (questionHash.present) {
      map['question_hash'] = Variable<String>(questionHash.value);
    }
    if (paperId.present) {
      map['paper_id'] = Variable<int>(paperId.value);
    }
    if (questionNo.present) {
      map['question_no'] = Variable<int>(questionNo.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (solution.present) {
      map['solution'] = Variable<String>(solution.value);
    }
    if (knowledgePoints.present) {
      map['knowledge_points'] = Variable<String>(knowledgePoints.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnswerLibraryCompanion(')
          ..write('id: $id, ')
          ..write('questionText: $questionText, ')
          ..write('questionHash: $questionHash, ')
          ..write('paperId: $paperId, ')
          ..write('questionNo: $questionNo, ')
          ..write('answer: $answer, ')
          ..write('solution: $solution, ')
          ..write('knowledgePoints: $knowledgePoints, ')
          ..write('subject: $subject, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AnswerPapersTable extends AnswerPapers
    with TableInfo<$AnswerPapersTable, AnswerPaperEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnswerPapersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('未分类'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, subject, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'answer_papers';
  @override
  VerificationContext validateIntegrity(Insertable<AnswerPaperEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnswerPaperEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnswerPaperEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AnswerPapersTable createAlias(String alias) {
    return $AnswerPapersTable(attachedDatabase, alias);
  }
}

class AnswerPaperEntity extends DataClass
    implements Insertable<AnswerPaperEntity> {
  final int id;
  final String name;
  final String subject;
  final DateTime createdAt;
  const AnswerPaperEntity(
      {required this.id,
      required this.name,
      required this.subject,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['subject'] = Variable<String>(subject);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnswerPapersCompanion toCompanion(bool nullToAbsent) {
    return AnswerPapersCompanion(
      id: Value(id),
      name: Value(name),
      subject: Value(subject),
      createdAt: Value(createdAt),
    );
  }

  factory AnswerPaperEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnswerPaperEntity(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      subject: serializer.fromJson<String>(json['subject']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'subject': serializer.toJson<String>(subject),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnswerPaperEntity copyWith(
          {int? id, String? name, String? subject, DateTime? createdAt}) =>
      AnswerPaperEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        subject: subject ?? this.subject,
        createdAt: createdAt ?? this.createdAt,
      );
  AnswerPaperEntity copyWithCompanion(AnswerPapersCompanion data) {
    return AnswerPaperEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      subject: data.subject.present ? data.subject.value : this.subject,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnswerPaperEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('subject: $subject, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, subject, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnswerPaperEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.subject == this.subject &&
          other.createdAt == this.createdAt);
}

class AnswerPapersCompanion extends UpdateCompanion<AnswerPaperEntity> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> subject;
  final Value<DateTime> createdAt;
  const AnswerPapersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.subject = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AnswerPapersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.subject = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<AnswerPaperEntity> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? subject,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (subject != null) 'subject': subject,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AnswerPapersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? subject,
      Value<DateTime>? createdAt}) {
    return AnswerPapersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnswerPapersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('subject: $subject, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeMasteryTable extends KnowledgeMastery
    with TableInfo<$KnowledgeMasteryTable, KnowledgeMasteryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeMasteryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _knowledgePointMeta =
      const VerificationMeta('knowledgePoint');
  @override
  late final GeneratedColumn<String> knowledgePoint = GeneratedColumn<String>(
      'knowledge_point', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('未分类'));
  static const VerificationMeta _correctCountMeta =
      const VerificationMeta('correctCount');
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
      'correct_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _wrongCountMeta =
      const VerificationMeta('wrongCount');
  @override
  late final GeneratedColumn<int> wrongCount = GeneratedColumn<int>(
      'wrong_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, knowledgePoint, subject, correctCount, wrongCount, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_mastery';
  @override
  VerificationContext validateIntegrity(
      Insertable<KnowledgeMasteryEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('knowledge_point')) {
      context.handle(
          _knowledgePointMeta,
          knowledgePoint.isAcceptableOrUnknown(
              data['knowledge_point']!, _knowledgePointMeta));
    } else if (isInserting) {
      context.missing(_knowledgePointMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('correct_count')) {
      context.handle(
          _correctCountMeta,
          correctCount.isAcceptableOrUnknown(
              data['correct_count']!, _correctCountMeta));
    }
    if (data.containsKey('wrong_count')) {
      context.handle(
          _wrongCountMeta,
          wrongCount.isAcceptableOrUnknown(
              data['wrong_count']!, _wrongCountMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KnowledgeMasteryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeMasteryEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      knowledgePoint: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}knowledge_point'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      correctCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}correct_count'])!,
      wrongCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}wrong_count'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $KnowledgeMasteryTable createAlias(String alias) {
    return $KnowledgeMasteryTable(attachedDatabase, alias);
  }
}

class KnowledgeMasteryEntity extends DataClass
    implements Insertable<KnowledgeMasteryEntity> {
  final int id;
  final String knowledgePoint;
  final String subject;
  final int correctCount;
  final int wrongCount;
  final DateTime updatedAt;
  const KnowledgeMasteryEntity(
      {required this.id,
      required this.knowledgePoint,
      required this.subject,
      required this.correctCount,
      required this.wrongCount,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['knowledge_point'] = Variable<String>(knowledgePoint);
    map['subject'] = Variable<String>(subject);
    map['correct_count'] = Variable<int>(correctCount);
    map['wrong_count'] = Variable<int>(wrongCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KnowledgeMasteryCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeMasteryCompanion(
      id: Value(id),
      knowledgePoint: Value(knowledgePoint),
      subject: Value(subject),
      correctCount: Value(correctCount),
      wrongCount: Value(wrongCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory KnowledgeMasteryEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeMasteryEntity(
      id: serializer.fromJson<int>(json['id']),
      knowledgePoint: serializer.fromJson<String>(json['knowledgePoint']),
      subject: serializer.fromJson<String>(json['subject']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      wrongCount: serializer.fromJson<int>(json['wrongCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'knowledgePoint': serializer.toJson<String>(knowledgePoint),
      'subject': serializer.toJson<String>(subject),
      'correctCount': serializer.toJson<int>(correctCount),
      'wrongCount': serializer.toJson<int>(wrongCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KnowledgeMasteryEntity copyWith(
          {int? id,
          String? knowledgePoint,
          String? subject,
          int? correctCount,
          int? wrongCount,
          DateTime? updatedAt}) =>
      KnowledgeMasteryEntity(
        id: id ?? this.id,
        knowledgePoint: knowledgePoint ?? this.knowledgePoint,
        subject: subject ?? this.subject,
        correctCount: correctCount ?? this.correctCount,
        wrongCount: wrongCount ?? this.wrongCount,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  KnowledgeMasteryEntity copyWithCompanion(KnowledgeMasteryCompanion data) {
    return KnowledgeMasteryEntity(
      id: data.id.present ? data.id.value : this.id,
      knowledgePoint: data.knowledgePoint.present
          ? data.knowledgePoint.value
          : this.knowledgePoint,
      subject: data.subject.present ? data.subject.value : this.subject,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      wrongCount:
          data.wrongCount.present ? data.wrongCount.value : this.wrongCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeMasteryEntity(')
          ..write('id: $id, ')
          ..write('knowledgePoint: $knowledgePoint, ')
          ..write('subject: $subject, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, knowledgePoint, subject, correctCount, wrongCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeMasteryEntity &&
          other.id == this.id &&
          other.knowledgePoint == this.knowledgePoint &&
          other.subject == this.subject &&
          other.correctCount == this.correctCount &&
          other.wrongCount == this.wrongCount &&
          other.updatedAt == this.updatedAt);
}

class KnowledgeMasteryCompanion
    extends UpdateCompanion<KnowledgeMasteryEntity> {
  final Value<int> id;
  final Value<String> knowledgePoint;
  final Value<String> subject;
  final Value<int> correctCount;
  final Value<int> wrongCount;
  final Value<DateTime> updatedAt;
  const KnowledgeMasteryCompanion({
    this.id = const Value.absent(),
    this.knowledgePoint = const Value.absent(),
    this.subject = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  KnowledgeMasteryCompanion.insert({
    this.id = const Value.absent(),
    required String knowledgePoint,
    this.subject = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : knowledgePoint = Value(knowledgePoint);
  static Insertable<KnowledgeMasteryEntity> custom({
    Expression<int>? id,
    Expression<String>? knowledgePoint,
    Expression<String>? subject,
    Expression<int>? correctCount,
    Expression<int>? wrongCount,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (knowledgePoint != null) 'knowledge_point': knowledgePoint,
      if (subject != null) 'subject': subject,
      if (correctCount != null) 'correct_count': correctCount,
      if (wrongCount != null) 'wrong_count': wrongCount,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  KnowledgeMasteryCompanion copyWith(
      {Value<int>? id,
      Value<String>? knowledgePoint,
      Value<String>? subject,
      Value<int>? correctCount,
      Value<int>? wrongCount,
      Value<DateTime>? updatedAt}) {
    return KnowledgeMasteryCompanion(
      id: id ?? this.id,
      knowledgePoint: knowledgePoint ?? this.knowledgePoint,
      subject: subject ?? this.subject,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (knowledgePoint.present) {
      map['knowledge_point'] = Variable<String>(knowledgePoint.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (wrongCount.present) {
      map['wrong_count'] = Variable<int>(wrongCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeMasteryCompanion(')
          ..write('id: $id, ')
          ..write('knowledgePoint: $knowledgePoint, ')
          ..write('subject: $subject, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PendingDeletesTable extends PendingDeletes
    with TableInfo<$PendingDeletesTable, PendingDeleteEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingDeletesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
      'remote_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, remoteId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_deletes';
  @override
  VerificationContext validateIntegrity(
      Insertable<PendingDeleteEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingDeleteEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingDeleteEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}remote_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PendingDeletesTable createAlias(String alias) {
    return $PendingDeletesTable(attachedDatabase, alias);
  }
}

class PendingDeleteEntity extends DataClass
    implements Insertable<PendingDeleteEntity> {
  final int id;
  final int remoteId;
  final DateTime createdAt;
  const PendingDeleteEntity(
      {required this.id, required this.remoteId, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['remote_id'] = Variable<int>(remoteId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingDeletesCompanion toCompanion(bool nullToAbsent) {
    return PendingDeletesCompanion(
      id: Value(id),
      remoteId: Value(remoteId),
      createdAt: Value(createdAt),
    );
  }

  factory PendingDeleteEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingDeleteEntity(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<int>(json['remoteId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<int>(remoteId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingDeleteEntity copyWith({int? id, int? remoteId, DateTime? createdAt}) =>
      PendingDeleteEntity(
        id: id ?? this.id,
        remoteId: remoteId ?? this.remoteId,
        createdAt: createdAt ?? this.createdAt,
      );
  PendingDeleteEntity copyWithCompanion(PendingDeletesCompanion data) {
    return PendingDeleteEntity(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingDeleteEntity(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, remoteId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingDeleteEntity &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.createdAt == this.createdAt);
}

class PendingDeletesCompanion extends UpdateCompanion<PendingDeleteEntity> {
  final Value<int> id;
  final Value<int> remoteId;
  final Value<DateTime> createdAt;
  const PendingDeletesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingDeletesCompanion.insert({
    this.id = const Value.absent(),
    required int remoteId,
    this.createdAt = const Value.absent(),
  }) : remoteId = Value(remoteId);
  static Insertable<PendingDeleteEntity> custom({
    Expression<int>? id,
    Expression<int>? remoteId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingDeletesCompanion copyWith(
      {Value<int>? id, Value<int>? remoteId, Value<DateTime>? createdAt}) {
    return PendingDeletesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingDeletesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSettingEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingEntity(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingEntity extends DataClass
    implements Insertable<AppSettingEntity> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSettingEntity(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingEntity(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingEntity copyWith(
          {String? key, String? value, DateTime? updatedAt}) =>
      AppSettingEntity(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSettingEntity copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingEntity(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingEntity(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingEntity &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingEntity> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSettingEntity> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SolveRecordsTable solveRecords = $SolveRecordsTable(this);
  late final $AnswerLibraryTable answerLibrary = $AnswerLibraryTable(this);
  late final $AnswerPapersTable answerPapers = $AnswerPapersTable(this);
  late final $KnowledgeMasteryTable knowledgeMastery =
      $KnowledgeMasteryTable(this);
  late final $PendingDeletesTable pendingDeletes = $PendingDeletesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final SolveRecordDao solveRecordDao =
      SolveRecordDao(this as AppDatabase);
  late final AnswerLibraryDao answerLibraryDao =
      AnswerLibraryDao(this as AppDatabase);
  late final AnswerPaperDao answerPaperDao =
      AnswerPaperDao(this as AppDatabase);
  late final KnowledgeDao knowledgeDao = KnowledgeDao(this as AppDatabase);
  late final PendingDeleteDao pendingDeleteDao =
      PendingDeleteDao(this as AppDatabase);
  late final AppSettingsDao appSettingsDao =
      AppSettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        solveRecords,
        answerLibrary,
        answerPapers,
        knowledgeMastery,
        pendingDeletes,
        appSettings
      ];
}

typedef $$SolveRecordsTableCreateCompanionBuilder = SolveRecordsCompanion
    Function({
  Value<int> id,
  required String questionText,
  Value<String> answer,
  Value<String> solution,
  Value<String> knowledgePoints,
  Value<String> subject,
  Value<String> aiModel,
  Value<int> latencyMs,
  Value<int> tokensUsed,
  Value<bool> matched,
  Value<String> userFeedback,
  Value<String> actionType,
  Value<bool> synced,
  Value<int?> remoteId,
  Value<String> imagePath,
  Value<DateTime> createdAt,
});
typedef $$SolveRecordsTableUpdateCompanionBuilder = SolveRecordsCompanion
    Function({
  Value<int> id,
  Value<String> questionText,
  Value<String> answer,
  Value<String> solution,
  Value<String> knowledgePoints,
  Value<String> subject,
  Value<String> aiModel,
  Value<int> latencyMs,
  Value<int> tokensUsed,
  Value<bool> matched,
  Value<String> userFeedback,
  Value<String> actionType,
  Value<bool> synced,
  Value<int?> remoteId,
  Value<String> imagePath,
  Value<DateTime> createdAt,
});

class $$SolveRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $SolveRecordsTable> {
  $$SolveRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionText => $composableBuilder(
      column: $table.questionText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get answer => $composableBuilder(
      column: $table.answer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get solution => $composableBuilder(
      column: $table.solution, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get knowledgePoints => $composableBuilder(
      column: $table.knowledgePoints,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aiModel => $composableBuilder(
      column: $table.aiModel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tokensUsed => $composableBuilder(
      column: $table.tokensUsed, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get matched => $composableBuilder(
      column: $table.matched, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userFeedback => $composableBuilder(
      column: $table.userFeedback, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SolveRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $SolveRecordsTable> {
  $$SolveRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionText => $composableBuilder(
      column: $table.questionText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get answer => $composableBuilder(
      column: $table.answer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get solution => $composableBuilder(
      column: $table.solution, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get knowledgePoints => $composableBuilder(
      column: $table.knowledgePoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aiModel => $composableBuilder(
      column: $table.aiModel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tokensUsed => $composableBuilder(
      column: $table.tokensUsed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get matched => $composableBuilder(
      column: $table.matched, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userFeedback => $composableBuilder(
      column: $table.userFeedback,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SolveRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SolveRecordsTable> {
  $$SolveRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get questionText => $composableBuilder(
      column: $table.questionText, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get solution =>
      $composableBuilder(column: $table.solution, builder: (column) => column);

  GeneratedColumn<String> get knowledgePoints => $composableBuilder(
      column: $table.knowledgePoints, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get aiModel =>
      $composableBuilder(column: $table.aiModel, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<int> get tokensUsed => $composableBuilder(
      column: $table.tokensUsed, builder: (column) => column);

  GeneratedColumn<bool> get matched =>
      $composableBuilder(column: $table.matched, builder: (column) => column);

  GeneratedColumn<String> get userFeedback => $composableBuilder(
      column: $table.userFeedback, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SolveRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SolveRecordsTable,
    SolveRecordEntity,
    $$SolveRecordsTableFilterComposer,
    $$SolveRecordsTableOrderingComposer,
    $$SolveRecordsTableAnnotationComposer,
    $$SolveRecordsTableCreateCompanionBuilder,
    $$SolveRecordsTableUpdateCompanionBuilder,
    (
      SolveRecordEntity,
      BaseReferences<_$AppDatabase, $SolveRecordsTable, SolveRecordEntity>
    ),
    SolveRecordEntity,
    PrefetchHooks Function()> {
  $$SolveRecordsTableTableManager(_$AppDatabase db, $SolveRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SolveRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SolveRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SolveRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> questionText = const Value.absent(),
            Value<String> answer = const Value.absent(),
            Value<String> solution = const Value.absent(),
            Value<String> knowledgePoints = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> aiModel = const Value.absent(),
            Value<int> latencyMs = const Value.absent(),
            Value<int> tokensUsed = const Value.absent(),
            Value<bool> matched = const Value.absent(),
            Value<String> userFeedback = const Value.absent(),
            Value<String> actionType = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SolveRecordsCompanion(
            id: id,
            questionText: questionText,
            answer: answer,
            solution: solution,
            knowledgePoints: knowledgePoints,
            subject: subject,
            aiModel: aiModel,
            latencyMs: latencyMs,
            tokensUsed: tokensUsed,
            matched: matched,
            userFeedback: userFeedback,
            actionType: actionType,
            synced: synced,
            remoteId: remoteId,
            imagePath: imagePath,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String questionText,
            Value<String> answer = const Value.absent(),
            Value<String> solution = const Value.absent(),
            Value<String> knowledgePoints = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> aiModel = const Value.absent(),
            Value<int> latencyMs = const Value.absent(),
            Value<int> tokensUsed = const Value.absent(),
            Value<bool> matched = const Value.absent(),
            Value<String> userFeedback = const Value.absent(),
            Value<String> actionType = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<int?> remoteId = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SolveRecordsCompanion.insert(
            id: id,
            questionText: questionText,
            answer: answer,
            solution: solution,
            knowledgePoints: knowledgePoints,
            subject: subject,
            aiModel: aiModel,
            latencyMs: latencyMs,
            tokensUsed: tokensUsed,
            matched: matched,
            userFeedback: userFeedback,
            actionType: actionType,
            synced: synced,
            remoteId: remoteId,
            imagePath: imagePath,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SolveRecordsTable, SolveRecordEntity>(table),
                    BaseReferences<_$AppDatabase, $SolveRecordsTable,
                        SolveRecordEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SolveRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SolveRecordsTable,
    SolveRecordEntity,
    $$SolveRecordsTableFilterComposer,
    $$SolveRecordsTableOrderingComposer,
    $$SolveRecordsTableAnnotationComposer,
    $$SolveRecordsTableCreateCompanionBuilder,
    $$SolveRecordsTableUpdateCompanionBuilder,
    (
      SolveRecordEntity,
      BaseReferences<_$AppDatabase, $SolveRecordsTable, SolveRecordEntity>
    ),
    SolveRecordEntity,
    PrefetchHooks Function()>;
typedef $$AnswerLibraryTableCreateCompanionBuilder = AnswerLibraryCompanion
    Function({
  Value<int> id,
  Value<String> questionText,
  Value<String> questionHash,
  Value<int?> paperId,
  Value<int?> questionNo,
  required String answer,
  Value<String> solution,
  Value<String> knowledgePoints,
  Value<String> subject,
  Value<String> source,
  Value<DateTime> createdAt,
});
typedef $$AnswerLibraryTableUpdateCompanionBuilder = AnswerLibraryCompanion
    Function({
  Value<int> id,
  Value<String> questionText,
  Value<String> questionHash,
  Value<int?> paperId,
  Value<int?> questionNo,
  Value<String> answer,
  Value<String> solution,
  Value<String> knowledgePoints,
  Value<String> subject,
  Value<String> source,
  Value<DateTime> createdAt,
});

class $$AnswerLibraryTableFilterComposer
    extends Composer<_$AppDatabase, $AnswerLibraryTable> {
  $$AnswerLibraryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionText => $composableBuilder(
      column: $table.questionText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionHash => $composableBuilder(
      column: $table.questionHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paperId => $composableBuilder(
      column: $table.paperId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get questionNo => $composableBuilder(
      column: $table.questionNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get answer => $composableBuilder(
      column: $table.answer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get solution => $composableBuilder(
      column: $table.solution, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get knowledgePoints => $composableBuilder(
      column: $table.knowledgePoints,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AnswerLibraryTableOrderingComposer
    extends Composer<_$AppDatabase, $AnswerLibraryTable> {
  $$AnswerLibraryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionText => $composableBuilder(
      column: $table.questionText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionHash => $composableBuilder(
      column: $table.questionHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paperId => $composableBuilder(
      column: $table.paperId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get questionNo => $composableBuilder(
      column: $table.questionNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get answer => $composableBuilder(
      column: $table.answer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get solution => $composableBuilder(
      column: $table.solution, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get knowledgePoints => $composableBuilder(
      column: $table.knowledgePoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AnswerLibraryTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnswerLibraryTable> {
  $$AnswerLibraryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get questionText => $composableBuilder(
      column: $table.questionText, builder: (column) => column);

  GeneratedColumn<String> get questionHash => $composableBuilder(
      column: $table.questionHash, builder: (column) => column);

  GeneratedColumn<int> get paperId =>
      $composableBuilder(column: $table.paperId, builder: (column) => column);

  GeneratedColumn<int> get questionNo => $composableBuilder(
      column: $table.questionNo, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get solution =>
      $composableBuilder(column: $table.solution, builder: (column) => column);

  GeneratedColumn<String> get knowledgePoints => $composableBuilder(
      column: $table.knowledgePoints, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AnswerLibraryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnswerLibraryTable,
    AnswerLibraryEntity,
    $$AnswerLibraryTableFilterComposer,
    $$AnswerLibraryTableOrderingComposer,
    $$AnswerLibraryTableAnnotationComposer,
    $$AnswerLibraryTableCreateCompanionBuilder,
    $$AnswerLibraryTableUpdateCompanionBuilder,
    (
      AnswerLibraryEntity,
      BaseReferences<_$AppDatabase, $AnswerLibraryTable, AnswerLibraryEntity>
    ),
    AnswerLibraryEntity,
    PrefetchHooks Function()> {
  $$AnswerLibraryTableTableManager(_$AppDatabase db, $AnswerLibraryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnswerLibraryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnswerLibraryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnswerLibraryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> questionText = const Value.absent(),
            Value<String> questionHash = const Value.absent(),
            Value<int?> paperId = const Value.absent(),
            Value<int?> questionNo = const Value.absent(),
            Value<String> answer = const Value.absent(),
            Value<String> solution = const Value.absent(),
            Value<String> knowledgePoints = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AnswerLibraryCompanion(
            id: id,
            questionText: questionText,
            questionHash: questionHash,
            paperId: paperId,
            questionNo: questionNo,
            answer: answer,
            solution: solution,
            knowledgePoints: knowledgePoints,
            subject: subject,
            source: source,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> questionText = const Value.absent(),
            Value<String> questionHash = const Value.absent(),
            Value<int?> paperId = const Value.absent(),
            Value<int?> questionNo = const Value.absent(),
            required String answer,
            Value<String> solution = const Value.absent(),
            Value<String> knowledgePoints = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AnswerLibraryCompanion.insert(
            id: id,
            questionText: questionText,
            questionHash: questionHash,
            paperId: paperId,
            questionNo: questionNo,
            answer: answer,
            solution: solution,
            knowledgePoints: knowledgePoints,
            subject: subject,
            source: source,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AnswerLibraryTable, AnswerLibraryEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $AnswerLibraryTable,
                        AnswerLibraryEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnswerLibraryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnswerLibraryTable,
    AnswerLibraryEntity,
    $$AnswerLibraryTableFilterComposer,
    $$AnswerLibraryTableOrderingComposer,
    $$AnswerLibraryTableAnnotationComposer,
    $$AnswerLibraryTableCreateCompanionBuilder,
    $$AnswerLibraryTableUpdateCompanionBuilder,
    (
      AnswerLibraryEntity,
      BaseReferences<_$AppDatabase, $AnswerLibraryTable, AnswerLibraryEntity>
    ),
    AnswerLibraryEntity,
    PrefetchHooks Function()>;
typedef $$AnswerPapersTableCreateCompanionBuilder = AnswerPapersCompanion
    Function({
  Value<int> id,
  required String name,
  Value<String> subject,
  Value<DateTime> createdAt,
});
typedef $$AnswerPapersTableUpdateCompanionBuilder = AnswerPapersCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String> subject,
  Value<DateTime> createdAt,
});

class $$AnswerPapersTableFilterComposer
    extends Composer<_$AppDatabase, $AnswerPapersTable> {
  $$AnswerPapersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AnswerPapersTableOrderingComposer
    extends Composer<_$AppDatabase, $AnswerPapersTable> {
  $$AnswerPapersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AnswerPapersTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnswerPapersTable> {
  $$AnswerPapersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AnswerPapersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnswerPapersTable,
    AnswerPaperEntity,
    $$AnswerPapersTableFilterComposer,
    $$AnswerPapersTableOrderingComposer,
    $$AnswerPapersTableAnnotationComposer,
    $$AnswerPapersTableCreateCompanionBuilder,
    $$AnswerPapersTableUpdateCompanionBuilder,
    (
      AnswerPaperEntity,
      BaseReferences<_$AppDatabase, $AnswerPapersTable, AnswerPaperEntity>
    ),
    AnswerPaperEntity,
    PrefetchHooks Function()> {
  $$AnswerPapersTableTableManager(_$AppDatabase db, $AnswerPapersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnswerPapersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnswerPapersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnswerPapersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AnswerPapersCompanion(
            id: id,
            name: name,
            subject: subject,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> subject = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AnswerPapersCompanion.insert(
            id: id,
            name: name,
            subject: subject,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AnswerPapersTable, AnswerPaperEntity>(table),
                    BaseReferences<_$AppDatabase, $AnswerPapersTable,
                        AnswerPaperEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnswerPapersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnswerPapersTable,
    AnswerPaperEntity,
    $$AnswerPapersTableFilterComposer,
    $$AnswerPapersTableOrderingComposer,
    $$AnswerPapersTableAnnotationComposer,
    $$AnswerPapersTableCreateCompanionBuilder,
    $$AnswerPapersTableUpdateCompanionBuilder,
    (
      AnswerPaperEntity,
      BaseReferences<_$AppDatabase, $AnswerPapersTable, AnswerPaperEntity>
    ),
    AnswerPaperEntity,
    PrefetchHooks Function()>;
typedef $$KnowledgeMasteryTableCreateCompanionBuilder
    = KnowledgeMasteryCompanion Function({
  Value<int> id,
  required String knowledgePoint,
  Value<String> subject,
  Value<int> correctCount,
  Value<int> wrongCount,
  Value<DateTime> updatedAt,
});
typedef $$KnowledgeMasteryTableUpdateCompanionBuilder
    = KnowledgeMasteryCompanion Function({
  Value<int> id,
  Value<String> knowledgePoint,
  Value<String> subject,
  Value<int> correctCount,
  Value<int> wrongCount,
  Value<DateTime> updatedAt,
});

class $$KnowledgeMasteryTableFilterComposer
    extends Composer<_$AppDatabase, $KnowledgeMasteryTable> {
  $$KnowledgeMasteryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get knowledgePoint => $composableBuilder(
      column: $table.knowledgePoint,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get correctCount => $composableBuilder(
      column: $table.correctCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wrongCount => $composableBuilder(
      column: $table.wrongCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$KnowledgeMasteryTableOrderingComposer
    extends Composer<_$AppDatabase, $KnowledgeMasteryTable> {
  $$KnowledgeMasteryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get knowledgePoint => $composableBuilder(
      column: $table.knowledgePoint,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get correctCount => $composableBuilder(
      column: $table.correctCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wrongCount => $composableBuilder(
      column: $table.wrongCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$KnowledgeMasteryTableAnnotationComposer
    extends Composer<_$AppDatabase, $KnowledgeMasteryTable> {
  $$KnowledgeMasteryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get knowledgePoint => $composableBuilder(
      column: $table.knowledgePoint, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
      column: $table.correctCount, builder: (column) => column);

  GeneratedColumn<int> get wrongCount => $composableBuilder(
      column: $table.wrongCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KnowledgeMasteryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KnowledgeMasteryTable,
    KnowledgeMasteryEntity,
    $$KnowledgeMasteryTableFilterComposer,
    $$KnowledgeMasteryTableOrderingComposer,
    $$KnowledgeMasteryTableAnnotationComposer,
    $$KnowledgeMasteryTableCreateCompanionBuilder,
    $$KnowledgeMasteryTableUpdateCompanionBuilder,
    (
      KnowledgeMasteryEntity,
      BaseReferences<_$AppDatabase, $KnowledgeMasteryTable,
          KnowledgeMasteryEntity>
    ),
    KnowledgeMasteryEntity,
    PrefetchHooks Function()> {
  $$KnowledgeMasteryTableTableManager(
      _$AppDatabase db, $KnowledgeMasteryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnowledgeMasteryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnowledgeMasteryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnowledgeMasteryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> knowledgePoint = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<int> correctCount = const Value.absent(),
            Value<int> wrongCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              KnowledgeMasteryCompanion(
            id: id,
            knowledgePoint: knowledgePoint,
            subject: subject,
            correctCount: correctCount,
            wrongCount: wrongCount,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String knowledgePoint,
            Value<String> subject = const Value.absent(),
            Value<int> correctCount = const Value.absent(),
            Value<int> wrongCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              KnowledgeMasteryCompanion.insert(
            id: id,
            knowledgePoint: knowledgePoint,
            subject: subject,
            correctCount: correctCount,
            wrongCount: wrongCount,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$KnowledgeMasteryTable, KnowledgeMasteryEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $KnowledgeMasteryTable,
                        KnowledgeMasteryEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KnowledgeMasteryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KnowledgeMasteryTable,
    KnowledgeMasteryEntity,
    $$KnowledgeMasteryTableFilterComposer,
    $$KnowledgeMasteryTableOrderingComposer,
    $$KnowledgeMasteryTableAnnotationComposer,
    $$KnowledgeMasteryTableCreateCompanionBuilder,
    $$KnowledgeMasteryTableUpdateCompanionBuilder,
    (
      KnowledgeMasteryEntity,
      BaseReferences<_$AppDatabase, $KnowledgeMasteryTable,
          KnowledgeMasteryEntity>
    ),
    KnowledgeMasteryEntity,
    PrefetchHooks Function()>;
typedef $$PendingDeletesTableCreateCompanionBuilder = PendingDeletesCompanion
    Function({
  Value<int> id,
  required int remoteId,
  Value<DateTime> createdAt,
});
typedef $$PendingDeletesTableUpdateCompanionBuilder = PendingDeletesCompanion
    Function({
  Value<int> id,
  Value<int> remoteId,
  Value<DateTime> createdAt,
});

class $$PendingDeletesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingDeletesTable> {
  $$PendingDeletesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingDeletesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingDeletesTable> {
  $$PendingDeletesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingDeletesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingDeletesTable> {
  $$PendingDeletesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingDeletesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingDeletesTable,
    PendingDeleteEntity,
    $$PendingDeletesTableFilterComposer,
    $$PendingDeletesTableOrderingComposer,
    $$PendingDeletesTableAnnotationComposer,
    $$PendingDeletesTableCreateCompanionBuilder,
    $$PendingDeletesTableUpdateCompanionBuilder,
    (
      PendingDeleteEntity,
      BaseReferences<_$AppDatabase, $PendingDeletesTable, PendingDeleteEntity>
    ),
    PendingDeleteEntity,
    PrefetchHooks Function()> {
  $$PendingDeletesTableTableManager(
      _$AppDatabase db, $PendingDeletesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingDeletesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingDeletesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingDeletesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> remoteId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PendingDeletesCompanion(
            id: id,
            remoteId: remoteId,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int remoteId,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PendingDeletesCompanion.insert(
            id: id,
            remoteId: remoteId,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingDeletesTable, PendingDeleteEntity>(
                        table),
                    BaseReferences<_$AppDatabase, $PendingDeletesTable,
                        PendingDeleteEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingDeletesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingDeletesTable,
    PendingDeleteEntity,
    $$PendingDeletesTableFilterComposer,
    $$PendingDeletesTableOrderingComposer,
    $$PendingDeletesTableAnnotationComposer,
    $$PendingDeletesTableCreateCompanionBuilder,
    $$PendingDeletesTableUpdateCompanionBuilder,
    (
      PendingDeleteEntity,
      BaseReferences<_$AppDatabase, $PendingDeletesTable, PendingDeleteEntity>
    ),
    PendingDeleteEntity,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSettingEntity,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSettingEntity,
      BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingEntity>
    ),
    AppSettingEntity,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AppSettingsTable, AppSettingEntity>(table),
                    BaseReferences<_$AppDatabase, $AppSettingsTable,
                        AppSettingEntity>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSettingEntity,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (
      AppSettingEntity,
      BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingEntity>
    ),
    AppSettingEntity,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SolveRecordsTableTableManager get solveRecords =>
      $$SolveRecordsTableTableManager(_db, _db.solveRecords);
  $$AnswerLibraryTableTableManager get answerLibrary =>
      $$AnswerLibraryTableTableManager(_db, _db.answerLibrary);
  $$AnswerPapersTableTableManager get answerPapers =>
      $$AnswerPapersTableTableManager(_db, _db.answerPapers);
  $$KnowledgeMasteryTableTableManager get knowledgeMastery =>
      $$KnowledgeMasteryTableTableManager(_db, _db.knowledgeMastery);
  $$PendingDeletesTableTableManager get pendingDeletes =>
      $$PendingDeletesTableTableManager(_db, _db.pendingDeletes);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
