/// SVG 字符串 → AST 解析器。
///
/// 自写的轻量级 SVG 解析器，只覆盖 MathJax SVG 输出的子集。替代 `pw.SvgImage`
/// 的核心目的：完全控制编码边界（utf8.encode 验证）、跳过不支持的元素
/// （不抛错）、把 SVG 转成我们可控的 AST 模型。
///
/// 入口函数：
/// ```dart
/// final root = parseSvgString('<svg>...</svg>');
/// ```
///
/// 容错策略：
/// - 任何顶层异常 → 返回空的 `SvgRoot`（含 `SvgUnsupported` 节点）
/// - 未知元素 → `SvgUnsupported`，绝不抛错
/// - viewBox/width/height 解析失败 → 退到合理默认值
library;

import 'dart:convert';

import 'package:xml/xml.dart';

import 'svg_ast.dart';

/// 解析入口。失败时返回包含 `SvgUnsupported` 占位的空 root，**绝不抛错**。
SvgRoot parseSvgString(String input) {
  if (input.isEmpty) {
    return const SvgRoot(
      viewBoxX: 0,
      viewBoxY: 0,
      viewBoxWidth: 0,
      viewBoxHeight: 0,
      children: [
        SvgUnsupported(
          reason: 'empty input',
          elementName: 'svg',
          originalTag: '',
        ),
      ],
    );
  }

  // 1) 防御性：eager utf8.encode 验证
  //    xml package 内部对字符串再走 utf8.encode 时遇到未配对代理会抛错，
  //    我们提前过滤避免穿透。
  final cleaned = _preClean(input);
  final bytes = utf8.encode(cleaned);

  // 2) 解析 DOM
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(utf8.decode(bytes));
  } on XmlException catch (e) {
    return _emptyRoot('xml parse error: ${e.message}');
  } on FormatException catch (e) {
    return _emptyRoot('utf8 decode error: ${e.message}');
  }

  // 3) 找根 <svg>。MathJax 常常包一层 <mjx-container ...><svg>...</svg></mjx-container>。
  final svgElement = _findSvgElement(doc.rootElement);
  if (svgElement == null) {
    return _emptyRoot('no <svg> root found');
  }

  return _parseSvgElement(svgElement);
}

SvgRoot _emptyRoot(String reason) {
  return SvgRoot(
    viewBoxX: 0,
    viewBoxY: 0,
    viewBoxWidth: 0,
    viewBoxHeight: 0,
    children: [
      SvgUnsupported(
        reason: reason,
        elementName: 'svg',
        originalTag: '',
      ),
    ],
  );
}

XmlElement? _findSvgElement(XmlElement root) {
  if (root.name.local.toLowerCase() == 'svg') return root;
  for (final child in root.childElements) {
    if (child.name.local.toLowerCase() == 'svg') return child;
  }
  // 兜底：递归一层
  for (final child in root.descendantElements) {
    if (child.name.local.toLowerCase() == 'svg') return child;
  }
  return null;
}

SvgRoot _parseSvgElement(XmlElement el) {
  // viewBox="x y w h" 或 "x,y,w,h"
  double vbx = 0, vby = 0, vbw = 0, vbh = 0;
  final viewBox = el.getAttribute('viewBox');
  if (viewBox != null) {
    final parts = _splitNumbers(viewBox);
    if (parts.length >= 4) {
      vbx = parts[0];
      vby = parts[1];
      vbw = parts[2];
      vbh = parts[3];
    }
  }
  if (vbw <= 0) vbw = _parseLength(el.getAttribute('width')) ?? 0;
  if (vbh <= 0) vbh = _parseLength(el.getAttribute('height')) ?? 0;
  if (vbw <= 0) vbw = 300;
  if (vbh <= 0) vbh = 60;

  final children = <SvgNode>[];
  for (final child in el.childElements) {
    final node = _parseElement(child);
    if (node != null) children.add(node);
  }

  return SvgRoot(
    viewBoxX: vbx,
    viewBoxY: vby,
    viewBoxWidth: vbw,
    viewBoxHeight: vbh,
    width: _parseLength(el.getAttribute('width')),
    height: _parseLength(el.getAttribute('height')),
    children: children,
  );
}

SvgNode? _parseElement(XmlElement el) {
  final tag = el.name.local.toLowerCase();
  try {
    switch (tag) {
      case 'g':
        return _parseGroup(el);
      case 'rect':
        return _parseRect(el);
      case 'line':
        return _parseLine(el);
      case 'circle':
        return _parseCircle(el);
      case 'ellipse':
        return _parseEllipse(el);
      case 'path':
        return _parsePath(el);
      case 'text':
        return _parseText(el);
      case 'use':
        return _parseUse(el);
      case 'defs':
        // <defs> 内部资源我们不主动展开，遇到 <use> 时退到 unsupported
        return null;
      case 'style':
      case 'title':
      case 'desc':
      case 'metadata':
        // 纯元数据，跳过
        return null;
      default:
        return SvgUnsupported(
          reason: 'unsupported element <$tag>',
          elementName: tag,
          originalTag: tag,
        );
    }
  } catch (e) {
    return SvgUnsupported(
      reason: 'parse error: $e',
      elementName: tag,
      originalTag: tag,
    );
  }
}

SvgGroup _parseGroup(XmlElement el) {
  final (tx, ty) = _parseTranslate(el.getAttribute('transform'));
  final children = <SvgNode>[];
  for (final child in el.childElements) {
    final node = _parseElement(child);
    if (node != null) children.add(node);
  }
  return SvgGroup(
    children: children,
    translateX: tx,
    translateY: ty,
  );
}

SvgRect _parseRect(XmlElement el) {
  return SvgRect(
    x: _parseLength(el.getAttribute('x')) ?? 0,
    y: _parseLength(el.getAttribute('y')) ?? 0,
    width: _parseLength(el.getAttribute('width')) ?? 0,
    height: _parseLength(el.getAttribute('height')) ?? 0,
    fill: el.getAttribute('fill'),
    stroke: el.getAttribute('stroke'),
    strokeWidth: _parseLength(el.getAttribute('stroke-width')) ?? 1,
  );
}

SvgLine _parseLine(XmlElement el) {
  return SvgLine(
    x1: _parseLength(el.getAttribute('x1')) ?? 0,
    y1: _parseLength(el.getAttribute('y1')) ?? 0,
    x2: _parseLength(el.getAttribute('x2')) ?? 0,
    y2: _parseLength(el.getAttribute('y2')) ?? 0,
    stroke: el.getAttribute('stroke'),
    strokeWidth: _parseLength(el.getAttribute('stroke-width')) ?? 1,
  );
}

SvgCircle _parseCircle(XmlElement el) {
  return SvgCircle(
    cx: _parseLength(el.getAttribute('cx')) ?? 0,
    cy: _parseLength(el.getAttribute('cy')) ?? 0,
    r: _parseLength(el.getAttribute('r')) ?? 0,
    fill: el.getAttribute('fill'),
    stroke: el.getAttribute('stroke'),
    strokeWidth: _parseLength(el.getAttribute('stroke-width')) ?? 1,
  );
}

SvgEllipse _parseEllipse(XmlElement el) {
  return SvgEllipse(
    cx: _parseLength(el.getAttribute('cx')) ?? 0,
    cy: _parseLength(el.getAttribute('cy')) ?? 0,
    rx: _parseLength(el.getAttribute('rx')) ?? 0,
    ry: _parseLength(el.getAttribute('ry')) ?? 0,
    fill: el.getAttribute('fill'),
    stroke: el.getAttribute('stroke'),
    strokeWidth: _parseLength(el.getAttribute('stroke-width')) ?? 1,
  );
}

SvgPath _parsePath(XmlElement el) {
  return SvgPath(
    d: el.getAttribute('d') ?? '',
    fill: el.getAttribute('fill'),
    stroke: el.getAttribute('stroke'),
    strokeWidth: _parseLength(el.getAttribute('stroke-width')) ?? 1,
    fillOpacity: _parseDouble(el.getAttribute('fill-opacity')) ?? 1,
  );
}

SvgText _parseText(XmlElement el) {
  final tspans = <SvgTspan>[];
  for (final child in el.childElements) {
    if (child.name.local.toLowerCase() == 'tspan') {
      tspans.add(_parseTspan(child));
    }
  }

  // 直接的文本内容（无 tspan 包裹）
  String text = '';
  if (tspans.isEmpty) {
    text = _extractText(el);
  }

  return SvgText(
    x: _parseLength(el.getAttribute('x')) ?? 0,
    y: _parseLength(el.getAttribute('y')) ?? 0,
    text: text,
    fontSize: _parseLength(el.getAttribute('font-size')) ?? 16,
    fontFamily: el.getAttribute('font-family'),
    fill: el.getAttribute('fill'),
    fontWeight: el.getAttribute('font-weight'),
    fontStyle: el.getAttribute('font-style'),
    children: tspans,
  );
}

SvgTspan _parseTspan(XmlElement el) {
  return SvgTspan(
    text: _extractText(el),
    x: _parseLength(el.getAttribute('x')),
    y: _parseLength(el.getAttribute('y')),
    fontSize: _parseLength(el.getAttribute('font-size')),
    fontFamily: el.getAttribute('font-family'),
    fill: el.getAttribute('fill'),
    fontWeight: el.getAttribute('font-weight'),
    fontStyle: el.getAttribute('font-style'),
  );
}

SvgUse _parseUse(XmlElement el) {
  final href =
      el.getAttribute('href') ?? el.getAttribute('xlink:href') ?? '#';
  return SvgUse(
    href: href,
    x: _parseLength(el.getAttribute('x')) ?? 0,
    y: _parseLength(el.getAttribute('y')) ?? 0,
  );
}

/// 提取元素内联文本（递归拼接子节点文本内容）。
String _extractText(XmlElement el) {
  final buf = StringBuffer();
  void walk(XmlNode node) {
    if (node is XmlText) {
      buf.write(node.value);
    } else if (node is XmlElement) {
      for (final c in node.children) {
        walk(c);
      }
    }
  }

  for (final c in el.children) {
    walk(c);
  }
  return buf.toString();
}

/// 解析 `transform="translate(x, y)"`（仅支持 MathJax 最常见形式）。
(double, double) _parseTranslate(String? transform) {
  if (transform == null || transform.isEmpty) return (0, 0);
  final match = RegExp(
    r'translate\s*\(\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*\)',
  ).firstMatch(transform);
  if (match == null) return (0, 0);
  return (double.parse(match.group(1)!), double.parse(match.group(2)!));
}

/// 解析长度字符串。MathJax 输出常用 `12`、`12px`、`12.5ex`、`1em`。
/// 这里只接受 `px` 和纯数字；其它单位（`ex`/`em`/`pt`）粗略按 1 处理。
double? _parseLength(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.endsWith('px')) {
    return double.tryParse(s.substring(0, s.length - 2));
  }
  return double.tryParse(s);
}

double? _parseDouble(String? raw) {
  if (raw == null) return null;
  return double.tryParse(raw.trim());
}

/// 把 "x y w h" / "x,y,w,h" / "x;y;w;h" 拆成数字列表。
List<double> _splitNumbers(String s) {
  final parts = s.split(RegExp(r'[\s,;]+'));
  final out = <double>[];
  for (final p in parts) {
    if (p.isEmpty) continue;
    final v = double.tryParse(p);
    if (v != null) out.add(v);
  }
  return out;
}

/// 把字符串里所有未配对的 UTF-16 代理对替换为 U+FFFD，
/// 并过滤 XML 1.0 不允许的控制字符。保持原 UTF-8 编码合法性。
String _preClean(String input) {
  final safe = <int>[];
  for (final r in input.runes) {
    if (r >= 0xD800 && r <= 0xDFFF) {
      safe.add(0xFFFD);
    } else if (r == 0xFFFE || r == 0xFFFF || r == 0xFDD0) {
      safe.add(0xFFFD);
    } else if (r >= 0x00 && r < 0x20 &&
        r != 0x09 &&
        r != 0x0A &&
        r != 0x0D) {
      safe.add(0xFFFD);
    } else {
      safe.add(r);
    }
  }
  return String.fromCharCodes(safe);
}
