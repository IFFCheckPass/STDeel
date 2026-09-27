/// 设置状态管理 - 思谛 STDeel
///
/// 管理：
///   - AI 供应商与模型配置（`List<AiProvider>`，JSON 持久化；供应商→多模型，两阶段启停/排序）
///   - think 检测超时阈值
///   - 后端 URL 与连通性测试
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/ai_config.dart';
import '../config/app_config.dart';
import '../models/ai_provider.dart';
import '../services/backend_api.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required BackendApi backendApi}) : _api = backendApi;

  final BackendApi _api;

  String _publicUrl = AppConfig.defaultBackendUrl;
  String _intranetUrl = '';
  bool _usePublic = true;
  List<AiProvider> _providers = [];
  int _thinkTimeout = AppConfig.defaultThinkTimeoutSeconds;
  bool _pinging = false;
  bool _pingOk = false;
  bool _loaded = false;
  ThemeMode _themeMode = ThemeMode.system;
  // 账号绑定（默认隐藏）
  String? _username;

  /// 当前使用的后端 URL（按所选通道返回）
  String get backendUrl => _usePublic
      ? _publicUrl
      : (_intranetUrl.trim().isEmpty ? _publicUrl : _intranetUrl);
  String get backendUrlPublic => _publicUrl;
  String get backendUrlIntranet => _intranetUrl;
  bool get usePublicBackend => _usePublic;
  List<AiProvider> get providers => List.unmodifiable(_providers);
  int get thinkTimeout => _thinkTimeout;
  bool get pinging => _pinging;
  bool get pingOk => _pingOk;
  bool get loaded => _loaded;
  String? get username => _username;
  ThemeMode get themeMode => _themeMode;

  int get availableModelCount {
    var n = 0;
    for (final p in _providers) {
      for (final m in p.models) {
        if (m.solveEnabled && p.isComplete) n++;
      }
    }
    return n;
  }

  Future<void> load() async {
    _publicUrl = await _api.getBackendUrlPublic();
    _intranetUrl = await _api.getBackendUrlIntranet() ?? '';
    _usePublic = await _api.getUsePublicBackend();
    _thinkTimeout = await _api.getThinkTimeoutSeconds();
    _username = await _api.getUsername();
    _themeMode = _parseThemeMode(await _api.getThemeMode());
    final raw = await _api.getAiCombosJson();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          // 新结构：List<AiProvider>
          if (decoded.every((e) =>
              (e as Map).containsKey('baseUrl') && (e).containsKey('models'))) {
            _providers = decoded
                .map((e) => AiProvider.fromJson(e as Map<String, dynamic>))
                .toList();
          } else if (decoded.first is Map &&
              (decoded.first as Map).containsKey('modelId')) {
            // 旧结构：List<AiCombo> → 迁移为单模型供应商
            _providers = _migrateFromCombos(decoded.cast<Map>());
          } else {
            _providers = defaultAiProviders();
          }
        } else {
          _providers = defaultAiProviders();
        }
      } catch (_) {
        _providers = defaultAiProviders();
      }
    } else {
      _providers = defaultAiProviders();
    }
    _loaded = true;
    notifyListeners();
    if (_username != null && _username!.isNotEmpty) {
      unawaited(_syncAccountApiKeys());
    }
  }

  /// 迁移旧版扁平组合（AiCombo）为「单模型供应商」
  /// 每个旧组合 ≈ 一个供应商（含一个模型，继承其多模态与启用）。
  List<AiProvider> _migrateFromCombos(List<Map> combos) {
    return combos.map((c) {
      final modelId = c['modelId'] as String? ?? '';
      final multimodal = c['multimodal'] as bool? ?? false;
      final enabled = c['enabled'] as bool? ?? true;
      final mid =
          'm-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      return AiProvider(
        id: c['id'] as String? ?? 'p-${mid}',
        name: c['name'] as String? ?? '未命名供应商',
        baseUrl: c['baseUrl'] as String? ?? '',
        apiKey: c['apiKey'] as String? ?? '',
        models: [
          AiModel(
            id: mid,
            name: c['name'] as String? ?? '模型',
            modelId: modelId,
            multimodal: multimodal,
            splitEnabled: multimodal && enabled,
            splitOrder: 0,
            solveEnabled: enabled,
            solveOrder: 0,
          ),
        ],
      );
    }).toList();
  }

  Future<void> _persist() async {
    await _api.setAiCombosJson(
      jsonEncode(_providers.map((p) => p.toJson()).toList()),
    );
  }

  // ---------- 供应商 / 模型管理 ----------

  Future<void> saveProvider(AiProvider provider) async {
    final idx = _providers.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      _providers[idx] = provider;
    } else {
      _providers.add(provider);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProvider(String id) async {
    _providers.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> saveModel(String providerId, AiModel model) async {
    final p = _providers.firstWhere((x) => x.id == providerId,
        orElse: () => throw StateError('供应商不存在'));
    final idx = p.models.indexWhere((m) => m.id == model.id);
    if (idx >= 0) {
      p.models[idx] = model;
    } else {
      p.models.add(model);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteModel(String providerId, String modelId) async {
    final p = _providers.firstWhere((x) => x.id == providerId,
        orElse: () => throw StateError('供应商不存在'));
    p.models.removeWhere((m) => m.id == modelId);
    await _persist();
    notifyListeners();
  }

  /// 拖动排序某阶段的模型顺序
  /// [stage]: 'split' | 'solve'
  Future<void> reorderStage(String providerId, String modelId, String stage,
      int oldIndex, int newIndex) async {
    final p = _providers.firstWhere((x) => x.id == providerId,
        orElse: () => throw StateError('供应商不存在'));
    final models = List<AiModel>.from(
        p.models.where((m) => m.multimodal || stage == 'solve').toList());
    final currentIdx = models.indexWhere((m) => m.id == modelId);
    if (currentIdx < 0) return;
    if (newIndex > currentIdx) newIndex -= 1;
    final item = models.removeAt(currentIdx);
    models.insert(newIndex, item);
    // 更新该阶段顺序
    for (var i = 0; i < models.length; i++) {
      if (stage == 'split') {
        models[i] = models[i].copyWith(splitOrder: i);
      } else {
        models[i] = models[i].copyWith(solveOrder: i);
      }
    }
    await _persist();
    notifyListeners();
  }

  /// 切换某模型在某阶段的启用状态
  Future<void> toggleStage(String providerId, String modelId, String stage) async {
    final p = _providers.firstWhere((x) => x.id == providerId,
        orElse: () => throw StateError('供应商不存在'));
    final mIdx = p.models.indexWhere((m) => m.id == modelId);
    if (mIdx < 0) return;
    if (stage == 'split') {
      p.models[mIdx] = p.models[mIdx].copyWith(
          splitEnabled: !p.models[mIdx].splitEnabled);
    } else {
      p.models[mIdx] = p.models[mIdx].copyWith(
          solveEnabled: !p.models[mIdx].solveEnabled);
    }
    await _persist();
    notifyListeners();
  }

  // ---------- 两阶段调用链生成 ----------

  /// 拆图分割阶段调用链：仅多模态且开启 split 的模型，按 splitOrder 排序
  List<AiModelConfig> buildSplitChain() {
    final list = <(AiModel, AiProvider)>[];
    for (final p in _providers) {
      for (final m in p.models) {
        if (m.multimodal && m.splitEnabled && m.hasModelId && p.isComplete) {
          list.add((m, p));
        }
      }
    }
    list.sort((a, b) => a.$1.splitOrder.compareTo(b.$1.splitOrder));
    return list
        .map((e) => e.$1.toModelConfig(
            providerName: e.$2.name,
            baseUrl: e.$2.baseUrl,
            apiKey: e.$2.apiKey))
        .toList();
  }

  /// 读题解答阶段·非多模态链（省经费优先），按 solveOrder 排序
  List<AiModelConfig> buildSolveChainPlain() {
    final list = <(AiModel, AiProvider)>[];
    for (final p in _providers) {
      for (final m in p.models) {
        if (!m.multimodal && m.solveEnabled && m.hasModelId && p.isComplete) {
          list.add((m, p));
        }
      }
    }
    list.sort((a, b) => a.$1.solveOrder.compareTo(b.$1.solveOrder));
    return list
        .map((e) => e.$1.toModelConfig(
            providerName: e.$2.name,
            baseUrl: e.$2.baseUrl,
            apiKey: e.$2.apiKey))
        .toList();
  }

  /// 读题解答阶段·多模态链（标记题/回退用），按 solveOrder 排序
  List<AiModelConfig> buildSolveChainMultimodal() {
    final list = <(AiModel, AiProvider)>[];
    for (final p in _providers) {
      for (final m in p.models) {
        if (m.multimodal && m.solveEnabled && m.hasModelId && p.isComplete) {
          list.add((m, p));
        }
      }
    }
    list.sort((a, b) => a.$1.solveOrder.compareTo(b.$1.solveOrder));
    return list
        .map((e) => e.$1.toModelConfig(
            providerName: e.$2.name,
            baseUrl: e.$2.baseUrl,
            apiKey: e.$2.apiKey))
        .toList();
  }

  /// 兼容旧调用方：整体读题解答链 = 非多模态在前、多模态在后（成本优先） 
  List<AiModelConfig> buildModelChain() =>
      [...buildSolveChainPlain(), ...buildSolveChainMultimodal()];

  // ---------- 通用设置 ----------

  Future<void> setBackendUrl(String url) async {
    final normalized = _normalize(url);
    if (_usePublic) {
      _publicUrl = normalized;
      await _api.setBackendUrlPublic(_publicUrl);
    } else {
      _intranetUrl = normalized;
      await _api.setBackendUrlIntranet(_intranetUrl);
    }
    notifyListeners();
  }

  Future<void> setBackendUrlPublic(String url) async {
    _publicUrl = _normalize(url);
    await _api.setBackendUrlPublic(_publicUrl);
    notifyListeners();
  }

  Future<void> setBackendUrlIntranet(String url) async {
    final v = url.trim();
    _intranetUrl = v.isEmpty ? '' : _normalize(v);
    await _api.setBackendUrlIntranet(_intranetUrl);
    notifyListeners();
  }

  Future<void> setUsePublicBackend(bool usePublic) async {
    _usePublic = usePublic;
    await _api.setUsePublicBackend(usePublic);
    notifyListeners();
  }

  String _normalize(String url) {
    final t = url.trim();
    if (t.isEmpty) return t;
    var u = t;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> setThinkTimeout(int seconds) async {
    _thinkTimeout = seconds.clamp(5, 300);
    await _api.setThinkTimeoutSeconds(_thinkTimeout);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _api.setThemeMode(_themeModeName(mode));
    notifyListeners();
  }

  String _themeModeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  ThemeMode _parseThemeMode(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> ping() async {
    _pinging = true;
    _pingOk = false;
    notifyListeners();
    try {
      _pingOk = await _api.ping();
    } catch (_) {
      _pingOk = false;
    } finally {
      _pinging = false;
      notifyListeners();
    }
  }

  // ---------- 账号绑定（隐藏预埋） ----------

  Future<void> _syncAccountApiKeys() async {
    final u = _username;
    if (u == null || u.isEmpty) return;
    final keys = <Map<String, dynamic>>[];
    for (final p in _providers) {
      if (p.isComplete && p.apiKey.trim().isNotEmpty) {
        keys.add({'api_key': p.apiKey.trim(), 'name': p.name, 'enabled': true});
      }
    }
    if (keys.isEmpty) return;
    await _api.syncUserApiKeys(keys);
  }

  Future<bool> setUsername(String username) async {
    final u = username.trim();
    _username = u;
    await _api.setUsername(u);
    notifyListeners();
    if (u.isNotEmpty && AppConfig.kAccountBindingEnabled) {
      return _api.bindUserByUsername(u);
    }
    return true;
  }
}