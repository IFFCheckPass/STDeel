/// AI 供应商与模型配置 - 思谛 STDeel (v0.9.0)
///
/// 取代旧的扁平组合（`AiCombo`），以「供应商 → 多模型」层级配置 AI：
/// - 每个 [AiProvider] 含一份 Base URL + 一个 API Key + 多个 [AiModel]；
/// - 每个 [AiModel] 是实际可调用的模型，可在「拆图分割 / 读题解答」两阶段
///   分别配置启用与顺序；
/// - 界面统一以「用户模型名」展示，形如 `1-1 Deepseek V4.1Flash`
///   （`1-1` 为唯一编号 = 供应商序号-模型序号，从 1 起）。
library;

import '../config/ai_config.dart';

/// 单个 AI 模型（隶属于某供应商）
class AiModel {
  AiModel({
    required this.id,
    required this.name,
    required this.modelId,
    this.multimodal = false,
    this.splitEnabled = true,
    this.splitOrder = 0,
    this.solveEnabled = true,
    this.solveOrder = 0,
  });

  /// 唯一模型 id（持久化用，非展示编号）
  final String id;

  /// 自定义模型名（如 V4.1Flash、qwen-vl-plus）
  String name;

  /// 调用 API 时使用的 model 字段
  String modelId;

  /// 是否支持多模态（视觉 / 图片理解）
  bool multimodal;

  /// 是否参与「拆图分割」阶段（仅多模态模型有意义）
  bool splitEnabled;

  /// 「拆图分割」阶段内的调用顺序（小者优先）
  int splitOrder;

  /// 是否参与「读题解答」阶段
  bool solveEnabled;

  /// 「读题解答」阶段内的调用顺序（小者优先）
  int solveOrder;

  bool get hasModelId => modelId.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'modelId': modelId,
        'multimodal': multimodal,
        'splitEnabled': splitEnabled,
        'splitOrder': splitOrder,
        'solveEnabled': solveEnabled,
        'solveOrder': solveOrder,
      };

  factory AiModel.fromJson(Map<String, dynamic> json) => AiModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '未命名模型',
        modelId: json['modelId'] as String? ?? '',
        multimodal: json['multimodal'] as bool? ?? false,
        splitEnabled: json['splitEnabled'] as bool? ?? true,
        splitOrder: json['splitOrder'] as int? ?? 0,
        solveEnabled: json['solveEnabled'] as bool? ?? true,
        solveOrder: json['solveOrder'] as int? ?? 0,
      );

  AiModel copyWith({
    String? id,
    String? name,
    String? modelId,
    bool? multimodal,
    bool? splitEnabled,
    int? splitOrder,
    bool? solveEnabled,
    int? solveOrder,
  }) =>
      AiModel(
        id: id ?? this.id,
        name: name ?? this.name,
        modelId: modelId ?? this.modelId,
        multimodal: multimodal ?? this.multimodal,
        splitEnabled: splitEnabled ?? this.splitEnabled,
        splitOrder: splitOrder ?? this.splitOrder,
        solveEnabled: solveEnabled ?? this.solveEnabled,
        solveOrder: solveOrder ?? this.solveOrder,
      );

  /// 转成 AI 调用配置（供应商信息由调用方注入 providerName / baseUrl / apiKey）
  AiModelConfig toModelConfig({
    required String providerName,
    required String baseUrl,
    required String apiKey,
  }) =>
      AiModelConfig(
        name: '${providerName} · ${name}',
        model: modelId.trim(),
        endpoint: normalizeBaseUrl(baseUrl),
        apiKey: apiKey.trim(),
        multimodal: multimodal,
      );
}

/// AI 供应商：一份 Base URL + 一个 API Key + 多个模型
class AiProvider {
  AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    List<AiModel>? models,
  }) : models = models ?? [];

  /// 唯一供应商 id
  final String id;

  /// 自定义供应商名（如 Deepseek、通义千问）
  String name;

  /// OpenAI 兼容 Base URL，如 https://api.deepseek.com/v1
  String baseUrl;

  /// API Key
  String apiKey;

  /// 该供应商下的模型（顺序即供应商内模型序号）
  List<AiModel> models;

  bool get isComplete =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty && models.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'models': models.map((m) => m.toJson()).toList(),
      };

  factory AiProvider.fromJson(Map<String, dynamic> json) => AiProvider(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '未命名供应商',
        baseUrl: json['baseUrl'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        models: (json['models'] as List<dynamic>? ?? const [])
            .map((e) => AiModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 供应商序号（1 起）
int providerNo(List<AiProvider> providers, AiProvider p) {
  final i = providers.indexWhere((x) => x.id == p.id);
  return i >= 0 ? i + 1 : 0;
}

/// 模型在供应商内的序号（1 起）
int modelNo(AiProvider provider, AiModel m) {
  final i = provider.models.indexWhere((x) => x.id == m.id);
  return i >= 0 ? i + 1 : 0;
}

/// 用户模型名：`编号 + 供应商名 + 模型名`，如 `1-1 Deepseek V4.1Flash`
String userModelName(List<AiProvider> providers, AiProvider p, AiModel m) {
  final pn = providerNo(providers, p);
  final mn = modelNo(p, m);
  if (pn == 0 || mn == 0) return '${p.name} · ${m.name}';
  return '$pn-$mn ${p.name} ${m.name}';
}

/// 规范化 Base URL：补全协议、去尾部斜杠
String normalizeBaseUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return '';
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// 预置默认供应商模板（API Key 留空，由用户填写）
///
/// 默认给 DeepSeek（非多模态）、通义千问 VL（多模态）、NVIDIA NIM（多模态）。
List<AiProvider> defaultAiProviders() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return [
    AiProvider(
      id: 'preset-deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: '',
      models: [
        AiModel(
          id: 'm-deepseek-chat-$ts',
          name: 'V3',
          modelId: 'deepseek-chat',
          multimodal: false,
          solveEnabled: true,
          solveOrder: 0,
        ),
      ],
    ),
    AiProvider(
      id: 'preset-qwen-vl',
      name: '通义千问 VL',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      apiKey: '',
      models: [
        AiModel(
          id: 'm-qwen-vl-$ts',
          name: 'VL',
          modelId: 'qwen-vl-plus',
          multimodal: true,
          splitEnabled: true,
          solveEnabled: true,
          splitOrder: 0,
          solveOrder: 1,
        ),
      ],
    ),
    AiProvider(
      id: 'preset-nim',
      name: 'NVIDIA NIM',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      apiKey: '',
      models: [
        AiModel(
          id: 'm-nim-$ts',
          name: '2.5VL',
          modelId: 'qwen/qwen2.5-vl-72b-instruct',
          multimodal: true,
          splitEnabled: true,
          solveEnabled: true,
          splitOrder: 1,
          solveOrder: 2,
        ),
      ],
    ),
  ];
}