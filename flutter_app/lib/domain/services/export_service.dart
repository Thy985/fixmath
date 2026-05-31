import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/parser/markdown_parser.dart';
import '../../core/parser/formula_extractor.dart';
import '../../data/models/document.dart';

class ExportService {
  static Future<Uint8List> exportToPdf(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final pdf = pw.Document();

    final pageChildren = <pw.Widget>[];

    for (final element in elements) {
      if (element.type == ElementType.heading) {
        pw.TextStyle style;
        switch (element.level) {
          case 1:
            style = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
            break;
          case 2:
            style = pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold);
            break;
          case 3:
            style = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
            break;
          default:
            style = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
        }
        pageChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
            child: pw.Text(element.content, style: style),
          ),
        );
      } else if (element.type == ElementType.paragraph) {
        final children = element.children ?? [];
        final List<pw.InlineSpan> spans = [];

        for (final child in children) {
          if (child.type == ElementType.formula) {
            final normalizedLatex = FormulaExtractor.normalizeLatex(child.content);
            spans.add(pw.TextSpan(
              text: ' $normalizedLatex ',
              style: const pw.TextStyle(
                fontStyle: pw.FontStyle.italic,
                fontSize: 13,
              ),
            ));
          } else {
            spans.add(pw.TextSpan(
              text: child.content,
              style: const pw.TextStyle(fontSize: 13),
            ));
          }
        }

        if (spans.isNotEmpty) {
          pageChildren.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.RichText(text: pw.TextSpan(children: spans)),
            ),
          );
        }
      } else if (element.type == ElementType.list) {
        pageChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('  •  '),
                pw.Expanded(child: pw.Text(element.content)),
              ],
            ),
          ),
        );
      } else if (element.type == ElementType.code) {
        pageChildren.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              element.content,
              style: pw.TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
              ),
            ),
          ),
        );
      } else if (element.type == ElementType.blockquote) {
        pageChildren.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.blue, width: 4)),
              color: PdfColors.grey100,
            ),
            child: pw.Text(
              element.content,
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ),
        );
      } else if (element.type == ElementType.mermaid) {
        pageChildren.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('[Mermaid 图表]', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text(element.content, style: pw.TextStyle(fontFamily: 'Courier', fontSize: 10)),
              ],
            ),
          ),
        );
      } else if (element.type == 'empty_line') {
        pageChildren.add(pw.SizedBox(height: 12));
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pageChildren,
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> exportToWord(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final archive = Archive();

    final documentXml = _buildDocumentXml(elements);
    final contentTypesXml = _buildContentTypesXml();
    final relsXml = _buildRelsXml();

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, contentTypesXml));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, relsXml));
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, documentXml));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', _buildDocRelsXml().length, _buildDocRelsXml()));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  static String _buildDocumentXml(List<DocumentElement> elements) {
    final bodyXml = StringBuffer();

    for (final element in elements) {
      if (element.type == ElementType.heading) {
        bodyXml.writeln(_buildHeadingXml(element));
      } else if (element.type == ElementType.paragraph) {
        bodyXml.writeln(_buildParagraphXml(element));
      } else if (element.type == ElementType.list) {
        bodyXml.writeln(_buildListXml(element));
      } else if (element.type == ElementType.code) {
        bodyXml.writeln(_buildCodeXml(element));
      } else if (element.type == ElementType.blockquote) {
        bodyXml.writeln(_buildBlockquoteXml(element));
      } else if (element.type == ElementType.mermaid) {
        bodyXml.writeln(_buildMermaidXml(element));
      } else if (element.type == 'empty_line') {
        bodyXml.writeln('<w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>');
      }
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
  xmlns:o="urn:schemas-microsoft-com:office:office"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:w10="urn:schemas-microsoft-com:office:word"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml">
  <w:body>
${bodyXml.toString()}
  </w:body>
</w:document>''';
  }

  static String _buildHeadingXml(DocumentElement element) {
    final escapedContent = _escapeXml(element.content);
    return '''<w:p>
  <w:pPr>
    <w:pStyle w:val="Heading${element.level}"/>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:b/>
      <w:sz w:val="${_headingSize(element.level)}"/>
    </w:rPr>
    <w:t xml:space="preserve">$escapedContent</w:t>
  </w:r>
</w:p>''';
  }

  static String _buildParagraphXml(DocumentElement element) {
    final children = element.children ?? [];
    final runs = StringBuffer();

    for (final child in children) {
      if (child.type == ElementType.formula) {
        final normalizedLatex = FormulaExtractor.normalizeLatex(child.content);
        runs.writeln('''  <w:r>
    <w:rPr>
      <w:i/>
      <w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/>
      <w:sz w:val="24"/>
    </w:rPr>
    <w:t xml:space="preserve"> $normalizedLatex </w:t>
  </w:r>''');
      } else {
        final escaped = _escapeXml(child.content);
        runs.writeln('''  <w:r>
    <w:rPr>
      <w:sz w:val="24"/>
    </w:rPr>
    <w:t xml:space="preserve">$escaped</w:t>
  </w:r>''');
      }
    }

    return '''<w:p>
${runs.toString()}</w:p>''';
  }

  static String _buildListXml(DocumentElement element) {
    final escapedContent = _escapeXml(element.content);
    return '''<w:p>
  <w:pPr>
    <w:pStyle w:val="ListParagraph"/>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:sz w:val="24"/>
    </w:rPr>
    <w:t xml:space="preserve">• $escapedContent</w:t>
  </w:r>
</w:p>''';
  }

  static String _buildCodeXml(DocumentElement element) {
    final escapedContent = _escapeXml(element.content);
    return '''<w:p>
  <w:pPr>
    <w:shd w:fill="F0F0F0" w:val="clear"/>
    <w:spacing w:before="100" w:after="100"/>
    <w:ind w:left="360"/>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>
      <w:sz w:val="20"/>
    </w:rPr>
    <w:t xml:space="preserve">$escapedContent</w:t>
  </w:r>
</w:p>''';
  }

  static String _buildBlockquoteXml(DocumentElement element) {
    final escapedContent = _escapeXml(element.content);
    return '''<w:p>
  <w:pPr>
    <w:shd w:fill="F0F0F0" w:val="clear"/>
    <w:bdr>
      <w:left w:val="single" w:sz="12" w:space="8" w:color="4472C4"/>
    </w:bdr>
    <w:ind w:left="360"/>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:i/>
      <w:sz w:val="24"/>
    </w:rPr>
    <w:t xml:space="preserve">$escapedContent</w:t>
  </w:r>
</w:p>''';
  }

  static String _buildMermaidXml(DocumentElement element) {
    final escapedContent = _escapeXml(element.content);
    return '''<w:p>
  <w:pPr>
    <w:shd w:fill="F0F0F0" w:val="clear"/>
    <w:bdr>
      <w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/>
      <w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/>
    </w:bdr>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:b/>
      <w:sz w:val="20"/>
    </w:rPr>
    <w:t xml:space="preserve">[Mermaid 图表]</w:t>
  </w:r>
  <w:r>
    <w:br/>
  </w:r>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>
      <w:sz w:val="18"/>
      <w:color w:val="888888"/>
    </w:rPr>
    <w:t xml:space="preserve">$escapedContent</w:t>
  </w:r>
</w:p>''';
  }

  static String _buildContentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
  }

  static String _buildRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  static String _buildDocRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
  }

  static int _headingSize(int level) {
    switch (level) {
      case 1: return 36;
      case 2: return 32;
      case 3: return 28;
      default: return 24;
    }
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static Future<Uint8List> exportToTxt(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final StringBuffer sb = StringBuffer();

    for (final element in elements) {
      if (element.type == ElementType.heading) {
        final prefix = '#' * element.level;
        sb.writeln('$prefix ${element.content}');
        sb.writeln();
      } else if (element.type == ElementType.paragraph) {
        final children = element.children ?? [];
        for (final child in children) {
          if (child.type == ElementType.formula) {
            sb.write(child.content);
          } else {
            sb.write(child.content);
          }
        }
        sb.writeln();
        sb.writeln();
      } else if (element.type == ElementType.list) {
        sb.writeln('• ${element.content}');
      } else if (element.type == ElementType.code) {
        sb.writeln('```');
        sb.writeln(element.content);
        sb.writeln('```');
        sb.writeln();
      } else if (element.type == ElementType.blockquote) {
        sb.writeln('> ${element.content}');
        sb.writeln();
      }
    }

    return Uint8List.fromList(sb.toString().codeUnits);
  }

  static Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  static Future<void> shareFile(Uint8List bytes, String filename) async {
    if (filename.endsWith('.pdf')) {
      await sharePdf(bytes, filename);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}