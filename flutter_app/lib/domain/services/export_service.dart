import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/parser/markdown_parser.dart';
import '../../data/models/document.dart';

class ExportService {
  static Future<Uint8List> exportToPdf(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final pdf = pw.Document();
    final List<pw.Widget> body = [];

    for (final element in elements) {
      final widget = _elementToPdfWidget(element);
      if (widget != null) {
        body.add(widget);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => body,
      ),
    );

    return pdf.save();
  }

  static pw.Widget? _elementToPdfWidget(DocumentElement element) {
    if (element is HeadingElement) {
      return _pdfHeading(element.level, element.text);
    } else if (element is ParagraphElement) {
      return _pdfParagraph(element.children);
    } else if (element is ListElement) {
      return _pdfList(element.text, element.indent, element.ordered);
    } else if (element is CodeElement) {
      return _pdfCode(element.code, element.language);
    } else if (element is BlockquoteElement) {
      return _pdfBlockquote(element.text);
    } else if (element is MermaidElement) {
      return _pdfMermaid(element.code);
    } else if (element is TableElement) {
      return _pdfTable(element.headers, element.rows);
    } else if (element is EmptyLineElement) {
      return pw.SizedBox(height: 12);
    }
    return null;
  }

  static pw.Widget _pdfHeading(int level, String text) {
    final size = switch (level) {
      1 => 24.0,
      2 => 20.0,
      3 => 16.0,
      _ => 14.0,
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _pdfParagraph(List<InlineElement> children) {
    final spans = children.map((c) {
      if (c is FormulaElement) {
        return pw.TextSpan(
          text: ' ${c.latex} ',
          style: pw.TextStyle(
            fontStyle: pw.FontStyle.italic,
            fontSize: 13,
          ),
        );
      } else if (c is TextElement) {
        return pw.TextSpan(
          text: c.text,
          style: const pw.TextStyle(fontSize: 13),
        );
      }
      return pw.TextSpan(text: '');
    }).toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.RichText(text: pw.TextSpan(children: spans)),
    );
  }

  static pw.Widget _pdfList(String text, int indent, bool ordered) {
    final prefix = ordered ? '${indent + 1}. ' : '• ';
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 16.0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(prefix),
          pw.Expanded(child: pw.Text(text)),
        ],
      ),
    );
  }

  static pw.Widget _pdfCode(String code, String? language) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (language != null && language.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                language,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blue700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.Text(code, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _pdfBlockquote(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue, width: 4),
        ),
        color: PdfColors.grey100,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  static pw.Widget _pdfMermaid(String code) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '[Mermaid 图表]',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(code, style: const pw.TextStyle(fontSize: 10)),
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
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ))
            .toList(),
      ),
      ...rows.map((row) => pw.TableRow(
            children: row
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(cell),
                    ))
                .toList(),
          )),
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: tableRows,
      ),
    );
  }

  static Future<Uint8List> exportToWord(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final archive = Archive();

    archive.addFile(ArchiveFile(
        '[Content_Types].xml', _contentTypesXml.length, _contentTypesXml));
    archive.addFile(
        ArchiveFile('_rels/.rels', _relsXml.length, _relsXml));
    archive.addFile(ArchiveFile('word/document.xml',
        _buildDocXml(elements).length, _buildDocXml(elements)));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels',
        _docRelsXml.length, _docRelsXml));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _buildDocXml(List<DocumentElement> elements) {
    final buffer = StringBuffer();
    
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
      1 => 36,
      2 => 32,
      3 => 28,
      _ => 24,
    };
    return '''<w:p><w:pPr><w:pStyle w:val="Heading$level"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="$sz"/></w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
  }

  static String _wordParagraph(List<InlineElement> children) {
    final runs = children.map((c) {
      if (c is FormulaElement) {
        return '''<w:r><w:rPr><w:i/><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve"> ${c.latex} </w:t></w:r>''';
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
        ? '<w:r><w:rPr><w:b/><w:sz w:val="18"/></w:rPr><w:t xml:space="preserve">$language</w:t></w:r><w:r><w:br/></w:r>'
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
        .map((h) => '''<w:tc><w:tcPr><w:tcBorders><w:top w:val="single" w:sz="4" w:color="CCCCCC"/><w:left w:val="single" w:sz="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:color="CCCCCC"/><w:right w:val="single" w:sz="4" w:color="CCCCCC"/></w:tcBorders><w:shd w:val="clear" w:fill="E0E0E0"/></w:tcPr><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${_esc(h)}</w:t></w:r></w:p></w:tc>''')
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
        if (c is FormulaElement) return c.latex;
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
