/// Markdown → PDF 导出器。
///
/// 把 Markdown 文档解析为 PDF：标题 / 段落 / 列表 / 表格 / 代码块 / 引用 /
/// 公式（含 SVG 矢量 + PNG 位图回退） / Mermaid 图表。
///
/// public API：仅暴露 [PdfExporter.export] 一个静态方法。所有渲染细节在
/// 文件内部完成；Mermaid 渲染委托给 [pdfMermaidRenderer]，公式渲染计划
/// 由 [FormulaRenderPlan] + 工厂构造。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/parser/formula_extractor.dart';
import '../../../core/parser/markdown_parser.dart';
import '../../../core/services/formula_pdf_renderer.dart';
import '../../../core/services/formula_svg_service.dart';
import '../../../core/services/mermaid_service.dart';
import '../../../data/models/document.dart';
import '../export_service.dart' show ExportException;
import 'formula_render_plan.dart';
import 'pdf_mermaid_renderer.dart';
import 'pdf_page_decoration.dart';

class PdfExporter {
  static pw.Font? _cjkFont;
  static bool _cjkFontLoadAttempted = false;
  static DateTime? _cjkFontLoadFailedAt;
  static const Duration _fontRetryInterval = Duration(seconds: 30);

  /// 加载 CJK 字体（用于中文等宽字符）。失败时回退 Helvetica。
  ///
  /// 具备重试机制：首次失败后间隔 [_fontRetryInterval] 可再次尝试加载，
  /// 避免临时 IO 抖动导致永久降级。
  static Future<pw.Font?> _ensureCjkFont() async {
    if (_cjkFontLoadAttempted && _cjkFont != null) {
      return _cjkFont;
    }

    // 如果已加载失败，检查是否超过重试间隔
    if (_cjkFontLoadAttempted && _cjkFont == null) {
      if (_cjkFontLoadFailedAt != null) {
        final elapsed = DateTime.now().difference(_cjkFontLoadFailedAt!);
        if (elapsed < _fontRetryInterval) {
          return null; // 仍在冷却期，使用 fallback
        }
        // 超过冷却期，允许重试
        debugPrint('CJK font retry attempt after ${elapsed.inSeconds}s cooldown');
      }
    }

    _cjkFontLoadAttempted = true;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      _cjkFont = pw.Font.ttf(data);
      _cjkFontLoadFailedAt = null; // 加载成功，清除失败记录
      debugPrint('CJK font loaded successfully');
    } catch (e, st) {
      // 详细 stack trace 记录：之前怀疑 ttf_parser.dart:126 是 Unexpected
      // extension byte 真因；如果以后还需要诊断，保留详细输出。
      debugPrint('CJK font load failed: $e');
      debugPrint('CJK font load stack: $st');
      _cjkFont = null;
      _cjkFontLoadFailedAt = DateTime.now();
    }
    return _cjkFont;
  }

  /// 决定 PDF 公式的渲染路径（SVG 矢量 vs PNG 位图）。
  /// SVG 优先（满足"矢量导出"硬约束），失败时回退到 PNG。
  ///
  /// [cjkFont] 用于 SvgPlan 内的中文字段（论文标题里的 $\alpha\beta$ 等
  /// 实际不会含中文，但 cjkFont 提供兜底字符映射）。
  static Future<FormulaRenderPlan> buildFormulaPlan(
    String latex,
    bool displayMode, {
    pw.Font? cjkFont,
  }) async {
    try {
      final svg = await FormulaSvgService.renderToSvg(
        latex,
        displayMode: displayMode,
      );
      if (svg.isNotEmpty) {
        return FormulaRenderPlan.svg(svg, latex, displayMode, cjkFont: cjkFont);
      }
    } catch (e) {
      debugPrint('SVG path failed for "$latex": $e');
    }
    final bytes = FormulaPdfRenderer.cachedBytes(
      latex,
      fontSize: 16,
      isDark: false,
      format: FormulaPdfRenderer.formatPdf,
    );
    if (bytes != null) {
      return FormulaRenderPlan.png(bytes, latex);
    }
    return FormulaRenderPlan.fallback(latex);
  }

  /// 入口：把 Markdown 文本导出为 PDF 字节流。
  static Future<Uint8List> export(
    String markdown, {
    String? title,
    String? author,
    bool isDark = false,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);

    // 收集所有公式（含 table cell 内的）。Set 自动去重。
    final allFormulas = collectAllFormulas(elements);

    if (allFormulas.isNotEmpty) {
      debugPrint(
          'Pre-rendering ${allFormulas.length} unique formulas (SVG, isDark=$isDark)...');
      // 主路径：SVG（WebView + MathJax）→ pw.SvgImage 矢量化嵌入 PDF。
      // 优势：无 GPU 离屏渲染、无内存压力、任意缩放清晰。
      // 不再预渲染 PNG：之前 5.0 倍 pixelRatio × 24 公式的离屏 toImage()
      // 会在真机低端设备上触发 GC 抖动 + 偶发 toImage 不返回。
      // PNG 缓存保留在 buildFormulaPlan 中作为最终兜底——WebView
      // 加载失败时回退到 bitmap（text fallback 之后）。
      try {
        await FormulaSvgService.preRenderAll(allFormulas, displayMode: false);
      } catch (e) {
        debugPrint('SVG pre-render failed (will fall back to PNG/text): $e');
      }
    }

    final cjk = await _ensureCjkFont();
    // 关键：除了 base + fontFallback，还要把 cjk 直接塞进 defaultStyle.font。
    // pdf 包内嵌的 pw.Text widget 在没显式指定 style.font 时，先用
    // defaultStyle.font；只有它不支持某字符时才走 fontFallback。
    // 之前 `pw.ThemeData.withFont(base: cjk, fontFallback: [cjk])` 只影响
    // Theme.defaultStyle.fontFallback 链，未显式设 defaultStyle.font
    // —— Helvetica 没有 CJK glyph 时直接走 "Unable to find a font" 路径，
    // 中文渲染为方框/空白。改用 `defaultTextStyle: TextStyle(font: cjk)`
    // 后所有 pw.Text 默认走 CJK 字体。
    final theme = cjk != null
        ? pw.ThemeData(
            defaultTextStyle: pw.TextStyle(
              font: cjk,
              fontFallback: [cjk],
            ),
          )
        : pw.ThemeData(
            defaultTextStyle: pw.TextStyle(
              font: pw.Font.helvetica(),
            ),
          );
    // 用于代码块的 monospace 字体。pdf 包内置 Courier。
    final monoFont = pw.Font.courier();

    final pdf = pw.Document(
      title: title ?? 'FormulaFix 文档',
      author: author ?? 'FormulaFix',
      creator: 'FormulaFix',
      subject: 'Markdown with LaTeX formulas',
      theme: theme,
    );

    final List<pw.Widget> body = [];

    for (final element in elements) {
      final widget = await _elementToPdfWidgetAsync(
        element,
        isDark: isDark,
        monoFont: monoFont,
        cjkFont: cjk,
      );
      if (widget != null) {
        body.add(widget);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 60, 40, 60),
        header: (ctx) => buildPdfHeader(title ?? 'FormulaFix', ctx, isDark: isDark),
        footer: (ctx) => buildPdfFooter(ctx, isDark: isDark),
        theme: theme,
        build: (_) => body,
      ),
    );

    // 不在导出末尾清理缓存——重复导出同一文档应能命中缓存。
    // 缓存在 editor_screen 退出 / app pause 时由调用方清理。
    // 但每次导出后清理 WebView DOM payload 元素，减少内存压力。
    await MermaidService.cleanupPayloads();
    try {
      return await pdf.save();
    } catch (e, st) {
      // DEBUG-DIAG: 抓完整 stack trace，帮助定位 Unexpected extension byte 真因
      debugPrint('====== [PDF-SAVE-DIAG] pdf.save() FAILED ======');
      debugPrint('Error: $e');
      debugPrint('Type: ${e.runtimeType}');
      debugPrint('Stack: $st');
      debugPrint('================================================');
      rethrow;
    }
  }

  /// 递归收集文档中所有唯一的 LaTeX 公式字符串（去重）。
  /// 覆盖 ParagraphElement / ListElement / TableElement（headers + 每个 cell）。
  ///
  /// 注意：MermaidElement / CodeElement 中的内容不是 LaTeX 公式，跳过。
  static Set<String> collectAllFormulas(List<DocumentElement> elements) {
    final out = <String>{};
    void walkInline(List<InlineElement> children) {
      for (final c in children) {
        if (c is FormulaElement) out.add(c.latex);
      }
    }

    for (final e in elements) {
      if (e is ParagraphElement) {
        walkInline(e.children);
      } else if (e is ListElement) {
        walkInline(e.children);
      } else if (e is TableElement) {
        // TableElement 当前不持有 inline children，但若未来扩展，walkInline 仍然兼容。
        // 现阶段 headers + rows 是 String，每个 cell 可能含 `$..$`，由 MarkdownParser
        // 暂未解析为 InlineElement；这里用 _scanForInlineFormulas 做字符串兜底。
        for (final h in e.headers) {
          _scanForInlineFormulas(h, out);
        }
        for (final row in e.rows) {
          for (final cell in row) {
            _scanForInlineFormulas(cell, out);
          }
        }
      }
    }
    return out;
  }

  /// 对单个字符串扫描 `$..$` / `$$..$$` 形式的内联公式并加入集合。
  /// 用作 TableElement 字符串 cell 的兜底（MarkdownParser 暂未把 cell 解析为 InlineElement）。
  static void _scanForInlineFormulas(String s, Set<String> out) {
    if (s.isEmpty || !s.contains(r'$')) return;
    final formulas = FormulaExtractor.extractFormulas(s);
    for (final f in formulas) {
      out.add(f.latex);
    }
  }

  // --- 元素 → PDF widget 派发 ---

  static Future<pw.Widget?> _elementToPdfWidgetAsync(
    DocumentElement element, {
    bool isDark = false,
    pw.Font? monoFont,
    pw.Font? cjkFont,
  }) async {
    if (element is HeadingElement) {
      return _pdfHeading(element.level, element.text, isDark: isDark, cjkFont: cjkFont);
    } else if (element is ParagraphElement) {
      return await _pdfParagraphAsync(element.children, fontSize: 13, isDark: isDark, cjkFont: cjkFont);
    } else if (element is ListElement) {
      final paragraph =
          await _pdfParagraphAsync(element.children, fontSize: 13, isDark: isDark, cjkFont: cjkFont);
      return _wrapListItem(paragraph, element.indent, element.ordered);
    } else if (element is CodeElement) {
      return _pdfCode(element.code, element.language, isDark: isDark, monoFont: monoFont, cjkFont: cjkFont);
    } else if (element is BlockquoteElement) {
      return _pdfBlockquote(element.text, isDark: isDark, cjkFont: cjkFont);
    } else if (element is MermaidElement) {
      return await buildMermaidPdfWidget(element.code, cjkFont: cjkFont);
    } else if (element is TableElement) {
      return await _pdfTable(element.headers, element.rows, isDark: isDark, cjkFont: cjkFont);
    } else if (element is EmptyLineElement) {
      return pw.SizedBox(height: 6);
    }
    return null;
  }

  // --- 段落 / 列表 / 标题 / 代码 / 引用 ---

  static Future<pw.Widget> _pdfParagraphAsync(
    List<InlineElement> children, {
    required double fontSize,
    bool bold = false,
    bool isDark = false,
    pw.Font? cjkFont,
  }) async {
    final textColor = isDark ? PdfColors.grey100 : PdfColors.black;
    final boldColor = isDark ? PdfColors.grey200 : PdfColors.grey900;
    final widgets = <pw.Widget>[];

    for (final c in children) {
      if (c is TextElement) {
        // 中文文本：使用 cjkFont（如果已加载），否则 helvetica 会显示方框
        widgets.add(pw.Text(
          c.text,
          style: pw.TextStyle(
            font: cjkFont,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? boldColor : textColor,
          ),
        ));
      } else if (c is FormulaElement) {
        final plan = await buildFormulaPlan(c.latex, c.displayMode, cjkFont: cjkFont);
        widgets.add(plan.toPdfWidget(fontSize: fontSize));
      } else if (c is BoldElement) {
        // 递归渲染 bold 内部
        widgets.add(await _pdfParagraphAsync(c.children, fontSize: fontSize, bold: true, isDark: isDark, cjkFont: cjkFont));
      }
    }

    return pw.Wrap(
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: widgets,
    );
  }

  static pw.Widget _wrapListItem(pw.Widget paragraph, int indent, bool ordered) {
    String prefix;
    if (ordered) {
      // 嵌套有序列表: indent=0 → "1.", indent=1 → "1.1.", indent=2 → "1.1.1."
      final parts = <String>[];
      for (int i = 0; i <= indent; i++) {
        parts.add('${i + 1}');
      }
      prefix = '${parts.join('.')}. ';
    } else {
      // 与 Word numbering.xml 中 bullet 样式对齐，每层用 `•`。
      prefix = '• ';
    }
    // 缩进与 Word 的 hanging 360 + 360*indent (twips) 保持近似比例。
    // 1 twip ≈ 0.0141 pt；360 twips ≈ 5pt = ~18.75 / 1.333 ≈ 14 logical pt
    const double indentPt = 14.0;
    final leftPad = indent * indentPt;
    final prefixWidth = leftPad + 24; // 留出编号+空白
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: prefixWidth,
            child: pw.Padding(
              padding: pw.EdgeInsets.only(left: leftPad),
              child: pw.Text(
                prefix,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Expanded(child: paragraph),
        ],
      ),
    );
  }

  static pw.Widget _pdfHeading(int level, String text,
      {bool isDark = false, pw.Font? cjkFont}) {
    final size = switch (level) {
      1 => 22.0,
      2 => 18.0,
      3 => 15.0,
      4 => 13.0,
      _ => 12.0,
    };
    final color = isDark ? PdfColors.grey100 : PdfColors.grey900;
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        top: level == 1 ? 16 : 12,
        bottom: 6,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: cjkFont,
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _pdfCode(
    String code,
    String? language, {
    bool isDark = false,
    pw.Font? monoFont,
    pw.Font? cjkFont,
  }) {
    final bgColor = isDark ? PdfColors.grey800 : PdfColors.grey100;
    final borderColor = isDark ? PdfColors.grey600 : PdfColors.grey300;
    final textColor = isDark ? PdfColors.grey100 : PdfColors.grey900;
    // 代码块优先用等宽字体 (Courier) 以保证代码对齐；
    // cjkFont 仅在无等宽字体时作 fallback（事实上 pdf 包的 standard fonts
    // 不支持 cjkFont fontFallback 命名参数，这里仅用 cjkFont 整体替换）。
    final codeFont = monoFont ?? (cjkFont ?? pw.Font.courier());
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (language != null && language.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: isDark ? PdfColors.blue900 : PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  language,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.Text(
            code,
            style: pw.TextStyle(
              fontSize: 11,
              color: textColor,
              font: codeFont,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfBlockquote(String text,
      {bool isDark = false, pw.Font? cjkFont}) {
    final bgColor = isDark ? PdfColors.grey800 : PdfColors.grey50;
    final textColor = isDark ? PdfColors.grey300 : PdfColors.grey800;
    final borderColor = isDark ? PdfColors.blue400 : PdfColors.blue700;
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: borderColor, width: 3),
        ),
        color: bgColor,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: cjkFont,
          fontSize: 13,
          fontStyle: pw.FontStyle.italic,
          color: textColor,
        ),
      ),
    );
  }

  // --- 表格 ---

  static Future<pw.Widget> _pdfTable(
    List<String> headers,
    List<List<String>> rows, {
    bool isDark = false,
    pw.Font? cjkFont,
  }) async {
    if (headers.isEmpty) return pw.SizedBox();

    // 把每个 header / cell 解析为 inline children，公式走矢量/位图渲染。
    final headerCells = <pw.Widget>[];
    for (final h in headers) {
      final inlines = MarkdownParser.parseInline(h);
      headerCells.add(pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: await _pdfParagraphAsync(inlines, fontSize: 12, bold: true, isDark: isDark, cjkFont: cjkFont),
      ));
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isDark ? PdfColors.grey700 : PdfColors.grey200,
        ),
        children: headerCells,
      ),
      for (int i = 0; i < rows.length; i++)
        await _buildDataTableRow(i, rows[i], isDark: isDark, cjkFont: cjkFont),
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(
          color: isDark ? PdfColors.grey600 : PdfColors.grey400,
          width: 0.5,
        ),
        children: tableRows,
      ),
    );
  }

  /// 构造一个数据行（带斑马纹 + 公式渲染）。
  static Future<pw.TableRow> _buildDataTableRow(int rowIndex, List<String> cells,
      {bool isDark = false, pw.Font? cjkFont}) async {
    final children = <pw.Widget>[];
    final evenBgColor = isDark ? PdfColors.grey800 : PdfColors.white;
     final oddBgColor = isDark ? PdfColors.grey700 : PdfColors.grey50;
    for (final cell in cells) {
      final inlines = MarkdownParser.parseInline(cell);
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: await _pdfParagraphAsync(inlines, fontSize: 11, isDark: isDark, cjkFont: cjkFont),
      ));
    }
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: rowIndex.isEven ? evenBgColor : oddBgColor,
      ),
      children: children,
    );
  }
}
