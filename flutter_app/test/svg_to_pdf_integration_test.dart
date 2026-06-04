/// SvgPdfWidget 集成测试。
///
/// 验证自写 SVG → PDF 矢量绘制器能正确处理真实场景：
/// 1. 含未配对代理对的 SVG（之前触发 "Unexpected extension byte" 的根因）
/// 2. 完整 pw.Document → save() 流程，验证 PDF 字节流正常生成
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:formula_fix/core/renderers/svg_ast.dart';
import 'package:formula_fix/core/renderers/svg_parser.dart';
import 'package:formula_fix/core/renderers/svg_to_pdf.dart';

void main() {
  group('SvgPdfWidget 集成', () {
    test('含未配对 high surrogate 的 SVG 可嵌入 PDF 而不抛错', () async {
      // 模拟 WebView 桥接出的 SVG，含孤立 U+D800
      final svg = '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 100 30">'
          '<text x="5" y="20" font-size="16" fill="#000">'
          'a${String.fromCharCode(0xD800)}b'
          '</text></svg>';

      final root = parseSvgString(svg);
      expect(root.children, isNotEmpty);

      // 构造 pw.Document 并嵌入 SvgPdfWidget
      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (ctx) => pw.Center(
          child: SvgPdfWidget(root: root),
        ),
      ));

      // save() 不应抛错
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      // PDF 文件头
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('含未配对 low surrogate 的 SVG 可嵌入 PDF', () async {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 200 40">'
          '<text x="0" y="20" font-size="14">x${String.fromCharCode(0xDC00)}y</text>'
          '<rect x="0" y="0" width="200" height="40" fill="none" stroke="#000"/>'
          '</svg>';

      final root = parseSvgString(svg);
      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (ctx) => SvgPdfWidget(root: root),
      ));

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });

    test('复杂嵌套 SVG（g/rect/circle/path/text/tspan）可嵌入 PDF', () async {
      final svg = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" width="300" height="100" viewBox="0 0 300 100">
  <g transform="translate(10, 10)">
    <rect x="0" y="0" width="50" height="30" fill="#ff0000" stroke="#000000" stroke-width="1"/>
    <circle cx="100" cy="20" r="15" fill="#00ff00"/>
    <ellipse cx="180" cy="20" rx="20" ry="10" fill="#0000ff"/>
    <line x1="0" y1="60" x2="200" y2="60" stroke="#333333" stroke-width="2"/>
    <path d="M 0 80 L 30 70 L 60 80 Z" fill="#ffff00" stroke="#888888"/>
    <text x="0" y="95" font-size="12" fill="#000000">Hello</text>
  </g>
</svg>''';

      final root = parseSvgString(svg);
      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (ctx) => SvgPdfWidget(root: root),
      ));

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });

    test('MathJax 风格的 mjx-container 包装 SVG 也能解析', () async {
      // MathJax 在 mjx-container 内部嵌入 <svg>
      final svg = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<mjx-container xmlns:mjx="http://www.w3.org/1998/Math/MathML" class="mjx-container">
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="20" viewBox="0 0 100 20">
  <g stroke="currentColor" fill="currentColor" stroke-width="0" transform="matrix(1 0 0 -1 0 0)">
    <path d="M 0 0 L 10 10 Z" stroke="none"/>
    <text x="20" y="15" font-size="14">x²</text>
  </g>
</svg>
</mjx-container>''';
      final root = parseSvgString(svg);
      expect(root.viewBoxWidth, 100);
      expect(root.viewBoxHeight, 20);
      // 至少有一个 g
      expect(root.children.whereType<SvgGroup>(), isNotEmpty);
    });

    test('空 SVG 输入也能保存 PDF（不退化）', () async {
      final root = parseSvgString('');
      // 应包含一个 SvgUnsupported 占位
      expect(root.children.whereType<SvgUnsupported>(), hasLength(1));

      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (ctx) => SvgPdfWidget(root: root),
      ));

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });

    test('完全无效的 SVG 也能保存 PDF（占位文本显示）', () async {
      final root = parseSvgString('garbage not xml at all');
      // 应包含 unsupported 占位
      expect(root.children.whereType<SvgUnsupported>(), isNotEmpty);

      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (ctx) => SvgPdfWidget(root: root),
      ));

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });

    test('含未知元素的 SVG 嵌入 PDF（[unsupported] 占位）', () async {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 100 30">'
          '<rect x="0" y="0" width="20" height="20" fill="#abc"/>'
          '<pattern id="p1"/>' // 不支持
          '<mask id="m1"/>' // 不支持
          '<text x="0" y="25" font-size="12">hi</text>'
          '</svg>';
      final root = parseSvgString(svg);
      // rect 和 text 应被解析
      expect(root.children.whereType<SvgRect>(), hasLength(1));
      expect(root.children.whereType<SvgText>(), hasLength(1));
      // pattern/mask 降级为 unsupported
      expect(root.children.whereType<SvgUnsupported>().length, 2);

      final doc = pw.Document();
      doc.addPage(pw.Page(
        build: (ctx) => SvgPdfWidget(root: root),
      ));

      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });
  });
}
