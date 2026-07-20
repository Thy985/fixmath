/// svg_parser 单元测试。
///
/// 覆盖 SVG 字符串 → AST 解析器的关键行为：viewBox、变换、未配对代理对
/// 清洗、未知元素降级、空输入。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/renderers/svg_ast.dart';
import 'package:formula_fix/core/renderers/svg_parser.dart';

void main() {
  group('parseSvgString - 基础解析', () {
    test('空字符串返回带 SvgUnsupported 占位的 SvgRoot', () {
      final root = parseSvgString('');
      expect(root.children, hasLength(1));
      expect(root.children.first, isA<SvgUnsupported>());
      expect((root.children.first as SvgUnsupported).reason, contains('empty'));
    });

    test('无效 XML 返回带 unsupported 的 root（不抛错）', () {
      // 不应抛错
      final root = parseSvgString('<<not valid xml');
      expect(root.children, isNotEmpty);
      expect(root.children.first, isA<SvgUnsupported>());
    });

    test('无 <svg> 标签时返回 unsupported', () {
      final root = parseSvgString('<html><body>nope</body></html>');
      expect(root.children, isNotEmpty);
      expect(root.children.first, isA<SvgUnsupported>());
      expect((root.children.first as SvgUnsupported).reason,
          contains('no <svg>'));
    });
  });

  group('parseSvgString - viewBox 与尺寸', () {
    test('解析 viewBox="x y w h" 形式', () {
      final root = parseSvgString(
          '<svg viewBox="10 20 300 60" xmlns="http://www.w3.org/2000/svg"><rect/></svg>');
      expect(root.viewBoxX, 10);
      expect(root.viewBoxY, 20);
      expect(root.viewBoxWidth, 300);
      expect(root.viewBoxHeight, 60);
    });

    test('解析 viewBox 逗号分隔形式', () {
      final root = parseSvgString(
          '<svg viewBox="0,0,400,80" xmlns="http://www.w3.org/2000/svg"><rect/></svg>');
      expect(root.viewBoxWidth, 400);
      expect(root.viewBoxHeight, 80);
    });

    test('无 viewBox 时退到 width/height 属性', () {
      final root = parseSvgString(
          '<svg width="200" height="40" xmlns="http://www.w3.org/2000/svg"><rect/></svg>');
      expect(root.viewBoxWidth, 200);
      expect(root.viewBoxHeight, 40);
    });

    test('viewBox 解析失败时使用 300x60 默认值', () {
      final root = parseSvgString(
          '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>');
      expect(root.viewBoxWidth, 300);
      expect(root.viewBoxHeight, 60);
    });
  });

  group('parseSvgString - 元素降级', () {
    test('未知元素降级为 SvgUnsupported', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <linearGradient id="g1"/>
          <rect x="0" y="0" width="10" height="10"/>
        </svg>''');
      // linearGradient 不被支持，应作为 unsupported
      expect(root.children.whereType<SvgUnsupported>(), isNotEmpty);
      // rect 仍应被解析
      expect(root.children.whereType<SvgRect>(), hasLength(1));
    });

    test('<use> 元素被记录但不抛错', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <use href="#foo" x="5" y="10"/>
        </svg>''');
      expect(root.children.whereType<SvgUse>(), hasLength(1));
      final use = root.children.whereType<SvgUse>().first;
      expect(use.href, '#foo');
      expect(use.x, 5);
      expect(use.y, 10);
    });

    test('<defs>/<style>/<title> 等元数据不产生子节点', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs><rect id="x" x="0" y="0" width="1" height="1"/></defs>
          <style>.foo{stroke:red}</style>
          <title>Title</title>
        </svg>''');
      // 所有元数据被吞掉，root 没有 children
      expect(root.children, isEmpty);
    });
  });

  group('parseSvgString - 形状属性', () {
    test('rect 解析 x/y/width/height/fill/stroke', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect x="1.5" y="2" width="3" height="4" fill="#ff0000" stroke="#00ff00" stroke-width="2"/>
        </svg>''');
      final r = root.children.whereType<SvgRect>().first;
      expect(r.x, 1.5);
      expect(r.y, 2);
      expect(r.width, 3);
      expect(r.height, 4);
      expect(r.fill, '#ff0000');
      expect(r.stroke, '#00ff00');
      expect(r.strokeWidth, 2);
    });

    test('line 解析 x1/y1/x2/y2', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <line x1="0" y1="0" x2="100" y2="50"/>
        </svg>''');
      final l = root.children.whereType<SvgLine>().first;
      expect(l.x1, 0);
      expect(l.y1, 0);
      expect(l.x2, 100);
      expect(l.y2, 50);
    });

    test('circle 解析 cx/cy/r', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="60" r="7" fill="#000"/>
        </svg>''');
      final c = root.children.whereType<SvgCircle>().first;
      expect(c.cx, 50);
      expect(c.cy, 60);
      expect(c.r, 7);
    });

    test('ellipse 解析 cx/cy/rx/ry', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="10" ry="20"/>
        </svg>''');
      final e = root.children.whereType<SvgEllipse>().first;
      expect(e.rx, 10);
      expect(e.ry, 20);
    });

    test('path 提取 d 属性', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M 0 0 L 10 10 Z" fill="#abc"/>
        </svg>''');
      final p = root.children.whereType<SvgPath>().first;
      expect(p.d, 'M 0 0 L 10 10 Z');
      expect(p.fill, '#abc');
    });
  });

  group('parseSvgString - 文本与 tspan', () {
    test('text 元素提取 x/y/text/font-size/fill', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <text x="5" y="10" font-size="16" fill="#ff0000">Hello</text>
        </svg>''');
      final t = root.children.whereType<SvgText>().first;
      expect(t.x, 5);
      expect(t.y, 10);
      expect(t.text, 'Hello');
      expect(t.fontSize, 16);
      expect(t.fill, '#ff0000');
    });

    test('tspan 子节点被收集', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <text x="0" y="0">
            <tspan x="0" y="0" fill="red">A</tspan>
            <tspan x="10" y="0" fill="blue">B</tspan>
          </text>
        </svg>''');
      final t = root.children.whereType<SvgText>().first;
      expect(t.children, hasLength(2));
      expect(t.children[0].text, 'A');
      expect(t.children[0].fill, 'red');
      expect(t.children[1].text, 'B');
      expect(t.children[1].fill, 'blue');
    });
  });

  group('parseSvgString - 变换', () {
    test('g 元素 transform="translate(x, y)" 被解析', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <g transform="translate(10, 20)">
            <rect x="0" y="0" width="5" height="5"/>
          </g>
        </svg>''');
      final g = root.children.whereType<SvgGroup>().first;
      expect(g.translateX, 10);
      expect(g.translateY, 20);
      expect(g.children.whereType<SvgRect>(), hasLength(1));
    });

    test('g 无 transform 时平移为 0', () {
      final root = parseSvgString('''<?xml version="1.0"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <g><rect x="0" y="0" width="5" height="5"/></g>
        </svg>''');
      final g = root.children.whereType<SvgGroup>().first;
      expect(g.translateX, 0);
      expect(g.translateY, 0);
    });
  });

  group('parseSvgString - 编码安全', () {
    test('未配对 high surrogate (U+D800) 被替换为 U+FFFD，不抛错', () {
      // U+D800 是 high surrogate 单独出现，应被清洗为 U+FFFD
      final input = '<svg xmlns="http://www.w3.org/2000/svg">'
          'text<tspan>${String.fromCharCode(0xD800)}</tspan>here'
          '</svg>';
      // 不应抛错
      final root = parseSvgString(input);
      expect(root, isA<SvgRoot>());
    });

    test('未配对 low surrogate (U+DC00) 被替换为 U+FFFD', () {
      final input = '<svg xmlns="http://www.w3.org/2000/svg">'
          'text${String.fromCharCode(0xDC00)}here'
          '</svg>';
      final root = parseSvgString(input);
      expect(root, isA<SvgRoot>());
    });

    test('非字符 (U+FFFE, U+FFFF) 被替换', () {
      final input = '<svg xmlns="http://www.w3.org/2000/svg">'
          'a${String.fromCharCode(0xFFFE)}b${String.fromCharCode(0xFFFF)}c'
          '</svg>';
      final root = parseSvgString(input);
      expect(root, isA<SvgRoot>());
    });

    test('合法非 BMP 字符 (U+1D44C) 不会触发清洗替换', () {
      // U+1D44C = MATHEMATICAL ITALIC SMALL A
      final input = '<svg xmlns="http://www.w3.org/2000/svg">'
          'before${String.fromCharCode(0x1D44C)}after'
          '</svg>';
      final root = parseSvgString(input);
      expect(root, isA<SvgRoot>());
    });

    test('C0 控制字符 (U+0001) 被替换为 U+FFFD', () {
      final input = '<svg xmlns="http://www.w3.org/2000/svg">'
          'a${String.fromCharCode(0x01)}b'
          '</svg>';
      final root = parseSvgString(input);
      expect(root, isA<SvgRoot>());
    });
  });

  group('parseSvgString - 真实 MathJax SVG 形状', () {
    test('嵌套 g/rect/text 类似 MathJax 输出', () {
      // MathJax 输出的 SVG 通常是这样的形状
      const svg = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="12.361ex" height="2.176ex" viewBox="0 -863.1 5321.5 936.9" role="img" focusable="false" aria-hidden="true">
<g stroke="currentColor" fill="currentColor" stroke-width="0" transform="matrix(1 0 0 -1 0 0)">
  <g>
    <path d="M 0 0 L 100 50 Z" stroke="none"/>
    <text x="10" y="40" font-size="100">x</text>
  </g>
</g>
</svg>''';
      final root = parseSvgString(svg);
      expect(root.viewBoxWidth, closeTo(5321.5, 0.01));
      expect(root.viewBoxHeight, closeTo(936.9, 0.01));
      // 顶层 g
      final g = root.children.whereType<SvgGroup>().first;
      expect(g, isNotNull);
      // 嵌套 g
      expect(g.children.whereType<SvgGroup>(), hasLength(1));
      // path + text
      final innerG = g.children.whereType<SvgGroup>().first;
      expect(innerG.children.whereType<SvgPath>(), hasLength(1));
      expect(innerG.children.whereType<SvgText>(), hasLength(1));
      final t = innerG.children.whereType<SvgText>().first;
      expect(t.text, 'x');
    });
  });
}
