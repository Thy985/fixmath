import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MermaidRenderer {
  static String? _cachedWebViewContent;
  static InAppWebViewController? _controller;
  static Completer<Uint8List?>? _activeRender;

  static Future<Uint8List?> renderMermaidToImage(
    String mermaidCode, {
    double width = 600,
    double height = 400,
  }) async {
    if (mermaidCode.trim().isEmpty) return null;

    try {
      final boundaryKey = GlobalKey();
      final completer = Completer<Uint8List?>();

      final htmlContent = _buildMermaidHtml(mermaidCode);

      final app = MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: width,
                height: height,
                color: Colors.white,
                child: InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: htmlContent,
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                  ),
                  initialOptions: InAppWebViewGroupOptions(
                    crossPlatform: InAppWebViewOptions(
                      javaScriptEnabled: true,
                      transparentBackground: true,
                    ),
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onLoadStop: (controller, url) async {
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (!completer.isCompleted) {
                      try {
                        final boundary = boundaryKey.currentContext
                            ?.findRenderObject() as RenderRepaintBoundary?;
                        if (boundary != null) {
                          final image = await boundary.toImage(
                            pixelRatio: 2.0,
                          );
                          final byteData = await image.toByteData(
                            format: ui.ImageByteFormat.png,
                          );
                          final bytes = byteData?.buffer.asUint8List();
                          image.dispose();
                          completer.complete(bytes);
                        } else {
                          completer.complete(null);
                        }
                      } catch (e) {
                        completer.complete(null);
                      }
                    }
                  },
                  onLoadError: (controller, url, code, message) {
                    if (!completer.isCompleted) completer.complete(null);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      runApp(app);

      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  static String _buildMermaidHtml(String mermaidCode) {
    final escapedCode = _escapeHtml(mermaidCode);
    return '''<!DOCTYPE html>
<html>
<head>
<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
<style>
body { margin: 0; padding: 16px; background: white; font-family: sans-serif; }
.mermaid { display: flex; justify-content: center; }
</style>
</head>
<body>
<div class="mermaid">
$escapedCode
</div>
<script>
mermaid.initialize({ 
  startOnLoad: true,
  theme: 'default',
  flowchart: { useMaxWidth: true }
});
</script>
</body>
</html>''';
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static Future<Uint8List?> renderMermaidToSvg(String mermaidCode) async {
    if (mermaidCode.trim().isEmpty) return null;
    return null;
  }

  static pw.Widget buildFallback(String mermaidCode) {
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
          pw.Text(
            '[Mermaid 图表 - PDF不支持实时渲染]',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            mermaidCode,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
