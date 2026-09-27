/// 后端 API 客户端 - 思谛 STDeel
///
/// 用 Dio 封装后端 REST 接口。后端仅负责数据库同步：
///   - 用户注册
///   - 解题记录上传 / 反馈更新
///   - 知识点掌握度 / 薄弱知识点
///   - 标准答案库上传 / 匹配
///   - 文件上传
///
/// URL 约定：[AppConfig.defaultBackendUrl] 与设置页输入的后端 URL 视为「完整 API 根」，
/// 含协议、host 与到 API 根的全部前缀路径（如 `https://api.stdeel.com/api/v1`
/// 或反代路径 `https://snserver.dpdns.org/stapi`）。本类只在其后追加资源名
/// （如 `/solve-records`、`/users/register`），不再硬编码 `/api/v1`，以兼容
/// 任意后端路由结构。
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/ai_provider.dart' show normalizeBaseUrl;

class BackendApi {
  BackendApi({Dio? dio, SharedPreferences? prefs})
      : _dio = dio ?? Dio(),
        _prefsCache = prefs;

  final Dio _dio;
  SharedPreferences? _prefsCache;

  /// 后端 URL：公网 / 内网双通道。
  ///
  /// - 公网：存于 `backend_url`（兼容旧版本字段），默认为 [AppConfig.defaultBackendUrl]
  /// - 内网：存于 `backend_url_intranet`，默认为空；未配置时回退公网
  /// - 内网支持 `http://192.168.x.x:端口/前缀` 这类带协议、内网 IP 与端口号的地址
  ///   （[normalizeBaseUrl] 会保留已有的 http:// 与端口，仅当无协议时才补 https://）
  ///
  /// 实际使用哪套由 [AppConfig.keyBackendUsePublic] 决定（默认公网）。
  ///
  /// 公网地址允许为空（配合仅内网使用的场景）：优先取所选通道，若所选通道为空
  /// 则回退另一通道，两者皆空才回退默认公网地址。
  Future<String> _baseUrl() async {
    _prefsCache ??= await SharedPreferences.getInstance();

    // 是否启用公网
    final usePublic =
        _prefsCache!.getBool(AppConfig.keyBackendUsePublic) ?? true;

    final public = _prefsCache!.getString(AppConfig.keyBackendUrl) ?? '';
    final intra = _prefsCache!.getString(AppConfig.keyBackendUrlIntranet) ?? '';

    String active;
    if (usePublic) {
      // 公网优先；公网空时回退内网
      active = public.trim().isNotEmpty
          ? public
          : (intra.trim().isNotEmpty ? intra : AppConfig.defaultBackendUrl);
    } else {
      // 内网优先；内网空时回退公网
      active = intra.trim().isNotEmpty
          ? intra
          : (public.trim().isNotEmpty ? public : AppConfig.defaultBackendUrl);
    }

    return normalizeBaseUrl(active);
  }

  /// 读取公网后端 URL（可能为空——允许仅内网场景；不再强加默认值）
  Future<String> getBackendUrlPublic() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    final v = _prefsCache!.getString(AppConfig.keyBackendUrl);
    if (v == null || v.trim().isEmpty) return '';
    return normalizeBaseUrl(v);
  }

  Future<void> setBackendUrlPublic(String url) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(
      AppConfig.keyBackendUrl,
      normalizeBaseUrl(url),
    );
  }

  /// 读取内网后端 URL（可能为空 / 未配置）
  Future<String?> getBackendUrlIntranet() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    final v = _prefsCache!.getString(AppConfig.keyBackendUrlIntranet);
    if (v == null || v.trim().isEmpty) return null;
    return normalizeBaseUrl(v);
  }

  Future<void> setBackendUrlIntranet(String url) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(
      AppConfig.keyBackendUrlIntranet,
      normalizeBaseUrl(url),
    );
  }

  Future<bool> getUsePublicBackend() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!.getBool(AppConfig.keyBackendUsePublic) ?? true;
  }

  Future<void> setUsePublicBackend(bool usePublic) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setBool(AppConfig.keyBackendUsePublic, usePublic);
  }

  Future<String> _userId() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    var id = _prefsCache!.getString(AppConfig.keyUserId);
    if (id == null) {
      // 首次启动自动注册
      id = await registerUser();
    }
    return id;
  }

  /// 设置新的后端 URL（用于设置页）
  Future<void> setBackendUrl(String url) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(AppConfig.keyBackendUrl, url);
  }

  /// AI 组合列表（JSON 数组持久化）
  Future<String?> getAiCombosJson() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!.getString(AppConfig.keyAiCombos);
  }

  Future<void> setAiCombosJson(String json) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(AppConfig.keyAiCombos, json);
  }

  Future<int> getThinkTimeoutSeconds() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!.getInt(AppConfig.keyThinkTimeoutSeconds) ??
        AppConfig.defaultThinkTimeoutSeconds;
  }

  Future<void> setThinkTimeoutSeconds(int seconds) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setInt(AppConfig.keyThinkTimeoutSeconds, seconds);
  }

  /// 主题模式（system | light | dark）持久化
  Future<String> getThemeMode() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!.getString(AppConfig.keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(AppConfig.keyThemeMode, mode);
  }

  Future<String> getBackendUrl() async => _baseUrl();

  /// POST /users/register
  /// 首次启动自动注册，持久化返回的 user_id
  Future<String> registerUser() async {
    final url = '${await _baseUrl()}/users/register';
    try {
      final resp = await _dio.post<dynamic>(
        url,
        data: {'device_id': await _deviceId(), 'platform': 'android'},
      );
      // 响应体可能为 null / 非 Map，先判型再取 id，避免首次启动崩溃。
      final data = resp.data;
      final id =
          (data is Map ? (data['user_id'] ?? data['id']) : null)?.toString();
      if (id == null || id.isEmpty) {
        throw BackendApiException('用户注册失败：响应缺少 user_id');
      }
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setString(AppConfig.keyUserId, id);
      return id;
    } on DioException catch (e) {
      throw BackendApiException('用户注册失败: ${e.message}');
    }
  }

  // ==================== 账号绑定（隐藏预埋） ====================
  // 目标：账号不变、数据不变。用户可手动设置 username，若后端存在对应
  // 用户则复用该 user_id；并可将本机 api-key 上传后端实现跨端同步。
  // 后端 api-key 同步接口尚未对接，此功能由 AppConfig.kAccountBindingEnabled
  // 控制（默认关闭隐藏），待适配完成后再开放 UI，避免数据污染。

  /// 读取本地持久化的 username（可能为空）
  Future<String?> getUsername() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!.getString(AppConfig.keyUsername);
  }

  /// 本地持久化 username
  Future<void> setUsername(String username) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(AppConfig.keyUsername, username.trim());
  }

  /// 读取本地持久化的用户 api-key（用于跨端同步，尚未对接后端）
  Future<String?> getUserApiKey() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!.getString(AppConfig.keyUserApiKey);
  }

  /// 本地持久化用户 api-key
  Future<void> setUserApiKey(String apiKey) async {
    _prefsCache ??= await SharedPreferences.getInstance();
    await _prefsCache!.setString(AppConfig.keyUserApiKey, apiKey.trim());
  }

  /// 按 username 获取后端 user_id（后端「仅传 username → 按 username 找或创建」）。
  ///
  /// 成功后将 user_id 持久化，后续所有数据都归属该用户。
  /// 返回 true 表示绑定成功；后端未适配 / 网络失败返回 false。
  /// 仅在 [AppConfig.kAccountBindingEnabled] 开启且存在 username 时由内部调用。
  Future<bool> bindUserByUsername(String username) async {
    final u = username.trim();
    if (u.isEmpty) return false;
    final url = '${await _baseUrl()}/users/register';
    try {
      final resp = await _dio.post<dynamic>(
        url,
        data: {'username': u, 'platform': 'android'},
      );
      final data = resp.data;
      final id =
          (data is Map ? (data['user_id'] ?? data['id']) : null)?.toString();
      if (id == null || id.isEmpty) return false;
      _prefsCache ??= await SharedPreferences.getInstance();
      await _prefsCache!.setString(AppConfig.keyUserId, id);
      return true;
    } on DioException {
      return false;
    }
  }

  /// PUT /users/api-key — 把本机配置的 AI api-key 上传账号（跨端同步）
  ///
  /// 后端契约：body `{user_id, api_keys: [{api_key, name?, enabled?}, ...]}`
  /// 全量覆盖该用户所有 key；也兼容纯字符串数组 `["sk-...", ...]`。
  /// [keys] 为对象列表：`{"api_key": "...", "name": "...", "enabled": true}`。
  /// 失败返回 false（不阻塞用户操作），由 UI 提示可稍后重试。
  Future<bool> syncUserApiKeys(List<Map<String, dynamic>> keys) async {
    if (keys.isEmpty) return true;
    final url = '${await _baseUrl()}/users/api-key';
    try {
      await _dio.put<dynamic>(
        url,
        data: {'user_id': await _userId(), 'api_keys': keys},
      );
      return true;
    } on DioException {
      return false;
    }
  }

  /// POST /solve-records — 上传解题记录
  ///
  /// 返回后端为本次上传分配的记录 id 列表（用于写回本地 remoteId，
  /// 使删除 / 反馈等后续操作能命中正确的服务器记录）。
  /// 后端未返回任何 id 时返回空列表，调用方保持原状（不写 remoteId）。
  Future<List<int>> uploadSolveRecord(Map<String, dynamic> payload) async {
    final url = '${await _baseUrl()}/solve-records';
    payload['user_id'] = await _userId();
    try {
      final resp = await _dio.post<dynamic>(url, data: payload);
      return _extractIds(resp.data);
    } on DioException catch (e) {
      throw BackendApiException('上传解题记录失败: ${e.message}');
    }
  }

  /// 递归收集响应中的 id 字段，兼容多种返回形状：
  /// `{id}` / `{data:{id}}` / `[{id},...]` / `{items:[{id},...]}`。
  List<int> _extractIds(dynamic data) {
    final ids = <int>[];
    void collect(dynamic v) {
      if (v is Map) {
        final id = v['id'];
        if (id is num) ids.add(id.toInt());
        final items = v['items'];
        if (items is List) {
          for (final it in items) {
            collect(it);
          }
        }
        final inner = v['data'];
        if (inner is Map || inner is List) collect(inner);
      } else if (v is List) {
        for (final it in v) {
          collect(it);
        }
      }
    }

    collect(data);
    return ids;
  }

  /// PATCH /solve-records/{id}/feedback
  Future<void> updateFeedback(int recordId, String feedback) async {
    final url = '${await _baseUrl()}/solve-records/$recordId/feedback';
    try {
      await _dio.patch<dynamic>(
        url,
        data: {'feedback': feedback, 'user_id': await _userId()},
      );
    } on DioException catch (e) {
      throw BackendApiException('更新反馈失败: ${e.message}');
    }
  }

  /// DELETE /solve-records/{id} — 本地与服务器同时删除解题记录
  ///
  /// 以后端主键 [remoteId] 删除对应记录；后端未适配或网络失败时返回 false，
  /// 由调用方决定是否仍删除本地（或提示稍后重试）。
  Future<bool> deleteSolveRecord(int remoteId) async {
    if (remoteId <= 0) return true;
    final url = '${await _baseUrl()}/solve-records/$remoteId';
    try {
      await _dio.delete<dynamic>(
        url,
        data: {'user_id': await _userId()},
      );
      return true;
    } on DioException {
      return false;
    }
  }

  /// GET /knowledge/mastery
  Future<List<Map<String, dynamic>>> fetchKnowledgeMastery() async {
    final url = '${await _baseUrl()}/knowledge/mastery';
    try {
      final resp = await _dio.get<dynamic>(
        url,
        queryParameters: {'user_id': await _userId()},
      );
      final list = resp.data['items'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw BackendApiException('获取知识点掌握度失败: ${e.message}');
    }
  }

  /// GET /knowledge/weak
  Future<List<Map<String, dynamic>>> fetchWeakKnowledge() async {
    final url = '${await _baseUrl()}/knowledge/weak';
    try {
      final resp = await _dio.get<dynamic>(
        url,
        queryParameters: {'user_id': await _userId()},
      );
      final list = resp.data['items'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw BackendApiException('获取薄弱知识点失败: ${e.message}');
    }
  }

  /// GET /solve-records — 下拉后端解题记录（双向同步下行）
  ///
  /// 按 user_id 拉取本机没有的记录：正确作答返回最近 [correctDays] 天，
  /// 错误作答返回最近 [wrongDays] 天。后端暂未适配时抛错，由调用方降级为空。
  Future<List<Map<String, dynamic>>> fetchSolveRecords({
    int correctDays = 30,
    int wrongDays = 90,
  }) async {
    final url = '${await _baseUrl()}/solve-records';
    try {
      final resp = await _dio.get<dynamic>(
        url,
        queryParameters: {
          'user_id': await _userId(),
          'correct_days': correctDays,
          'wrong_days': wrongDays,
        },
      );
      final list = resp.data['items'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw BackendApiException('获取解题记录失败: ${e.message}');
    }
  }

  /// POST /answer-library — 上传标准答案
  Future<void> uploadAnswer(Map<String, dynamic> payload) async {
    final url = '${await _baseUrl()}/answer-library';
    payload['user_id'] = await _userId();
    try {
      await _dio.post<dynamic>(url, data: payload);
    } on DioException catch (e) {
      throw BackendApiException('上传标准答案失败: ${e.message}');
    }
  }

  /// POST /answer-library/match — 后端 FTS5 匹配
  /// 返回 {hit: bool, similarity: double, answer?: {...}}
  Future<Map<String, dynamic>> matchAnswer({
    required String questionText,
    required String questionHash,
  }) async {
    final url = '${await _baseUrl()}/answer-library/match';
    try {
      final resp = await _dio.post<dynamic>(
        url,
        data: {
          'user_id': await _userId(),
          'question_text': questionText,
          'question_hash': questionHash,
        },
      );
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      throw BackendApiException('后端答案匹配失败: ${e.message}');
    }
  }

  /// POST /files/upload — 上传图片
  Future<String> uploadImage(String localPath) async {
    final url = '${await _baseUrl()}/files/upload';
    final form = FormData.fromMap({
      'user_id': await _userId(),
      'file': await MultipartFile.fromFile(localPath),
    });
    try {
      final resp = await _dio.post<dynamic>(url, data: form);
      return (resp.data['url'] ?? resp.data['file_url']).toString();
    } on DioException catch (e) {
      throw BackendApiException('图片上传失败: ${e.message}');
    }
  }

  /// 连通性测试（设置页用）
  ///
  /// 访问后端根 host 的 `/healthz`（而非 API 前缀下的 healthz），
  /// 用于判断「网络可达 + HTTP 服务存活」，与具体 API 路由结构无关。
  /// 任何 2xx/3xx/4xx 响应都视为可达（说明 HTTP 服务起来了），
  /// 仅网络错误或 5xx 视为不通。
  Future<bool> ping() async {
    try {
      final base = await _baseUrl();
      final uri = Uri.tryParse(base);
      // 解析失败或无 host：直接访问 baseUrl 本身探测
      final pingUrl = (uri == null || uri.host.isEmpty)
          ? '$base/healthz'
          : '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/healthz';
      final resp = await _dio.get<dynamic>(
        pingUrl,
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final code = resp.statusCode ?? 0;
      return code >= 200 && code < 500;
    } catch (_) {
      return false;
    }
  }

  /// 稳定设备标识（UUID，本地持久化）
  ///
  /// 后端注册接口按 device_id 复用用户：同一 device_id 首次注册后，
  /// 之后再注册会返回同一个 user_id。因此该值必须在卸载重装间保持稳定，
  /// 否则会反复创建新用户。首次调用生成 UUID v4 并持久化，之后始终复用。
  Future<String> _deviceId() async {
    _prefsCache ??= await SharedPreferences.getInstance();
    var id = _prefsCache!.getString(AppConfig.keyDeviceId);
    if (id == null || id.isEmpty) {
      id = _generateUuid4();
      await _prefsCache!.setString(AppConfig.keyDeviceId, id);
    }
    return id;
  }

  /// 生成 UUID v4（纯 Dart，Random.secure 保证随机性）
  String _generateUuid4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class BackendApiException implements Exception {
  const BackendApiException(this.message);
  final String message;

  @override
  String toString() => 'BackendApiException: $message';
}
