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
  static List<FormulaMatch> extractFormulas(String text) {
    final List<FormulaMatch> results = [];
    
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

    return results;
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
