/// 本地备份服务 - 思谛 STDeel
///
/// 把解题记录 + 知识点掌握度导出为 JSON 文件（离线保存、跨设备迁移），
/// 或从导出的 JSON 文件导入恢复（幂等，不产生重复记录）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../data/database.dart';
import '../models/ai_provider.dart';

class BackupService {
  BackupService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  static const String _typeTag = 'stdeel-backup';
  // v2：新增 ai_providers（AI 供应商含 API Key / Base URL / 模型）备份。
  static const int _version = 2;

  /// 导出全部解题记录 + 知识点 + AI 供应商配置到 JSON 文件。
  ///
  /// [providers] 为当前 AI 供应商列表（含 API Key），可为空。
  /// 返回保存路径；用户取消或失败抛异常。
  Future<String> exportBackup({List<AiProvider>? providers}) async {
    final records = await _db.solveRecordDao.getAll();
    final knowledge = await _db.knowledgeDao.getAll();

    final payload = <String, dynamic>{
      'type': _typeTag,
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'solve_records': records.map(_solveRecordToJson).toList(),
      'knowledge': knowledge.map(_knowledgeToJson).toList(),
      'ai_providers': (providers ?? const [])
          .map((p) => p.toJson())
          .toList(),
    };

    final bytes = utf8.encode(jsonEncode(payload));
    final fileName =
        'stdeel-backup-${DateTime.now().toIso8601String().split('T').first}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出思谛备份',
      fileName: fileName,
      type: FileType.any,
      bytes: bytes,
    );
    if (path == null || path.isEmpty) {
      throw '已取消导出';
    }
    return path;
  }

  /// 从 JSON 文件导入恢复。
  ///
  /// [onRestoreProviders] 非空时，将备份中的 AI 供应商配置（含 API Key）写回；
  /// 返回 (解题记录导入数, 知识点导入数, AI 供应商导入数)；格式非法抛异常。
  Future<({int solve, int knowledge, int aiProviders})> importBackup({
    Future<void> Function(List<AiProvider> providers)? onRestoreProviders,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择思谛备份文件',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) {
      throw '已取消导入';
    }
    final file = result.files.single;
    final data = file.bytes ??
        await File(file.path!).readAsBytes();
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(data));
    } catch (_) {
      throw '备份文件不是有效的 JSON';
    }
    if (decoded is! Map || decoded['type'] != _typeTag) {
      throw '不是思谛备份文件（缺少类型标记）';
    }

    var solveImported = 0;
    final solveList = decoded['solve_records'];
    if (solveList is List) {
      for (final raw in solveList) {
        final text = raw is Map ? (raw['questionText'] ?? '') : '';
        final created = raw is Map ? (raw['createdAtEpochMs'] ?? 0) : 0;
        final textStr = text.toString();
        final createdMs = created is num ? created.toInt() : 0;
        if (await _db.solveRecordDao.existsBySourceKey(textStr, createdMs)) {
          continue; // 重复，跳过
        }
        await _db.solveRecordDao.insertFromBackup(_solveRecordFromJson(raw));
        solveImported++;
      }
    }

    var knowledgeImported = 0;
    final kpList = decoded['knowledge'];
    if (kpList is List) {
      for (final raw in kpList) {
        final m = raw is Map ? raw : <String, dynamic>{};
        await _db.knowledgeDao.importAbsolute(
          knowledgePoint: (m['knowledgePoint'] ?? '').toString(),
          subject: (m['subject'] ?? '未分类').toString(),
          correctCount: (m['correctCount'] is num)
              ? (m['correctCount'] as num).toInt()
              : 0,
          wrongCount: (m['wrongCount'] is num)
              ? (m['wrongCount'] as num).toInt()
              : 0,
        );
        knowledgeImported++;
      }
    }

    var aiImported = 0;
    final aiList = decoded['ai_providers'];
    if (onRestoreProviders != null && aiList is List && aiList.isNotEmpty) {
      final restored = aiList
          .map((e) => AiProvider.fromJson(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .toList();
      await onRestoreProviders(restored);
      aiImported = restored.length;
    }
    return (solve: solveImported, knowledge: knowledgeImported, aiProviders: aiImported);
  }

  Map<String, dynamic> _solveRecordToJson(SolveRecordEntity r) {
    return {
      'questionText': r.questionText,
      'answer': r.answer,
      'solution': r.solution,
      'knowledgePoints': r.knowledgePoints,
      'subject': r.subject,
      'aiModel': r.aiModel,
      'latencyMs': r.latencyMs,
      'tokensUsed': r.tokensUsed,
      'matched': r.matched,
      'userFeedback': r.userFeedback,
      'actionType': r.actionType,
      'synced': r.synced,
      'remoteId': r.remoteId,
      'imagePath': r.imagePath,
      'createdAtEpochMs': r.createdAt.millisecondsSinceEpoch,
    };
  }

  SolveRecordEntity _solveRecordFromJson(dynamic raw) {
    final m = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final created = m['createdAtEpochMs'] is num
        ? (m['createdAtEpochMs'] as num).toInt()
        : 0;
    return SolveRecordEntity(
      id: 0,
      questionText: (m['questionText'] ?? '').toString(),
      answer: (m['answer'] ?? '').toString(),
      solution: (m['solution'] ?? '').toString(),
      knowledgePoints: (m['knowledgePoints'] ?? '[]').toString(),
      subject: (m['subject'] ?? '未分类').toString(),
      aiModel: (m['aiModel'] ?? '').toString(),
      latencyMs: (m['latencyMs'] ?? 0) is num
          ? ((m['latencyMs'] ?? 0) as num).toInt()
          : 0,
      tokensUsed: (m['tokensUsed'] ?? 0) is num
          ? ((m['tokensUsed'] ?? 0) as num).toInt()
          : 0,
      matched: m['matched'] == true,
      userFeedback: (m['userFeedback'] ?? 'none').toString(),
      actionType: (m['actionType'] ?? 'solve').toString(),
      synced: m['synced'] == true,
      remoteId: m['remoteId'] is num ? (m['remoteId'] as num).toInt() : null,
      imagePath: (m['imagePath'] ?? '').toString(),
      createdAt: created > 0
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> _knowledgeToJson(KnowledgeMasteryEntity k) => {
        'knowledgePoint': k.knowledgePoint,
        'subject': k.subject,
        'correctCount': k.correctCount,
        'wrongCount': k.wrongCount,
      };
}