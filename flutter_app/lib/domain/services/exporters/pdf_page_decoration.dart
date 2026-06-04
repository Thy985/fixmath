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
pw.Widget buildPdfHeader(String title, pw.Context ctx) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'FormulaFix',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey500,
          ),
        ),
      ],
    ),
  );
}

/// 每页页脚：左侧生成日期，右侧"第 N 页 / 共 M 页" + 上边线。
pw.Widget buildPdfFooter(pw.Context ctx) {
  final now = DateTime.now();
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '生成于 ${now.year}-$mm-$dd',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          '第 ${ctx.pageNumber} 页 / 共 ${ctx.pagesCount} 页',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    ),
  );
}
