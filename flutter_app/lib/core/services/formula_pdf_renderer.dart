import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/parser/formula_extractor.dart';
import '../../data/models/document.dart';

class FormulaPdfRenderer {
  static final _cache = <String, Uint8List>{};
  static const int _maxCacheSize = 256;

  static Future<Uint8List?> renderLatexToImage(
    String latex, {
    double fontSize = 14,
    bool displayMode = false,
  }) async {
    final normalized = FormulaExtractor.normalizeLatex(latex);
    final cacheKey = '${normalized}_${fontSize}_$displayMode';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final completer = Completer<Uint8List?>();
      final boundaryKey = GlobalKey();

      final mathWidget = MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Math.tex(
                  normalized,
                  textStyle: TextStyle(
                    fontSize: fontSize,
                    color: Colors.black,
                  ),
                  onErrorFallback: (err) => Text(
                    latex,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      bool captured = false;

      void tryCapture(Duration _) {
        if (captured) return;
        final boundary = boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          captured = true;
          _captureBoundary(boundary).then((bytes) {
            if (!completer.isCompleted) {
              completer.complete(bytes);
            }
          }).catchError((_) {
            if (!completer.isCompleted) completer.complete(null);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback(tryCapture);
        }
      }

      WidgetsBinding.instance.addPostFrameCallback(tryCapture);

      runApp(mathWidget);

      final bytes = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (bytes != null) {
        _addToCache(cacheKey, bytes);
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List?> _captureBoundary(RenderRepaintBoundary boundary) async {
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final bytes = byteData?.buffer.asUint8List();
      image.dispose();
      return bytes;
    } catch (e) {
      return null;
    }
  }

  static void _addToCache(String key, Uint8List bytes) {
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[key] = bytes;
  }

  static Future<void> preRender(
    String latex, {
    double fontSize = 14,
    bool displayMode = false,
  }) async {
    await renderLatexToImage(latex, fontSize: fontSize, displayMode: displayMode);
  }

  static Future<void> preRenderAll(
    Iterable<String> latexList, {
    double fontSize = 14,
  }) async {
    final uniqueList = latexList.toSet();
    final futures = <Future<Uint8List?>>[];

    for (final latex in uniqueList) {
      futures.add(renderLatexToImage(
        latex,
        fontSize: fontSize,
        displayMode: false,
      ));
      if (latex.contains(r'\\') ||
          latex.contains('^') ||
          latex.contains('_')) {
        futures.add(renderLatexToImage(
          latex,
          fontSize: fontSize,
          displayMode: true,
        ));
      }
    }
    await Future.wait(futures, eagerError: false);
  }

  static void clearCache() => _cache.clear();

  static int get cacheSize => _cache.length;

  static int get estimatedMemoryUsage {
    return _cache.values.fold(0, (sum, bytes) => sum + bytes.length);
  }

  static pw.Widget build(
    String latex, {
    double fontSize = 14,
    bool displayMode = false,
  }) {
    final normalized = FormulaExtractor.normalizeLatex(latex);
    final cacheKey = '${normalized}_${fontSize}_$displayMode';

    final bytes = _cache[cacheKey];

    if (bytes != null) {
      final image = pw.MemoryImage(bytes);
      final aspectRatio = displayMode ? 3.5 : 2.0;
      final width = displayMode ? fontSize * aspectRatio * 1.2 : null;
      final height = fontSize * 1.6;

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        alignment: displayMode ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Image(
          image,
          width: width,
          height: height,
          fit: displayMode ? pw.BoxFit.scaleDown : pw.BoxFit.contain,
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Text(
        normalized,
        style: pw.TextStyle(
          fontSize: fontSize - 1,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.blue800,
        ),
      ),
    );
  }
}

class PdfParagraphBuilder {
  static Future<pw.Widget> buildAsync(
    List<InlineElement> children, {
    double fontSize = 13,
  }) async {
    final formulaElements = children.whereType<FormulaElement>().toList();
    if (formulaElements.isNotEmpty) {
      final latexList = formulaElements.map((e) => e.latex).toList();
      await FormulaPdfRenderer.preRenderAll(latexList, fontSize: fontSize + 2);
    }

    return build(children, fontSize: fontSize);
  }

  static pw.Widget build(
    List<InlineElement> children, {
    double fontSize = 13,
  }) {
    final formulas = <_FormulaPart>[];
    final buffer = StringBuffer();

    for (final child in children) {
      if (child is TextElement) {
        buffer.write(child.text);
      } else if (child is FormulaElement) {
        if (buffer.isNotEmpty) {
          formulas.add(_FormulaPart.text(buffer.toString()));
          buffer.clear();
        }
        formulas.add(_FormulaPart.formula(child.latex, child.displayMode));
      }
    }
    if (buffer.isNotEmpty) {
      formulas.add(_FormulaPart.text(buffer.toString()));
    }

    final spans = <pw.InlineSpan>[];
    for (final part in formulas) {
      if (part.isText) {
        spans.add(pw.TextSpan(
          text: part.text,
          style: pw.TextStyle(fontSize: fontSize, lineSpacing: 1.5),
        ));
      } else {
        spans.add(pw.WidgetSpan(
          child: FormulaPdfRenderer.build(
            part.latex!,
            fontSize: fontSize + 1,
            displayMode: part.displayMode!,
          ),
        ));
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.RichText(
        text: pw.TextSpan(children: spans),
      ),
    );
  }
}

class _FormulaPart {
  final String? text;
  final String? latex;
  final bool? displayMode;
  final bool isText;

  _FormulaPart.text(this.text)
      : latex = null,
        displayMode = null,
        isText = true;

  _FormulaPart.formula(this.latex, this.displayMode)
      : text = null,
        isText = false;
}
