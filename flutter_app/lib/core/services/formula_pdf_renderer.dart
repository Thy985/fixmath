import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/parser/formula_extractor.dart';
import '../../data/models/document.dart';

/// PDF 公式渲染器
/// 将 LaTeX 公式渲染为 PDF 可嵌入的图像
class FormulaPdfRenderer {
  /// 缓存 key -> PNG bytes
  static final _cache = <String, Uint8List>{};

  /// 预渲染公式到图片（可在导出前调用）
  static Future<void> preRender(String latex, {double fontSize = 16}) async {
    final normalized = FormulaExtractor.normalizeLatex(latex);
    final cacheKey = '${normalized}_$fontSize';

    if (_cache.containsKey(cacheKey)) return;

    try {
      final bytes = await _renderToImage(normalized, fontSize: fontSize);
      if (bytes != null) {
        _cache[cacheKey] = bytes;
      }
    } catch (_) {
      // 渲染失败静默忽略，使用 fallback
    }
  }

  /// 批量预渲染文档中的所有公式
  static Future<void> preRenderAll(List<String> latexList, {double fontSize = 16}) async {
    for (final latex in latexList) {
      await preRender(latex, fontSize: fontSize);
    }
  }

  /// 清除缓存
  static void clearCache() => _cache.clear();

  static Future<Uint8List?> _renderToImage(String latex, {double fontSize = 16}) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final textPainter = TextPainter(
        text: TextSpan(
          text: latex,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'monospace',
            color: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final w = textPainter.width.toInt() + 16;
      final h = textPainter.height.toInt() + 8;

      canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.white);
      textPainter.paint(canvas, const Offset(8, 4));

      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 构建公式 PDF Widget
  static pw.Widget build(String latex, {double fontSize = 14, bool displayMode = false}) {
    final normalized = FormulaExtractor.normalizeLatex(latex);
    final cacheKey = '${normalized}_$fontSize';

    if (_cache.containsKey(cacheKey)) {
      final bytes = _cache[cacheKey]!;
      return pw.Image(
        pw.MemoryImage(bytes),
        width: displayMode ? null : fontSize * 3,
        height: fontSize * 2,
        fit: displayMode ? pw.BoxFit.scaleDown : pw.BoxFit.contain,
      );
    }

    // Fallback: 带样式的公式文本
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        normalized,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.blue800,
        ),
      ),
    );
  }
}

/// PDF 段落渲染器（支持公式嵌入图片）
class PdfParagraphBuilder {
  static pw.Widget build(List<InlineElement> children, {double fontSize = 13}) {
    final spans = <pw.InlineSpan>[];

    for (final child in children) {
      if (child is FormulaElement) {
        spans.add(pw.WidgetSpan(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
            child: FormulaPdfRenderer.build(
              child.latex,
              fontSize: fontSize,
              displayMode: child.displayMode,
            ),
          ),
        ));
      } else if (child is TextElement) {
        spans.add(pw.TextSpan(
          text: child.text,
          style: pw.TextStyle(fontSize: fontSize),
        ));
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: spans,
          style: pw.TextStyle(fontSize: fontSize, lineSpacing: 1.5),
        ),
      ),
    );
  }
}