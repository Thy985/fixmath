import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/constants/app_constants.dart';

class MermaidRenderer extends StatefulWidget {
  final String code;
  final bool isDark;

  const MermaidRenderer({
    super.key,
    required this.code,
    required this.isDark,
  });

  @override
  State<MermaidRenderer> createState() => _MermaidRendererState();
}

class _MermaidRendererState extends State<MermaidRenderer> {
  bool _loading = true;
  String? _error;
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(MermaidRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.isDark != widget.isDark) {
      _buildHtml();
    }
  }

  Future<void> _loadAsset() async {
    try {
      final js = await rootBundle.loadString('assets/js/mermaid.min.js');
      _htmlContent = js;
      _buildHtml();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '无法加载 Mermaid 引擎: $e';
      });
    }
  }

  void _buildHtml() {
    if (_htmlContent == null) return;

    final escaped = const HtmlEscape().convert(widget.code);
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { padding: 8px; background: transparent; }
    svg { max-width: 100%; height: auto; }
    .error { color: #dc3545; font-size: 12px; padding: 8px; font-family: monospace; }
  </style>
</head>
<body>
  <div id="output"></div>
  <script>$_htmlContent</script>
  <script>
    try {
      mermaid.initialize({
        theme: '${widget.isDark ? 'dark' : 'default'}',
        startOnLoad: false,
        securityLevel: 'loose',
      });
      mermaid.render('mermaid-svg', decodeURIComponent('$escaped'))
        .then(function(result) {
          document.getElementById('output').innerHTML = result.svg;
        })
        .catch(function(e) {
          document.getElementById('output').innerHTML =
            '<div class="error">Mermaid: ' + e.message + '</div>';
        });
    } catch(e) {
      document.getElementById('output').innerHTML =
        '<div class="error">Mermaid 初始化失败: ' + e.message + '</div>';
    }
  </script>
</body>
</html>
''';

    setState(() {
      _loading = false;
      _htmlContent = html;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 80,
        margin: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isDark ? AppColors.darkTableBorder : AppColors.tableBorder,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(data: _htmlContent!),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            isInspectable: false,
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: true,
          ),
        ),
      ),
    );
  }
}
