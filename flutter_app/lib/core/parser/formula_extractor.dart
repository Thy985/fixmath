class FormulaMatch {
  final String latex;
  final int start;
  final int end;
  final bool displayMode;

  const FormulaMatch({
    required this.latex,
    required this.start,
    required this.end,
    required this.displayMode,
  });
}

class FormulaExtractor {
  static const Set<String> _latexCommands = {
    'vec', 'hat', 'bar', 'tilde', 'overline', 'underline',
    'dot', 'ddot', 'check', 'breve', 'grave', 'acute',
    'widehat', 'widetilde', 'overset', 'underset',
    'overbrace', 'underbrace', 'overleftarrow', 'overrightarrow',
    'frac', 'dfrac', 'tfrac', 'binom', 'cfrac',
    'sqrt',
    'sin', 'cos', 'tan', 'cot', 'sec', 'csc',
    'arcsin', 'arccos', 'arctan',
    'sinh', 'cosh', 'tanh', 'coth',
    'log', 'ln', 'exp',
    'lim', 'limsup', 'liminf',
    'sum', 'prod', 'int', 'oint', 'iint', 'iiint', 'iiiint',
    'bigcup', 'bigcap', 'bigoplus', 'bigotimes', 'bigvee', 'bigwedge',
    'mathrm', 'mathbf', 'mathit', 'mathsf', 'mathtt',
    'mathcal', 'mathfrak', 'mathbb', 'operatorname', 'text', 'textbf', 'textit',
    'leq', 'le', 'geq', 'ge', 'neq', 'ne',
    'approx', 'sim', 'simeq', 'cong', 'equiv', 'doteq', 'triangleq',
    'propto', 'prec', 'succ', 'preceq', 'succeq', 'll', 'gg',
    'in', 'notin', 'ni', 'owns',
    'subset', 'supset', 'subseteq', 'supseteq', 'nsubseteq', 'nsupseteq',
    'cup', 'cap', 'setminus', 'emptyset', 'varnothing',
    'pm', 'mp', 'times', 'div', 'cdot', 'ast', 'star', 'circ', 'bullet',
    'oplus', 'ominus', 'otimes', 'oslash', 'odot',
    'to', 'mapsto', 'rightarrow', 'leftarrow', 'leftrightarrow',
    'Rightarrow', 'Leftarrow', 'Leftrightarrow',
    'uparrow', 'downarrow', 'updownarrow', 'Uparrow', 'Downarrow',
    'infty', 'partial', 'nabla', 'forall', 'exists', 'nexists',
    'therefore', 'because', 'square',
    'langle', 'rangle', 'lfloor', 'rfloor', 'lceil', 'rceil',
    'ldots', 'cdots', 'vdots', 'ddots',
    'color', 'textcolor', 'colorbox', 'boxed', 'fbox',
    'cancel', 'bcancel', 'xcancel',
    'quad', 'qquad',
    'stackrel',
    'arg', 'argmin', 'argmax',
    'min', 'max', 'sup', 'inf', 'det', 'dim', 'ker', 'deg', 'hom', 'gcd',
    'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'varepsilon',
    'zeta', 'eta', 'theta', 'vartheta', 'iota', 'kappa',
    'lambda', 'mu', 'nu', 'xi', 'omicron', 'pi', 'varpi',
    'rho', 'varrho', 'sigma', 'varsigma', 'tau', 'upsilon',
    'phi', 'varphi', 'chi', 'psi', 'omega',
    'Gamma', 'Delta', 'Theta', 'Lambda', 'Xi', 'Pi',
    'Sigma', 'Upsilon', 'Phi', 'Psi', 'Omega',
  };

  static List<FormulaMatch> extractFormulas(String text) {
    final results = <FormulaMatch>[];

    _extractExplicitFormulas(text, results);
    _extractImplicitFormulas(text, results);

    results.sort((a, b) {
      final c = a.start.compareTo(b.start);
      if (c != 0) return c;
      return (b.end - b.start).compareTo(a.end - a.start);
    });

    final filtered = <FormulaMatch>[];
    int lastEnd = -1;
    for (final m in results) {
      if (m.start >= lastEnd) {
        filtered.add(m);
        lastEnd = m.end;
      }
    }

    return filtered;
  }

  static void _extractExplicitFormulas(String text, List<FormulaMatch> results) {
    int i = 0;
    while (i < text.length) {
      if (i < text.length - 1 && text[i] == '\\' &&
          (text[i + 1] == r'$' || text[i + 1] == '\\')) {
        i += 2;
        continue;
      }

      if (i < text.length - 1 && text[i] == r'$' && text[i + 1] == r'$') {
        final end = _findMatchingDelimiter(text, i + 2);
        if (end != -1) {
          results.add(FormulaMatch(
            latex: text.substring(i + 2, end),
            start: i,
            end: end + 2,
            displayMode: true,
          ));
          i = end + 2;
          continue;
        }
      }

      if (text[i] == r'$' && !_isEscaped(text, i)) {
        final end = _findInlineFormulaEnd(text, i + 1);
        if (end != -1) {
          results.add(FormulaMatch(
            latex: text.substring(i + 1, end),
            start: i,
            end: end + 1,
            displayMode: false,
          ));
          i = end + 1;
          continue;
        }
      }

      i++;
    }
  }

  static void _extractImplicitFormulas(String text, List<FormulaMatch> results) {
    final commands = _latexCommands.join('|');
    final regex = RegExp(
      '(?<![A-Za-z0-9\\\\])($commands)(?:\\{(?:[^{}]+|\\{[^{}]*\\})*\\}|\\([^)]*\\))',
    );

    for (final match in regex.allMatches(text)) {
      final matchedText = match.group(0)!;
      final hasBackslash = match.start > 0 && text[match.start - 1] == r'\';

      String latex;
      if (hasBackslash) {
        latex = matchedText;
      } else {
        latex = '\\$matchedText';
        latex = _ensureBackslashForCommands(latex);
      }

      results.add(FormulaMatch(
        latex: latex,
        start: match.start,
        end: match.end,
        displayMode: false,
      ));
    }
  }

  static String _ensureBackslashForCommands(String input) {
    if (!input.contains('{') && !input.contains('(')) return input;
    final commands = _latexCommands.join('|');
    final regex = RegExp('(?<!\\\\)\\b($commands)\\b');
    return input.replaceAllMapped(
      regex,
      (m) => '\\${m.group(1)!}',
    );
  }

  static int _findMatchingDelimiter(String text, int start) {
    int i = start;
    while (i < text.length) {
      if (i < text.length - 1 && text[i] == '\\' &&
          (text[i + 1] == r'$' || text[i + 1] == '\\')) {
        i += 2;
        continue;
      }

      if (i < text.length - 1 && text[i] == r'$' && text[i + 1] == r'$') {
        return i;
      }
      i++;
    }
    return -1;
  }

  static int _findInlineFormulaEnd(String text, int start) {
    int i = start;
    while (i < text.length) {
      if (text[i] == '\\') {
        i += 2;
        continue;
      }

      if (text[i] == r'$') {
        return i;
      }

      if (text[i] == '\n') {
        return -1;
      }
      i++;
    }
    return -1;
  }

  static bool _isEscaped(String text, int index) {
    if (index == 0) return false;
    int backslashCount = 0;
    for (int i = index - 1; i >= 0 && text[i] == '\\'; i--) {
      backslashCount++;
    }
    return backslashCount % 2 == 1;
  }

  static String normalizeLatex(String input) {
    String result = input;

    result = result.replaceAll('→', r'\to');
    result = result.replaceAll('←', r'\gets');
    result = result.replaceAll('↔', r'\leftrightarrow');
    result = result.replaceAll('⇒', r'\Rightarrow');
    result = result.replaceAll('⇔', r'\Leftrightarrow');
    result = result.replaceAll('↦', r'\mapsto');
    result = result.replaceAll('∂', r'\partial');
    result = result.replaceAll('∇', r'\nabla');
    result = result.replaceAll('∞', r'\infty');
    result = result.replaceAll('∫', r'\int');
    result = result.replaceAll('∑', r'\sum');
    result = result.replaceAll('∏', r'\prod');
    result = result.replaceAll('√', r'\sqrt');
    result = result.replaceAll('±', r'\pm');
    result = result.replaceAll('∓', r'\mp');
    result = result.replaceAll('×', r'\times');
    result = result.replaceAll('÷', r'\div');
    result = result.replaceAll('·', r'\cdot');
    result = result.replaceAll('≤', r'\leq');
    result = result.replaceAll('≥', r'\geq');
    result = result.replaceAll('≠', r'\neq');
    result = result.replaceAll('≈', r'\approx');
    result = result.replaceAll('≡', r'\equiv');
    result = result.replaceAll('∝', r'\propto');
    result = result.replaceAll('∈', r'\in');
    result = result.replaceAll('∉', r'\notin');
    result = result.replaceAll('⊂', r'\subset');
    result = result.replaceAll('⊃', r'\supset');
    result = result.replaceAll('⊆', r'\subseteq');
    result = result.replaceAll('⊇', r'\supseteq');
    result = result.replaceAll('∪', r'\cup');
    result = result.replaceAll('∩', r'\cap');
    result = result.replaceAll('∅', r'\emptyset');

    final greekLetters = {
      'Δ': r'\Delta', 'δ': r'\delta', 'π': r'\pi', 'α': r'\alpha',
      'β': r'\beta', 'γ': r'\gamma', 'ε': r'\epsilon', 'ζ': r'\zeta',
      'η': r'\eta', 'θ': r'\theta', 'ι': r'\iota', 'κ': r'\kappa',
      'λ': r'\lambda', 'μ': r'\mu', 'ν': r'\nu', 'ξ': r'\xi',
      'ρ': r'\rho', 'σ': r'\sigma', 'τ': r'\tau', 'υ': r'\upsilon',
      'φ': r'\phi', 'χ': r'\chi', 'ψ': r'\psi', 'ω': r'\omega',
      'Γ': r'\Gamma', 'Θ': r'\Theta', 'Λ': r'\Lambda', 'Ξ': r'\Xi',
      'Π': r'\Pi', 'Σ': r'\Sigma', 'Φ': r'\Phi', 'Ψ': r'\Psi', 'Ω': r'\Omega',
    };

    greekLetters.forEach((unicode, latex) {
      result = result.replaceAll(unicode, latex);
    });

    result = result.replaceAllMapped(
      RegExp(r'dy/dx'),
      (_) => r'\frac{dy}{dx}',
    );
    result = result.replaceAllMapped(
      RegExp(r'd\^2y/dx\^2'),
      (_) => r'\frac{d^2y}{dx^2}',
    );
    result = result.replaceAllMapped(
      RegExp(r'd(\w+)/d(\w+)'),
      (m) => '\\frac{d${m.group(1)}}{d${m.group(2)}}',
    );

    return result;
  }
}
