/// 应用设置键值 DAO - 思谛 STDeel
///
/// 关键设置的可靠持久化（SQLite），替代不保证落盘的 SharedPreferences。
library;

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// 写入（存在则覆盖）。
  /// 用事务 + 立即读取回写校验，确保写入真正落盘后才返回成功，
  /// 从根上杜绝"看似保存成功、大退后丢失"。
  Future<void> set(String key, String value) async {
    await transaction(() async {
      await into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: key,
          value: value,
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
    // 回读校验：确保已持久化（不可读到或值不符则抛错，交由调用方上报）
    final check = await get(key);
    if (check != value) {
      throw StateError('设置写入校验失败（key=$key）');
    }
  }

  Future<void> remove(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  Future<Map<String, String>> getAll() async {
    final rows = await select(appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<int> count() async {
    final rows = await select(appSettings).get();
    return rows.length;
  }
}