import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/formula_extractor.dart';

void main() {
  group('FormulaExtractor', () {
    group('extractFormulas', () {
      test('提取行内公式 \$...\$', () {
        final formulas = FormulaExtractor.extractFormulas(r'$E=mc^2$');
        expect(formulas.length, 1);
        expect(formulas[0].latex, 'E=mc^2');
        expect(formulas[0].displayMode, false);
      });

      test('提取块级公式 \$\$...\$\$', () {
        final formulas = FormulaExtractor.extractFormulas(r'$$\int_0^1 x^2 dx$$');
        expect(formulas.length, 1);
        expect(formulas[0].latex, r'\int_0^1 x^2 dx');
        expect(formulas[0].displayMode, true);
      });

      test('混合提取多种公式', () {
        final formulas = FormulaExtractor.extractFormulas(
          r'$E=mc^2$ and $$\int_0^1 x^2 dx$$',
        );
        expect(formulas.length, 2);
      });

      test('无公式文本返回空列表', () {
        final formulas = FormulaExtractor.extractFormulas('这是普通文本，没有公式');
        expect(formulas, isEmpty);
      });

      test('去重叠公式：后面的优先', () {
        final text = r'$a$ $b$';
        final formulas = FormulaExtractor.extractFormulas(text);
        expect(formulas.length, 2);
        expect(formulas[0].latex, 'a');
        expect(formulas[1].latex, 'b');
      });

      group('转义字符处理', () {
        test('转义的美元符号不触发公式', () {
          final formulas = FormulaExtractor.extractFormulas(r'价格是 \$100');
          expect(formulas, isEmpty);
        });

        test('双反斜杠转义的美元符号', () {
          final formulas = FormulaExtractor.extractFormulas(r'\\$E=mc^2$');
          expect(formulas.length, 1);
        });

        test('公式中的转义字符', () {
          final formulas = FormulaExtractor.extractFormulas(r'$\alpha \$ \beta$');
          expect(formulas.length, 1);
          expect(formulas[0].latex, contains(r'\$'));
        });
      });

      group('复杂公式', () {
        test('矩阵公式', () {
          final formulas = FormulaExtractor.extractFormulas(
            r'$$\begin{matrix} a & b \\ c & d \end{matrix}$$',
          );
          expect(formulas.length, 1);
          expect(formulas[0].displayMode, true);
        });

        test('极限公式', () {
          final formulas = FormulaExtractor.extractFormulas(r'$\lim_{x \to \infty} f(x)$');
          expect(formulas.length, 1);
          expect(formulas[0].latex, contains(r'\lim'));
        });

        test('求和公式', () {
          final formulas = FormulaExtractor.extractFormulas(r'$\sum_{i=1}^{n} i$');
          expect(formulas.length, 1);
          expect(formulas[0].latex, contains(r'\sum'));
        });

        test('积分公式', () {
          final formulas = FormulaExtractor.extractFormulas(r'$\int_a^b f(x)dx$');
          expect(formulas.length, 1);
          expect(formulas[0].latex, contains(r'\int'));
        });

        test('分数公式', () {
          final formulas = FormulaExtractor.extractFormulas(r'$\frac{dy}{dx}$');
          expect(formulas.length, 1);
          expect(formulas[0].latex, contains(r'\frac'));
        });
      });

      group('公式位置', () {
        test('公式位置正确', () {
          final formulas = FormulaExtractor.extractFormulas(r'文本$E=mc^2$文本');
          expect(formulas.length, 1);
          expect(formulas[0].start, greaterThan(0));
          expect(formulas[0].end, lessThan(20));
        });

        test('多个公式不重叠', () {
          final formulas = FormulaExtractor.extractFormulas(r'$a$ + $b$ = $c$');
          expect(formulas.length, 3);
          expect(formulas[0].end, lessThan(formulas[1].start));
          expect(formulas[1].end, lessThan(formulas[2].start));
        });
      });
    });

    group('normalizeLatex', () {
      test('希腊字母转换', () {
        final result = FormulaExtractor.normalizeLatex('α + β = γ');
        expect(result, contains(r'\alpha'));
        expect(result, contains(r'\beta'));
        expect(result, contains(r'\gamma'));
      });

      test('大写希腊字母转换', () {
        final result = FormulaExtractor.normalizeLatex('Δ + Π = Σ');
        expect(result, contains(r'\Delta'));
        expect(result, contains(r'\Pi'));
        expect(result, contains(r'\Sigma'));
      });

      test('导数符号转换', () {
        final result = FormulaExtractor.normalizeLatex('dy/dx');
        expect(result, contains(r'\frac{dy}{dx}'));
      });

      test('二阶导数符号转换', () {
        final result = FormulaExtractor.normalizeLatex('d^2y/dx^2');
        expect(result, contains(r'\frac{d^2y}{dx^2}'));
      });

      test('偏导数符号转换', () {
        final result = FormulaExtractor.normalizeLatex('df/dx');
        expect(result, contains(r'\frac{df}{dx}'));
      });

      test('Unicode箭头转换', () {
        expect(FormulaExtractor.normalizeLatex('→'), contains(r'\to'));
        expect(FormulaExtractor.normalizeLatex('⇒'), contains(r'\Rightarrow'));
        expect(FormulaExtractor.normalizeLatex('⇔'), contains(r'\Leftrightarrow'));
      });

      test('不修改已有正确格式', () {
        final input = r'\frac{a}{b}';
        final result = FormulaExtractor.normalizeLatex(input);
        expect(result, contains(r'\frac{a}{b}'));
      });
    });
  });
}
