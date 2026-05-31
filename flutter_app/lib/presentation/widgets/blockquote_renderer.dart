import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class BlockquoteRenderer extends StatelessWidget {
  final String text;
  final bool isDark;

  const BlockquoteRenderer({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: AppColors.blockquoteBorder, width: 4),
        ),
        color: isDark ? AppColors.darkBlockquoteBg : AppColors.blockquoteBg,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppSpacing.body,
          height: 1.6,
          fontStyle: FontStyle.italic,
          color: isDark ? AppColors.darkTextSecondary : Colors.black54,
        ),
      ),
    );
  }
}