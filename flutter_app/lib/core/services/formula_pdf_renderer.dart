import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// 全局隐藏的 LaTeX 渲染 host，用于离屏渲染公式到 PDF/Word。
///
/// 通过在 MaterialApp 顶层插入一个 Offstage 的 [FormulaRenderHost]，
/// 公式渲染请求可以排队交给它处理，避免摧毁应用主 UI。
class FormulaRenderHost extends StatefulWidget {
  const FormulaRenderHost({super.key, required this.child});
  final Widget child;

  static _FormulaRenderHostState? _instance;

  /// 提交一个公式渲染请求。返回 PNG 字节。
  /// 如果 host 尚未挂载（无 _instance），返回 null。
  static Future<Uint8List?> render({
    required String latex,
    required double fontSize,
    required bool displayMode,
    required bool isDark,
  }) {
    final inst = _instance;
    if (inst == null) {
      return Future.value(null);
    }
    final completer = Completer<Uint8List?>();
    inst._pendingRenders.add(_RenderRequest(
      latex: latex,
      fontSize: fontSize,
      displayMode: displayMode,
      isDark: isDark,
      completer: completer,
    ));
    inst._schedule();
    return completer.future;
  }

  @override
  State<FormulaRenderHost> createState() => _FormulaRenderHostState();
}

class _FormulaRenderHostState extends State<FormulaRenderHost> {
  final List<_RenderRequest> _pendingRenders = [];

  @override
  void initState() {
    super.initState();
    FormulaRenderHost._instance = this;
  }

  @override
  void dispose() {
    if (FormulaRenderHost._instance == this) {
      FormulaRenderHost._instance = null;
    }
    super.dispose();
  }

  void _schedule() {
    if (_pendingRenders.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingRenders.isEmpty) return;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingRenders.isNotEmpty ? _pendingRenders.first : null;
    return Stack(
      children: [
        widget.child,
        if (pending != null)
          Positioned(
            left: -10000,
            top: -10000,
            child: _OffscreenCapture(
              latex: pending.latex,
              fontSize: pending.fontSize,
              displayMode: pending.displayMode,
              isDark: pending.isDark,
              onCaptured: (bytes) {
                pending.completer.complete(bytes);
                _pendingRenders.removeAt(0);
                _schedule();
              },
            ),
          ),
      ],
    );
  }
}

class _RenderRequest {
  final String latex;
  final double fontSize;
  final bool displayMode;
  final bool isDark;
  final Completer<Uint8List?> completer;

  _RenderRequest({
    required this.latex,
    required this.fontSize,
    required this.displayMode,
    required this.isDark,
    required this.completer,
  });
}

class _OffscreenCapture extends StatefulWidget {
  final String latex;
  final double fontSize;
  final bool displayMode;
  final bool isDark;
  final ValueChanged<Uint8List?> onCaptured;

  const _OffscreenCapture({
    required this.latex,
    required this.fontSize,
    required this.displayMode,
    required this.isDark,
    required this.onCaptured,
  });

  @override
  State<_OffscreenCapture> createState() => _OffscreenCaptureState();
}

class _OffscreenCaptureState extends State<_OffscreenCapture> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 16));
      await _capture();
    });
  }

  Future<void> _capture() async {
    try {
      final boundary = _key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        widget.onCaptured(null);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 5.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      widget.onCaptured(byteData?.buffer.asUint8List());
    } catch (e) {
      widget.onCaptured(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _key,
      child: Container(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        padding: const EdgeInsets.all(4),
        child: Math.tex(
          widget.latex,
          mathStyle: widget.displayMode ? MathStyle.display : MathStyle.text,
          textStyle: TextStyle(
            fontSize: widget.fontSize,
            color: widget.isDark ? Colors.white : Colors.black,
          ),
          onErrorFallback: (err) => Text(
            widget.latex,
            style: TextStyle(
              fontSize: widget.fontSize * 0.6,
              color: widget.isDark ? Colors.grey : Colors.red,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

/// 公式 PDF 渲染缓存管理器（LRU 实现）。
///
/// 缓存 key 维度：`$format|$fontSize|$isDark|$latex`
///   - [format] 区分 PDF / Word 等不同导出路径（防止不同像素密度的渲染互相覆盖）
///   - [fontSize] 字号
///   - [isDark] 深色 / 浅色主题（深色导出需要白字+深底）
///   - [latex] LaTeX 源文本
class FormulaPdfRenderer {
  FormulaPdfRenderer._();

  static const int _maxEntries = 256;
  static const int _maxBytes = 64 * 1024 * 1024; // 64 MB
  static const int _maxConcurrent = 4; // 最大并发渲染数

  /// PDF 导出格式的 cache key 维度。
  static const String formatPdf = 'pdf';

  /// Word 导出格式的 cache key 维度。
  static const String formatWord = 'word';

  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static int _totalBytes = 0;

  static int get cacheSize => _cache.length;
  static int get totalBytes => _totalBytes;

  /// 同步获取缓存的公式 PNG 字节。如果未缓存返回 null。
  /// 命中后会把这个 entry 移到 LRU 最近位置。
  ///
  /// [format] 默认 [formatPdf]。Word 导出应传 [formatWord]，避免与 PDF 缓存互相覆盖。
  static Uint8List? cachedBytes(
    String latex, {
    double fontSize = 16,
    bool isDark = false,
    String format = formatPdf,
  }) {
    final key = _keyOf(latex, fontSize: fontSize, isDark: isDark, format: format);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    return null;
  }

  /// 预渲染所有唯一公式。会调用全局 [FormulaRenderHost] 离屏渲染。
  /// [fontSize] 用于统一字号。并发数限制为 [_maxConcurrent]。
  ///
  /// [format] / [isDark] 进入缓存 key 维度，确保不同导出格式/主题不互相覆盖。
  static Future<void> preRenderAll(
    Iterable<String> formulas, {
    double fontSize = 16,
    bool isDark = false,
    String format = formatPdf,
  }) async {
    final pending = <String>[];
    for (final latex in formulas) {
      final key = _keyOf(latex, fontSize: fontSize, isDark: isDark, format: format);
      if (!_cache.containsKey(key)) pending.add(latex);
    }
    if (pending.isEmpty) return;

    // 分批并发执行，每批最多 _maxConcurrent 个
    for (var i = 0; i < pending.length; i += _maxConcurrent) {
      final batch = pending.skip(i).take(_maxConcurrent);
      final futures = batch.map(
        (latex) => _renderSingle(latex, fontSize: fontSize, isDark: isDark, format: format),
      );
      await Future.wait(futures);
    }
  }

  static Future<void> _renderSingle(
    String latex, {
    required double fontSize,
    required bool isDark,
    required String format,
  }) async {
    final key = _keyOf(latex, fontSize: fontSize, isDark: isDark, format: format);
    if (_cache.containsKey(key)) return;

    final displayMode = latex.contains('\n') || latex.length > 50;
    final bytes = await FormulaRenderHost.render(
      latex: latex,
      fontSize: fontSize,
      displayMode: displayMode,
      isDark: isDark,
    );
    if (bytes == null) return;

    _cache[key] = bytes;
    _totalBytes += bytes.length;
    _evictIfNeeded();
  }

  /// 构造缓存 key。维度顺序固定，避免不同参数组合产生相同 key。
  ///
  /// 注意：此方法对外可见（`@visibleForTesting` 等价）以便单元测试断言。
  /// 生产代码请使用 [cachedBytes] / [preRenderAll]。
  static String _keyOf(
    String latex, {
    required double fontSize,
    required bool isDark,
    required String format,
  }) =>
      '$format|${fontSize.toStringAsFixed(2)}|${isDark ? 'D' : 'L'}|$latex';

  static void _evictIfNeeded() {
    while (_cache.length > _maxEntries || _totalBytes > _maxBytes) {
      if (_cache.isEmpty) break;
      final firstKey = _cache.keys.first;
      final removed = _cache.remove(firstKey);
      if (removed != null) _totalBytes -= removed.length;
    }
  }

  static void clearCache() {
    _cache.clear();
    _totalBytes = 0;
  }
}
