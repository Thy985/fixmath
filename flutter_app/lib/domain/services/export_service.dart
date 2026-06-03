import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/parser/formula_extractor.dart';
import '../../core/parser/markdown_parser.dart';
import '../../core/services/export_service.dart' show ExportException;
import '../../core/services/formula_pdf_renderer.dart';
import '../../core/services/formula_svg_service.dart';
import '../../core/services/mermaid_service.dart';
import '../../data/models/document.dart';
import 'word_ooxml_templates.dart';

class MarkdownExporter {
  static pw.Font? _cjkFont;
  static bool _cjkFontLoadAttempted = false;
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
  static Future<_FormulaRenderPlan> _buildFormulaPlan(
    String latex,
    bool displayMode,
  ) async {
    try {
      final svg = await FormulaSvgService.renderToSvg(
        latex,
        displayMode: displayMode,
      );
      if (svg.isNotEmpty) {
        return _FormulaRenderPlan.svg(svg, latex, displayMode);
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
      return _FormulaRenderPlan.png(bytes, latex);
    }
    return _FormulaRenderPlan.fallback(latex);
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
        // 现阶段 headers + rows 是 String，每个 cell 可能含 `$..$`，由 _parseTableRow 暂未解析。
        // 真正在 Table cell 里走公式需要 MarkdownParser 支持；目前我们通过预扫描 raw markdown 二次
        // 抽取来保证不漏，见 [collectAllFormulasFromMarkdown]。
        // 这里仍然为未来扩展留 hook：
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

  static Future<Uint8List> exportToPdf(
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
        header: (ctx) => _buildHeader(title ?? 'FormulaFix', ctx),
        footer: (ctx) => _buildFooter(ctx),
        theme: theme,
        build: (_) => body,
      ),
    );

    // 不在导出末尾清理缓存——重复导出同一文档应能命中缓存。
    // 缓存在 editor_screen 退出 / app pause 时由调用方清理。
    return pdf.save();
  }

  static pw.Widget _buildHeader(String title, pw.Context ctx) {
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

  static pw.Widget _buildFooter(pw.Context ctx) {
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
            '生成于 ${_formatDate(DateTime.now())}',
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

  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

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
      return await _pdfMermaid(element.code);
    } else if (element is TableElement) {
      return await _pdfTable(element.headers, element.rows);
    } else if (element is EmptyLineElement) {
      return pw.SizedBox(height: 6);
    }
    return null;
  }

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
        final plan = await _buildFormulaPlan(c.latex, c.displayMode);
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

  static String _inlineToText(List<InlineElement> children) {
    final buf = StringBuffer();
    for (final c in children) {
      if (c is TextElement) {
        buf.write(c.text);
      } else if (c is FormulaElement) {
        buf.write(' [${c.latex}] ');
      }
    }
    return buf.toString();
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

  static Future<pw.Widget> _pdfMermaid(String code) async {
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

  static pw.Widget _buildSvgInPdf(String svg) {
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

  static pw.Widget _buildMermaidFallback(String code) {
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

  static Future<Uint8List> exportToWord(
    String markdown, {
    String? title,
    bool isDark = false,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);

    // 收集所有公式（含 table cell 内的）。Set 自动去重。
    final allFormulasSet = collectAllFormulas(elements);

    // 保持 Word 端原有的有序列表（保持生成文件名 / relId 顺序稳定）
    final allFormulas = <String>[];
    final formulaRels = <String, _FormulaImageInfo>{};
    final allMermaids = <String>[];
    final mermaidRels = <String, _MermaidImageInfo>{};

    for (final e in elements) {
      _collectFormulasForWord(e, allFormulas, formulaRels);
      _collectMermaidsForWord(e, allMermaids, mermaidRels);
    }
    // 把 set 里多出来的公式（来自 table cell 字符串扫描）也补到有序列表中
    for (final latex in allFormulasSet) {
      if (!formulaRels.containsKey(latex)) {
        final idx = allFormulas.length + 1;
        allFormulas.add(latex);
        formulaRels[latex] = _FormulaImageInfo(
          relId: 'rIdImage$idx',
          widthEmu: 0,
          heightEmu: 0,
        );
      }
    }

    if (allFormulas.isNotEmpty) {
      // Word 导出走独立的 cache key 维度，避免与 PDF 像素密度不同导致的互相覆盖
      await FormulaPdfRenderer.preRenderAll(
        allFormulas.toSet(),
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatWord,
      );
    }

    // 渲染 Mermaid 为 SVG
    if (allMermaids.isNotEmpty) {
      for (int i = 0; i < allMermaids.length; i++) {
        final code = allMermaids[i];
        try {
          final svg = await MermaidService.renderToSvg(code);
          final info = mermaidRels[code];
          if (info != null) {
            mermaidRels[code] = _MermaidImageInfo(
              relId: info.relId,
              svg: svg,
            );
          }
        } catch (e) {
          debugPrint('Mermaid SVG render failed for Word: $e');
        }
      }
    }

    // 计算每个公式图片的实际尺寸并更新 formulaRels
    for (final latex in allFormulas) {
      final bytes = FormulaPdfRenderer.cachedBytes(
        latex,
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatWord,
      );
      if (bytes != null) {
        final dims = _parsePngDimensions(bytes);
        if (dims != null) {
          final info = formulaRels[latex];
          if (info != null) {
            formulaRels[latex] = _FormulaImageInfo(
              relId: info.relId,
              widthEmu: dims.width * 9525,
              heightEmu: dims.height * 9525,
            );
          }
        }
      }
    }

    final docXml = _buildDocXml(elements, title, formulaRels, mermaidRels);
    final imageRelsXml = _buildImageRelsXml(formulaRels, mermaidRels);

    // [Content_Types].xml 现在包含 styles/settings/numbering 的 Override，
    // 见 WordOoxmlTemplates.contentTypesXml。
    final contentTypesXml = WordOoxmlTemplates.contentTypesXml;
    final rootRelsXml = WordOoxmlTemplates.rootRelsXml;

    final archive = Archive();

    archive.addFile(ArchiveFile(
        '[Content_Types].xml', contentTypesXml.length, contentTypesXml));
    archive.addFile(
        ArchiveFile('_rels/.rels', rootRelsXml.length, rootRelsXml));
    archive.addFile(ArchiveFile(
        'word/document.xml', docXml.length, docXml));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels',
        imageRelsXml.length, imageRelsXml));

    // 补全 OOXML 必需 Part：styles / settings / numbering。
    // 这些文件让导出的 docx 在 Word/WPS/LibreOffice 中能识别 pStyle 和 numId。
    final stylesXml = WordOoxmlTemplates.stylesXml;
    final settingsXml = WordOoxmlTemplates.settingsXml;
    final numberingXml = WordOoxmlTemplates.numberingXml;
    archive.addFile(ArchiveFile(
        'word/styles.xml', stylesXml.length, stylesXml));
    archive.addFile(ArchiveFile(
        'word/settings.xml', settingsXml.length, settingsXml));
    archive.addFile(ArchiveFile(
        'word/numbering.xml', numberingXml.length, numberingXml));

    int i = 0;
    for (final latex in allFormulas) {
      i++;
      final bytes = FormulaPdfRenderer.cachedBytes(
        latex,
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatWord,
      );
      if (bytes != null) {
        final name = 'word/media/formula_$i.png';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    // 添加 Mermaid SVG 文件
    i = 0;
    for (final code in allMermaids) {
      i++;
      final info = mermaidRels[code];
      if (info != null && info.svg != null) {
        final name = 'word/media/mermaid_$i.svg';
        archive.addFile(ArchiveFile(name, info.svg!.length, info.svg!));
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw ExportException('Failed to encode Word document');
    }
    // 不在导出末尾清理缓存——重复导出同一文档应能命中缓存。
    // 缓存在 editor_screen 退出 / app pause 时由调用方清理。
    return Uint8List.fromList(encoded);
  }

  static void _collectFormulasForWord(
    DocumentElement element,
    List<String> allFormulas,
    Map<String, _FormulaImageInfo> formulaRels,
  ) {
    int register(String latex) {
      if (formulaRels.containsKey(latex)) return 0;
      final idx = allFormulas.length + 1;
      allFormulas.add(latex);
      formulaRels[latex] = _FormulaImageInfo(relId: 'rIdImage$idx', widthEmu: 0, heightEmu: 0);
      return idx;
    }

    if (element is ParagraphElement) {
      for (final c in element.children) {
        if (c is FormulaElement) register(c.latex);
      }
    } else if (element is ListElement) {
      for (final c in element.children) {
        if (c is FormulaElement) register(c.latex);
      }
    }
  }

  static void _collectMermaidsForWord(
    DocumentElement element,
    List<String> allMermaids,
    Map<String, _MermaidImageInfo> mermaidRels,
  ) {
    int register(String code) {
      if (mermaidRels.containsKey(code)) return 0;
      final idx = allMermaids.length + 1;
      allMermaids.add(code);
      mermaidRels[code] = _MermaidImageInfo(relId: 'rIdMermaid$idx', svg: null);
      return idx;
    }

    if (element is MermaidElement) {
      register(element.code);
    }
  }

  static String _buildDocXml(
    List<DocumentElement> elements,
    String? title,
    Map<String, _FormulaImageInfo> formulaRels,
    Map<String, _MermaidImageInfo> mermaidRels,
  ) {
    final buffer = StringBuffer();

    final docTitle = title ?? 'FormulaFix 文档';
    buffer.write(_wordHeading(0, docTitle));

    for (final element in elements) {
      buffer.write(_elementToWordXml(
        element,
        formulaRels: formulaRels,
        mermaidRels: mermaidRels,
      ));
      buffer.write('\n');
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>$buffer</w:body>
</w:document>''';
  }

  static String _buildImageRelsXml(
      Map<String, _FormulaImageInfo> formulaRels,
      Map<String, _MermaidImageInfo> mermaidRels) {
    final buf = StringBuffer();
    for (final entry in formulaRels.entries) {
      final info = entry.value;
      final i = info.relId.replaceFirst('rIdImage', '');
      buf.write(
        '<Relationship Id="${info.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/formula_$i.png"/>',
      );
    }
    for (final entry in mermaidRels.entries) {
      final info = entry.value;
      if (info.svg != null) {
        final i = info.relId.replaceFirst('rIdMermaid', '');
        buf.write(
          '<Relationship Id="${info.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/mermaid_$i.svg"/>',
        );
      }
    }
    // 用 WordOoxmlTemplates 提供的前缀包裹，里面已经包含 styles/settings/numbering
    // 的 Relationship（rIdStyles / rIdSettings / rIdNumbering），
    // 后面追加图片 Relationship（rIdImageN / rIdMermaidN），命名空间不冲突。
    return '''${WordOoxmlTemplates.documentRelsHeader}
$buf${WordOoxmlTemplates.documentRelsFooter}''';
  }

  static String _elementToWordXml(
    DocumentElement element, {
    required Map<String, _FormulaImageInfo> formulaRels,
    required Map<String, _MermaidImageInfo> mermaidRels,
  }) {
    if (element is HeadingElement) {
      return _wordHeading(element.level, element.text);
    } else if (element is ParagraphElement) {
      return _wordParagraph(element.children, formulaRels: formulaRels);
    } else if (element is ListElement) {
      return _wordList(
        element.children,
        element.indent,
        element.ordered,
        formulaRels: formulaRels,
      );
    } else if (element is CodeElement) {
      return _wordCode(element.code, element.language);
    } else if (element is BlockquoteElement) {
      return _wordBlockquote(element.text);
    } else if (element is MermaidElement) {
      return _wordMermaidSvg(element.code, mermaidRels: mermaidRels);
    } else if (element is TableElement) {
      return _wordTable(element.headers, element.rows);
    } else if (element is EmptyLineElement) {
      return '<w:p/>';
    }
    return '';
  }

  static String _wordHeading(int level, String text) {
    final escaped = _esc(text);
    // level 0 是文档标题（Title 样式），1..6 是 Heading1..Heading6
    // 样式表里的 size/bold 等由 pStyle 决定，run 上不再重复 <w:sz>，避免与样式冲突
    if (level == 0) {
      return '''<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
    }
    final styleId = 'Heading$level';
    return '''<w:p><w:pPr><w:pStyle w:val="$styleId"/></w:pPr><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
  }

  static String _wordParagraph(
    List<InlineElement> children, {
    required Map<String, _FormulaImageInfo> formulaRels,
  }) {
    final runs = StringBuffer();
    for (final c in children) {
      if (c is FormulaElement) {
        final info = formulaRels[c.latex];
        if (info != null) {
          runs.write(_wordFormulaImage(info.relId, info.widthEmu, info.heightEmu));
        } else {
          runs.write(_wordFormulaFallback(c.latex));
        }
      } else if (c is TextElement) {
        runs.write(
          '''<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
        );
      }
    }
    return '<w:p>$runs</w:p>';
  }

  static String _wordFormulaImage(String relId, int widthEmu, int heightEmu) {
    // 限制最大尺寸，防止 Word 显示异常
    const maxDim = 2600000; // ~27cm
    final w = widthEmu > 0 && widthEmu < maxDim ? widthEmu : 1200000;
    final h = heightEmu > 0 && heightEmu < maxDim ? heightEmu : 360000;
    return '''<w:r><w:rPr><w:noProof/></w:rPr><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$w" cy="$h"/><wp:docPr id="${relId.hashCode & 0x7FFFFFFF}" name="Formula"/><wp:cNvGraphicFramePr/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="formula"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$w" cy="$h"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>''';
  }

  static String _wordFormulaFallback(String latex) {
    return '''<w:r><w:rPr><w:i/><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(latex)}</w:t></w:r>''';
  }

  static String _wordList(
    List<InlineElement> children,
    int indent,
    bool ordered, {
    required Map<String, _FormulaImageInfo> formulaRels,
  }) {
    // 真正使用 numbering.xml 里定义的 numId。
    // ordered → numId 1 (decimal "1.")；unordered → numId 2 (bullet "•")。
    // ilvl 0 对应 abstractNum 的第一层，Word 会根据 numFmt 自动渲染前缀，
    // 因此不再手动写 "${indent + 1}. " 文本前缀。
    final numId = ordered
        ? WordOoxmlTemplates.numIdOrdered
        : WordOoxmlTemplates.numIdBullet;
    final leftIndent = 360 + (indent * 360);
    final runs = StringBuffer();
    for (final c in children) {
      if (c is TextElement) {
        runs.write(
          '''<w:r><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''',
        );
      } else if (c is FormulaElement) {
        final info = formulaRels[c.latex];
        if (info != null) {
          runs.write(_wordFormulaImage(info.relId, info.widthEmu, info.heightEmu));
        } else {
          runs.write(_wordFormulaFallback(c.latex));
        }
      }
    }
    return '''<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="$indent"/><w:numId w:val="$numId"/></w:numPr><w:ind w:left="$leftIndent" w:hanging="360"/></w:pPr>$runs</w:p>''';
  }

  static String _wordCode(String code, String? language) {
    // CodeBlock 样式已经包含 shd 灰底、Courier New 字体和左缩进，
    // 这里只在 run 上保留 <w:rPr> 上的语言徽章（如有），避免重复样式覆盖。
    final langTag = (language != null && language.isNotEmpty)
        ? '''<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/><w:highlight w:val="blue"/></w:rPr><w:t xml:space="preserve"> $language </w:t></w:r><w:r><w:br/></w:r>'''
        : '';
    return '''<w:p><w:pPr><w:pStyle w:val="CodeBlock"/></w:pPr>$langTag<w:r><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  static String _wordBlockquote(String text) {
    // Blockquote 样式已经包含左边框、灰底、左缩进和斜体灰色字，
    // 这里 run 上不再重复 shd/bdr/i 样式，避免冲突并保证样式可被用户统一修改。
    return '''<w:p><w:pPr><w:pStyle w:val="Blockquote"/></w:pPr><w:r><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>''';
  }

  /// 解析 SVG viewBox 属性，返回 (width, height) 比例。
  /// 解析失败时返回 null。
  static ({double width, double height})? _parseSvgViewBox(String svg) {
    try {
      final match = RegExp(r'''viewBox\s*=\s*["']([^"']+)["']''').firstMatch(svg);
      if (match == null) return null;
      final parts = match.group(1)!.split(RegExp(r'[\s,]+'));
      if (parts.length < 4) return null;
      final w = double.tryParse(parts[2]);
      final h = double.tryParse(parts[3]);
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      return (width: w, height: h);
    } catch (_) {
      return null;
    }
  }

  /// 根据 SVG viewBox 比例计算 Word 绘图尺寸（EMU 单位）。
  /// 限制最大宽度为 6 英寸（5486400 EMU），高度按比例计算。
  static (int cx, int cy) _calcMermaidEmu(String svg) {
    const maxWidthEmu = 5486400; // 6 inches in EMU
    const minHeightEmu = 100000; // 最小高度 1cm
    const defaultRatio = 2.0; // 默认 6x3 inches

    final dims = _parseSvgViewBox(svg);
    if (dims == null) {
      return (maxWidthEmu, (maxWidthEmu / defaultRatio).round());
    }

    final ratio = dims.width / dims.height;
    final widthEmu = maxWidthEmu;
    final heightEmu = (widthEmu / ratio).round().clamp(minHeightEmu, maxWidthEmu);
    return (widthEmu, heightEmu);
  }

  static String _wordMermaidSvg(String code, {required Map<String, _MermaidImageInfo> mermaidRels}) {
    final info = mermaidRels[code];
    if (info != null && info.svg != null && info.svg!.isNotEmpty) {
      final (cx, cy) = _calcMermaidEmu(info.svg!);
      return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/></w:bdr></w:pPr><w:r><w:rPr><w:noProof/></w:rPr><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="1" name="Mermaid Diagram"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="0" name="mermaid"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="${info.relId}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></a:graphic></wp:inline></w:drawing></w:r><w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:t xml:space="preserve"> (Mermaid 图表)</w:t></w:r></w:p>''';
    }
    // 渲染失败，显示代码作为回退
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/></w:bdr></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">[Mermaid 图表 - 代码]</w:t></w:r><w:r><w:br/></w:r><w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="18"/><w:color w:val="888888"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  static String _wordTable(List<String> headers, List<List<String>> rows) {
    if (headers.isEmpty) return '<w:p/>';

    final headerCells = headers
        .map((h) => '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/><w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/></w:tcBorders><w:shd w:val="clear" w:fill="DDDDDD"/></w:tcPr><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${_esc(h)}</w:t></w:r></w:p></w:tc>''')
        .join('');

    final dataRows = rows.map((row) {
      final cells = row
          .map((cell) => '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="CCCCCC"/><w:left w:val="single" w:sz="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:color="CCCCCC"/><w:right w:val="single" w:sz="4" w:color="CCCCCC"/></w:tcBorders></w:tcPr><w:p><w:r><w:t>${_esc(cell)}</w:t></w:r></w:p></w:tc>''')
          .join('');
      return '<w:tr>$cells</w:tr>';
    }).join('');

    return '''<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/></w:tblPr><w:tr>$headerCells</w:tr>$dataRows</w:tbl>''';
  }

  static String _esc(String s) {
    final cleaned = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x20 && rune != 0x7F) {
        cleaned.writeCharCode(rune);
      } else {
        cleaned.write('\uFFFD');
      }
    }
    return cleaned
        .toString()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// 解析 PNG 图片的宽高（单位：像素）。
  /// PNG header: signature(8) + IHDR chunk(len:4 + type:4 + data:13 + crc:4)
  /// 宽度在偏移 16 处，高度在偏移 20 处，均为 4 字节 big-endian。
  static ({int width, int height})? _parsePngDimensions(Uint8List bytes) {
    if (bytes.length < 24) return null;
    if (bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47) return null; // Not PNG
    try {
      final w0 = bytes[16] & 0xFF;
      final w1 = bytes[17] & 0xFF;
      final w2 = bytes[18] & 0xFF;
      final w3 = bytes[19] & 0xFF;
      final h0 = bytes[20] & 0xFF;
      final h1 = bytes[21] & 0xFF;
      final h2 = bytes[22] & 0xFF;
      final h3 = bytes[23] & 0xFF;
      final width = (w0 << 24) | (w1 << 16) | (w2 << 8) | w3;
      final height = (h0 << 24) | (h1 << 16) | (h2 << 8) | h3;
      return (width: width, height: height);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> exportToTxt(String markdown) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);
    final sb = StringBuffer();

    for (final element in elements) {
      final line = _elementToText(element);
      if (line.isNotEmpty) {
        sb.writeln(line);
      }
    }

    final result = sb.toString();
    final trimmed = result.endsWith('\n')
        ? result.substring(0, result.length - 1)
        : result;
    return Uint8List.fromList(utf8.encode(trimmed));
  }

  static String _elementToText(DocumentElement element) {
    if (element is HeadingElement) {
      return '${'#' * element.level} ${element.text}';
    } else if (element is ParagraphElement) {
      return element.children.map((c) {
        if (c is FormulaElement) return ' [${c.latex}] ';
        if (c is TextElement) return c.text;
        return '';
      }).join('');
    } else if (element is ListElement) {
      final text = _inlineToText(element.children);
      return '${'  ' * element.indent}${element.ordered ? '${element.indent + 1}. ' : '- '}$text';
    } else if (element is CodeElement) {
      return '```${element.language ?? ''}\n${element.code}\n```';
    } else if (element is BlockquoteElement) {
      return '> ${element.text}';
    } else if (element is MermaidElement) {
      return '```mermaid\n${element.code}\n```';
    } else if (element is TableElement) {
      final lines = <String>[];
      lines.add('| ${element.headers.join(' | ')} |');
      lines.add('| ${element.headers.map((_) => '---').join(' | ')} |');
      for (final row in element.rows) {
        lines.add('| ${row.join(' | ')} |');
      }
      return lines.join('\n');
    }
    return '';
  }
}

/// PDF 公式渲染计划：SVG 矢量 / PNG 位图 / 回退文本三选一。
/// SVG 优先（满足"矢量导出"硬约束），失败回退 PNG，最终回退文本。
sealed class _FormulaRenderPlan {
  const _FormulaRenderPlan();

  /// SVG 矢量路径：直接在 PDF 中嵌入 SVG，缩放不失真。
  factory _FormulaRenderPlan.svg(String svg, String latex, bool displayMode) =
      _SvgPlan;

  /// PNG 位图路径：嵌入高分辨率位图。
  factory _FormulaRenderPlan.png(Uint8List bytes, String latex) =
      _PngPlan;

  /// 回退路径：显示原始 LaTeX 文本。
  factory _FormulaRenderPlan.fallback(String latex) = _FallbackPlan;

  /// 转换为 PDF widget。
  pw.Widget toPdfWidget({required double fontSize});
}

class _SvgPlan extends _FormulaRenderPlan {
  final String svg;
  final String latex;
  final bool displayMode;

  const _SvgPlan(this.svg, this.latex, this.displayMode);

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
      return _FallbackPlan._(latex).toPdfWidget(fontSize: fontSize);
    }
  }
}

class _PngPlan extends _FormulaRenderPlan {
  final Uint8List bytes;
  final String latex;

  const _PngPlan(this.bytes, this.latex);

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
      return _FallbackPlan._(latex).toPdfWidget(fontSize: fontSize);
    }
  }
}

class _FallbackPlan extends _FormulaRenderPlan {
  final String latex;

  const _FallbackPlan._(this.latex);

  factory _FallbackPlan(String latex) => _FallbackPlan._(latex);

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

/// Word 公式图片信息：关联 ID + 实际尺寸（EMU 单位）。
/// EMU = English Metric Units，1 inch = 914400 EMU，1 pixel ≈ 9525 EMU (96dpi)
class _FormulaImageInfo {
  final String relId;
  final int widthEmu;
  final int heightEmu;

  const _FormulaImageInfo({
    required this.relId,
    required this.widthEmu,
    required this.heightEmu,
  });
}

/// Word Mermaid 图片信息：关联 ID + SVG 数据。
class _MermaidImageInfo {
  final String relId;
  final String? svg;

  const _MermaidImageInfo({
    required this.relId,
    required this.svg,
  });
}
