/// 题目/答案/解答文本渲染封装 - 思谛 STDeel
///
/// 统一入口：内部委托 [MarkdownLatex] 做 Markdown + LaTeX 混合渲染。
///
/// 背景：AI 输出常含 `\frac{3}{4}`、`\sqrt{5}`、`x^2` 等 LaTeX，以及 Markdown
/// 结构（标题/列表/粗体/代码块）。历史实现曾直接用纯文本渲染，公式原样显示，
/// 阅读困难。曾尝试 flutter_tex（WebView）在受限布局中经常空白，故不再使用。
///
/// 现方案：纯 Dart 的 `Text.rich` 渲染，可选中/可复制，公式转 Unicode
/// （`(3)/(4)`、`√(5)`、`x²`、`≤`），任何异常输入都退化为原文，绝不白屏。
library;

import 'package:flutter/material.dart';

import 'markdown_latex.dart';

class LatexRenderer extends StatelessWidget {
  const LatexRenderer({
    super.key,
    required this.text,
    this.isBlock = true,
    this.style,
  });

  /// 题目 / 答案 / 解答原文（Markdown / LaTeX 混排）
  final String text;
  final bool isBlock;

  /// 可选基础样式
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return MarkdownLatex(text: text, isBlock: isBlock, style: style);
  }
}