import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF165DFF);
  static const success = Color(0xFF00B42A);

  static const lightBg = Color(0xFFF2F3F5);
  static const darkBg = Color(0xFF2D2D2D);
  static const darkSurface = Color(0xFF1A1A1A);

  static const lightText = Color(0xFF000000);
  static const darkText = Color(0xFFFFFFFF);
  static const lightTextSecondary = Color(0xff000000de);
  static const darkTextSecondary = Color(0xffffffffb3);

  static const codeBlockBg = Color(0xFFF5F5F5);
  static const darkCodeBlockBg = Color(0xFF2D2D2D);

  static const blockquoteBorder = primary;
  static const blockquoteBg = Color(0xFFF5F5F5);
  static const darkBlockquoteBg = Color(0xFF2D2D2D);

  static const tableBorder = Color(0xFFE5E6EB);
  static const darkTableBorder = Color(0xFF424242);
  static const tableHeaderBg = Color(0xFFF5F5F5);
  static const darkTableHeaderBg = Color(0xFF2D2D2D);

  static const formulaInlineBg = Color(0xFFF5F5F5);
  static const darkFormulaInlineBg = Color(0xFF2D2D2D);

  static const error = Color(0xFFFF3B30);
  static const warning = Color(0xFFFF9500);

  static const wordAccent = Color(0xFF4472C4);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double pageMargin = 16;
  static const double cardPadding = 16;
  static const double cardRadius = 12;
  static const double codeRadius = 8;

  static const double heading1 = 28;
  static const double heading2 = 24;
  static const double heading3 = 20;
  static const double heading4 = 18;
  static const double body = 16;
  static const double code = 14;
  static const double small = 13;
  static const double caption = 11;

  static const double formulaInline = 16;
  static const double formulaDisplay = 20;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> card({bool isDark = false}) => [
    BoxShadow(
      color: (isDark ? Colors.black : Colors.black).withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
}