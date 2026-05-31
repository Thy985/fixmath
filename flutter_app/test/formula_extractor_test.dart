import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/formula_extractor.dart';
import 'package:formula_fix/data/models/document.dart';

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

      test('提取 \\[...\\] 块级公式', () {
        final formulas = FormulaExtractor.extractFormulas(r'\[\frac{a}{b}\]');
        expect(formulas.length, 1);
        expect(formulas[0].latex, r'\frac{a}{b}');
        expect(formulas[0].displayMode, true);
      });

      test('提取 \\(...\\) 行内公式', () {
        final formulas = FormulaExtractor.extractFormulas(r'\(\alpha + \beta\)');
        expect(formulas.length, 1);
        expect(formulas[0].latex, r'\alpha + \beta');
        expect(formulas[0].displayMode, false);
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
    });

    group('normalizeLatex', () {
      test('希腊字母转换', () {
        final result = FormulaExtractor.normalizeLatex('α + β = γ');
        expect(result, contains(r'\alpha'));
        expect(result, contains(r'\beta'));
        expect(result, contains(r'\gamma'));
      });

      test('导数符号转换', () {
        final result = FormulaExtractor.normalizeLatex('dy/dx');
        expect(result, contains(r'\frac{dy}{dx}'));
      });

      test('常见命令补全', () {
        final result = FormulaExtractor.normalizeLatex('lim sin cos tan');
        expect(result, contains(r'\lim'));
        expect(result, contains(r'\sin'));
        expect(result, contains(r'\cos'));
        expect(result, contains(r'\tan'));
      });

      test('不修改已有正确格式', () {
        final input = r'\frac{a}{b}';
        final result = FormulaExtractor.normalizeLatex(input);
        expect(result, contains(r'\frac{a}{b}'));
      });
    });
  });
}