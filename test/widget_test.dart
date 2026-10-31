/// 基础冒烟测试 - 思谛 STDeel
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:stdeel/models/ai_provider.dart';
import 'package:stdeel/widgets/markdown_latex.dart';

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

  // ---- LaTeX → Unicode（答案可读性，v0.9.10） ----
  test('LaTeX 分数转换为可读文本', () {
    expect(latexToUnicode(r'm=-\frac{3}{4}'), 'm=-3/4');
    expect(latexToUnicode(r'\frac{a+b}{2}'), '(a+b)/2');
  });

  test('LaTeX 根号转换为可读文本', () {
    expect(latexToUnicode(r'4\sqrt{5}'), '4√(5)');
    expect(latexToUnicode(r'\sqrt{x+1}'), '√(x+1)');
    expect(latexToUnicode(r'\sqrt[3]{8}'), '³√(8)');
  });

  test('LaTeX 上下标与运算符转换', () {
    expect(latexToUnicode(r'x^{2}+y^2=25'), 'x²+y²=25');
    expect(latexToUnicode(r'a \le b \ge c \neq d'),
        'a ≤ b ≥ c ≠ d');
    expect(latexToUnicode(r'2 \times 3 \cdot 4'), '2 × 3 · 4');
    expect(latexToUnicode(r'\pi \approx 3.14'), 'π ≈ 3.14');
  });

  test('LaTeX 定界符与文本命令清理', () {
    expect(latexToUnicode(r'$\frac{1}{2}$'), '1/2');
    expect(latexToUnicode(r'\text{面积} = \frac{1}{2}ab'), '面积 = 1/2ab');
    expect(latexToUnicode(r'\left( x \right)'), '( x )');
  });

  test('无 LaTeX 的普通文本保持不变', () {
    expect(latexToUnicode('圆的标准方程'), '圆的标准方程');
    expect(latexToUnicode('m=3, n=4'), 'm=3, n=4');
  });

  // ---- v0.9.12：向量/重音/集合/环境等模型常用语法 ----
  test('LaTeX 向量、粗体与集合符号转换', () {
    expect(
      latexToUnicode(r'\overrightarrow{AB}=\mathbf{a}+2\mathbf{b}'),
      'AB⃗=a+2b',
    );
    expect(latexToUnicode(r'\mathbb{R}'), 'ℝ');
    expect(latexToUnicode(r'\vec{a}'), 'a⃗');
    expect(latexToUnicode(r'\overline{AB}'), 'AB̅');
  });

  test('LaTeX 环境/多行/未知命令兜底', () {
    expect(
      latexToUnicode(r'\begin{cases}x+y=1\\x-y=3\end{cases}'),
      'x+y=1\nx-y=3',
    );
    expect(latexToUnicode(r'\left|\overrightarrow{AB}\right|'), '|AB⃗|');
    expect(latexToUnicode(r'\foo{bar}'), 'bar');
    expect(latexToUnicode(r'\displaystyle x^{2}'), 'x²');
  });

  test('Markdown 行内样式不被 LaTeX 转换破坏', () {
    expect(latexToUnicode('**重点**：圆的标准方程'), '**重点**：圆的标准方程');
  });
}