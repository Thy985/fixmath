import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MermaidEngine {
  static String _buildHtml(String code) {
    const mermaidJsUrl = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js';
    final escapedCode = const HtmlEscape().convert(code);

    return '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 16px; background: transparent; }
    #output { text-align: center; }
    #error { color: red; font-size: 14px; padding: 8px; display: none; }
  </style>
</head>
<body>
  <div id="output"></div>
  <div id="error"></div>
  <script src="$mermaidJsUrl"></script>
  <script>
    mermaid.initialize({ startOnLoad: false, theme: 'default' });
    (async () => {
      try {
        const { svg } = await mermaid.render('mermaid-svg', decodeURIComponent('$escapedCode'));
        document.getElementById('output').innerHTML = svg;
      } catch (e) {
        document.getElementById('error').style.display = 'block';
        document.getElementById('error').textContent = 'Mermaid: ' + e.message;
      }
    })();
  </script>
</body>
</html>''';
  }

  static Widget buildPreview(String code, {double? height}) {
    return SizedBox(
      height: height ?? 300,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: _buildHtml(code)),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          isInspectable: false,
        ),
      ),
    );
  }
}

class MermaidWidget extends StatefulWidget {
  final String code;
  final double? height;

  const MermaidWidget({super.key, required this.code, this.height});

  @override
  State<MermaidWidget> createState() => _MermaidWidgetState();
}

class _MermaidWidgetState extends State<MermaidWidget> {
  @override
  Widget build(BuildContext context) {
    return MermaidEngine.buildPreview(widget.code, height: widget.height);
  }
}