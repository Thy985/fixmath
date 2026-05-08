import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../parser/markdown_parser.dart';
import '../parser/formula_extractor.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/widgets.dart' as widgets;

class ExportService {
  static Future<Uint8List> exportToPdf(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final pdf = pw.Document();

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
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text(element.content, style: style),
            ),
          ),
        );
      } else if (element.type == ElementType.paragraph) {
        final children = element.children ?? [];
        final List<pw.Widget> paragraphWidgets = [];

        for (final child in children) {
          if (child.type == ElementType.formula) {
            final normalizedLatex = FormulaExtractor.normalizeLatex(child.content);
            final formulaWidget = Math.tex(
              normalizedLatex,
              textStyle: const widgets.TextStyle(fontSize: 18),
              onErrorFallback: (err) => widgets.Text('[公式: ${child.content}]'),
            );
            paragraphWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Child(child: formulaWidget),
              ),
            );
          } else {
            paragraphWidgets.add(
              pw.Text(child.content),
            );
          }
        }

        if (paragraphWidgets.isNotEmpty) {
          pdf.addPage(
            pw.Page(
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: paragraphWidgets,
              ),
            ),
          );
        }
      } else if (element.type == ElementType.list) {
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• '),
                pw.Expanded(child: pw.Text(element.content)),
              ],
            ),
          ),
        );
      } else if (element.type == ElementType.code) {
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                element.content,
                style: pw.TextStyle(fontFamily: 'Courier'),
              ),
            ),
          ),
        );
      } else if (element.type == ElementType.blockquote) {
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(
                    color: PdfColors.blue,
                    width: 4,
                  ),
                ),
                color: PdfColors.grey100,
              ),
              child: pw.Text(
                element.content,
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ),
        );
      }
    }

    return pdf.save();
  }

  static Future<Uint8List> exportToWord(String markdown) async {
    final elements = MarkdownParser.parse(markdown);
    final StringBuffer sb = StringBuffer();

    sb.writeln('========================================');
    sb.writeln('FormulaFix 文档导出');
    sb.writeln('========================================');
    sb.writeln();

    for (final element in elements) {
      if (element.type == ElementType.heading) {
        final prefix = '#' * element.level;
        sb.writeln('$prefix ${element.content}');
        sb.writeln();
      } else if (element.type == ElementType.paragraph) {
        final children = element.children ?? [];
        for (final child in children) {
          if (child.type == ElementType.formula) {
            sb.write('[公式: ${child.content}]');
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

  static Future<Uint8List> exportToTxt(String markdown) async {
    return exportToWord(markdown);
  }

  static Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  static Future<void> shareFile(Uint8List bytes, String filename) async {
    if (filename.endsWith('.pdf')) {
      await sharePdf(bytes, filename);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}
