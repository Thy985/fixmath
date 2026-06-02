import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum MermaidTheme { light, dark }

class MermaidSvgCache {
  static final _cache = <String, String>{};

  static String generateKey(String code, MermaidTheme theme) {
    final input = '${theme.name}|$code';
    return md5.convert(utf8.encode(input)).toString();
  }

  static String? get(String key) => _cache[key];

  static void put(String key, String svg) {
    if (_cache.length > 500) {
      final toRemove = _cache.keys.take(100).toList();
      for (final k in toRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = svg;
  }

  static bool contains(String key) => _cache.containsKey(key);

  static void clear() => _cache.clear();

  static int get size => _cache.length;
}

class MermaidService {
  static InAppWebViewController? _controller;
  static Completer<String>? _activeRender;
  static bool _initialized = false;
  static String? _pendingInitError;
  static String _mermaidHtml = '';

  static Future<String> renderToSvg(
    String mermaidCode, {
    MermaidTheme theme = MermaidTheme.light,
  }) async {
    if (mermaidCode.trim().isEmpty) {
      throw MermaidRenderException('Empty Mermaid code');
    }

    final cacheKey = MermaidSvgCache.generateKey(mermaidCode, theme);
    if (MermaidSvgCache.contains(cacheKey)) {
      return MermaidSvgCache.get(cacheKey)!;
    }

    final svg = await _renderViaWebView(mermaidCode, theme);
    MermaidSvgCache.put(cacheKey, svg);
    return svg;
  }

  static Future<String> _renderViaWebView(
    String mermaidCode,
    MermaidTheme theme,
  ) async {
    if (!_initialized) {
      throw MermaidRenderException(
        'MermaidService not initialized. Call MermaidService.init() in main().',
      );
    }

    if (_pendingInitError != null) {
      throw MermaidRenderException(_pendingInitError!);
    }

    final controller = _controller;
    if (controller == null) {
      throw MermaidRenderException('WebView controller not available');
    }

    _activeRender = Completer<String>();

    final escapedCode = _escapeForJs(mermaidCode);
    final themeStr = theme == MermaidTheme.dark ? 'dark' : 'light';

    try {
      await controller.evaluateJavascript(
        source: '''
        window.renderMermaid("$escapedCode", "$themeStr");
        ''',
      );
    } catch (e) {
      throw MermaidRenderException('JavaScript evaluation failed: $e');
    }

    return _activeRender!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw MermaidRenderException('Mermaid render timeout');
      },
    );
  }

  static Future<void> init() async {
    if (_initialized) return;

    try {
      _mermaidHtml = await _buildHtml();
    } catch (e) {
      _pendingInitError = 'Failed to load Mermaid.js: $e';
      _initialized = true;
      return;
    }

    _initialized = true;
  }

  static Future<String> _buildHtml() async {
    final mermaidJs = await rootBundle.loadString('assets/js/mermaid.min.js');
    final escapedJs = mermaidJs
        .replaceAll('</script>', '<\\/script>')
        .replaceAll('<!--', '<\\!--');

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { margin: 0; padding: 8px; background: transparent; font-family: sans-serif; }
#container { display: inline-block; }
</style>
<script>
$escapedJs
</script>
</head>
<body>
<div id="container"></div>
<script>
window.renderMermaid = function(code, theme) {
  try {
    var themeVars;
    if (theme === 'dark') {
      themeVars = {
        primaryColor: '#1f2937',
        primaryTextColor: '#ffffff',
        primaryBorderColor: '#9ca3af',
        lineColor: '#9ca3af',
        secondaryColor: '#374151',
        tertiaryColor: '#4b5563',
        background: '#111827'
      };
      mermaid.initialize({ startOnLoad: false, theme: 'dark', securityLevel: 'loose', themeVariables: themeVars });
    } else {
      themeVars = {
        primaryColor: '#ffffff',
        primaryTextColor: '#000000',
        primaryBorderColor: '#000000',
        lineColor: '#000000',
        secondaryColor: '#f4f4f4',
        tertiaryColor: '#fafafa',
        background: '#ffffff'
      };
      mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose', themeVariables: themeVars });
    }

    var id = 'mermaid_' + Date.now() + '_' + Math.floor(Math.random() * 10000);
    mermaid.render(id, code)
      .then(function(result) {
        console.log('SVG_RESULT:' + result.svg);
      })
      .catch(function(err) {
        console.log('SVG_ERROR:' + (err.message || err.toString()));
      });
  } catch (e) {
    console.log('SVG_ERROR:' + (e.message || e.toString()));
  }
};
</script>
</body>
</html>''';
  }

  static void attachController(InAppWebViewController controller) {
    _controller = controller;
  }

  static void handleConsoleMessage(String message) {
    if (_activeRender == null || _activeRender!.isCompleted) return;

    if (message.startsWith('SVG_RESULT:')) {
      final svg = message.substring('SVG_RESULT:'.length);
      _activeRender!.complete(svg);
    } else if (message.startsWith('SVG_ERROR:')) {
      final err = message.substring('SVG_ERROR:'.length);
      _activeRender!.completeError(MermaidRenderException(err));
    }
  }

  static bool get isReady => _initialized && _controller != null;

  static String get html => _mermaidHtml;

  static String _escapeForJs(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\$', '\\\$');
  }
}

class MermaidRenderException implements Exception {
  final String message;
  MermaidRenderException(this.message);

  @override
  String toString() => 'MermaidRenderException: $message';
}
