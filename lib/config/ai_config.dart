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
  static const String systemPrompt = '''
你是一个数学及多学科解题助手。请分析图片中的题目，返回 JSON 格式：
{"questions": [{"id": 1, "content": "题目内容", "subject": "所属科目", "knowledge_points": ["知识点1","知识点2"], "answer": "答案", "solution": "简略解答过程", "confidence": 0.95}]}
- subject 是该题所属科目，取值如：数学、语文、英语、物理、化学、生物、政治、历史、地理、其他。不确定时给最可能的科目。
- knowledge_points 中的每个知识点即该题subject对应学科下的知识点。
如果图片中有多道题，请在 questions 数组中分别返回。
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
- answer: 标准答案
- solution: 简略的解答过程
- knowledge_points: 知识点标签数组（1~5 个，如 ["三角函数","两角和差公式"]），都归属于 subject 对应学科
- confidence: 一个 0~1 之间的置信度
返回纯 JSON，格式如下（不要输出任何解释文字，不要用 markdown 代码块）：
{"questions":[{"question_no":3,"content":"...","subject":"科目","answer":"...","solution":"...","knowledge_points":["..."],"confidence":0.95}]}
如果文档中题目无法辨认或没有题目，请返回 {"questions":[]}。
''';

  /// 拆图分割提示词（v0.9.0 两阶段管线的 Stage A）。
  ///
  /// 由多模态模型读取整页图片：提取题目文字、对图片/图表做理解转述，
  /// 并将数学绘图转成文本/结构化描述；若某题难以转换为纯文本（如复杂几何
  /// 图形、数轴、表格、函数图像），则标记 ``needs_multimodal: true``，
  /// 进入读题解答阶段优先用多模态模型直接解该题。
  ///
  /// 只输出题号与题干，不解答。供「拆图分割 → 答案库匹配 → 分类解题」使用。
  static const String imageSplitPrompt = '''
你是一个图片题目识别助手。请读取这张图片中的每一道题目，做三件事：
1) 尽量完整提取题目文字（含选项、图表/公式的描述）；
2) 把图片中的图表、几何图形、数学绘图用文字或结构化语言精确转述（坐标系、
   圆/三角形边长、坐标点、曲线方程等尽量补全）；
3) 若某道题(如复杂几何图/难以转文字的图)无法用纯文本表达清楚，请把该题标记
   needs_multimodal 为 true，示意解答阶段需要直接看原图（多模态）求解；否则为 false。
对每一道题输出：
- question_no: 该题在卷子中的题号（如 3；图中无题号时按从上到下从 1 开始编号）
- content: 该题完整题干（文字+图形转述的综合，尽量完整）
- subject: 所属科目（数学、语文、英语、物理、化学、生物、政治、历史、地理、其他）
- needs_multimodal: 是否必须用多模态模型直接看图解题（布尔）
返回纯 JSON，格式如下（不要输出任何解释文字，不要用 markdown 代码块）：
{"questions":[{"question_no":3,"content":"...","subject":"数学","needs_multimodal":false}]}
如果图片中没有题目，请返回 {"questions":[]}。
''';

  /// 轻量拆题：只识别题号与题干，不解答。
  ///
  /// 用于解题前的"拆题→答案库匹配"：命中答案库的题直接返回答案，
  /// 未命中的题才走完整解题，从而省掉命中部分的 token 消耗。
  /// content 尽力完整（含选项/图表描述），供题干 hash 匹配与反哺补全。
  static const String questionExtractPrompt = '''
你是一个题目识别助手。请识别图片中的每一道题目，只输出题号与题干，不要解答，不要给出任何答案。
对每一道题输出：
- question_no: 该题在卷子中的题号（如 3；图中无题号时，按从上到下顺序从 1 开始编号）
- content: 该题的完整题干（含选项、图表/公式描述，尽力完整准确）
返回纯 JSON，格式如下（不要输出任何解释文字，不要用 markdown 代码块）：
{"questions":[{"question_no":3,"content":"..."}]}
如果图片中没有题目，请返回 {"questions":[]}。
''';
}
