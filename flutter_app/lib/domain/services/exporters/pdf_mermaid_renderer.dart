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
import '../../../core/renderers/svg_parser.dart';
import '../../../core/renderers/svg_to_pdf.dart';
import '../../../core/services/mermaid_service.dart';
import 'formula_render_plan.dart' show sanitizeSvgString;

/// 构造 PDF 中的 Mermaid widget：SVG 矢量优先，失败回退代码块展示。
///
/// [cjkFont] 由 PdfExporter 注入；用于 Mermaid 节点中的中文字段。
Future<pw.Widget> buildMermaidPdfWidget(String code, {pw.Font? cjkFont}) async {
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
            _buildSvgInPdf(svg, cjkFont: cjkFont),
          ],
        ),
      );
    } catch (e) {
      debugPrint('SVG to PDF conversion failed: $e');
    }
  }

  return _buildMermaidFallback(code);
}

pw.Widget _buildSvgInPdf(String svg, {pw.Font? cjkFont}) {
  try {
    // 关键：先清洗 SVG。Mermaid 在某些 Unicode 字符上会通过 WebView
    // console 桥接回 Dart 时残留未配对 UTF-16 代理对。
    // 新路线（stage1+）：与公式路径一致 —— svg_parser → AST → SvgPdfWidget。
    // 关键好处：
    // 1. **layout 按父约束缩放**——避免 Mermaid 大尺寸 SVG 触发 TooManyPagesException
    //    （修复前 pw.SvgImage(width: 480) 在高瘦 SVG 上能撑到 1262pt 高度）
    // 2. **彻底绕开 pw.SvgImage 内部 utf8.encode 路径**——根除 Unexpected extension byte
    final cleaned = sanitizeSvgString(svg);
    final root = parseSvgString(cleaned);
    return SvgPdfWidget(root: root, textFont: cjkFont, fallbackFont: cjkFont);
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
