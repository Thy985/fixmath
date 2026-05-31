import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class TableRenderer extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final bool isDark;

  const TableRenderer({
    super.key,
    required this.headers,
    required this.rows,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkTableBorder : AppColors.tableBorder;
    final headerBg = isDark ? AppColors.darkTableHeaderBg : AppColors.tableHeaderBg;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
      ),
      child: Column(
        children: [
          _buildRow(headers, headerBg, isDark, true),
          ...rows.map((row) => _buildRow(row, Colors.transparent, isDark, false)),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> cells, Color bg, bool isDark, bool isHeader) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkTableBorder : AppColors.tableBorder,
          ),
        ),
      ),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            child: Text(
              cell.trim(),
              style: TextStyle(
                fontSize: AppSpacing.body,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}