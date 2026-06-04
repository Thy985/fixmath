/// PDF 导出的 Mermaid 渲染辅助。
///
/// 把 Markdown 中的 Mermaid 代码块渲染为 PDF widget：优先尝试 SVG 矢量嵌入，
/// 失败则降级到代码块回退显示。
///
/// 文件级 internal 类型：仅在 exporters/ 目录内可见；不参与公开 API。
library;

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/services/mermaid_service.dart';

/// 构造 PDF 中的 Mermaid widget：SVG 矢量优先，失败回退代码块展示。
Future<pw.Widget> buildMermaidPdfWidget(String code) async {
  String? svg;
  try {
    svg = await MermaidService.renderToSvg(code);
  } catch (e) {
    debugPrint('Mermaid render failed: $e');
    svg = null;
  }

  if (svg != null && svg.isNotEmpty) {
    try {
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 10),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green700,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'Mermaid 图表 (矢量)',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            _buildSvgInPdf(svg),
          ],
        ),
      );
    } catch (e) {
      debugPrint('SVG to PDF conversion failed: $e');
    }
  }

  return _buildMermaidFallback(code);
}

pw.Widget _buildSvgInPdf(String svg) {
  try {
    final wrappedSvg = svg.contains('xmlns')
        ? svg
        : svg.replaceFirst('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');

    return pw.SvgImage(svg: wrappedSvg, width: 480);
  } catch (e) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Text(
        '[Mermaid SVG - ${svg.length} 字符]',
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }
}

pw.Widget _buildMermaidFallback(String code) {
  return pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 8),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: const pw.BoxDecoration(
                color: PdfColors.orange700,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              'Mermaid 图表 (代码)',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          code,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );
}
