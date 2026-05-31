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
  static String? _cachedJs;
  static final Map<String, _MermaidInstance> _instanceCache = {};

  String? _svgContent;
  bool _loading = true;
  String? _error;
  InAppWebViewController? _controller;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    _ensureInit();
  }

  Future<void> _ensureInit() async {
    if (_cachedJs == null) {
      try {
        _cachedJs = await rootBundle.loadString('assets/js/mermaid.min.js');
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = '无法加载 Mermaid 引擎';
          });
        }
        return;
      }
    }
    _render();
  }

  @override
  void didUpdateWidget(MermaidRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.isDark != widget.isDark) {
      _render();
    }
  }

  Future<void> _render() async {
    if (_cachedJs == null) return;

    final key = '${widget.code.hashCode}_${widget.isDark}';

    if (!_instanceCache.containsKey(key)) {
      _instanceCache[key] = _MermaidInstance();
    }

    final instance = _instanceCache[key]!;

    if (instance.svgContent != null && !_webViewReady) {
      setState(() {
        _svgContent = instance.svgContent;
        _loading = false;
      });
      return;
    }

    if (_controller != null && instance.svgContent == null) {
      await _injectAndRender(instance);
      return;
    }

    if (_controller != null && instance.svgContent != null) {
      if (_webViewReady) {
        await _updateTheme(instance);
      } else {
        setState(() {
          _svgContent = instance.svgContent;
          _loading = false;
        });
      }
    }
  }

  void _onConsoleMessage(InAppWebViewController controller, ConsoleMessage msg) {
    final data = msg.message;
    final key = '${widget.code.hashCode}_${widget.isDark}';
    final instance = _instanceCache[key];
    if (data.startsWith('SVG:')) {
      instance?.svgContent = data.substring(4);
      if (mounted) {
        setState(() {
          _svgContent = instance?.svgContent;
          _loading = false;
        });
      }
    } else if (data.startsWith('ERROR:')) {
      if (mounted) {
        setState(() {
          _error = data.substring(6);
          _loading = false;
        });
      }
    }
  }

  Future<void> _injectAndRender(_MermaidInstance instance) async {
    final escaped = Uri.encodeComponent(widget.code);
    final script = '''
      if (typeof mermaid !== 'undefined') {
        mermaid.initialize({
          theme: '${widget.isDark ? 'dark' : 'default'}',
          startOnLoad: false,
          securityLevel: 'loose',
        });
        try {
          const { svg } = await mermaid.render('mermaid-${widget.code.hashCode}', '$escaped');
          console.log('SVG:' + svg);
        } catch(e) {
          console.log('ERROR:' + e.message);
        }
      } else {
        console.log('ERROR:mermaid not loaded');
      }
    ''';

    await _controller?.evaluateJavascript(source: '''
      (function() {
        if (!document.getElementById('mermaid-script')) {
          var s = document.createElement('script');
          s.id = 'mermaid-script';
          s.textContent = atob('${base64Encode(utf8.encode(_cachedJs!))}');
          document.head.appendChild(s);
        }
        $script
      })();
    ''');
  }

  Future<void> _updateTheme(_MermaidInstance instance) async {
    if (_controller == null) return;
    await _controller!.evaluateJavascript(source: '''
      if (typeof mermaid !== 'undefined') {
        mermaid.initialize({
          theme: '${widget.isDark ? 'dark' : 'default'}',
          startOnLoad: false,
        });
      }
    ''');
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
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
        margin: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.codeRadius),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('Mermaid: $_error',
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
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
      child: _SvgWebView(
        key: ValueKey('${widget.code.hashCode}_${widget.isDark}'),
        svgContent: _svgContent,
        onControllerCreated: (c) => _controller = c,
        onReady: (ready) { if (mounted) setState(() => _webViewReady = ready); },
        onConsoleMessage: _onConsoleMessage,
      ),
    );
  }
}

class _MermaidInstance {
  String? svgContent;
  _MermaidInstance();
}

class _SvgWebView extends StatefulWidget {
  final String? svgContent;
  final void Function(InAppWebViewController) onControllerCreated;
  final void Function(bool) onReady;
  final void Function(InAppWebViewController, ConsoleMessage) onConsoleMessage;

  const _SvgWebView({
    super.key,
    required this.svgContent,
    required this.onControllerCreated,
    required this.onReady,
    required this.onConsoleMessage,
  });

  @override
  State<_SvgWebView> createState() => _SvgWebViewState();
}

class _SvgWebViewState extends State<_SvgWebView> {
  @override
  Widget build(BuildContext context) {
    if (widget.svgContent != null) {
      return SizedBox(
        height: 300,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: '<html><body style="margin:0;padding:8px;background:transparent">${widget.svgContent}</body></html>',
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            javaScriptEnabled: false,
            mediaPlaybackRequiresUserGesture: true,
          ),
          onWebViewCreated: (c) => widget.onControllerCreated(c),
          onLoadStop: (_, __) => widget.onReady(true),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: '<html><body></body></html>',
        ),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (c) => widget.onControllerCreated(c),
        onLoadStop: (_, __) => widget.onReady(true),
        onConsoleMessage: widget.onConsoleMessage,
      ),
    );
  }
}
