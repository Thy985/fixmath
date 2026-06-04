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
import '../../../data/models/document.dart';
import '../export_service.dart' show ExportException;
import 'formula_render_plan.dart';
import 'pdf_mermaid_renderer.dart';
import 'pdf_page_decoration.dart';

class PdfExporter {
  static pw.Font? _cjkFont;
  static bool _cjkFontLoadAttempted = false;

  /// 加载 CJK 字体（用于中文等宽字符）。失败时回退 Helvetica。
  static Future<pw.Font?> _ensureCjkFont() async {
    if (_cjkFontLoadAttempted) return _cjkFont;
    _cjkFontLoadAttempted = true;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      _cjkFont = pw.Font.ttf(data);
    } catch (e) {
      debugPrint('CJK font load failed: $e');
      _cjkFont = null;
    }
    return _cjkFont;
  }

  /// 决定 PDF 公式的渲染路径（SVG 矢量 vs PNG 位图）。
  /// SVG 优先（满足"矢量导出"硬约束），失败时回退到 PNG。
  static Future<FormulaRenderPlan> buildFormulaPlan(
    String latex,
    bool displayMode,
  ) async {
    try {
      final svg = await FormulaSvgService.renderToSvg(
        latex,
        displayMode: displayMode,
      );
      if (svg.isNotEmpty) {
        return FormulaRenderPlan.svg(svg, latex, displayMode);
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
      debugPrint('Pre-rendering ${allFormulas.length} unique formulas (PDF, isDark=$isDark)...');
      await FormulaPdfRenderer.preRenderAll(
        allFormulas,
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatPdf,
      );
      try {
        await FormulaSvgService.preRenderAll(allFormulas, displayMode: false);
      } catch (e) {
        debugPrint('SVG pre-render skipped: $e');
      }
    }

    final cjk = await _ensureCjkFont();
    final theme = (cjk != null)
        ? pw.ThemeData.withFont(base: cjk, fontFallback: [cjk])
        : pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            fontFallback: const [],
          );

    final pdf = pw.Document(
      title: title ?? 'FormulaFix 文档',
      author: author ?? 'FormulaFix',
      creator: 'FormulaFix',
      subject: 'Markdown with LaTeX formulas',
      theme: theme,
    );

    final List<pw.Widget> body = [];

    for (final element in elements) {
      final widget = await _elementToPdfWidgetAsync(element);
      if (widget != null) {
        body.add(widget);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 60, 40, 60),
        header: (ctx) => buildPdfHeader(title ?? 'FormulaFix', ctx),
        footer: (ctx) => buildPdfFooter(ctx),
        theme: theme,
        build: (_) => body,
      ),
    );

    // 不在导出末尾清理缓存——重复导出同一文档应能命中缓存。
    // 缓存在 editor_screen 退出 / app pause 时由调用方清理。
    return pdf.save();
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

  static Future<pw.Widget?> _elementToPdfWidgetAsync(DocumentElement element) async {
    if (element is HeadingElement) {
      return _pdfHeading(element.level, element.text);
    } else if (element is ParagraphElement) {
      return await _pdfParagraphAsync(element.children, fontSize: 13);
    } else if (element is ListElement) {
      final paragraph =
          await _pdfParagraphAsync(element.children, fontSize: 13);
      return _wrapListItem(paragraph, element.indent, element.ordered);
    } else if (element is CodeElement) {
      return _pdfCode(element.code, element.language);
    } else if (element is BlockquoteElement) {
      return _pdfBlockquote(element.text);
    } else if (element is MermaidElement) {
      return await buildMermaidPdfWidget(element.code);
    } else if (element is TableElement) {
      return await _pdfTable(element.headers, element.rows);
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
  }) async {
    final widgets = <pw.Widget>[];

    for (final c in children) {
      if (c is TextElement) {
        widgets.add(pw.Text(
          c.text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? PdfColors.grey900 : PdfColors.black,
          ),
        ));
      } else if (c is FormulaElement) {
        final plan = await buildFormulaPlan(c.latex, c.displayMode);
        widgets.add(plan.toPdfWidget(fontSize: fontSize));
      } else if (c is BoldElement) {
        // 递归渲染 bold 内部
        widgets.add(await _pdfParagraphAsync(c.children, fontSize: fontSize, bold: true));
      }
    }

    return pw.Wrap(
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: widgets,
    );
  }

  static pw.Widget _wrapListItem(pw.Widget paragraph, int indent, bool ordered) {
    final prefix = ordered ? '${indent + 1}. ' : '• ';
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 16.0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: indent * 16.0 + 20,
            child: pw.Text(
              prefix,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(child: paragraph),
        ],
      ),
    );
  }

  static pw.Widget _pdfHeading(int level, String text) {
    final size = switch (level) {
      1 => 22.0,
      2 => 18.0,
      3 => 15.0,
      4 => 13.0,
      _ => 12.0,
    };
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        top: level == 1 ? 16 : 12,
        bottom: 6,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _pdfCode(String code, String? language) {
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
          if (language != null && language.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
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
              font: null,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfBlockquote(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue700, width: 3),
        ),
        color: PdfColors.grey50,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  // --- 表格 ---

  static Future<pw.Widget> _pdfTable(
    List<String> headers,
    List<List<String>> rows,
  ) async {
    if (headers.isEmpty) return pw.SizedBox();

    // 把每个 header / cell 解析为 inline children，公式走矢量/位图渲染。
    final headerCells = <pw.Widget>[];
    for (final h in headers) {
      final inlines = MarkdownParser.parseInline(h);
      headerCells.add(pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: await _pdfParagraphAsync(inlines, fontSize: 12, bold: true),
      ));
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: headerCells,
      ),
      for (int i = 0; i < rows.length; i++)
        await _buildDataTableRow(i, rows[i]),
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: tableRows,
      ),
    );
  }

  /// 构造一个数据行（带斑马纹 + 公式渲染）。
  static Future<pw.TableRow> _buildDataTableRow(int rowIndex, List<String> cells) async {
    final children = <pw.Widget>[];
    for (final cell in cells) {
      final inlines = MarkdownParser.parseInline(cell);
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: await _pdfParagraphAsync(inlines, fontSize: 11),
      ));
    }
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: rowIndex.isEven ? PdfColors.white : PdfColors.grey50,
      ),
      children: children,
    );
  }
}
