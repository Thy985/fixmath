/// PDF 公式渲染计划：SVG 矢量 / PNG 位图 / 回退文本三选一。
///
/// 在 [PdfExporter] 中通过 [buildFormulaPlan] 工厂构造。SVG 优先（满足
/// "矢量导出"硬约束），失败时回退 PNG，最终回退文本。
///
/// 文件级 internal 类型：仅在 exporters/ 目录内可见；不参与公开 API。
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

/// 把任意来源的字符串（含未配对 UTF-16 代理对 / 不可编码字符 / 非 BMP 字符）
/// 清洗成可安全 `utf8.encode` 的 Dart String。
///
/// 背景：MathJax / Mermaid 在某些 Unicode 边缘字符上会输出孤立的 high
/// surrogate (U+D800-U+DBFF) 或 low surrogate (U+DC00-U+DFFF)。WebView
/// 桥接回 Dart 时这些 surrogate 会被原样保留在 String 里。`pw.SvgImage`
/// 内部走 `utf8.encode` → 抛 "Unexpected extension byte" → 整份 PDF
/// 导出失败（错误分类为 parseError → 用户看到"文档中有无法识别的内容"）。
///
/// 实现要点：
/// 1. 用 `runes` 迭代 code points（不是 code units），正确处理非 BMP 字符
///    （如数学字母数字 U+1D400-U+1D7FF、emoji）
/// 2. 把未配对 surrogate 替换为 U+FFFD
/// 3. **关键**：用 `String.fromCharCodes` 一次性重建字符串——Dart 内部会
///    自动为非 BMP 字符生成合法 surrogate pair。如果用 `String.fromCharCode`
///    逐字符重建，对 rune > 0xFFFF 会**截断为低 16 位**，产生新的孤立
///    surrogate，再次触发 utf8.encode 抛 "Unexpected extension byte
///    (at offset 1)"（错误点正好是非 BMP 字符被编码后第二个字节的位置）
String sanitizeSvgString(String input) {
  if (input.isEmpty) return input;
  // 第一遍：扫 runes，把孤立 surrogate / 非字符 / 控制字符替换为 U+FFFD
  final safeRunes = <int>[];
  for (final r in input.runes) {
    if (r >= 0xD800 && r <= 0xDFFF) {
      // 孤立 surrogate：U+D800-U+DFFF 范围
      safeRunes.add(0xFFFD);
    } else if (r == 0xFFFE || r == 0xFFFF || r == 0xFDD0) {
      // Unicode 非字符（noncharacter）
      safeRunes.add(0xFFFD);
    } else if (r >= 0x00 && r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) {
      // C0 控制字符（除 Tab / LF / CR 三个合法 XML 字符外）
      safeRunes.add(0xFFFD);
    } else if (r == 0x7F) {
      // DEL 字符
      safeRunes.add(0xFFFD);
    } else {
      safeRunes.add(r);
    }
  }
  // 第二遍：用 fromCharCodes 一次性重建。Dart 内部会正确编码
  // 非 BMP 字符（如 0x1D44C → D835 DD0C 合法 surrogate pair）
  final cleaned = String.fromCharCodes(safeRunes);
  // 第三遍：round-trip 验证。清洗后字符串必须能成功 utf8.encode，
  // 如果这一步还失败（理论上不会），退化为空字符串防止 PDF 导出整体崩溃
  try {
    final bytes = utf8.encode(cleaned);
    return utf8.decode(bytes, allowMalformed: true);
  } on FormatException {
    return '';
  }
}

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
    // 关键：先清洗 SVG 字符串。MathJax / Mermaid 在某些 Unicode 字符上
    // 会通过 WebView console 桥接回 Dart 时残留未配对的 UTF-16 代理对，
    // pw.SvgImage 内部 utf8.encode 会抛 "Unexpected extension byte"
    // 致整份 PDF 导出失败。
    String wrapped = sanitizeSvgString(svg);
    if (!wrapped.contains('xmlns=')) {
      wrapped = wrapped.replaceFirst(
        '<svg',
        '<svg xmlns="http://www.w3.org/2000/svg/"',
      );
    }
    // 防御性深度：sanitizeSvgString 已经尽力清洗，但若清洗后 SVG 仍无法
    // utf8.encode（极端情况：原始 SVG 含非 BMP 字符 + 孤立 surrogate 组合），
    // 这里**主动**调用 utf8.encode 验证。pw.SvgImage 是懒构造 widget，
    // 错误要到 pdf.save() 阶段才抛，到那时已无法 catch 退回 PNG。
    try {
      utf8.encode(wrapped);
    } catch (e) {
      // 关键：打印出问题的 SVG 字节序列前 20 字节，
      // 帮助定位是哪个字符触发 "Unexpected extension byte (at offset 1)"
      // 编码失败时不能再用 utf8.encode（会再次抛错）——用 runes + String 显示
      final preview = wrapped.runes
          .take(20)
          .map((r) => r > 0xFFFF ? '[U+${r.toRadixString(16)}]' : String.fromCharCode(r))
          .join();
      debugPrint(
          'SvgPlan: sanitized SVG still fails utf8.encode! Latex: ${latex.length > 40 ? '${latex.substring(0, 40)}...' : latex}');
      debugPrint('SvgPlan: first 20 runes of sanitized SVG: $preview');
      debugPrint('SvgPlan: error: $e');
      return FallbackPlan(latex).toPdfWidget(fontSize: fontSize);
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
