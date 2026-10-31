/// AI 调用配置 - 思谛 STDeel
///
/// 模型组合由用户在设置页自由配置（见 [AiCombo]），
/// 本文件仅保留单模型调用配置与提示词。
library;

/// 单个 AI 模型的调用配置（由 AiCombo 生成）
class AiModelConfig {
  const AiModelConfig({
    required this.name,
    required this.model,
    required this.endpoint,
    required this.apiKey,
    this.multimodal = false,
  });

  /// 模型人类可读名（用于通知/UI，一般为组合名）
  final String name;

  /// 调用 API 时使用的 model 字段
  final String model;

  /// OpenAI 兼容端点（不含 /chat/completions 后缀，已规范化）
  final String endpoint;

  /// API Key
  final String apiKey;

  /// 是否支持多模态（视觉/图片/文档识别）。用于题目分析与文档拆分时优先调度。
  final bool multimodal;

  AiModelConfig copyWith({bool? multimodal}) => AiModelConfig(
        name: name,
        model: model,
        endpoint: endpoint,
        apiKey: apiKey,
        multimodal: multimodal ?? this.multimodal,
      );
}

class AiConfig {
  AiConfig._();

  /// 系统提示词：要求 AI 返回结构化 JSON
  ///
  /// 每道题带 `subject`（科目），用于知识点按学科自动归类，避免人工逐题分类。
  /// **大题含多个小题时必须拆分为独立条目**（如 (1)(2)(3) 各一条），
  /// 便于用户对每个小题单独标记「正确 / 部分错误 / 错误」。
  static const String systemPrompt = '''
你是一个数学及多学科解题助手。请分析图片中的题目，返回 JSON 格式：
{"questions": [{"id": 1, "content": "题目内容", "subject": "所属科目", "knowledge_points": ["知识点1","知识点2"], "answer": "答案", "solution": "简略解答过程", "confidence": 0.95}]}
- subject 是该题所属科目，取值如：数学、语文、英语、物理、化学、生物、政治、历史、地理、其他。不确定时给最可能的科目。
- knowledge_points 中的每个知识点即该题subject对应学科下的知识点。
- 如果图片中有多道题，请在 questions 数组中分别返回。
- 若一道大题包含多个小题（如 (1)(2)(3) 或 ①②③），必须把每个小题拆成 questions 数组中的独立条目：
  在每个小题的 content 中保留小题编号与完整题干，并分别给出该小题自己的 answer、solution、knowledge_points；
  不要把多个小题合并在同一条目内，也不要只给整体答案。
- answer 与 solution 字段内部必须使用 Markdown 排版：可用 **加粗**、- 或 1. 列表、### 小标题、换行分段；
  数学公式一律使用标准 LaTeX 并用 \$ 包裹（如 \$\\frac{3}{4}\$、\$\\sqrt{5}\$、\$x^{2}\$、\$\\overrightarrow{AB}\$），
  严禁使用 \\(...\\)、\\[...\\] 定界符，严禁输出 HTML 或代码块。
仅返回 JSON，不要附加任何解释性文字。
''';

  /// 附加"详细分步解答"指令（疑问按钮）
  static const String detailedSolutionSuffix =
      '。请给出详细分步解答，每一步都要清晰说明。';

  /// 答案库文档解析：把一份 PDF/Word 里的题目与答案，拆成结构化条目。
  ///
  /// 输入可能是整篇文档文本（docx/doc/文本型 PDF），也可能是文档页面图片
  /// （扫描件 PDF，由多模态模型读图）。要求一律只返回 JSON。
  ///
  /// 兼容两类答案册：
  ///   - 带题干：content 非空，可走题干匹配；
  ///   - 只有题号+答案：content 留空字符串，靠 question_no + 卷次认领。
  static const String documentSplitPrompt = '''
你是一个试卷/答案整理助手。请把下面给出的题库文档内容，逐题拆分并整理为标准答案条目。
对每一道题输出：
- question_no: 该题在卷子中的题号（如 3；文档中有题号就用题号，无法确定时用 0）
- content: 题干（完整、准确；如果文档中只有题号与答案、没有原题，请输出空字符串 ""）
- subject: 该题所属科目（如 数学、语文、英语、物理、化学、生物、政治、历史、地理、其他）
- answer: 标准答案（内部用 Markdown 排版，公式用 \$...\$ 包裹的标准 LaTeX）
- solution: 简略的解答过程（内部用 Markdown 排版，公式用 \$...\$ 包裹的标准 LaTeX）
- knowledge_points: 知识点标签数组（1~5 个，如 ["三角函数","两角和差公式"]），都归属于 subject 对应学科
- confidence: 一个 0~1 之间的置信度
返回纯 JSON，格式如下（不要输出任何解释文字，不要用 markdown 代码块）：
{"questions":[{"question_no":3,"content":"...","subject":"科目","answer":"...","solution":"...","knowledge_points":["..."],"confidence":0.95}]}
如果文档中题目无法辨认或没有题目，请返回 {"questions":[]}。
''';
}
