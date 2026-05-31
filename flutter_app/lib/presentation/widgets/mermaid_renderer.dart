import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  static final _webviewCache = <String, GlobalKey<_MermaidViewState>>{};
  final GlobalKey<_MermaidViewState> _key = GlobalKey();

  String get _cacheKey => '${widget.code.hashCode}_${widget.isDark}';

  @override
  void initState() {
    super.initState();
    _webviewCache[_cacheKey] = _key;
  }

  @override
  void didUpdateWidget(MermaidRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.isDark != widget.isDark) {
      _webviewCache[_cacheKey] = _key;
      _key.currentState?._refresh(widget.code, widget.isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isDark ? AppColors.darkTableBorder : AppColors.tableBorder,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: _MermaidView(key: _key, code: widget.code, isDark: widget.isDark),
    );
  }
}

class _MermaidView extends StatefulWidget {
  final String code;
  final bool isDark;

  const _MermaidView({
    required super.key,
    required this.code,
    required this.isDark,
  });

  @override
  State<_MermaidView> createState() => _MermaidViewState();
}

class _MermaidViewState extends State<_MermaidView> {
  String? _cachedSvg;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(_MermaidView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.isDark != widget.isDark) {
      _render();
    }
  }

  void _refresh(String code, bool isDark) {
    setState(() {
      _cachedSvg = null;
      _loading = true;
      _error = null;
    });
  }

  Future<void> _render() async {
    final html = _buildHtml(widget.code, widget.isDark);

    await InAppWebViewWidget().evaluateJavascript(
      source: '''
        (function() {
          var container = document.createElement('div');
          container.innerHTML = `$html`;
          return container.innerHTML;
        })()
      ''',
    );

    setState(() => _loading = false);
  }

  String _buildHtml(String code, bool isDark) {
    const theme = 'default';
    final escaped = const HtmlEscape().convert(code);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { margin: 0; padding: 8px; background: transparent; }
    svg { max-width: 100%; }
  </style>
</head>
<body>
  <div id="output"></div>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <script>
    mermaid.initialize({ theme: '$theme', startOnLoad: false });
    mermaid.render('mermaid-svg', decodeURIComponent('$escaped'))
      .then(({ svg }) => {
        document.getElementById('output').innerHTML = svg;
      })
      .catch(e => {
        document.getElementById('output').innerHTML =
          '<pre style="color:red;font-size:12px;">Mermaid: ' + e.message + '</pre>';
      });
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: _buildHtml(widget.code, widget.isDark)),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          isInspectable: false,
          javaScriptEnabled: true,
        ),
      ),
    );
  }
}