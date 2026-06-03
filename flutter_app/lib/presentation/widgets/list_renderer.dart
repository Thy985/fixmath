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
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final spans = <InlineSpan>[];

    for (final child in children) {
      if (child is TextElement) {
        spans.add(TextSpan(
          text: child.text,
          style: TextStyle(
            fontSize: AppSpacing.body,
            height: 1.6,
            color: textColor,
          ),
        ));
      } else if (child is FormulaElement) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildFormula(child.latex, child.displayMode),
        ));
      } else if (child is BoldElement) {
        spans.add(TextSpan(
          children: child.children.map((c) {
            if (c is TextElement) {
              return TextSpan(
                text: c.text,
                style: TextStyle(
                  fontSize: AppSpacing.body,
                  height: 1.6,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
            return const TextSpan(text: '');
          }).toList(),
        ));
      }
    }

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
                  color: textColor,
                  fontWeight: ordered ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: spans),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormula(String latex, bool displayMode) {
    final normalized = FormulaExtractor.normalizeLatex(latex);

    if (displayMode) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Math.tex(
          normalized,
          mathStyle: MathStyle.display,
          textStyle: const TextStyle(fontSize: AppSpacing.formulaDisplay),
          onErrorFallback: _fallback(latex),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkFormulaInlineBg : AppColors.formulaInlineBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Math.tex(
        normalized,
        mathStyle: MathStyle.text,
        textStyle: const TextStyle(fontSize: AppSpacing.formulaInline),
        onErrorFallback: _fallback(latex),
      ),
    );
  }

  Widget Function(FlutterMathException) _fallback(String latex) {
    return (_) => Text(
      '\$$latex\$',
      style: const TextStyle(
        color: AppColors.error,
        fontFamily: 'monospace',
        fontSize: 12,
      ),
    );
  }
}
