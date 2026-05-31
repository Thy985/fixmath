import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class ListRenderer extends StatelessWidget {
  final String text;
  final bool ordered;
  final int index;
  final bool isDark;

  const ListRenderer({
    super.key,
    required this.text,
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
            width: 24,
            child: Text(
              ordered ? '${index + 1}.' : '•',
              style: TextStyle(
                fontSize: AppSpacing.body,
                height: 1.6,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppSpacing.body,
                height: 1.6,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}