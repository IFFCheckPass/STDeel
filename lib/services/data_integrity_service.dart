/// 数据完整性启动核查服务 - 思谛 STDeel
///
/// **每次启动必须执行**（挂在 [SettingsProvider.load] 尾部，强制规则见
/// AGENTS.md「数据完整性强制规则」）。三步：
///
/// 1. **快照**：把关键持久化数据（模型配置 JSON、账号 username、device_id、
///    user_id）快照到 prefs（保留上一份 prev）。覆盖安装场景下 prefs 会保留，
///    一旦新版本误清/误覆盖关键 key，可从快照找回；
/// 2. **核查**：SQLite 各表可读并统计行数；模型配置可解析且非空；账号绑定
///    状态（username / user_id）一致性；
/// 3. **自愈**：username 存在但 user_id 缺失 → 自动按 username 重绑后端账号
///    （找回云端记录归属）；异常情况写入 FaultLog 供用户在设置页查看。
library;

import 'dart:convert';

import '../config/app_config.dart';
import '../data/database.dart';
import '../services/backend_api.dart';
import '../services/fault_log_service.dart';

/// 一次启动核查的结果报告
class IntegrityReport {
  IntegrityReport({
    required this.checkedAt,
    required this.solveRecords,
    required this.knowledgePoints,
    required this.providerGroups,
    required this.hasAiConfig,
    required this.username,
    required this.userIdPresent,
    required this.selfHealActions,
    required this.issues,
  });

  final DateTime checkedAt;
  final int solveRecords;
  final int knowledgePoints;
  final int providerGroups;
  final bool hasAiConfig;
  final String username;
  final bool userIdPresent;
  final List<String> selfHealActions;
  final List<String> issues;

  bool get allOk => issues.isEmpty;

  String get summary =>
      '记录 $solveRecords 条 · 知识点 $knowledgePoints 条 · '
      'AI 配置 ${hasAiConfig ? '$providerGroups 组' : '缺失'} · '
      '账号 ${username.isEmpty ? '未绑定' : '已绑定($username)'}';
}

class DataIntegrityService {
  DataIntegrityService({required AppDatabase db, required BackendApi api})
      : _db = db,
        _api = api;

  final AppDatabase _db;
  final BackendApi _api;

  static IntegrityReport? _last;
  static IntegrityReport? get last => _last;

  /// 执行启动核查（每次启动必须调用一次）
  Future<IntegrityReport> run() async {
    final actions = <String>[];
    final issues = <String>[];

    // ===== 1. 快照关键数据（先转存旧快照为 prev）=====
    try {
      final prev = await _api.getPrefsString(AppConfig.keyIntegritySnapshot);
      if (prev != null && prev.isNotEmpty) {
        await _api.setPrefsString(AppConfig.keyIntegritySnapshotPrev, prev);
      }
      final snapshot = jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'ai_combos': await _api.getAiCombosJson(),
        'username': await _api.getUsername(),
        'device_id': await _api.getPrefsString(AppConfig.keyDeviceId),
        'user_id': await _api.getPrefsString(AppConfig.keyUserId),
      });
      await _api.setPrefsString(AppConfig.keyIntegritySnapshot, snapshot);
    } catch (e) {
      issues.add('快照失败：$e');
    }

    // ===== 2. SQLite 核查（各表可读 + 行数统计）=====
    var solveCount = 0;
    var knowledgeCount = 0;
    try {
      solveCount = await _db.solveRecordDao.getAll().then((l) => l.length);
    } catch (e) {
      issues.add('解题记录表不可读：$e');
    }
    try {
      knowledgeCount = await _db.knowledgeDao.getAll().then((l) => l.length);
    } catch (e) {
      issues.add('知识点表不可读：$e');
    }

    // ===== 3. 模型配置核查（可解析 + 非空；腐损已在 load 阶段 salvage/留底）=====
    var providerGroups = 0;
    var hasAiConfig = false;
    try {
      final raw = await _api.getAiCombosJson();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          hasAiConfig = true;
          providerGroups = decoded.length;
        } else {
          issues.add('模型配置 JSON 存在但为空/非列表（已由启动解析兜底）');
        }
      } else {
        issues.add('模型配置为空（首次安装或曾被清空，可在设置页从备份导入）');
      }
    } catch (e) {
      issues.add('模型配置读取失败：$e');
    }

    // ===== 4. 账号绑定核查 + 自愈 =====
    final username = (await _api.getUsername()) ?? '';
    var userIdPresent = false;
    try {
      final userId = await _api.getPrefsString(AppConfig.keyUserId);
      userIdPresent = userId != null && userId.isNotEmpty;
      // 自愈：绑定过用户名但 user_id 丢失（卸载重装/清数据）→
      // 按 username 重绑后端，找回原账号的云端记录归属。
      if (username.isNotEmpty && !userIdPresent) {
        final ok = await _api.bindUserByUsername(username);
        if (ok) {
          actions.add('已按用户名「$username」重新绑定云端账号，云端记录归属已恢复');
          userIdPresent = true;
        } else {
          issues.add('账号「$username」重绑失败（后端不可达？），可在设置页重试绑定');
        }
      }
      if (username.isEmpty && userIdPresent) {
        issues.add('存在 user_id 但未绑定用户名，换设备后将无法找回云端数据，建议设置用户名');
      }
    } catch (e) {
      issues.add('账号状态核查失败：$e');
    }

    final report = IntegrityReport(
      checkedAt: DateTime.now(),
      solveRecords: solveCount,
      knowledgePoints: knowledgeCount,
      providerGroups: providerGroups,
      hasAiConfig: hasAiConfig,
      username: username,
      userIdPresent: userIdPresent,
      selfHealActions: actions,
      issues: issues,
    );
    _last = report;

    // 核查结果写入故障记录（设置页可见；异常情况用户能主动发现）
    if (issues.isNotEmpty || actions.isNotEmpty) {
      FaultLogService.instance.record(
        source: '数据完整性核查',
        code: issues.isEmpty ? '自愈' : '警告',
        summary: actions.isEmpty
            ? (issues.isEmpty ? '核查通过' : '发现 ${issues.length} 项数据风险')
            : (issues.isEmpty
                ? '核查完成并自动修复'
                : '发现 ${issues.length} 项风险并${actions.length}项自愈'),
        detail: [
          report.summary,
          if (actions.isNotEmpty) '自愈：${actions.join('；')}',
          if (issues.isNotEmpty) '风险：${issues.join('；')}',
        ].join('\n'),
      );
    }

    return report;
  }
}