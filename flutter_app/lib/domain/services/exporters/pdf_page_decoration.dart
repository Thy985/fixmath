/// PDF 页面装饰：每页 header / footer 渲染。
///
/// 提取自 [PdfExporter] 以减小其体积；纯静态函数，被 PdfExporter.export
/// 闭包引用。
///
/// 文件级 internal 类型：仅在 exporters/ 目录内可见。
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 每页页眉：左侧文档标题，右侧应用名 + 下边线。
pw.Widget buildPdfHeader(String title, pw.Context ctx, {bool isDark = false}) {
  final textColor = isDark ? PdfColors.grey400 : PdfColors.grey600;
  final borderColor = isDark ? PdfColors.grey700 : PdfColors.grey300;
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: borderColor, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            color: textColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'FormulaFix',
          style: pw.TextStyle(
            fontSize: 9,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

/// 每页页脚：左侧生成日期，右侧"第 N 页 / 共 M 页" + 上边线。
pw.Widget buildPdfFooter(pw.Context ctx, {bool isDark = false}) {
  final now = DateTime.now();
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  final textColor = isDark ? PdfColors.grey400 : PdfColors.grey500;
  final borderColor = isDark ? PdfColors.grey700 : PdfColors.grey300;
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: borderColor, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '生成于 ${now.year}-$mm-$dd',
          style: pw.TextStyle(fontSize: 8, color: textColor),
        ),
        pw.Text(
          '第 ${ctx.pageNumber} 页 / 共 ${ctx.pagesCount} 页',
          style: pw.TextStyle(fontSize: 8, color: textColor),
        ),
      ],
    ),
  );
}
