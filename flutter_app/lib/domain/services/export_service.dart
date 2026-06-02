import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/parser/markdown_parser.dart';
import '../../core/services/formula_pdf_renderer.dart';
import '../../core/services/mermaid_service.dart';
import '../../data/models/document.dart';

class ExportException implements Exception {
  final String message;
  ExportException(this.message);
  
  @override
  String toString() => message;
}

class ExportService {
  static const _maxConcurrentPreRenders = 4;

  static Future<Uint8List> exportToPdf(
    String markdown, {
    String? title,
    String? author,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);

    final allFormulas = <String>{};
    for (final e in elements) {
      if (e is ParagraphElement) {
        for (final c in e.children) {
          if (c is FormulaElement) {
            allFormulas.add(c.latex);
          }
        }
      }
    }

    if (allFormulas.isNotEmpty) {
      debugPrint('Pre-rendering ${allFormulas.length} unique formulas...');
      await FormulaPdfRenderer.preRenderAll(allFormulas, fontSize: 16);
    }

    final pdf = pw.Document(
      title: title ?? 'FormulaFix 文档',
      author: author ?? 'FormulaFix',
      creator: 'FormulaFix',
      subject: 'Markdown with LaTeX formulas',
    );

    final List<pw.Widget> body = [];
    int headingIndex = 0;

    for (final element in elements) {
      final widget = await _elementToPdfWidgetAsync(element);
      if (widget != null) {
        body.add(widget);
        if (element is HeadingElement) {
          headingIndex++;
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 60, 40, 60),
        header: (ctx) => _buildHeader(title ?? 'FormulaFix', ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) => body,
      ),
    );

    FormulaPdfRenderer.clearCache();
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
            '生成于 ${DateTime.now().toString().substring(0, 10)}',
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

  static Future<pw.Widget?> _elementToPdfWidgetAsync(DocumentElement element) async {
    if (element is HeadingElement) {
      return _pdfHeading(element.level, element.text);
    } else if (element is ParagraphElement) {
      return await PdfParagraphBuilder.buildAsync(
        element.children,
        fontSize: 13,
      );
    } else if (element is ListElement) {
      return _pdfList(element.text, element.indent, element.ordered);
    } else if (element is CodeElement) {
      return _pdfCode(element.code, element.language);
    } else if (element is BlockquoteElement) {
      return _pdfBlockquote(element.text);
    } else if (element is MermaidElement) {
      return await _pdfMermaid(element.code);
    } else if (element is TableElement) {
      return _pdfTable(element.headers, element.rows);
    } else if (element is EmptyLineElement) {
      return pw.SizedBox(height: 6);
    }
    return null;
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

  static pw.Widget _pdfList(String text, int indent, bool ordered) {
    final prefix = ordered ? '${indent + 1}. ' : '• ';
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        left: indent * 16.0 + 4,
        top: 2,
        bottom: 2,
      ),
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
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 13, lineSpacing: 1.4),
            ),
          ),
        ],
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
      svg = null;
    }

    if (svg != null && svg.isNotEmpty) {
      try {
        final svgString = svg;
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
              await _buildSvgInPdf(svgString),
            ],
          ),
        );
      } catch (e) {
        debugPrint('SVG to PDF conversion failed: $e');
      }
    }

    return _buildMermaidFallback(code);
  }

  static Future<pw.Widget> _buildSvgInPdf(String svg) async {
    try {
      final wrappedSvg = svg.contains('xmlns')
          ? svg
          : svg.replaceFirst('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');

      return pw.SvgImage(svg: wrappedSvg, width: 480);
    } catch (e) {
      final base64Data = base64Encode(svg.codeUnits);
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

  static pw.Widget _pdfTable(List<String> headers, List<List<String>> rows) {
    if (headers.isEmpty) return pw.SizedBox();

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: headers
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                ))
            .toList(),
      ),
      for (int i = 0; i < rows.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : PdfColors.grey50,
          ),
          children: rows[i]
              .map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      cell,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ))
              .toList(),
        ),
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: tableRows,
      ),
    );
  }

  static Future<Uint8List> exportToWord(
    String markdown, {
    String? title,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);
    final archive = Archive();

    archive.addFile(ArchiveFile(
        '[Content_Types].xml', _contentTypesXml.length, _contentTypesXml));
    archive.addFile(
        ArchiveFile('_rels/.rels', _relsXml.length, _relsXml));
    archive.addFile(ArchiveFile('word/document.xml',
        _buildDocXml(elements, title).length, _buildDocXml(elements, title)));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels',
        _docRelsXml.length, _docRelsXml));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _buildDocXml(List<DocumentElement> elements, String? title) {
    final buffer = StringBuffer();

    final docTitle = title ?? 'FormulaFix 文档';
    buffer.write(_wordHeading(0, docTitle));

    for (final element in elements) {
      buffer.write(_elementToWordXml(element));
      buffer.write('\n');
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>$buffer</w:body>
</w:document>''';
  }

  static String _elementToWordXml(DocumentElement element) {
    if (element is HeadingElement) {
      return _wordHeading(element.level, element.text);
    } else if (element is ParagraphElement) {
      return _wordParagraph(element.children);
    } else if (element is ListElement) {
      return _wordList(element.text, element.indent, element.ordered);
    } else if (element is CodeElement) {
      return _wordCode(element.code, element.language);
    } else if (element is BlockquoteElement) {
      return _wordBlockquote(element.text);
    } else if (element is MermaidElement) {
      return _wordMermaid(element.code);
    } else if (element is TableElement) {
      return _wordTable(element.headers, element.rows);
    } else if (element is EmptyLineElement) {
      return '<w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>';
    }
    return '';
  }

  static String _wordHeading(int level, String text) {
    final escaped = _esc(text);
    final sz = switch (level) {
      0 => 44,
      1 => 36,
      2 => 32,
      3 => 28,
      _ => 24,
    };
    final alignment = level == 0 ? '<w:jc w:val="center"/>' : '';
    return '''<w:p><w:pPr><w:pStyle w:val="Heading$level"/>$alignment</w:pPr><w:r><w:rPr><w:b/><w:sz w:val="$sz"/></w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
  }

  static String _wordParagraph(List<InlineElement> children) {
    final runs = children.map((c) {
      if (c is FormulaElement) {
        return '''<w:r><w:rPr><w:i/><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve"> ${_esc(c.latex)} </w:t></w:r>''';
      } else if (c is TextElement) {
        return '''<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(c.text)}</w:t></w:r>''';
      }
      return '';
    }).join('\n');
    return '<w:p>$runs</w:p>';
  }

  static String _wordList(String text, int indent, bool ordered) {
    final prefix = ordered ? '${indent + 1}. ' : '• ';
    final leftIndent = 360 + (indent * 360);
    return '''<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:ind w:left="$leftIndent"/></w:pPr><w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">$prefix${_esc(text)}</w:t></w:r></w:p>''';
  }

  static String _wordCode(String code, String? language) {
    final langTag = (language != null && language.isNotEmpty)
        ? '''<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/><w:highlight w:val="blue"/></w:rPr><w:t xml:space="preserve"> $language </w:t></w:r><w:r><w:br/></w:r>'''
        : '';
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:ind w:left="360"/></w:pPr>$langTag<w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  static String _wordBlockquote(String text) {
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:left w:val="single" w:sz="12" w:space="8" w:color="4472C4"/></w:bdr><w:ind w:left="360"/></w:pPr><w:r><w:rPr><w:i/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>''';
  }

  static String _wordMermaid(String code) {
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/></w:bdr></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">[Mermaid 图表]</w:t></w:r><w:r><w:br/></w:r><w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="18"/><w:color w:val="888888"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
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
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static const String _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const String _relsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  static const String _docRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '</Relationships>';

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
      return '${'  ' * element.indent}${element.ordered ? '${element.indent + 1}. ' : '- '}${element.text}';
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
