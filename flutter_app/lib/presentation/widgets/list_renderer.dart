import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/constants/app_constants.dart';
import '../../core/parser/formula_extractor.dart';
import '../../data/models/document.dart';

class ListRenderer extends StatelessWidget {
  final List<InlineElement> children;
  final bool ordered;
  final int index;
  final bool isDark;

  const ListRenderer({
    super.key,
    required this.children,
    this.ordered = false,
    this.index = 0,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                ordered ? '${index + 1}.' : '•',
                style: TextStyle(
                  fontSize: AppSpacing.body,
                  height: 1.6,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: ordered ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children
                  .map((child) => _renderInline(child))
                  .toList(),
            ),
          ),
        ],
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Math.tex(
          normalized,
          textStyle: const TextStyle(fontSize: AppSpacing.formulaDisplay),
          onErrorFallback: (err) => Text(
            latex,
            style: const TextStyle(
              color: AppColors.error,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Math.tex(
        normalized,
        textStyle: TextStyle(
          fontSize: AppSpacing.formulaInline,
          backgroundColor:
              isDark ? AppColors.darkFormulaInlineBg : AppColors.formulaInlineBg,
        ),
        onErrorFallback: (err) => Text(
          latex,
          style: const TextStyle(
            color: AppColors.error,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
