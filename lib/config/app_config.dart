/// 全局配置 - 思谛 STDeel
///
/// 集中管理后端 URL、SharedPreferences key、命中阈值等常量。
class AppConfig {
  AppConfig._();

  /// 默认后端 API 基础 URL（可在设置页覆盖）
  ///
  /// URL 语义为「完整 API 根」——含协议、host、以及到 API 根的全部前缀路径
  /// （如 `/api/v1` 或反代前缀 `/stapi`）。代码只在其后追加资源名
  /// （如 `/solve-records`、`/users/register`），不再硬编码 `/api/v1`，
  /// 从而兼容 `snserver.dpdns.org/stapi` 这类反代路径。
  static const String defaultBackendUrl = 'https://api.stdeel.com/api/v1';

  /// SharedPreferences keys
  static const String keyBackendUrl = 'backend_url'; // 公网，兼容旧版本字段
  static const String keyBackendUrlIntranet = 'backend_url_intranet'; // 内网
  static const String keyBackendUsePublic = 'backend_use_public'; // 默认走公网
  static const String keyUserId = 'user_id';
  static const String keyDeviceId = 'device_id';
  static const String keyUsername = 'username';
  static const String keyUserApiKey = 'user_api_key';
  static const String keyAiCombos = 'ai_combos_json';
  // 数据完整性防呆（T0 级保护，见 AGENTS.md「数据完整性强制规则」）：
  // - keyAiCombosPrev：每次覆盖写模型配置前，把上一份原始 JSON 留底
  // - keyAiCombosCorrupt：解析失败/无法识别的原始 JSON 快照（绝不静默丢弃）
  // - keyIntegritySnapshot / keyIntegritySnapshotPrev：启动核查时的关键数据快照
  static const String keyAiCombosPrev = 'ai_combos_json_prev';
  static const String keyAiCombosCorrupt = 'ai_combos_json_corrupt';
  static const String keyIntegritySnapshot = 'integrity_snapshot_json';
  static const String keyIntegritySnapshotPrev = 'integrity_snapshot_prev_json';
  static const String keyThinkTimeoutSeconds = 'think_timeout_seconds';
  static const String keyThemeMode = 'theme_mode'; // system | light | dark
  static const String keyFaultLogs = 'fault_logs_json'; // 故障码记录诊断日志

  /// 账号绑定（用户名 / api-key 同步）功能开关
  ///
  /// 后端已适配"仅传 username → 按 username 找或创建"接口，现开放设置页
  /// 中的用户名绑定入口；api-key 跨端同步按需触发上传。
  static const bool kAccountBindingEnabled = true;

  /// 默认 think 检测超时（秒）
  static const int defaultThinkTimeoutSeconds = 20;

  /// 三层匹配阈值
  static const double matchHighThreshold = 0.85; // 直接返回
  static const double matchLowThreshold = 0.60;  // 低于走 AI

  /// AI 返回 JSON 解析失败时的兜底文案
  static const String fallbackAnswerText = '（AI 未返回有效答案）';
}
