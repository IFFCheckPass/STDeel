/// 解题结果模型 - 思谛 STDeel
library;

import 'dart:convert';

/// AI 返回的单道题结果
class QuestionResult {
  QuestionResult({
    int id = 0,
    int sessionNo = 0,
    required this.content,
    List<String>? knowledgePoints,
    this.answer = '',
    this.solution = '',
    this.confidence = 0.0,
    this.subject = '未分类',
    this.questionNo = 0,
    this.needsMultimodal = false,
  })  : this.id = id,
        sessionNo = sessionNo <= 0 ? (id > 0 ? id : 0) : sessionNo,
        knowledgePoints = knowledgePoints ?? const [];

  factory QuestionResult.fromJson(Map<String, dynamic> json) {
    final sessionNo = json['id'] is num ? (json['id'] as num).toInt() : 0;
    return QuestionResult(
      id: sessionNo,
      sessionNo: sessionNo,
      questionNo: json['question_no'] is num
          ? (json['question_no'] as num).toInt()
          : 0,
      content: json['content']?.toString() ?? '',
      knowledgePoints: json['knowledge_points'] is List
          ? (json['knowledge_points'] as List)
              .map((e) => e.toString())
              .toList()
          : const [],
      answer: json['answer']?.toString() ?? '',
      solution: json['solution']?.toString() ?? '',
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0.0,
      subject: json['subject']?.toString().trim().isNotEmpty == true
          ? json['subject'].toString().trim()
          : '未分类',
      needsMultimodal: json['needs_multimodal'] == true,
    );
  }

  final String content;
  final List<String> knowledgePoints;
  String answer;
  String solution;
  double confidence;

  /// 所属学科（AI 自动归类，默认"未分类"）
  String subject;

  /// 记录 ID：AI 返回阶段通常为 0；解题被持久化后写回漂移(drift)主键，
  /// 供重答/疑问/反馈命中同一历史记录。相当于全局"解过的题"的序号。
  int id;

  /// 当次解题的题号（AI 按图内顺序返回 1、2、3…），供用户界面醒目展示。
  /// 与 [id]（内部全局序号）区分开。
  int sessionNo;

  /// 卷内题号（答案册条目用）：文档拆分/拆题时 AI 返回的题号，
  /// 用于"卷次+题号"认领答案册中的无题干条目。0 表示未知。
  final int questionNo;

  /// 该题是否需要多模态模型直接看图解题（拆图分割阶段标记）。
  final bool needsMultimodal;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'knowledge_points': knowledgePoints,
        'answer': answer,
        'solution': solution,
        'confidence': confidence,
        'subject': subject,
        'question_no': questionNo,
      };
}

/// 一次完整解题会话的结果（多道题）
class SolveResult {
  SolveResult({
    required this.questions,
    required this.aiModel,
    required this.latencyMs,
    required this.tokensUsed,
    required this.source,
    this.imagePath = '',
    this.error,
  });

  final List<QuestionResult> questions;
  final String aiModel;
  final int latencyMs;
  final int tokensUsed;

  /// 'ai' | 'answer_library' | 'error'
  final String source;
  final String imagePath;
  final String? error;

  bool get isSuccess => error == null && questions.isNotEmpty;

  /// 兼容后端上传用的 JSON 串
  String toJsonString() => jsonEncode({
        'ai_model': aiModel,
        'latency_ms': latencyMs,
        'tokens_used': tokensUsed,
        'source': source,
        'image_path': imagePath,
        'questions':
            questions.map((q) => q.toJson()).toList(growable: false),
      });
}
