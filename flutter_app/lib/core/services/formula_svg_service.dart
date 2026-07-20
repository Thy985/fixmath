import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'mermaid_service.dart' show MermaidService;

/// MathJax 渲染 LaTeX 为 SVG 字符串服务（与 MermaidService 共享 WebView）。
///
/// 互补于 [FormulaPdfRenderer]（位图路径）：
///  - 本服务输出 SVG 字符串，可在 PDF 中作为矢量嵌入（[pw.SvgImage]）
///  - 当 WebView 未就绪时，调用方应降级到 PNG 路径
///
/// ## 与 WebView 的通信协议 (v2)
/// 旧协议用 `console.log('LATEX_OK|<id>|<len>|<svg>')` 拼回 SVG，如果 SVG
/// 本身含 `|` 字符（MathJax 内部可能产生），`parts.sublist(3).join('|')` 会丢字符。
///
/// 新协议：
///   1. JS 把 SVG 写入 `<div id="payload-{id}">`（display: none）
///   2. JS 通过 `console.log('LATEX_OK|<id>')` 通知 Dart 渲染完成
///   3. Dart 收到后用 `controller.evaluateJavascript(...)` 读取 innerHTML
///   4. 失败时 fallback 到 base64 编码的 console 协议 `LATEX_OK|<id>|b64:<base64>`
///      避免 `|` 字符引发的解码歧义
class FormulaSvgService {
  FormulaSvgService._();

  static const Duration _renderTimeout = Duration(seconds: 30);
  static const int _maxConcurrent = 4;
  static const int _maxCacheEntries = 256;
  static const int _maxCacheBytes = 32 * 1024 * 1024; // 32 MB

  static final LinkedHashMap<String, String> _cache = LinkedHashMap();
  static int _totalCacheBytes = 0;
  static int _requestCounter = 0;

  static final List<_PendingLatex> _waiting = [];
  static final Map<String, _PendingLatex> _active = {};

  /// 渲染 LaTeX 为 SVG 字符串。结果按 (latex, displayMode) 缓存。
  /// 多次并发调用会自动排队，并发上限 [_maxConcurrent]。
  /// 失败时抛 [FormulaSvgException]。
  static Future<String> renderToSvg(
    String latex, {
    bool displayMode = false,
  }) async {
    final key = _cacheKey(latex, displayMode);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }

    final controller = MermaidService.attachedController;
    if (controller == null) {
      throw FormulaSvgException(
        'MermaidRendererHost is not mounted. Mount it before calling renderToSvg.',
      );
    }

    // 关键：等 HTML + tex-svg.js 真正加载完。否则 window.renderLatex 不存在，
    // evaluateJavascript 静默失败，30s 后才超时。
    _ensurePageLoadedCallbackRegistered();
    await MermaidService.awaitPageLoaded();
    if (MermaidService.attachedController == null) {
      throw FormulaSvgException('WebView reset during page-load wait');
    }

    final completer = Completer<String>();
    final requestId = 'l${++_requestCounter}';
    final pending = _PendingLatex(
      requestId: requestId,
      completer: completer,
      latex: latex,
      displayMode: displayMode,
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
      throw FormulaSvgException('LaTeX SVG render timeout');
    } catch (e) {
      _active.remove(requestId);
      _waiting.remove(pending);
      rethrow;
    }
  }

  /// 预渲染一组 LaTeX。失败的项目会跳过（不抛错），调用方需检查 [cachedSvg]。
  /// 并发执行以提高性能。
  static Future<void> preRenderAll(
    Iterable<String> formulas, {
    bool displayMode = false,
  }) async {
    final futures = <Future>[];
    for (final latex in formulas) {
      final key = _cacheKey(latex, displayMode);
      if (_cache.containsKey(key)) continue;
      futures.add(_preRenderOne(latex, displayMode: displayMode));
    }
    // 并发等待所有任务，允许部分失败
    await Future.wait(futures, eagerError: false);
  }

  static Future<void> _preRenderOne(String latex, {required bool displayMode}) async {
    try {
      await renderToSvg(latex, displayMode: displayMode);
    } catch (e) {
      // 失败跳过，让调用方用 PNG 兜底
    }
  }

  /// 同步获取缓存的 SVG 字符串。
  static String? cachedSvg(String latex, {bool displayMode = false}) {
    final key = _cacheKey(latex, displayMode);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    return null;
  }

  static void _dispatchWaiting() {
    final controller = MermaidService.attachedController;
    if (controller == null) return;
    if (!MermaidService.isPageLoaded) return; // 等 onLoadStop
    while (_active.length < _maxConcurrent && _waiting.isNotEmpty) {
      final next = _waiting.removeAt(0);
      _evaluate(controller, next);
    }
  }

  static bool _pageLoadedCallbackRegistered = false;

  /// 注册一次性的页面加载回调——当 MermaidService 报告页面真正加载完成后
  /// 立即 dispatch 自己的 _waiting 队列。多次调用 [renderToSvg] 共享同一个
  /// 回调。
  static void _ensurePageLoadedCallbackRegistered() {
    if (_pageLoadedCallbackRegistered) return;
    _pageLoadedCallbackRegistered = true;
    MermaidService.addPageLoadedCallback(_onPageLoaded);
  }

  static void _onPageLoaded() {
    _dispatchWaiting();
  }

  static Future<void> _evaluate(
    InAppWebViewController controller,
    _PendingLatex p,
  ) async {
    final script =
        'window.renderLatex(${_js(p.requestId)}, ${_js(p.latex)}, ${p.displayMode})';
    try {
      await controller.evaluateJavascript(source: script).timeout(_renderTimeout);
    } on TimeoutException {
      // WebView 进程卡死，重置渲染器
      MermaidService.resetRenderer();
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

  /// 由 [MermaidRendererHost] 的 onConsoleMessage 调用。
  /// 处理 LATEX_OK 和 LATEX_ERR 前缀的消息（v2 协议）。
  ///
  /// 新格式：
  ///   - `LATEX_OK|<id>`           — SVG 在 `document.getElementById("payload-<id>")` 的 textContent 里
  ///   - `LATEX_OK|<id>|b64:<b64>` — base64 fallback（DOM 不可用时使用）
  ///   - `LATEX_ERR|<id>|<reason>` — 渲染失败
  static void handleConsoleMessage(String message) {
    if (message.startsWith('LATEX_OK|')) {
      final rest = message.substring('LATEX_OK|'.length);
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
          // 避免 SVG 中夹杂的边缘 Unicode 字符（未配对 surrogate 等）
          // 导致整批公式渲染失败。
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
    } else if (message.startsWith('LATEX_ERR|')) {
      final idx = message.indexOf('|', 'LATEX_ERR|'.length);
      if (idx > 0) {
        final id = message.substring('LATEX_ERR|'.length, idx);
        _completePendingError(id, message);
      }
    }
  }

  /// 异步从 WebView DOM 读取 SVG 内容。
  /// 失败时不会无限重试——会通过 _completePendingError 通知调用方。
  static Future<void> _fetchSvgFromDom(String id) async {
    final controller = MermaidService.attachedController;
    if (controller == null) {
      _completePendingError(id, 'controller not available for DOM fetch');
      return;
    }
    try {
      final raw = await controller.evaluateJavascript(
        source:
            '(function(){var e=document.getElementById("payload-${_js(id).substring(1, _js(id).length - 1)}");return e?e.textContent:"";})()',
      );
      final svg = (raw is String) ? raw : (raw?.toString() ?? '');
      // best-effort cleanup
      try {
        await controller.evaluateJavascript(
          source:
              '(function(){var e=document.getElementById("payload-${_js(id).substring(1, _js(id).length - 1)}");if(e)e.remove();})()',
        );
      } catch (_) {}
      if (svg.isEmpty) {
        _completePendingError(id, 'DOM fetch returned empty SVG');
      } else {
        _completePending(id, svg);
      }
    } catch (e) {
      _completePendingError(id, 'DOM fetch failed: $e');
    }
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
      p.completer.completeError(FormulaSvgException(error));
    }
    _dispatchWaiting();
  }

  static String _cacheKey(String latex, bool displayMode) {
    final h = md5.convert(latex.codeUnits).toString();
    return '${displayMode ? 'B' : 'I'}|$h';
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
  }
}

class _PendingLatex {
  final String requestId;
  final Completer<String> completer;
  final String latex;
  final bool displayMode;

  _PendingLatex({
    required this.requestId,
    required this.completer,
    required this.latex,
    required this.displayMode,
  });
}

class FormulaSvgException implements Exception {
  final String message;
  FormulaSvgException(this.message);

  @override
  String toString() => 'FormulaSvgException: $message';
}
