/// 故障码记录服务 - 思谛 STDeel
///
/// 在 AI 调用 / GitHub 更新 / 后端同步等环节出现 HTTP 故障码时记录一条
/// 诊断日志（含来源、时间、HTTP 状态码、错误概要），供用户在设置页查看并
/// 一键复制，便于反馈与定位问题。故障码一律以中文文案展示。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'key_value_store.dart';

/// 单条故障记录
class FaultLog {
  const FaultLog({
    required this.id,
    required this.source,
    required this.timestamp,
    required this.code,
    required this.summary,
    this.detail = '',
  });

  /// 本地自增 id（用于列表 key）
  final String id;

  /// 来源（如 `AI 调用 · 知识点整理`、`GitHub 更新`、`后端同步`）
  final String source;

  /// ISO8601 时间
  final DateTime timestamp;

  /// HTTP 状态码或其字符串；网络层错误为 `-1`
  final String code;

  /// 中文错误概要（列表展示用，保持简洁）
  final String summary;

  /// 原始故障返回信息（API 英文原文 + 模型/组合上下文），
  /// 点击单条或复制时使用，便于真正定位问题。
  final String detail;

  String get timeText {
    final d = timestamp.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
        'code': code,
        'summary': summary,
        'detail': detail,
      };

  factory FaultLog.fromJson(Map<String, dynamic> json) => FaultLog(
        id: (json['id'] ?? '').toString(),
        source: (json['source'] ?? '').toString(),
        timestamp:
            DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
                DateTime.now(),
        code: (json['code'] ?? '0').toString(),
        summary: (json['summary'] ?? '').toString(),
        detail: (json['detail'] ?? '').toString(),
      );

  /// 复制用的文本：单行概要 + 原始故障返回信息（便于粘贴后真正定位问题）
  String toClipboardText() {
    final line = '[$timeText] [$source] HTTP $code $summary';
    final d = detail.trim();
    if (d.isEmpty) return line;
    return '$line\n详细：$d';
  }
}

/// 故障码记录单例。AI / 更新 / 后端各服务在故障时调用 [FaultLogService.instance.record]，
/// 设置页通过监听 [logs] 刷新展示。
class FaultLogService extends ChangeNotifier {
  FaultLogService._();

  static final FaultLogService instance = FaultLogService._();

  static const int _maxLogs = 50;

  List<FaultLog> _logs = [];
  bool _loaded = false;

  /// 最新在前
  List<FaultLog> get logs => List.unmodifiable(_logs);

  bool get loaded => _loaded;

  /// 预热：读取持久化的记录。AppProviders 启动时调用一次。
  Future<void> load() async {
    // v0.9.9：改用 SQLite 键值存储（SharedPreferences 不保证落盘）
    final raw = await KeyValueStore.instance.getString(AppConfig.keyFaultLogs);
    if (raw != null && raw.isNotEmpty) {
      try {
        final arr = jsonDecode(raw) as List<dynamic>;
        _logs = arr
            .map((e) => FaultLog.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _logs = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// 记录一条故障。fire-and-forget 持久化，随后通知刷新。
  /// [summary] 为中文概要（列表展示）；[detail] 为原始故障返回信息（点击/复制用）。
  void record({
    required String source,
    required String code,
    required String summary,
    String detail = '',
  }) {
    final log = FaultLog(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      source: source,
      timestamp: DateTime.now(),
      code: code,
      summary: summary,
      detail: detail,
    );
    _logs.insert(0, log);
    if (_logs.length > _maxLogs) {
      _logs = _logs.sublist(0, _maxLogs);
    }
    _persist();
    notifyListeners();
  }

  /// 清空所有故障码记录
  Future<void> clear() async {
    _logs = [];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await KeyValueStore.instance.setString(
      AppConfig.keyFaultLogs,
      jsonEncode(_logs.map((e) => e.toJson()).toList()),
    );
  }
}

/// 便捷：把 DioException 的 HTTP 状态码转成 log 用的 code 字符串
/// （无响应时为 `-1`，连接类错误给出明确中文原因）。
String faultCodeFor({int? statusCode, String reason = ''}) {
  if (statusCode != null && statusCode > 0) return '$statusCode';
  if (reason.isNotEmpty) return reason;
  return '网络';
}