import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ExportFormat { pdf, docx, txt }

class ExportService {
  static Future<void> exportAndShare({
    required String markdown,
    required ExportFormat format,
    required Future<Uint8List> Function(String) exporter,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    try {
      final bytes = await exporter(markdown);
      final tempDir = await getTemporaryDirectory();
      final extension = format.name;
      final filename = 'formulafix_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${tempDir.path}/$filename');
      
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'FormulaFix $extension',
      );
    } catch (e) {
      if (e is ExportException) rethrow;
      throw ExportException('Export failed: $e');
    }
  }
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);
  
  @override
  String toString() => message;
}
