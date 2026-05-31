import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/parser/markdown_parser.dart';
import '../../core/parser/formula_extractor.dart';
import '../../data/models/document.dart';

class ExportService {
  static Future<Uint8List> exportToPdf(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final pdf = pw.Document();
    final List<pw.Widget> body = [];

    for (final element in elements) {
      final widget = switch (element) {
        HeadingElement(:final level, :final text) => _pdfHeading(level, text),
        ParagraphElement(:final children) => _pdfParagraph(children),
        ListElement(:final text) => _pdfList(text),
        CodeElement(:final code) => _pdfCode(code),
        BlockquoteElement(:final text) => _pdfBlockquote(text),
        MermaidElement(:final code) => _pdfMermaid(code),
        EmptyLineElement() => pw.SizedBox(height: 12),
        _ => pw.SizedBox.shrink(),
      };
      if (widget != null) body.add(widget);
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => body,
    ));

    return pdf.save();
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
      child: pw.Text(text, style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _pdfParagraph(List<InlineElement> children) {
    final spans = children.map((c) {
      return switch (c) {
        FormulaElement(:final latex) => pw.TextSpan(
            text: ' ${FormulaExtractor.normalizeLatex(latex)} ',
            style: const pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 13)),
        TextElement(:final text) => pw.TextSpan(text: text, style: const pw.TextStyle(fontSize: 13)),
      };
    }).toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.RichText(text: pw.TextSpan(children: spans)),
    );
  }

  static pw.Widget _pdfList(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [pw.Text('  •  '), pw.Expanded(child: pw.Text(text))],
      ),
    );
  }

  static pw.Widget _pdfCode(String code) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(code, style: pw.TextStyle(fontFamily: 'Courier', fontSize: 11)),
    );
  }

  static pw.Widget _pdfBlockquote(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColors.blue, width: 4)),
        color: PdfColors.grey100,
      ),
      child: pw.Text(text, style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
    );
  }

  static pw.Widget _pdfMermaid(String code) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('[Mermaid 图表]', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(code, style: pw.TextStyle(fontFamily: 'Courier', fontSize: 10)),
        ],
      ),
    );
  }

  static Future<Uint8List> exportToWord(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final archive = Archive();

    archive.addFile(ArchiveFile('[Content_Types].xml',
        _contentTypesXml.length, _contentTypesXml));
    archive.addFile(ArchiveFile('_rels/.rels', _relsXml.length, _relsXml));
    archive.addFile(ArchiveFile('word/document.xml',
        _buildDocXml(elements).length, _buildDocXml(elements)));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels',
        _docRelsXml.length, _docRelsXml));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _buildDocXml(List<DocumentElement> elements) {
    final body = elements.map((e) => switch (e) {
      HeadingElement(:final level, :final text) => _wordHeading(level, text),
      ParagraphElement(:final children) => _wordParagraph(children),
      ListElement(:final text) => _wordList(text),
      CodeElement(:final code) => _wordCode(code),
      BlockquoteElement(:final text) => _wordBlockquote(text),
      MermaidElement(:final code) => _wordMermaid(code),
      EmptyLineElement() => '<w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>',
      _ => '',
    }).join('\n');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>$body</w:body>
</w:document>''';
  }

  static String _wordHeading(int level, String text) {
    final escaped = _esc(text);
    final sz = switch (level) { 1 => 36, 2 => 32, 3 => 28, _ => 24 };
    return '''<w:p><w:pPr><w:pStyle w:val="Heading$level"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="$sz"/></w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>''';
  }

  static String _wordParagraph(List<InlineElement> children) {
    final runs = children.map((c) => switch (c) {
      FormulaElement(:final latex) => '''<w:r><w:rPr><w:i/><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve"> ${FormulaExtractor.normalizeLatex(latex)} </w:t></w:r>''',
      TextElement(:final text) => '''<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r>''',
    }).join('\n');
    return '<w:p>$runs</w:p>';
  }

  static String _wordList(String text) =>
      '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/></w:pPr><w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">• ${_esc(text)}</w:t></w:r></w:p>';

  static String _wordCode(String code) {
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:ind w:left="360"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  static String _wordBlockquote(String text) {
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:left w:val="single" w:sz="12" w:space="8" w:color="4472C4"/></w:bdr><w:ind w:left="360"/></w:pPr><w:r><w:rPr><w:i/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>''';
  }

  static String _wordMermaid(String code) {
    return '''<w:p><w:pPr><w:shd w:fill="F0F0F0" w:val="clear"/><w:bdr><w:top w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/><w:bottom w:val="single" w:sz="4" w:space="4" w:color="CCCCCC"/></w:bdr></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">[Mermaid 图表]</w:t></w:r><w:r><w:br/></w:r><w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="18"/><w:color w:val="888888"/></w:rPr><w:t xml:space="preserve">${_esc(code)}</w:t></w:r></w:p>''';
  }

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
       .replaceAll('"', '&quot;').replaceAll("'", '&apos;');

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
      final line = switch (element) {
        HeadingElement(:final level, :final text) => '${'#' * level} $text',
        ParagraphElement(:final children) => children.map((c) => switch (c) {
          FormulaElement(:final latex) => latex,
          TextElement(:final text) => text,
        }).join(''),
        ListElement(:final text) => '• $text',
        CodeElement(:final code) => '```\n$code\n```',
        BlockquoteElement(:final text) => '> $text',
        MermaidElement(:final code) => '```mermaid\n$code\n```',
        EmptyLineElement() => '',
        _ => '',
      };
      sb.writeln(line);
    }
    return Uint8List.fromList(sb.toString().codeUnits);
  }
}
