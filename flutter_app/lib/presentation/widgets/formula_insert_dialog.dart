import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/constants/app_constants.dart';
import '../../core/parser/formula_extractor.dart';

class FormulaInsertDialog extends StatefulWidget {
  final bool displayMode;
  final bool isDark;

  const FormulaInsertDialog({
    super.key,
    required this.displayMode,
    required this.isDark,
  });

  @override
  State<FormulaInsertDialog> createState() => _FormulaInsertDialogState();
}

class _FormulaInsertDialogState extends State<FormulaInsertDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _showPreview = false;

  static const _presets = <String, String>{
    '分数': r'\frac{a}{b}',
    '根号': r'\sqrt{x}',
    '向量': r'\vec{n}',
    '上标': r'x^2 + y^2',
    '下标': r'a_1 + a_2',
    '希腊': r'\alpha + \beta',
    '求和': r'\sum_{i=1}^{n} i',
    '积分': r'\int_0^1 f(x)\,dx',
    '极限': r'\lim_{x \to 0}',
    '矩阵': r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
    '联立': r'\begin{cases} x + y = 1 \\ x - y = 0 \end{cases}',
    'cos': r'\cos\theta',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertPreset(String latex) {
    _controller.text = latex;
    _controller.selection = TextSelection.collapsed(offset: latex.length);
    setState(() {
      _error = null;
      _showPreview = true;
    });
  }

  void _onTextChanged(String _) {
    setState(() {
      _error = null;
      _showPreview = _controller.text.trim().isNotEmpty;
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入公式内容');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppColors.darkText : AppColors.lightText;
    final surface = widget.isDark ? AppColors.darkSurface : Colors.white;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  widget.displayMode ? Icons.straighten : Icons.functions,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.displayMode ? '插入块级公式' : '插入行内公式',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              onChanged: _onTextChanged,
              onSubmitted: (_) => _submit(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: r'输入 LaTeX，如 \frac{a}{b}',
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: widget.isDark
                    ? Colors.white10
                    : Colors.grey.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _buildPreview(textColor),
            const SizedBox(height: AppSpacing.md),
            _buildPresets(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('插入'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(Color textColor) {
    if (!_showPreview || _controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final raw = _controller.text.trim();
    final normalized = FormulaExtractor.normalizeLatex(raw);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.darkFormulaInlineBg
            : AppColors.formulaInlineBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预览',
            style: TextStyle(
              fontSize: 11,
              color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              normalized,
              mathStyle:
                  widget.displayMode ? MathStyle.display : MathStyle.text,
              textStyle: TextStyle(
                fontSize: widget.displayMode
                    ? AppSpacing.formulaDisplay
                    : AppSpacing.formulaInline,
                color: textColor,
              ),
              onErrorFallback: (err) => Text(
                raw,
                style: const TextStyle(
                  color: AppColors.error,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final textColor = widget.isDark ? AppColors.darkText : AppColors.lightText;
    final entries = _presets.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '常用模板',
          style: TextStyle(
            fontSize: 12,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: entries
              .map(
                (e) => InkWell(
                  onTap: () => _insertPreset(e.value),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
