/// PDF 公式渲染计划：SVG 矢量 / PNG 位图 / 回退文本三选一。
///
/// 在 [PdfExporter] 中通过 [buildFormulaPlan] 工厂构造。SVG 优先（满足
/// "矢量导出"硬约束），失败时回退 PNG，最终回退文本。
///
/// 文件级 internal 类型：仅在 exporters/ 目录内可见；不参与公开 API。
library;

import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

/// PDF 公式渲染计划。
///
/// SVG 矢量 / PNG 位图 / 回退文本 三选一，按优先级顺序：
///   1. SVG 矢量（矢量导出硬约束）
///   2. PNG 位图（SVG 失败时回退）
///   3. 原始 LaTeX 文本（最终兜底）
sealed class FormulaRenderPlan {
  const FormulaRenderPlan();

  /// SVG 矢量路径：直接在 PDF 中嵌入 SVG，缩放不失真。
  factory FormulaRenderPlan.svg(String svg, String latex, bool displayMode) =
      SvgPlan;

  /// PNG 位图路径：嵌入高分辨率位图。
  factory FormulaRenderPlan.png(Uint8List bytes, String latex) = PngPlan;

  /// 回退路径：显示原始 LaTeX 文本。
  factory FormulaRenderPlan.fallback(String latex) = FallbackPlan;

  /// 转换为 PDF widget。
  pw.Widget toPdfWidget({required double fontSize});
}

class SvgPlan extends FormulaRenderPlan {
  final String svg;
  final String latex;
  final bool displayMode;

  const SvgPlan(this.svg, this.latex, this.displayMode);

  @override
  pw.Widget toPdfWidget({required double fontSize}) {
    String wrapped = svg;
    if (!wrapped.contains('xmlns=')) {
      wrapped = wrapped.replaceFirst(
        '<svg',
        '<svg xmlns="http://www.w3.org/2000/svg/"',
      );
    }
    try {
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: pw.SvgImage(svg: wrapped, width: fontSize * 6),
      );
    } catch (e) {
      return FallbackPlan(latex).toPdfWidget(fontSize: fontSize);
    }
  }
}

class PngPlan extends FormulaRenderPlan {
  final Uint8List bytes;
  final String latex;

  const PngPlan(this.bytes, this.latex);

  @override
  pw.Widget toPdfWidget({required double fontSize}) {
    try {
      final img = pw.MemoryImage(bytes, dpi: 300.0);
      final iw = img.width?.toDouble() ?? (fontSize * 4);
      final ih = img.height?.toDouble() ?? (fontSize * 1.4);
      final targetHeight = fontSize * 1.5;
      final targetWidth = (iw / ih) * targetHeight;
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        child: pw.Image(img, height: targetHeight, width: targetWidth),
      );
    } catch (e) {
      return FallbackPlan(latex).toPdfWidget(fontSize: fontSize);
    }
  }
}

class FallbackPlan extends FormulaRenderPlan {
  final String latex;

  const FallbackPlan(this.latex);

  @override
  pw.Widget toPdfWidget({required double fontSize}) {
    return pw.Text(
      '[$latex]',
      style: pw.TextStyle(
        fontSize: fontSize * 0.85,
        fontStyle: pw.FontStyle.italic,
        color: PdfColors.grey600,
      ),
    );
  }
}
