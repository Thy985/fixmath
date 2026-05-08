import '../models/document.dart';

class FormulaExtractor {
  static final List<_FormulaDelimiter> _delimiters = [
    _FormulaDelimiter(r'\$\$\s*([\s\S]*?)\s*\$\$', true),
    _FormulaDelimiter(r'\\\[\s*([\s\S]*?)\s*\\\]', true),
    _FormulaDelimiter(r'\\\((.*?)\\\)', false),
    _FormulaDelimiter(r'\$([^\$\n]+?)\$', false),
  ];

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

    final Map<String, String> greekLetters = {
      'Δ': r'\Delta', 'δ': r'\delta', 'π': r'\pi', 'α': r'\alpha',
      'β': r'\beta', 'γ': r'\gamma', 'ε': r'\epsilon', 'ζ': r'\zeta',
      'η': r'\eta', 'θ': r'\theta', 'ι': r'\iota', 'κ': r'\kappa',
      'λ': r'\lambda', 'μ': r'\mu', 'ν': r'\nu', 'ξ': r'\xi',
      'ρ': r'\rho', 'σ': r'\sigma', 'τ': r'\tau', 'υ': r'\upsilon',
      'φ': r'\phi', 'χ': r'\chi', 'ψ': r'\psi', 'ω': r'\omega',
    };

    greekLetters.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    result = result.replaceAllMapped(
      RegExp(r'dy/dx'),
      (m) => r'\frac{dy}{dx}',
    );
    result = result.replaceAllMapped(
      RegExp(r'd(\w+)/d(\w+)'),
      (m) => r'\frac{d${m.group(1)}}{d${m.group(2)}}',
    );

    final Map<String, String> commands = {
      'lim': r'\lim',
      'sin': r'\sin',
      'cos': r'\cos',
      'tan': r'\tan',
      'log': r'\log',
      'ln': r'\ln',
      'exp': r'\exp',
      'frac': r'\frac',
      'sqrt': r'\sqrt',
      'int': r'\int',
      'sum': r'\sum',
      'prod': r'\prod',
    };

    commands.forEach((key, value) {
      result = result.replaceAllMapped(
        RegExp(r'\b$key\b'),
        (m) => value,
      );
    });

    return result;
  }
}

class _FormulaDelimiter {
  final RegExp regex;
  final bool displayMode;

  _FormulaDelimiter(String pattern, this.displayMode)
      : regex = RegExp(pattern);
}
