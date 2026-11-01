/// 同步 v2 的稳定键 - 思谛 STDeel
///
/// - `client_ref`：`device_id + ":" + local_id`，同一设备重复同步幂等；
/// - `content_key`：题干规范化 + 原始解题时间（毫秒）的 SHA-256，
///   跨设备/重装/换机去重（不随答案、反馈变化）。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 题干规范化：去首尾空白，连续空白压缩为单个空格。
String normalizeQuestionText(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// 跨设备稳定的内容键（与后端约定一致）。
///
/// `sha256_hex(normalized_question_text + "|" + created_at.millisecondsSinceEpoch)`
String contentKeyFor({
  required String questionText,
  required DateTime createdAt,
}) {
  final normalized = normalizeQuestionText(questionText);
  final ms = createdAt.millisecondsSinceEpoch;
  return sha256.convert(utf8.encode('$normalized|$ms')).toString();
}

/// 同一设备内的幂等键。
String clientRefFor({required String deviceId, required int localId}) =>
    '$deviceId:$localId';
