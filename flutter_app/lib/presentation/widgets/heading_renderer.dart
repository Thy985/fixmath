import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class HeadingRenderer extends StatelessWidget {
  final int level;
  final String text;
  final bool isDark;

  const HeadingRenderer({
    super.key,
    required this.level,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        text,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  double get _fontSize {
    return switch (level) {
      1 => AppSpacing.heading1,
      2 => AppSpacing.heading2,
      3 => AppSpacing.heading3,
      _ => AppSpacing.heading4,
    };
  }
}