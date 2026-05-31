import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('MarkdownParser', () {
    test('空内容返回空列表', () {
      expect(MarkdownParser.parse(''), isEmpty);
    });

    test('解析标题', () {
      final elements = MarkdownParser.parse('# 一级标题');
      expect(elements.length, 1);
      expect(elements[0], isA<HeadingElement>());
      final h = elements[0] as HeadingElement;
      expect(h.level, 1);
      expect(h.text, '一级标题');
    });

    test('解析多级标题', () {
      final elements = MarkdownParser.parse('## 二级标题\n### 三级标题');
      expect(elements.length, 2);
      final h1 = elements[0] as HeadingElement;
      final h2 = elements[1] as HeadingElement;
      expect(h1.level, 2);
      expect(h2.level, 3);
    });

    test('解析无序列表', () {
      final elements = MarkdownParser.parse('- 列表项1\n- 列表项2');
      final items = elements.whereType<ListElement>().toList();
      expect(items.length, 2);
      expect(items[0].text, '列表项1');
      expect(items[1].text, '列表项2');
    });

    test('解析有序列表', () {
      final elements = MarkdownParser.parse('1. 第一项\n2. 第二项');
      final items = elements.whereType<ListElement>().toList();
      expect(items.length, 2);
      expect(items[0].ordered, true);
    });

    test('解析引用块', () {
      final elements = MarkdownParser.parse('> 这是一段引用');
      expect(elements.length, 1);
      expect(elements[0], isA<BlockquoteElement>());
      final bq = elements[0] as BlockquoteElement;
      expect(bq.text, '这是一段引用');
    });

    test('解析代码块', () {
      final elements = MarkdownParser.parse('```dart\nprint("hello");\n```');
      final codeElements = elements.whereType<CodeElement>().toList();
      expect(codeElements.length, 1);
      expect(codeElements[0].language, 'dart');
    });

    test('解析包含行内公式的段落', () {
      final elements = MarkdownParser.parse('这是一段包含 \$E=mc^2\$ 的文本');
      final paragraphs = elements.whereType<ParagraphElement>().toList();
      expect(paragraphs.isNotEmpty, true);
      final hasFormula = paragraphs[0].children.any((c) => c is FormulaElement);
      expect(hasFormula, true);
    });

    test('解析包含块级公式的段落', () {
      final elements = MarkdownParser.parse(r'$$\int_0^1 x^2 dx$$');
      final paragraphs = elements.whereType<ParagraphElement>().toList();
      expect(paragraphs.isNotEmpty, true);
      final hasDisplayFormula = paragraphs[0].children.any(
        (c) => c is FormulaElement && c.displayMode,
      );
      expect(hasDisplayFormula, true);
    });

    test('代码块多行合并为单个元素', () {
      final elements = MarkdownParser.parse('```python\nprint("line1")\nprint("line2")\n```');
      final codeElements = elements.whereType<CodeElement>().toList();
      expect(codeElements.length, 1);
      expect(codeElements[0].code, contains('line1'));
      expect(codeElements[0].code, contains('line2'));
    });

    test('解析Mermaid代码块', () {
      final elements = MarkdownParser.parse('```mermaid\ngraph TD\n  A-->B\n```');
      final mermaidElements = elements.whereType<MermaidElement>().toList();
      expect(mermaidElements.length, 1);
      expect(mermaidElements[0].code, contains('graph TD'));
    });
  });
}
