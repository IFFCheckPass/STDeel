/// 基础冒烟测试 - 思谛 STDeel
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:stdeel/models/ai_provider.dart';

void main() {
  test('AiProvider/AiModel JSON 序列化往返', () {
    final provider = AiProvider(
      id: 'p-1',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1/',
      apiKey: 'sk-test',
      models: [
        AiModel(
          id: 'm-1',
          name: 'V3',
          modelId: 'deepseek-chat',
          multimodal: false,
          solveEnabled: true,
        ),
      ],
    );
    final restored = AiProvider.fromJson(provider.toJson());
    expect(restored.name, provider.name);
    expect(restored.baseUrl, provider.baseUrl);
    expect(restored.apiKey, provider.apiKey);
    expect(restored.models.length, 1);
    expect(restored.models.first.modelId, 'deepseek-chat');
    expect(restored.models.first.solveEnabled, true);
  });

  test('用户模型名 = 编号 + 供应商名 + 模型名', () {
    final providers = [
      AiProvider(
        id: 'p-1',
        name: 'DeepSeek',
        baseUrl: '',
        apiKey: '',
        models: [AiModel(id: 'm-1', name: 'V3', modelId: 'deepseek-chat')],
      ),
    ];
    final p = providers.first;
    final m = p.models.first;
    expect(userModelName(providers, p, m), '1-1 DeepSeek V3');
    expect(providerNo(providers, p), 1);
    expect(modelNo(p, m), 1);
  });

  test('normalizeBaseUrl 补全协议并去尾部斜杠', () {
    expect(normalizeBaseUrl('api.example.com/v1/'),
        'https://api.example.com/v1');
    expect(normalizeBaseUrl('https://api.example.com/v1/'),
        'https://api.example.com/v1');
    expect(normalizeBaseUrl('http://a.b/c//'), 'http://a.b/c');
    expect(normalizeBaseUrl(''), '');
  });
}