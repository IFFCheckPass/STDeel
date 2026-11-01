/// LaTeX 命令清单与 JSON 反斜杠修复 - 思谛 STDeel
///
/// 背景：部分模型返回 JSON 时把 LaTeX 直接写进字符串（只写一个反斜杠），
/// 例如 `{"answer": "\frac{3}{4}"}`：
///   - `\f` / `\b` / `\t` / `\n` / `\r` 会被 JSON 当成控制字符（**静默损坏**，
///     表现为公式里出现换页符/退格符，渲染后是方框或空白）；
///   - `\sqrt` / `\le` 等是非法转义，`jsonDecode` 直接失败 → 整题解析为空。
///
/// 本文件提供 [repairLatexEscapesInJson]，在 `jsonDecode` 前把"LaTeX 反斜杠"
/// 补成合法的 `\\`，从而保留公式原文，交给 [MarkdownLatex] 渲染。
library;

/// 常用 LaTeX 命令名（覆盖渲染器支持的全部结构/符号/字体命令）。
const Set<String> kLatexCommandNames = {
  // 结构与字体
  'frac', 'dfrac', 'tfrac', 'cfrac', 'sqrt', 'root', 'text', 'textrm',
  'textnormal', 'textsf', 'texttt', 'textbf', 'textit', 'mbox', 'mathrm',
  'mathbf', 'mathit', 'mathsf', 'mathtt', 'boldsymbol', 'bm', 'pmb',
  'mathfrak', 'operatorname', 'boxed', 'substack', 'overset', 'underset',
  'stackrel', 'mathbb', 'mathcal', 'mathscr', 'overline', 'underline',
  'vec', 'hat', 'widehat', 'bar', 'tilde', 'widetilde', 'dot', 'ddot',
  'check', 'breve', 'acute', 'grave', 'mathring', 'overrightarrow',
  'overleftarrow', 'overleftrightarrow', 'left', 'right', 'middle', 'big',
  'Big', 'bigg', 'Bigg', 'begin', 'end', 'hline', 'cline', 'toprule',
  'midrule', 'bottomrule', 'label', 'tag', 'hspace', 'vspace', 'phantom',
  'hphantom', 'vphantom', 'rule', 'color', 'textcolor', 'definecolor',
  'displaystyle', 'textstyle', 'scriptstyle', 'scriptscriptstyle', 'limits',
  'nolimits', 'nonumber', 'notag', 'quad', 'qquad',

  // 关系 / 逻辑 / 箭头
  'times', 'cdot', 'div', 'pm', 'mp', 'le', 'leq', 'ge', 'geq', 'ne',
  'neq', 'lt', 'gt', 'approx', 'equiv', 'sim', 'propto', 'infty', 'angle',
  'triangle', 'degree', 'circ', 'perp', 'parallel', 'mid', 'nmid', 'bullet',
  'star', 'odot', 'sum', 'prod', 'int', 'partial', 'nabla', 'in', 'notin',
  'ni', 'subset', 'subseteq', 'supset', 'supseteq', 'cup', 'cap', 'emptyset',
  'varnothing', 'to', 'rightarrow', 'Rightarrow', 'implies', 'leftarrow',
  'Leftarrow', 'leftrightarrow', 'Leftrightarrow', 'iff', 'mapsto',
  'therefore', 'because', 'forall', 'exists', 'neg', 'lnot', 'land', 'wedge',
  'lor', 'vee', 'oplus', 'otimes', 'ldots', 'cdots', 'dots', 'vdots', 'ddots',
  'aleph', 'hbar', 'ell', 'prime', 'not',

  // 希腊字母
  'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'varepsilon', 'zeta', 'eta',
  'theta', 'vartheta', 'iota', 'kappa', 'lambda', 'mu', 'nu', 'xi', 'pi',
  'rho', 'sigma', 'tau', 'upsilon', 'phi', 'varphi', 'chi', 'psi', 'omega',
  'Alpha', 'Beta', 'Gamma', 'Delta', 'Theta', 'Lambda', 'Pi', 'Sigma', 'Phi',
  'Psi', 'Omega',

  // 函数名
  'log', 'ln', 'lg', 'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'lim', 'max',
  'min', 'arg', 'det', 'gcd',
};

/// 修复 JSON 文本中"未转义"的 LaTeX 反斜杠。
///
/// 规则（只处理 `\` + 字母串）：
///   - 已是合法 JSON 转义（`\n`、`\t`、`\uXXXX` 等单字母）→ 保持原样；
///   - 字母串是 LaTeX 命令（如 `\frac`、`\beta`、`\times`）→ 补成 `\\`；
///   - 其他多字母串（未知命令）→ 同样补成 `\\`，避免 `\f`/`\b` 静默损坏；
///   - 连续多个反斜杠（已正确转义，如 `\\frac`）→ 原样保留。
String repairLatexEscapesInJson(String raw) {
  final out = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    if (raw[i] != r'\') {
      out.write(raw[i]);
      i++;
      continue;
    }
    // 连续反斜杠：成对出现即为已转义，原样保留
    var j = i;
    while (j < raw.length && raw[j] == r'\') {
      j++;
    }
    if (j - i >= 2) {
      out.write(raw.substring(i, j));
      i = j;
      continue;
    }
    // 单个反斜杠：读取后面的字母串
    var k = j;
    while (k < raw.length && _isLetter(raw[k])) {
      k++;
    }
    final name = raw.substring(j, k);
    if (name.isEmpty) {
      out.write(raw[i]);
      i++;
      continue;
    }
    // 已是 LaTeX 命令（含未知多字母命令）：补成合法的 \\，jsonDecode 后仍是 \
    if (kLatexCommandNames.contains(name)) {
      out.write(r'\\');
      out.write(name);
      i = k;
      continue;
    }
    // 合法 JSON 转义：\n / \t 等单字母转义，或 \uXXXX。
    // 注意 `\n` 后面直接跟字母（如 "a\nbc"）时，字母串整体不是命令，
    // 此时只消费反斜杠，其余字母按普通文本原样输出。
    final first = name[0];
    if ('bfnrt'.contains(first)) {
      out.write(raw[i]);
      i = j;
      continue;
    }
    if (name == 'u' &&
        k + 4 <= raw.length &&
        RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(raw.substring(k, k + 4))) {
      out.write(raw[i]);
      i = j;
      continue;
    }
    // 非法转义（如 \sqrt 的 \s）：补成 \\，保证 JSON 合法并保留字面反斜杠
    out.write(r'\\');
    out.write(name);
    i = k;
  }
  return out.toString();
}

bool _isLetter(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
}
