import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ExportFormat { pdf, docx, txt }

class ExportService {
  static const _shareTimeout = Duration(seconds: 60);
  static const _exportTimeout = Duration(seconds: 120);

  static Future<void> exportAndShare({
    required String markdown,
    required ExportFormat format,
    required Future<Uint8List> Function(String) exporter,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final Uint8List bytes;
    try {
      bytes = await exporter(markdown).timeout(_exportTimeout);
    } on TimeoutException {
      throw ExportException('Export timeout - please try again');
    } catch (e) {
      throw ExportException('Export failed: $e');
    }

    final tempDir = await getTemporaryDirectory();
    final extension = format.name;
    final filename = 'formulafix_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File('${tempDir.path}/$filename');

    try {
      await file.writeAsBytes(bytes);

      // 等待分享完成或超时
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'FormulaFix $extension',
        ).timeout(_shareTimeout);
      } on TimeoutException {
        debugPrint('Share timeout, file saved at: ${file.path}');
      }
    } finally {
      // 分享完成后（或超时后）再删除临时文件
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}
