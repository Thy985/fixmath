import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/constants/app_constants.dart';
import '../../core/parser/formula_extractor.dart';
import '../../data/models/document.dart';

class ParagraphRenderer extends StatelessWidget {
  final List<InlineElement> children;
  final bool isDark;

  const ParagraphRenderer({
    super.key,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children.map((child) => _renderInline(child)).toList(),
      ),
    );
  }

  Widget _renderInline(InlineElement child) {
    if (child is TextElement) {
      return Text(
        child.text,
        style: TextStyle(
          fontSize: AppSpacing.body,
          height: 1.6,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      );
    } else if (child is FormulaElement) {
      return _buildFormula(child.latex, child.displayMode);
    }
    return const SizedBox.shrink();
  }

  Widget _buildFormula(String latex, bool displayMode) {
    final normalized = FormulaExtractor.normalizeLatex(latex);

    if (displayMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Math.tex(
            normalized,
            textStyle: const TextStyle(fontSize: AppSpacing.formulaDisplay),
            onErrorFallback: _fallback(latex),
          ),
        ),
      );
    }

    return Math.tex(
      normalized,
      textStyle: TextStyle(
        fontSize: AppSpacing.formulaInline,
        backgroundColor: isDark ? AppColors.darkFormulaInlineBg : AppColors.formulaInlineBg,
      ),
      onErrorFallback: _fallback(latex),
    );
  }

  Widget Function(FlutterMathException) _fallback(String latex) {
    return (_) => Text(
      latex,
      style: const TextStyle(
        color: AppColors.error,
        fontFamily: 'monospace',
      ),
    );
  }
}
