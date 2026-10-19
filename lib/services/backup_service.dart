/// 本地备份服务 - 思谛 STDeel
///
/// v3 备份格式（数据完整性强制，见 AGENTS.md「数据完整性强制规则」）：
///   {
///     "type": "stdeel-backup",
///     "version": 3,
///     "exported_at": "...",
///     "username": "账号绑定用户名（可空）",
///     "ai_providers": [ AiProvider.toJson() ... ],   // 模型 API 配置（含 Key）
///     "solve_records": [ ... ],
///     "knowledge": [ ... ],
///   }
///
/// 导入原则（T0 级）：
///   1. **AI 配置恢复最优先**——先于任何记录写入执行，失败立即精确上报；
///   2. **逐条容错**——单条记录失败只计入失败明细，绝不让"已写入一半"
///      的导入被笼统报成"导入失败"（v0.9.7 曾出现"报错但实际导入成功"）；
///   3. **宽容格式**——兼容 v1（无 ai_providers）/v2/v3，type 标记缺失但含
///      已知字段的 JSON 也按兼容模式导入；文件选择不强制 .json 扩展名。
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../data/database.dart';
import '../models/ai_provider.dart';

/// 导入结果（精确分类，杜绝"报错但实际成功"歧义）。
typedef ImportResult = ({
  int solve,
  int knowledge,
  int aiProviders,
  bool usernameRestored,
  bool hasAiConfig,
  List<String> warnings,
});

class BackupService {
  BackupService({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  static const String _typeTag = 'stdeel-backup';
  // v3：+username（账号绑定）；v2：+ai_providers；v1：记录+知识点。
  static const int _version = 3;

  /// 导出全部数据到 JSON 文件。
  ///
  /// [providers] 当前 AI 供应商配置（含 API Key）；[username] 账号绑定用户名。
  /// 返回保存路径；用户取消或失败抛异常。
  Future<String> exportBackup({
    List<AiProvider>? providers,
    String? username,
  }) async {
    final records = await _db.solveRecordDao.getAll();
    final knowledge = await _db.knowledgeDao.getAll();

    final payload = <String, dynamic>{
      'type': _typeTag,
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      if (username != null && username.isNotEmpty) 'username': username,
      'ai_providers':
          (providers ?? const []).map((p) => p.toJson()).toList(),
      'solve_records': records.map(_solveRecordToJson).toList(),
      'knowledge': knowledge.map(_knowledgeToJson).toList(),
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

  /// 从 JSON 文件导入恢复（宽容格式 + 逐条容错）。
  ///
  /// [onRestoreProviders] 恢复 AI 供应商配置（最先执行）；
  /// [onRestoreUsername] 恢复账号绑定（随后自动重绑云端 user_id）。
  Future<ImportResult> importBackup({
    Future<void> Function(List<AiProvider> providers)? onRestoreProviders,
    Future<void> Function(String username)? onRestoreUsername,
  }) async {
    // 不强制 .json：Windows/Android 文件管理器扩展名五花八门（.JSON/.txt/无后缀）
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择思谛备份文件',
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) {
      throw '已取消导入';
    }
    final file = result.files.single;
    final data = file.bytes ?? await File(file.path!).readAsBytes();
    var text = utf8.decode(data, allowMalformed: true);
    // 去除 BOM / 前后杂白
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.trim();

    final warnings = <String>[];

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (e) {
      throw '备份文件不是有效的 JSON（$e）';
    }
    if (decoded is! Map) {
      // 顶层直接是 providers / combos 数组：按"裸配置"兼容导入
      if (decoded is List && onRestoreProviders != null) {
        final restored = _parseProviders(decoded, warnings);
        if (restored.isNotEmpty) {
          await onRestoreProviders(restored);
          return (
            solve: 0,
            knowledge: 0,
            aiProviders: restored.length,
            usernameRestored: false,
            hasAiConfig: true,
            warnings: [...warnings, '已按兼容模式导入裸模型配置（无记录数据）'],
          );
        }
      }
      throw '备份文件格式不正确（顶层不是对象）';
    }

    // type 标记宽容校验：标准备份直接过；缺 type 但含已知字段 → 兼容模式
    final hasKnownFields = decoded['solve_records'] is List ||
        decoded['knowledge'] is List ||
        decoded['ai_providers'] is List;
    final typeOk = decoded['type'] == _typeTag;
    if (!typeOk) {
      if (!hasKnownFields) {
        throw '不是思谛备份文件（缺少类型标记且无可识别数据）';
      }
      warnings.add('备份缺少类型标记，已按兼容模式导入');
    }

    // ===== 1. AI 配置恢复（最优先；单条容错，失败精确上报）=====
    var aiImported = 0;
    var hasAiConfig = false;
    final aiList = decoded['ai_providers'];
    if (aiList is List) {
      hasAiConfig = true;
      if (aiList.isEmpty) {
        warnings.add('备份中的 AI 配置为空（可能导出时未配置模型）');
      } else if (onRestoreProviders != null) {
        final restored = _parseProviders(aiList, warnings);
        if (restored.isEmpty) {
          warnings.add('AI 配置解析失败：${warnings.last}');
        } else {
          try {
            await onRestoreProviders(restored);
            aiImported = restored.length;
          } catch (e) {
            warnings.add('AI 配置写入失败：$e');
          }
        }
      } else {
        warnings.add('备份含 AI 配置，但当前环境未提供恢复入口');
      }
    } else {
      warnings.add('该备份为旧版格式（v1），未包含 AI 配置——模型 API 信息需手动重新填写');
    }

    // ===== 2. 账号绑定恢复（随后自动重绑云端 user_id）=====
    var usernameRestored = false;
    final backupUsername = decoded['username']?.toString() ?? '';
    if (backupUsername.isNotEmpty && onRestoreUsername != null) {
      try {
        await onRestoreUsername(backupUsername);
        usernameRestored = true;
      } catch (e) {
        warnings.add('账号绑定恢复失败：$e');
      }
    }

    // ===== 3. 解题记录（逐条容错）=====
    var solveImported = 0;
    var solveFailed = 0;
    final solveList = decoded['solve_records'];
    if (solveList is List) {
      for (final raw in solveList) {
        try {
          if (raw is! Map) {
            solveFailed++;
            continue;
          }
          final textStr = (raw['questionText'] ?? '').toString();
          final createdMs = raw['createdAtEpochMs'] is num
              ? (raw['createdAtEpochMs'] as num).toInt()
              : 0;
          if (await _db.solveRecordDao.existsBySourceKey(textStr, createdMs)) {
            continue; // 重复，跳过（不计入失败）
          }
          await _db.solveRecordDao.insertFromBackup(_solveRecordFromJson(raw));
          solveImported++;
        } catch (e) {
          solveFailed++;
          if (warnings.length < 20) {
            warnings.add('1 条解题记录导入失败：$e');
          }
        }
      }
    }

    // ===== 4. 知识点（逐条容错）=====
    var knowledgeImported = 0;
    final kpList = decoded['knowledge'];
    if (kpList is List) {
      for (final raw in kpList) {
        try {
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
        } catch (e) {
          if (warnings.length < 20) {
            warnings.add('1 条知识点导入失败：$e');
          }
        }
      }
    }

    if (solveFailed > 0) {
      warnings.add('共有 $solveFailed 条解题记录导入失败（其余已成功写入）');
    }

    return (
      solve: solveImported,
      knowledge: knowledgeImported,
      aiProviders: aiImported,
      usernameRestored: usernameRestored,
      hasAiConfig: hasAiConfig,
      warnings: warnings,
    );
  }

  /// 宽容解析 providers 列表（新 provider / 旧 AiCombo 形状均可，单条容错）
  List<AiProvider> _parseProviders(List list, List<String> warnings) {
    final out = <AiProvider>[];
    var bad = 0;
    for (final e in list) {
      try {
        if (e is! Map) {
          bad++;
          continue;
        }
        if (e.containsKey('models')) {
          out.add(AiProvider.fromJson(Map<String, dynamic>.from(e)));
        } else if (e.containsKey('modelId') || e.containsKey('baseUrl')) {
          // 旧 AiCombo 形状 → 单模型供应商
          final modelId = (e['modelId'] ?? '').toString();
          final baseUrl = (e['baseUrl'] ?? '').toString();
          final name = (e['name'] ?? '导入供应商').toString();
          out.add(AiProvider(
            id: (e['id'] ?? 'p-import-${out.length}').toString(),
            name: name,
            baseUrl: baseUrl,
            apiKey: (e['apiKey'] ?? '').toString(),
            models: [
              AiModel(
                id: 'm-import-${out.length}-${DateTime.now().microsecondsSinceEpoch}',
                name: name,
                modelId: modelId,
                multimodal: e['multimodal'] == true,
                splitEnabled: e['multimodal'] == true,
                solveEnabled: e['enabled'] != false,
                solveOrder: 0,
              ),
            ],
          ));
        } else {
          bad++;
        }
      } catch (_) {
        bad++;
      }
    }
    if (bad > 0) {
      warnings.add('AI 配置中有 $bad 条无法识别已跳过');
    }
    return out;
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