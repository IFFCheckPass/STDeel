/// Markdown + LaTeX 混合文本渲染 - 思谛 STDeel
///
/// AI 输出常混合 Markdown 结构（标题/列表/粗体/代码块）与 LaTeX 数学语法
/// （`\frac{3}{4}`、`\sqrt{5}`、`x^2`、`\le` 等）。历史上答案用纯文本渲染，
/// 公式会原样显示成 `m=-\frac{3}{4}`，难以阅读。
///
/// 本组件在**不引入 WebView / 数学渲染插件**（避免受限布局空白与崩溃）的前提下：
///   1. 解析常用 Markdown 块级结构：标题、无序/有序列表、引用、代码块、分隔线；
///   2. 解析行内 Markdown：`**粗体**`、`*斜体*`、`` `代码` ``、`~~删除线~~`、链接；
///   3. 识别并转换 LaTeX：`$...$`、`$$...$$`、`\(...\)`、`\[...\]` 以及
///      **裸命令**（未加 `$` 的 `\frac` / `\sqrt` 等，AI 常见输出），
///      统一转成 Unicode 可读形式（`(3)/(4)`、`√(5)`、`x²`、`≤`…）。
///
/// 全部基于 `Text.rich` 渲染，可选中、可复制，任何异常输入都只会退化为原文，
/// 不会崩溃或白屏（数据完整性/可用性优先，见 AGENTS.md）。
library;

import 'package:flutter/material.dart';

/// Markdown + LaTeX 混合文本（可选中）
class MarkdownLatex extends StatelessWidget {
  const MarkdownLatex({
    super.key,
    required this.text,
    this.isBlock = true,
    this.style,
  });

  /// 原始文本（Markdown / LaTeX 混排）
  final String text;

  /// 块级（题目/答案/解答正文）时字号略大
  final bool isBlock;

  /// 基础文字样式（可选）
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) return const SizedBox.shrink();

    final base = style ??
        TextStyle(
          height: 1.65,
          fontSize: isBlock ? 14 : 13,
          leadingDistribution: TextLeadingDistribution.even,
        );

    final blocks = _parseBlocks(normalized);
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : _blockGap(blocks[i]),
            ),
            child: _renderBlock(context, blocks[i], base),
          ),
      ],
    );
  }

  double _blockGap(_Block b) {
    switch (b.kind) {
      case _BlockKind.heading:
        return 10;
      case _BlockKind.code:
        return 8;
      case _BlockKind.divider:
        return 10;
      default:
        return 6;
    }
  }

  Widget _renderBlock(BuildContext context, _Block b, TextStyle base) {
    switch (b.kind) {
      case _BlockKind.heading:
        final size = switch (b.level) {
          1 => 18.0,
          2 => 16.5,
          3 => 15.0,
          _ => 14.0,
        };
        return SelectableText.rich(
          TextSpan(
            children: _inline(b.text, base),
            style: base.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case _BlockKind.bullet:
        return _withMarker('•', b, base);
      case _BlockKind.ordered:
        return _withMarker(b.marker, b, base);
      case _BlockKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                width: 3,
              ),
            ),
          ),
          child: SelectableText.rich(
            TextSpan(children: _inline(b.text, base), style: base),
          ),
        );
      case _BlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            b.text,
            style: base.copyWith(
              fontFamily: 'monospace',
              fontSize: (base.fontSize ?? 14) - 1,
              height: 1.5,
            ),
          ),
        );
      case _BlockKind.divider:
        return Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        );
      case _BlockKind.paragraph:
        return SelectableText.rich(
          TextSpan(children: _inline(b.text, base), style: base),
        );
    }
  }

  /// 列表项：标记 + 首行缩进对齐
  Widget _withMarker(String marker, _Block b, TextStyle base) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            marker,
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SelectableText.rich(
            TextSpan(children: _inline(b.text, base), style: base),
          ),
        ),
      ],
    );
  }
}

// ======================= 块级解析 =======================

enum _BlockKind { paragraph, heading, bullet, ordered, quote, code, divider }

class _Block {
  _Block(this.kind, this.text, {this.level = 1, this.marker = ''});

  final _BlockKind kind;
  final String text;
  final int level;
  final String marker;
}

List<_Block> _parseBlocks(String raw) {
  final lines = raw.split('\n');
  final blocks = <_Block>[];
  final para = <String>[];
  var inFence = false;
  final codeBuf = <String>[];

  void flushPara() {
    if (para.isEmpty) return;
    final t = para.join('\n').trim();
    if (t.isNotEmpty) blocks.add(_Block(_BlockKind.paragraph, t));
    para.clear();
  }

  for (final line in lines) {
    final trimmedRight = line.trimRight();
    final trimmed = trimmedRight.trim();

    // 代码围栏 ``` 或 ~~~
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      if (inFence) {
        blocks.add(_Block(_BlockKind.code, codeBuf.join('\n')));
        codeBuf.clear();
        inFence = false;
      } else {
        flushPara();
        inFence = true;
      }
      continue;
    }
    if (inFence) {
      codeBuf.add(trimmedRight);
      continue;
    }

    if (trimmed.isEmpty) {
      flushPara();
      continue;
    }

    // 分隔线
    if (RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(trimmed)) {
      flushPara();
      blocks.add(_Block(_BlockKind.divider, ''));
      continue;
    }

    // 标题
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushPara();
      blocks.add(_Block(
        _BlockKind.heading,
        heading.group(2)!.trim(),
        level: heading.group(1)!.length,
      ));
      continue;
    }

    // 引用
    final quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
    if (quote != null) {
      flushPara();
      blocks.add(_Block(_BlockKind.quote, quote.group(1)!.trim()));
      continue;
    }

    // 无序列表
    final bullet = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      flushPara();
      blocks.add(_Block(_BlockKind.bullet, bullet.group(1)!.trim()));
      continue;
    }

    // 有序列表
    final ordered = RegExp(r'^\s*(\d+[.)])\s+(.*)$').firstMatch(line);
    if (ordered != null) {
      flushPara();
      blocks.add(_Block(
        _BlockKind.ordered,
        ordered.group(2)!.trim(),
        marker: ordered.group(1)!,
      ));
      continue;
    }

    // 普通段落（连续行合并，保留换行）
    para.add(trimmedRight);
  }

  // 未闭合围栏：按代码块输出（避免内容丢失）
  if (inFence && codeBuf.isNotEmpty) {
    blocks.add(_Block(_BlockKind.code, codeBuf.join('\n')));
  }
  flushPara();
  return blocks;
}

// ======================= 行内解析 =======================

/// 行内 Markdown + LaTeX → spans
List<InlineSpan> _inline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final mathRe = RegExp(
    r'\$\$([\s\S]*?)\$\$'
    r'|\$([^\$\n]+?)\$'
    r'|\\\(([\s\S]*?)\\\)'
    r'|\\\[([\s\S]*?)\\\]',
  );

  var cursor = 0;
  for (final m in mathRe.allMatches(text)) {
    if (m.start > cursor) {
      spans.addAll(_markdownSpans(text.substring(cursor, m.start), base));
    }
    final tex = m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4) ?? '';
    spans.add(TextSpan(
      text: latexToUnicode(tex).trim(),
      style: base,
    ));
    cursor = m.end;
  }
  if (cursor < text.length) {
    spans.addAll(_markdownSpans(text.substring(cursor), base));
  }

  // 空文本保护
  if (spans.isEmpty) return [TextSpan(text: text, style: base)];
  return spans;
}

/// 行内 Markdown → spans（粗体/斜体/代码/删除线/链接），并处理裸 LaTeX
List<InlineSpan> _markdownSpans(String text, TextStyle base) {
  if (text.isEmpty) return const [];

  // 裸 LaTeX（AI 常不加 $）：只要出现明确的命令，就整段做公式转换
  final plain = _looksLikeLatex(text) ? latexToUnicode(text) : text;

  final re = RegExp(
    r'(\*\*[\s\S]+?\*\*)'
    r'|(__[\s\S]+?__)'
    r'|(\*[^*\n]+?\*)'
    r'|(_[^_\n]+?_)'
    r'|(`[^`\n]+?`)'
    r'|(~~[\s\S]+?~~)'
    r'|(\[[^\]]+\]\([^)]+\))',
  );

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final m in re.allMatches(plain)) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: plain.substring(cursor, m.start), style: base));
    }
    final token = m.group(0)!;
    if (token.startsWith('**') && token.length > 4) {
      spans.add(TextSpan(
        text: token.substring(2, token.length - 2),
        style: base.copyWith(fontWeight: FontWeight.w700),
      ));
    } else if (token.startsWith('__') && token.length > 4) {
      spans.add(TextSpan(
        text: token.substring(2, token.length - 2),
        style: base.copyWith(fontWeight: FontWeight.w700),
      ));
    } else if (token.startsWith('*') && token.length > 2) {
      spans.add(TextSpan(
        text: token.substring(1, token.length - 1),
        style: base.copyWith(fontStyle: FontStyle.italic),
      ));
    } else if (token.startsWith('_') && token.length > 2) {
      spans.add(TextSpan(
        text: token.substring(1, token.length - 1),
        style: base.copyWith(fontStyle: FontStyle.italic),
      ));
    } else if (token.startsWith('`') && token.length > 2) {
      spans.add(TextSpan(
        text: token.substring(1, token.length - 1),
        style: base.copyWith(
          fontFamily: 'monospace',
          fontSize: (base.fontSize ?? 14) - 0.5,
        ),
      ));
    } else if (token.startsWith('~~') && token.length > 4) {
      spans.add(TextSpan(
        text: token.substring(2, token.length - 2),
        style: base.copyWith(decoration: TextDecoration.lineThrough),
      ));
    } else if (token.startsWith('[')) {
      // [文本](链接) → 只显示文本
      final label = RegExp(r'^\[([^\]]+)\]').firstMatch(token)?.group(1) ?? token;
      spans.add(TextSpan(text: label, style: base));
    } else {
      spans.add(TextSpan(text: token, style: base));
    }
    cursor = m.end;
  }
  if (cursor < plain.length) {
    spans.add(TextSpan(text: plain.substring(cursor), style: base));
  }
  if (spans.isEmpty) spans.add(TextSpan(text: plain, style: base));
  return spans;
}

// ======================= LaTeX → Unicode =======================

/// 是否含明确 LaTeX 命令（用于识别"裸公式"，避免误伤普通文本）
bool _looksLikeLatex(String s) {
  return RegExp(
    r'\\(frac|dfrac|tfrac|sqrt|times|cdot|div|pm|mp|le|leq|ge|geq|ne|neq|'
    r'approx|equiv|infty|alpha|beta|gamma|delta|theta|lambda|mu|pi|sigma|'
    r'omega|sum|prod|int|lim|log|ln|sin|cos|tan|left|right|angle|triangle|'
    r'because|therefore|in|notin|subset|cup|cap|to|rightarrow|Rightarrow|'
    r'overline|vec|text|mathrm|mathbf)',
  ).hasMatch(s);
}

/// LaTeX 片段 → Unicode 可读文本（公开以便单元测试）。
///
/// 例：`\frac{3}{4}` → `3/4`；`4\sqrt{5}` → `4√(5)`；`x^{2}` → `x²`；
/// `\le` → `≤`；`\times` → `×`。
/// 纯字符串处理，任何异常输入都会原样退化，绝不抛错。
String latexToUnicode(String input) {
  var s = input;

  // 数学定界符（本函数处理的就是公式段，直接去掉 $）
  s = s.replaceAll(r'$', '');

  // 去掉数学定界符/间距命令
  s = s.replaceAll(RegExp(r'\\[()\[\]]'), '');
  s = s.replaceAll(RegExp(r'\\(left|right|big|Big|bigg|Bigg)\b'), '');
  s = s.replaceAll(RegExp(r'\\(quad|qquad|,|;|:|!)'), ' ');
  s = s.replaceAll('\\%', '%');
  s = s.replaceAll(r'\{', '{').replaceAll(r'\}', '}');
  s = s.replaceAll(r'\&', '&');
  s = s.replaceAll(RegExp(r'\\\\'), '\n');
  s = s.replaceAll('&', ' ');

  // 分数（支持嵌套花括号；从内向外多轮替换）
  s = _replaceCommandGroups(s, const ['frac', 'dfrac', 'tfrac'], (args) {
    if (args.length < 2) return null;
    final a = args[0].trim();
    final b = args[1].trim();
    final simpleA = RegExp(r'^[\w\u0370-\u03ff]+$').hasMatch(a);
    final simpleB = RegExp(r'^[\w\u0370-\u03ff]+$').hasMatch(b);
    if (simpleA && simpleB) return '$a/$b';
    // 只给"复杂"的一侧加括号，保持可读性（如 (a+b)/2 而非 (a+b)/(2)）
    if (simpleA && !simpleB) return '$a/($b)';
    if (!simpleA && simpleB) return '($a)/$b';
    return '($a)/($b)';
  });

  // 根号：\sqrt[n]{x} / \sqrt{x}
  s = _replaceSqrt(s);

  // 文本类命令：\text{...} / \mathrm{...} / \mathbf{...} → 内部内容
  s = _replaceCommandGroups(
    s,
    const [
      'text', 'mathrm', 'mathbf', 'mathit', 'textbf', 'operatorname',
      'overline', 'underline', 'vec', 'hat', 'bar', 'widehat', 'widetilde',
    ],
    (args) => args.isEmpty ? null : args.first,
  );

  // 上标 / 下标（逐字符转 Unicode，无法映射的保留 ^ / _ 形式）
  s = s.replaceAllMapped(
    RegExp(r'\^\{([^{}]*)\}|\^(\w)'),
    (m) => _toSuperscript(m.group(1) ?? m.group(2) ?? ''),
  );
  s = s.replaceAllMapped(
    RegExp(r'_\{([^{}]*)\}|_(\w)'),
    (m) => _toSubscript(m.group(1) ?? m.group(2) ?? ''),
  );

  // 常用命令 → 符号
  const symbols = <String, String>{
    'times': '×', 'cdot': '·', 'div': '÷', 'pm': '±', 'mp': '∓',
    'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'ne': '≠', 'neq': '≠',
    'approx': '≈', 'equiv': '≡', 'sim': '∼', 'propto': '∝',
    'infty': '∞', 'angle': '∠', 'triangle': '△', 'degree': '°',
    'circ': '∘', 'perp': '⊥', 'parallel': '∥',
    'sum': '∑', 'prod': '∏', 'int': '∫', 'partial': '∂',
    'in': '∈', 'notin': '∉', 'subset': '⊂', 'subseteq': '⊆',
    'cup': '∪', 'cap': '∩', 'emptyset': '∅', 'varnothing': '∅',
    'to': '→', 'rightarrow': '→', 'Rightarrow': '⇒',
    'leftarrow': '←', 'Leftarrow': '⇐', 'leftrightarrow': '↔',
    'therefore': '∴', 'because': '∵', 'forall': '∀', 'exists': '∃',
    'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε',
    'varepsilon': 'ε', 'zeta': 'ζ', 'eta': 'η', 'theta': 'θ',
    'vartheta': 'ϑ', 'iota': 'ι', 'kappa': 'κ', 'lambda': 'λ', 'mu': 'μ',
    'nu': 'ν', 'xi': 'ξ', 'pi': 'π', 'rho': 'ρ', 'sigma': 'σ',
    'tau': 'τ', 'upsilon': 'υ', 'phi': 'φ', 'varphi': 'φ', 'chi': 'χ',
    'psi': 'ψ', 'omega': 'ω',
    'Alpha': 'Α', 'Beta': 'Β', 'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ',
    'Lambda': 'Λ', 'Pi': 'Π', 'Sigma': 'Σ', 'Phi': 'Φ', 'Psi': 'Ψ',
    'Omega': 'Ω',
    'log': 'log', 'ln': 'ln', 'lg': 'lg', 'sin': 'sin', 'cos': 'cos',
    'tan': 'tan', 'cot': 'cot', 'sec': 'sec', 'csc': 'csc', 'lim': 'lim',
    'max': 'max', 'min': 'min', 'arg': 'arg', 'det': 'det', 'gcd': 'gcd',
    'overline': '', 'vec': '', 'hat': '', 'bar': '',
  };
  s = s.replaceAllMapped(RegExp(r'\\([A-Za-z]+)'), (m) {
    final name = m.group(1)!;
    return symbols[name] ?? name; // 未知命令：去掉反斜杠，保留可读命令名
  });

  // 清理多余空格（保留换行）
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  return s;
}

/// 匹配 `\cmd{...}{...}`（支持嵌套花括号），对参数做转换后交给 [build]
String _replaceCommandGroups(
  String s,
  List<String> names,
  String? Function(List<String> args) build,
) {
  var out = s;
  var guard = 0;
  while (guard++ < 50) {
    var changed = false;
    for (final name in names) {
      final idx = out.indexOf('\\$name{');
      if (idx < 0) continue;
      final braceStart = idx + name.length + 1;
      final args = <String>[];
      var pos = braceStart;
      // 连续读取 {..} 参数
      while (pos < out.length && out[pos] == '{') {
        final end = _matchBrace(out, pos);
        if (end < 0) break;
        args.add(out.substring(pos + 1, end));
        pos = end + 1;
      }
      if (args.isEmpty) continue;
      final replaced = build(args);
      if (replaced == null) continue;
      out = out.substring(0, idx) + replaced + out.substring(pos);
      changed = true;
    }
    if (!changed) break;
  }
  return out;
}

/// `\sqrt[n]{x}` / `\sqrt{x}`
String _replaceSqrt(String s) {
  var out = s;
  var guard = 0;
  while (guard++ < 50) {
    final idx = out.indexOf(r'\sqrt');
    if (idx < 0) break;
    var pos = idx + r'\sqrt'.length;
    var index = '';
    if (pos < out.length && out[pos] == '[') {
      final end = out.indexOf(']', pos);
      if (end > pos) {
        index = out.substring(pos + 1, end).trim();
        pos = end + 1;
      }
    }
    if (pos >= out.length || out[pos] != '{') break;
    final end = _matchBrace(out, pos);
    if (end < 0) break;
    final body = out.substring(pos + 1, end).trim();
    final root = index.isEmpty ? '√' : '${_toSuperscript(index)}√';
    out = out.substring(0, idx) + '$root($body)' + out.substring(end + 1);
  }
  return out;
}

/// 从 `{` 起始找匹配的 `}`（支持嵌套），返回下标；失败返回 -1
int _matchBrace(String s, int openPos) {
  var depth = 0;
  for (var i = openPos; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

const Map<String, String> _supMap = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  'n': 'ⁿ', 'i': 'ⁱ', 'x': 'ˣ', 'y': 'ʸ', 'a': 'ᵃ', 'b': 'ᵇ',
  'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ', 'k': 'ᵏ', 'm': 'ᵐ', 'p': 'ᵖ',
  't': 'ᵗ', 'u': 'ᵘ', 'v': 'ᵛ', 'w': 'ʷ', 'z': 'ᶻ',
};

const Map<String, String> _subMap = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'x': 'ₓ', 'h': 'ₕ', 'k': 'ₖ',
  'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'p': 'ₚ', 's': 'ₛ', 't': 'ₜ',
  'i': 'ᵢ', 'j': 'ⱼ', 'r': 'ᵣ', 'u': 'ᵤ', 'v': 'ᵥ',
};

String _toSuperscript(String s) {
  final t = s.trim();
  if (t.isEmpty) return '';
  final buf = StringBuffer();
  for (final ch in t.split('')) {
    final mapped = _supMap[ch];
    if (mapped == null) return '^($t)'; // 无法全部映射时保留可读形式
    buf.write(mapped);
  }
  return buf.toString();
}

String _toSubscript(String s) {
  final t = s.trim();
  if (t.isEmpty) return '';
  final buf = StringBuffer();
  for (final ch in t.split('')) {
    final mapped = _subMap[ch];
    if (mapped == null) return '_($t)';
    buf.write(mapped);
  }
  return buf.toString();
}