/// SVG AST → PDF 矢量绘制。
///
/// 把 `svg_parser.dart` 生成的 AST 树用 `pdf` 包的底层 `PdfGraphics` API
/// 画出来。完全绕开 `pw.SvgImage`（已知在含未配对代理对的 SVG 上抛
/// "Unexpected extension byte"），且不依赖第三方 SVG 渲染器。
///
/// 用法：
/// ```dart
/// final root = parseSvgString(svgString);
/// final widget = SvgPdfWidget(
///   root: root,
///   textFont: pw.Font.courier(),  // 来自调用方 context.document
///   textColor: PdfColors.black,
///   fallbackFont: pw.Font.courier(),
/// );
/// ```
///
/// 设计原则：
/// 1. **永不抛错**。任何不支持的元素显示为 `[unsupported: ...]` 占位文本
///    （不阻塞整份 PDF 导出）
/// 2. **路径数据直通**。`canvas.drawShape(d)` 走 `pdf` 包内部的
///    `writeSvgPathDataToPath` 解析器，只解析 `d` 字符串本身，不解析
///    XML —— 完全绕开 `XmlDocument.parse` 路径上的 utf8 边界 bug
/// 3. **可选 transform 嵌套**。`<g transform="translate(x,y)">` 通过
///    `canvas.setTransform(matrix)` 嵌套 push/pop 实现
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' show Widget, Context, BoxConstraints;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'svg_ast.dart';

/// 入口：把 SVG 字符串直接转成 `pw.Widget`。
///
/// 失败时（解析异常、root 为空等）会创建一个 fallback widget，
/// 显示为 `[unsupported: <reason>]` 单行文字，绝不抛错。
class SvgPdfWidget extends Widget {
  SvgPdfWidget({
    required this.root,
    required this.textFont,
    this.textColor,
    required this.fallbackFont,
    this.unsupportedColor,
  });

  /// 已解析的 AST。
  final SvgRoot root;

  /// 文本节点使用的字体。MathJax 输出大量 `<text>`，复用调用方传入的字体。
  final PdfFont textFont;

  /// 文本节点默认颜色。
  final PdfColor? textColor;

  /// 兜底字体（用于 unsupported 占位 / 字族查找）。必须已构造（绑定 PdfDocument）。
  final PdfFont fallbackFont;

  /// 未支持占位文本的颜色（默认红灰色 #B00020）。
  final PdfColor? unsupportedColor;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = root.intrinsicWidth;
    final h = root.intrinsicHeight;
    box = PdfRect.fromPoints(PdfPoint.zero, PdfPoint(w, h));
  }

  @override
  void paint(Context context) {
    super.paint(context);
    final canvas = context.canvas;

    // SVG 用户坐标系：原点在 (0,0)，x 右、y 下。
    // PDF 坐标系是 y 向上 —— 这里不动 origin，由调用方决定放置位置。
    _paintNode(canvas, root);
  }

  void _paintNode(PdfGraphics canvas, SvgNode node) {
    if (node is SvgRoot) {
      for (final child in node.children) {
        _paintNode(canvas, child);
      }
    } else if (node is SvgGroup) {
      canvas.saveContext();
      if (node.translateX != 0 || node.translateY != 0) {
        // SVG 用户坐标系下 translate；在 PDF 坐标系里是平移。
        canvas.setTransform(
            Matrix4.identity()..translateByDouble(node.translateX, node.translateY, 0, 1));
      }
      for (final child in node.children) {
        _paintNode(canvas, child);
      }
      canvas.restoreContext();
    } else if (node is SvgRect) {
      _drawRect(canvas, node);
    } else if (node is SvgLine) {
      _drawLine(canvas, node);
    } else if (node is SvgCircle) {
      _drawCircle(canvas, node);
    } else if (node is SvgEllipse) {
      _drawEllipse(canvas, node);
    } else if (node is SvgPath) {
      _drawPath(canvas, node);
    } else if (node is SvgText) {
      _drawText(canvas, node);
    } else if (node is SvgUse) {
      _drawUnsupported(canvas, '<use href="${node.href}">');
    } else if (node is SvgUnsupported) {
      _drawUnsupported(canvas, '<${node.elementName}>');
    }
  }

  // === 形状绘制 ===============================================

  void _drawRect(PdfGraphics canvas, SvgRect r) {
    if (r.width <= 0 || r.height <= 0) return;
    final fill = _parseColor(r.fill);
    final stroke = _parseColor(r.stroke);
    if (fill == null && stroke == null) return;
    canvas.saveContext();
    if (fill != null) canvas.setFillColor(fill);
    if (stroke != null) canvas.setStrokeColor(stroke);
    canvas.setLineWidth(r.strokeWidth);
    canvas.drawRect(r.x, r.y, r.width, r.height);
    _finish(canvas, fill: fill, stroke: stroke);
    canvas.restoreContext();
  }

  void _drawLine(PdfGraphics canvas, SvgLine l) {
    final stroke = _parseColor(l.stroke) ?? textColor ?? PdfColors.black;
    canvas.saveContext();
    canvas.setStrokeColor(stroke);
    canvas.setLineWidth(l.strokeWidth);
    canvas.moveTo(l.x1, l.y1);
    canvas.lineTo(l.x2, l.y2);
    canvas.strokePath();
    canvas.restoreContext();
  }

  void _drawCircle(PdfGraphics canvas, SvgCircle c) {
    if (c.r <= 0) return;
    final fill = _parseColor(c.fill);
    final stroke = _parseColor(c.stroke);
    if (fill == null && stroke == null) return;
    canvas.saveContext();
    if (fill != null) canvas.setFillColor(fill);
    if (stroke != null) canvas.setStrokeColor(stroke);
    canvas.setLineWidth(c.strokeWidth);
    canvas.drawEllipse(c.cx, c.cy, c.r, c.r);
    _finish(canvas, fill: fill, stroke: stroke);
    canvas.restoreContext();
  }

  void _drawEllipse(PdfGraphics canvas, SvgEllipse e) {
    if (e.rx <= 0 || e.ry <= 0) return;
    final fill = _parseColor(e.fill);
    final stroke = _parseColor(e.stroke);
    if (fill == null && stroke == null) return;
    canvas.saveContext();
    if (fill != null) canvas.setFillColor(fill);
    if (stroke != null) canvas.setStrokeColor(stroke);
    canvas.setLineWidth(e.strokeWidth);
    canvas.drawEllipse(e.cx, e.cy, e.rx, e.ry);
    _finish(canvas, fill: fill, stroke: stroke);
    canvas.restoreContext();
  }

  void _drawPath(PdfGraphics canvas, SvgPath p) {
    if (p.d.isEmpty) return;
    final fill = _parseColor(p.fill);
    final stroke = _parseColor(p.stroke);
    if (fill == null && stroke == null) return;
    canvas.saveContext();
    if (fill != null) canvas.setFillColor(fill);
    if (stroke != null) canvas.setStrokeColor(stroke);
    canvas.setLineWidth(p.strokeWidth);
    try {
      canvas.drawShape(p.d);
    } catch (_) {
      canvas.restoreContext();
      _drawUnsupported(canvas, '<path>');
      return;
    }
    _finish(canvas, fill: fill, stroke: stroke);
    canvas.restoreContext();
  }

  void _finish(PdfGraphics canvas, {PdfColor? fill, PdfColor? stroke}) {
    if (fill != null && stroke != null) {
      canvas.fillAndStrokePath();
    } else if (stroke != null) {
      canvas.strokePath();
    } else {
      canvas.fillPath();
    }
  }

  // === 文本绘制 ===============================================

  void _drawText(PdfGraphics canvas, SvgText t) {
    if (t.children.isNotEmpty) {
      for (final s in t.children) {
        _drawTspan(canvas, t, s);
      }
      return;
    }
    if (t.text.isEmpty) return;

    final font = _lookupFont(t.fontFamily);
    final size = t.fontSize > 0 ? t.fontSize : 12.0;
    final color = _parseColor(t.fill) ?? textColor;

    canvas.saveContext();
    if (color != null) {
      canvas.setFillColor(color);
    }
    try {
      canvas.drawString(font, size, t.text, t.x, t.y);
    } catch (_) {
      canvas.restoreContext();
      _drawUnsupported(canvas, t.text);
      return;
    }
    canvas.restoreContext();
  }

  void _drawTspan(PdfGraphics canvas, SvgText parent, SvgTspan s) {
    if (s.text.isEmpty) return;
    final font = _lookupFont(s.fontFamily);
    final size = s.fontSize ?? parent.fontSize;
    final color = _parseColor(s.fill) ?? _parseColor(parent.fill) ?? textColor;
    final x = s.x ?? parent.x;
    final y = s.y ?? parent.y;

    canvas.saveContext();
    if (color != null) {
      canvas.setFillColor(color);
    }
    try {
      canvas.drawString(font, size, s.text, x, y);
    } catch (_) {
      canvas.restoreContext();
      _drawUnsupported(canvas, s.text);
      return;
    }
    canvas.restoreContext();
  }

  // === 占位文本 ===============================================

  void _drawUnsupported(PdfGraphics canvas, String detail) {
    final color = unsupportedColor ?? const PdfColor.fromInt(0xFFB00020);
    final label = '[unsupported: $detail]';
    canvas.saveContext();
    canvas.setFillColor(color);
    try {
      canvas.drawString(fallbackFont, 8, label, 4, 10);
    } catch (_) {
      // swallow — 绝不让 unsupported 占位阻塞导出
    }
    canvas.restoreContext();
  }

  // === 颜色 / 字体辅助 =======================================

  /// 解析 SVG 颜色字符串。MathJax 输出常用 `#rrggbb` / `#rgb` / `none` /
  /// `currentColor`。`none` / 空返回 null（不绘制）。
  PdfColor? _parseColor(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s == 'none' || s == 'transparent') return null;
    if (s == 'currentColor') return textColor;
    if (s.startsWith('#')) {
      try {
        if (s.length == 7) {
          return PdfColor.fromInt(int.parse(s.substring(1), radix: 16) |
              0xFF000000);
        }
        if (s.length == 4) {
          final r = s[1];
          final g = s[2];
          final b = s[3];
          return PdfColor.fromInt(
            int.parse('$r$r$g$g$b$b', radix: 16) | 0xFF000000,
          );
        }
        if (s.length == 9) {
          return PdfColor.fromInt(int.parse(s.substring(1), radix: 16));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 简单 font-family 查找 —— MathJax SVG 通常不输出 font-family。
  PdfFont _lookupFont(String? family) {
    if (family == null) return textFont;
    final lower = family.toLowerCase();
    if (lower.contains('mono') || lower.contains('courier')) {
      return fallbackFont;
    }
    if (lower.contains('serif') || lower.contains('times')) {
      return fallbackFont;
    }
    if (lower.contains('italic') || lower.contains('oblique')) {
      return fallbackFont;
    }
    if (lower.contains('bold')) {
      return fallbackFont;
    }
    return textFont;
  }
}
