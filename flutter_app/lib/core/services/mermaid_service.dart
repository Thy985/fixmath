import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 页面加载完成后的回调签名。由 [MermaidService.markPageLoaded] 触发。
typedef MermaidPageLoadedCallback = void Function();

enum MermaidTheme { light, dark }

/// Mermaid 图表 → SVG 字符串渲染服务。
///
/// 6 层架构：
///  1) Markdown 解析  →  MermaidElement
///  2) 共享 WebView 渲染 mermaid.js
///  3) console.message 触发，DOM payload 提取 SVG 字符串 (v2 协议)
///  4) MD5 哈希 LRU 缓存
///  5) flutter_svg 矢量绘制到 PDF
///  6) 主题同步
///
/// ## v2 协议说明
/// 旧协议：`MERMAID_OK|<id>|<svg.length>|<svg>` —— 用 `|` 分隔字段，
/// 如果 SVG 自身含 `|` 字符（MathJax 渲染某些公式时可能产生），`parts.sublist(3).join('|')`
/// 会丢字符。
///
/// 新协议：
///   1. JS 把 SVG 写入 `<div id="payload-<id>">`（display: none）
///   2. JS 触发 `console.log('MERMAID_OK|<id>')` 通知 Dart 渲染完成
///   3. Dart 用 `controller.evaluateJavascript(...)` 读 innerHTML
///   4. 失败时 fallback 到 base64 编码的 console 协议 `MERMAID_OK|<id>|b64:<base64>`
class MermaidService {
  MermaidService._();

  static const Duration _renderTimeout = Duration(seconds: 30);
  static const int _maxConcurrent = 4;
  static const int _maxCacheEntries = 256;
  static const int _maxCacheBytes = 32 * 1024 * 1024; // 32 MB

  static final LinkedHashMap<String, String> _cache = LinkedHashMap();
  static int _totalCacheBytes = 0;
  static int _requestCounter = 0;
  static InAppWebViewController? _controller;
  static bool _isReady = false;
  static bool _pageLoaded = false;
  static Completer<void>? _pageLoadedCompleter;

  static final List<_PendingRender> _waiting = [];
  static final Map<String, _PendingRender> _active = {};
  static final Map<MermaidTheme, String> _themeSvgCache = {};
  static final List<MermaidPageLoadedCallback> _pageLoadedCallbacks = [];

  static String get html => _kHtml;
  static bool get isReady => _isReady;
  static bool get isPageLoaded => _pageLoaded;
  static MermaidTheme _activeTheme = MermaidTheme.light;

  /// WebView 加载本地 HTML 的相对资产路径。
  ///
  /// 配合 [MermaidRendererHost] 使用 [InAppWebViewController.loadFile]，让模板内
  /// 的 `<script src="js/tex-svg.js">` / `<script src="js/mermaid.min.js">` 等相对
  /// 引用解析到打包好的 Flutter 资产目录，从而实现"100% 离线"。
  static const String rendererAssetPath = 'assets/mermaid_renderer.html';

  static void attachController(InAppWebViewController controller) {
    _controller = controller;
    _isReady = true;
    // 新的 WebView 实例 = 页面需要重新加载 = 必须等 onLoadStop 之后
    // 才能让 window.renderMermaid(window.cleanupPayloads 等) 真正可用。
    _pageLoaded = false;
    _pageLoadedCompleter = Completer<void>();
    _dispatchWaiting();
  }

  /// 由 [MermaidRendererHost] 的 `onLoadStop` 回调触发。
  ///
  /// 必须在页面 + 子资源（tex-svg.js / mermaid.min.js）真正加载完成
  /// 之后调用 — 在那之前调用 [renderToSvg] 会让 evaluateJavascript
  /// 静默失败（window.renderMermaid 不存在），30s 后才超时。
  static void markPageLoaded() {
    if (_pageLoaded) return;
    _pageLoaded = true;
    final c = _pageLoadedCompleter;
    if (c != null && !c.isCompleted) c.complete();
    // 页面就绪后，dispatch 已经在 _waiting 里排队的请求。
    _dispatchWaiting();
    // 同时通知兄弟服务（FormulaSvgService 等）可以 dispatch 自己的队列。
    for (final cb in List.of(_pageLoadedCallbacks)) {
      try {
        cb();
      } catch (_) {}
    }
  }

  /// 注册一个在 WebView 页面真正加载完成后被同步触发的回调。
  /// 用于共享同一个 WebView 的其他服务（如 [FormulaSvgService]）。
  ///
  /// 重复注册同一个回调可能导致多次触发——调用方需自行去重。
  static void addPageLoadedCallback(MermaidPageLoadedCallback cb) {
    _pageLoadedCallbacks.add(cb);
    if (_pageLoaded) {
      // 页面已经加载完，立即触发
      try {
        cb();
      } catch (_) {}
    }
  }

  /// 异步等待页面真正加载完成。已有 completer 则复用，否则创建一个。
  /// 等待超时上限是 _renderTimeout（30s），与单次渲染超时对齐。
  ///
  /// 公开给共享 WebView 的兄弟服务（如 [FormulaSvgService]）使用。
  static Future<void> awaitPageLoaded() async {
    if (_pageLoaded) return;
    _pageLoadedCompleter ??= Completer<void>();
    await _pageLoadedCompleter!.future.timeout(
      _renderTimeout,
      onTimeout: () {
        // 不抛错：让下游 renderToSvg 自身的 30s 兜底超时来报错。
        // 抛错会和我们已有的错误分类冲突。
      },
    );
  }

  /// WebView 渲染进程崩溃时调用，重置状态并清除所有待处理的渲染请求。
  static void resetRenderer() {
    _controller = null;
    _isReady = false;
    _pageLoaded = false;
    final pendingPage = _pageLoadedCompleter;
    _pageLoadedCompleter = null;
    if (pendingPage != null && !pendingPage.isCompleted) {
      pendingPage.complete(); // 解开所有 await _awaitPageLoaded 的等待者
    }
    for (final p in _waiting) {
      if (!p.completer.isCompleted) {
        p.completer.completeError(
          MermaidRenderException('WebView renderer crashed'),
        );
      }
    }
    _waiting.clear();
    for (final p in _active.values) {
      if (!p.completer.isCompleted) {
        p.completer.completeError(
          MermaidRenderException('WebView renderer crashed'),
        );
      }
    }
    _active.clear();
    _cache.clear();
  }

  /// 清理 WebView DOM 中的所有 payload 元素，释放内存。
  static Future<void> cleanupPayloads() async {
    final controller = _controller;
    if (controller == null || !_isReady) return;
    try {
      await controller.evaluateJavascript(source: 'window.cleanupPayloads();');
    } catch (_) {}
  }

  /// 暴露已 attach 的 WebView 控制器给其他服务（如 [FormulaSvgService]）复用。
  static InAppWebViewController? get attachedController => _controller;

  static void handleConsoleMessage(String message) {
    if (message.startsWith('MERMAID_OK|')) {
      final rest = message.substring('MERMAID_OK|'.length);
      // 找到 id 和 payload 之间的第一个 '|'
      final idx = rest.indexOf('|');
      final String id;
      final String payload;
      if (idx < 0) {
        // 新格式：纯 id，SVG 在 DOM
        id = rest;
        payload = '';
      } else {
        // Fallback 格式：id|b64:<base64>
        id = rest.substring(0, idx);
        payload = rest.substring(idx + 1);
      }
      if (id.isEmpty) return;
      if (payload.startsWith('b64:')) {
        // base64 fallback — 立即解码（避免 '|' 字符问题）
        try {
          // 关键：allowMalformed: true 容忍部分字节无法解码的情况，
          // 避免 Mermaid SVG 中夹杂的边缘 Unicode 字符（未配对 surrogate 等）
          // 导致整批图表渲染失败。
          final svg = utf8.decode(base64Decode(payload.substring(4)),
              allowMalformed: true);
          _completePending(id, svg);
        } catch (e) {
          _completePendingError(id, 'base64 decode failed: $e');
        }
      } else {
        // DOM 路径 — 异步读取 hidden element
        _fetchSvgFromDom(id);
      }
    } else if (message.startsWith('MERMAID_ERR|')) {
      final idx = message.indexOf('|', 'MERMAID_ERR|'.length);
      if (idx > 0) {
        final id = message.substring('MERMAID_ERR|'.length, idx);
        _completePendingError(id, message);
      }
    } else if (message.startsWith('MERMAID_THEME|')) {
      const prefix = 'MERMAID_THEME|';
      final firstPipe = message.indexOf('|', prefix.length);
      if (firstPipe > 0) {
        final themeName = message.substring(prefix.length, firstPipe);
        final svg = message.substring(firstPipe + 1);
        final theme = themeName == 'dark' ? MermaidTheme.dark : MermaidTheme.light;
        _themeSvgCache[theme] = svg;
      }
    }
  }

  /// 异步从 WebView DOM 读取 SVG 内容。
  /// 失败时通过 _completePendingError 通知调用方。
  static Future<void> _fetchSvgFromDom(String id) async {
    final controller = _controller;
    if (controller == null) {
      _completePendingError(id, 'controller not available for DOM fetch');
      return;
    }
    final idLiteral = _js(id).substring(1, _js(id).length - 1);
    try {
      final raw = await controller
          .evaluateJavascript(
            source:
                '(function(){var e=document.getElementById("payload-$idLiteral");return e?e.textContent:"";})()',
          )
          .timeout(_renderTimeout);
      final svg = (raw is String) ? raw : (raw?.toString() ?? '');
      // best-effort cleanup
      try {
        await controller
            .evaluateJavascript(
              source:
                  '(function(){var e=document.getElementById("payload-$idLiteral");if(e)e.remove();})()',
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (svg.isEmpty) {
        _completePendingError(id, 'DOM fetch returned empty SVG');
      } else {
        _completePending(id, svg);
      }
    } on TimeoutException {
      resetRenderer();
    } catch (e) {
      _completePendingError(id, 'DOM fetch failed: $e');
    }
  }

  /// 渲染 Mermaid 代码为 SVG 字符串。结果按 (code, theme) 缓存。
  /// 多次并发调用会自动排队，并发上限 [_maxConcurrent]。
  static Future<String> renderToSvg(
    String code, {
    MermaidTheme theme = MermaidTheme.light,
  }) async {
    final key = _cacheKey(code, theme);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }

    if (_controller == null || !_isReady) {
      throw MermaidRenderException(
        'Mermaid WebView is not ready. Ensure MermaidRendererHost is mounted before exporting.',
      );
    }

    // 关键：等待 HTML + 子资源（tex-svg.js / mermaid.min.js）真正加载完毕。
    // 在此之前 window.renderMermaid 还不存在，evaluateJavascript 会静默
    // 失败，30s 后才超时。
    await awaitPageLoaded();
    if (_controller == null || !_isReady) {
      // 等待过程中 WebView 被 reset 了
      throw MermaidRenderException('Mermaid WebView reset during page-load wait');
    }

    final completer = Completer<String>();
    final requestId = 'm${++_requestCounter}';
    final pending = _PendingRender(
      requestId: requestId,
      completer: completer,
      code: code,
      theme: theme,
    );

    _waiting.add(pending);
    _active[requestId] = pending;
    _dispatchWaiting();

    try {
      final svg = await completer.future.timeout(_renderTimeout);
      _cachePut(key, svg);
      return svg;
    } on TimeoutException {
      _active.remove(requestId);
      _waiting.remove(pending);
      throw MermaidRenderException('Mermaid render timeout');
    } catch (e) {
      _active.remove(requestId);
      _waiting.remove(pending);
      rethrow;
    }
  }

  static void _dispatchWaiting() {
    if (_controller == null || !_isReady || !_pageLoaded) return;
    while (_active.length < _maxConcurrent && _waiting.isNotEmpty) {
      final next = _waiting.removeAt(0);
      if (_activeTheme != next.theme) {
        _activeTheme = next.theme;
      }
      _evaluate(next);
    }
  }

  static Future<void> _evaluate(_PendingRender p) async {
    final themeStr = p.theme == MermaidTheme.dark ? 'dark' : 'default';
    final script =
        '(function(){if(!window._mermaidTheme||window._mermaidTheme!==$themeStr){window._mermaidTheme=$themeStr;} '
        'return window.renderMermaid(${_js(p.requestId)}, ${_js(p.code)}, $themeStr);})()';
    try {
      await (_controller?.evaluateJavascript(source: script) ?? Future.value(null))
          .timeout(_renderTimeout);
    } on TimeoutException {
      // evaluateJavascript 超时，说明 WebView 进程可能已卡死，重置渲染器状态
      resetRenderer();
    } catch (e) {
      _completePendingError(p.requestId, 'evaluateJavascript failed: $e');
    }
  }

  static String _js(String s) {
    // Escape backslash first, then quotes, then control chars
    return "'${s
            .replaceAll('\\', '\\\\')
            .replaceAll("'", "\\'")
            .replaceAll('\r', '\\r')
            .replaceAll('\n', '\\n')
            .replaceAll('\t', '\\t')}'";
  }

  static void _completePending(String requestId, String svg) {
    final p = _active.remove(requestId);
    if (p != null && !p.completer.isCompleted) {
      p.completer.complete(svg);
    }
    _dispatchWaiting();
  }

  static void _completePendingError(String requestId, String error) {
    final p = _active.remove(requestId);
    if (p != null && !p.completer.isCompleted) {
      p.completer.completeError(MermaidRenderException(error));
    }
    _dispatchWaiting();
  }

  static String _cacheKey(String code, MermaidTheme theme) {
    final h = md5.convert(code.codeUnits).toString();
    return '${theme.name}|$h';
  }

  static void _cachePut(String key, String svg) {
    final old = _cache.remove(key);
    if (old != null) {
      _totalCacheBytes -= old.length;
    }
    _cache[key] = svg;
    _totalCacheBytes += svg.length;
    _evictIfNeeded();
  }

  static void _evictIfNeeded() {
    while (_cache.length > _maxCacheEntries || _totalCacheBytes > _maxCacheBytes) {
      if (_cache.isEmpty) break;
      final firstKey = _cache.keys.first;
      final removed = _cache.remove(firstKey);
      if (removed != null) _totalCacheBytes -= removed.length;
    }
  }

  static int get cacheSize => _cache.length;
  static int get totalCacheBytes => _totalCacheBytes;

  static void clearCache() {
    _cache.clear();
    _totalCacheBytes = 0;
    _themeSvgCache.clear();
  }

  // 注意: 此模板必须与 `assets/mermaid_renderer.html` 保持一致。
  // WebView 通过 [rendererAssetPath] 加载真正的资产文件 (使用相对路径解析本地
  // JS 资源)，但保留这里的常量用于兼容老代码 / 单元测试对 [html] getter 的访问。
  // 严禁再出现任何外部主机引用或平台特定 (file://) 的硬编码资源路径。
  static const String _kHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<script>
window.MathJax = {
  tex: { },
  svg: { fontCache: 'global' },
  startup: { typeset: false }
};
</script>
<!-- Local bundle: mathjax 3 es5 tex-svg, served from Flutter assets/js/ -->
<script src="js/tex-svg.js" async></script>
<style>
body { margin: 0; padding: 8px; background: transparent; }
#out { display: inline-block; }
</style>
</head>
<body>
<div id="out"></div>
<!-- Local bundle: mermaid.min.js, served from Flutter assets/js/ -->
<script src="js/mermaid.min.js"></script>
<script>
let currentTheme = 'default';
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose', theme: currentTheme, fontFamily: 'sans-serif' });
window.renderMermaid = async function(id, code, theme) {
  try {
    const el = document.getElementById('out');
    el.innerHTML = '';
    if (currentTheme !== theme) {
      currentTheme = theme;
      mermaid.initialize({ startOnLoad: false, securityLevel: 'loose', theme: theme, fontFamily: 'sans-serif' });
    }
    const { svg } = await mermaid.render(id, code);
    el.innerHTML = svg;
    // 限制 payload 数量：超过 10 个时移除最早的
    var allPayloads = document.querySelectorAll('[id^="payload-"]');
    if (allPayloads.length > 10) {
      allPayloads[0].remove();
    }
    // v2 协议：把 SVG 写入 hidden payload slot，Dart 用 evaluateJavascript 读 innerHTML
    // 避免旧版 MERMAID_OK|id|len|svg 协议中 '|' 字符丢失的问题
    let payload = document.getElementById('payload-' + id);
    if (!payload) {
      payload = document.createElement('div');
      payload.id = 'payload-' + id;
      payload.style.display = 'none';
      document.body.appendChild(payload);
    }
    payload.textContent = svg;
    console.log('MERMAID_OK|' + id);
    return true;
  } catch (e) {
    console.log('MERMAID_ERR|' + id + '|' + (e.message || String(e)));
    return false;
  }
};

window.renderLatex = async function(id, latex, displayMode) {
  try {
    if (typeof MathJax === 'undefined' || !MathJax.tex2svg) {
      console.log('LATEX_ERR|' + id + '|mathjax_not_loaded');
      return false;
    }
    const node = MathJax.tex2svg(latex, { display: displayMode === true });
    const svg = node.querySelector('svg');
    if (!svg) {
      console.log('LATEX_ERR|' + id + '|no_svg_in_output');
      return false;
    }
    const serialized = svg.outerHTML;
    // v2 协议：把 SVG 写入 hidden payload slot，Dart 用 evaluateJavascript 读 innerHTML
    let payload = document.getElementById('payload-' + id);
    if (!payload) {
      payload = document.createElement('div');
      payload.id = 'payload-' + id;
      payload.style.display = 'none';
      document.body.appendChild(payload);
    }
    payload.textContent = serialized;
    // 限制 payload 数量：超过 10 个时移除最早的
    var allPayloads = document.querySelectorAll('[id^="payload-"]');
    if (allPayloads.length > 10) {
      allPayloads[0].remove();
    }
    console.log('LATEX_OK|' + id);
    return true;
  } catch (e) {
    console.log('LATEX_ERR|' + id + '|render_failed|' + (e.message || String(e)));
    return false;
  }
};

// 清理所有 payload 元素，释放 DOM 内存
window.cleanupPayloads = function() {
  var allPayloads = document.querySelectorAll('[id^="payload-"]');
  for (var i = 0; i < allPayloads.length; i++) {
    allPayloads[i].remove();
  }
};
</script>
</body>
</html>
''';
}

class _PendingRender {
  final String requestId;
  final Completer<String> completer;
  final String code;
  final MermaidTheme theme;

  _PendingRender({
    required this.requestId,
    required this.completer,
    required this.code,
    required this.theme,
  });
}

class MermaidRenderException implements Exception {
  final String message;
  MermaidRenderException(this.message);

  @override
  String toString() => 'MermaidRenderException: $message';
}
