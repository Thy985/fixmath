import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CodeRenderer extends StatelessWidget {
  final String code;
  final bool isDark;

  const CodeRenderer({
    super.key,
    required this.code,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCodeBlockBg : AppColors.codeBlockBg,
        borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: AppSpacing.code,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }
}