/// 关键设置键值存储 - 思谛 STDeel（v0.9.9）
///
/// 用 SQLite（drift `app_settings` 表）持久化全部关键设置，**替代
/// SharedPreferences**。原因（T0 数据完整性，见 AGENTS.md）：
///   - SharedPreferences 官方文档明确："不保证写入落盘，不得用于关键数据"；
///   - 实测出现过插件 API 不匹配（`NoSuchMethodError: ...Registrar.getAll`）
///     导致 prefs 整体读写失效，模型配置/账号绑定在大退后丢失。
/// SQLite 事务写入有落盘保证，且与他人已验证可靠的历史记录共用同一数据库。
///
/// **兼容迁移**：首次运行时若 `app_settings` 为空而旧 SharedPreferences 有数据，
/// 自动把全部已知 key 迁移进来（老版本用户数据不丢）。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/daos/app_settings_dao.dart';
import '../data/database.dart';

class KeyValueStore {
  KeyValueStore._();
  static final KeyValueStore instance = KeyValueStore._();

  static const String _migratedFlag = '_kv_migrated_from_prefs_v1';

  bool _ready = false;

  /// 需要从旧 SharedPreferences 迁移的全部 key（含完整性快照/腐损留底/故障日志）
  static const List<String> _migrateKeys = [
    AppConfig.keyBackendUrl,
    AppConfig.keyBackendUrlIntranet,
    AppConfig.keyBackendUsePublic,
    AppConfig.keyUserId,
    AppConfig.keyDeviceId,
    AppConfig.keyUsername,
    AppConfig.keyUserApiKey,
    AppConfig.keyAiCombos,
    AppConfig.keyAiCombosPrev,
    AppConfig.keyAiCombosCorrupt,
    AppConfig.keyIntegritySnapshot,
    AppConfig.keyIntegritySnapshotPrev,
    AppConfig.keyThinkTimeoutSeconds,
    AppConfig.keyThemeMode,
    AppConfig.keyFaultLogs,
  ];

  /// 初始化（幂等）：确保表就绪 + 一次性迁移旧 prefs 数据。
  /// 建议在 `main()` 启动时调用一次；各读写方法也会惰性确保。
  Future<void> ensureReady() async {
    if (_ready) return;
    final dao = AppDatabase.instance.appSettingsDao;

    // 一次性迁移：drift 表为空 + 未迁移过 + prefs 可读 → 搬运
    try {
      final count = await dao.count();
      final migrated = await dao.get(_migratedFlag);
      if (count == 0 && migrated == null) {
        await _migrateFromPrefs(dao);
      }
      // 迁移完成标记（同时保证不会重复搬运覆盖新数据）
      await dao.set(_migratedFlag, '1');
    } catch (_) {
      // 迁移失败不阻塞（下次启动重试；新数据不受影响）
    }
    _ready = true;
  }

  Future<void> _migrateFromPrefs(AppSettingsDao dao) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return; // prefs 插件不可用（正是迁移的原因），无可搬运数据
    }
    for (final key in _migrateKeys) {
      final v = prefs.get(key);
      if (v == null) continue;
      final s = v is String ? v : v.toString();
      if (s.isEmpty) continue;
      await dao.set(key, s);
    }
  }

  // ---------- 字符串 / 布尔 / 整型 ----------

  Future<String?> getString(String key) async {
    await ensureReady();
    return AppDatabase.instance.appSettingsDao.get(key);
  }

  Future<void> setString(String key, String value) async {
    await ensureReady();
    await AppDatabase.instance.appSettingsDao.set(key, value);
  }

  Future<bool?> getBool(String key) async {
    final v = await getString(key);
    if (v == null) return null;
    return v == 'true' || v == '1';
  }

  Future<void> setBool(String key, bool value) =>
      setString(key, value ? 'true' : 'false');

  Future<int?> getInt(String key) async {
    final v = await getString(key);
    if (v == null) return null;
    return int.tryParse(v);
  }

  Future<void> setInt(String key, int value) => setString(key, '$value');

  Future<void> remove(String key) async {
    await ensureReady();
    await AppDatabase.instance.appSettingsDao.remove(key);
  }

  /// 全部键值（启动核查/调试用）
  Future<Map<String, String>> getAll() async {
    await ensureReady();
    return AppDatabase.instance.appSettingsDao.getAll();
  }
}