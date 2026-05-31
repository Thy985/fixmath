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
  static final List<_FormulaDelimiter> _delimiters = [
    _FormulaDelimiter(r'\$\$\s*([\s\S]*?)\s*\$\$', true),
    _FormulaDelimiter(r'\\\[\s*([\s\S]*?)\s*\\\]', true),
    _FormulaDelimiter(r'\\\((.*?)\\\)', false),
    _FormulaDelimiter(r'\$([^\$\n]+?)\$', false),
  ];

  static final List<String> _commonCommands = [
    'lim', 'frac', 'sqrt', 'int', 'sum', 'prod', 'liminf', 'limsup', 'max', 'min',
    'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'arcsin', 'arccos', 'arctan',
    'sinh', 'cosh', 'tanh', 'log', 'ln', 'exp', 'det', 'rank', 'ker',
    'gcd', 'lcm', 'mod', 'equiv', 'approx', 'sim', 'cong', 'perp', 'parallel',
    'leq', 'geq', 'll', 'gg', 'subset', 'supset', 'subseteq', 'supseteq',
    'in', 'notin', 'ni', 'cup', 'cap', 'setminus', 'times', 'div', 'pm', 'mp',
    'infty', 'aleph', 'nabla', 'partial', 'forall', 'exists', 'neg', 'land', 'lor',
    'implies', 'iff', 'because', 'therefore', 'dots', 'cdots', 'vdots', 'ddots',
    'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'eta', 'theta', 'iota',
    'kappa', 'lambda', 'mu', 'nu', 'xi', 'omicron', 'pi', 'rho', 'sigma', 'tau',
    'upsilon', 'phi', 'chi', 'psi', 'omega',
  ];

  static final Map<String, String> _greekLetters = {
    'Δ': r'\Delta', 'δ': r'\delta', 'π': r'\pi', 'α': r'\alpha',
    'β': r'\beta', 'γ': r'\gamma', 'ε': r'\epsilon', 'ζ': r'\zeta',
    'η': r'\eta', 'θ': r'\theta', 'ι': r'\iota', 'κ': r'\kappa',
    'λ': r'\lambda', 'μ': r'\mu', 'ν': r'\nu', 'ξ': r'\xi',
    'ρ': r'\rho', 'σ': r'\sigma', 'τ': r'\tau', 'υ': r'\upsilon',
    'φ': r'\phi', 'χ': r'\chi', 'ψ': r'\psi', 'ω': r'\omega',
  };

  static List<FormulaMatch> extractFormulas(String text) {
    final List<FormulaMatch> results = [];

    for (final delimiter in _delimiters) {
      final matches = delimiter.regex.allMatches(text);
      for (final match in matches) {
        results.add(FormulaMatch(
          latex: match.group(1) ?? '',
          start: match.start,
          end: match.end,
          displayMode: delimiter.displayMode,
        ));
      }
    }

    results.sort((a, b) => a.start.compareTo(b.start));

    final List<FormulaMatch> filtered = [];
    int lastEnd = 0;
    for (final match in results) {
      if (match.start >= lastEnd) {
        filtered.add(match);
        lastEnd = match.end;
      }
    }

    return filtered;
  }

  static String normalizeLatex(String input) {
    String result = input;

    _greekLetters.forEach((unicode, latex) {
      result = result.replaceAll(unicode, latex);
    });

    result = result.replaceAllMapped(
      RegExp(r'dy/dx'),
      (_) => r'\frac{dy}{dx}',
    );
    result = result.replaceAllMapped(
      RegExp(r'd^2y/dx^2'),
      (_) => r'\frac{d^2y}{dx^2}',
    );
    result = result.replaceAllMapped(
      RegExp(r'd(\w+)/d(\w+)'),
      (m) => '\\frac{d${m.group(1)}}{d${m.group(2)}}',
    );

    for (final cmd in _commonCommands) {
      result = result.replaceAllMapped(
        RegExp('(\\s|^)$cmd(\\s|\$)'),
        (m) => '${m.group(1)}\\$cmd${m.group(2)}',
      );
      result = result.replaceAllMapped(
        RegExp('(\\s|^)$cmd\\{'),
        (m) => '${m.group(1)}\\$cmd{',
      );
    }

    result = result.replaceAll('→', r'\to');

    result = result.replaceAllMapped(
      RegExp(r'([^\\])_([a-zA-Z0-9])'),
      (m) => '${m.group(1)}_{${m.group(2)}}',
    );
    result = result.replaceAllMapped(
      RegExp(r'([^\\])\^([a-zA-Z0-9])'),
      (m) => '${m.group(1)}^{${m.group(2)}}',
    );

    for (final cmd in ['lim', 'frac', 'sqrt', 'int', 'sum', 'prod', 'sin', 'cos', 'tan', 'log', 'ln']) {
      result = result.replaceAllMapped(
        RegExp('\\b$cmd\\b'),
        (m) => '\\$cmd',
      );
    }

    result = result.replaceAllMapped(
      RegExp(r'\b(lim|frac|sqrt|int|sum|prod|sin|cos|tan|log|ln)_(\w+)'),
      (m) => '${m.group(1)}_{${m.group(2)}}',
    );

    return result;
  }
}

class _FormulaDelimiter {
  final RegExp regex;
  final bool displayMode;

  _FormulaDelimiter(String pattern, this.displayMode)
      : regex = RegExp(pattern);
}