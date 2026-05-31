import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('MarkdownParser', () {
    test('空内容返回空列表', () {
      final elements = MarkdownParser.parse('');
      expect(elements, isEmpty);
    });

    test('解析标题', () {
      final elements = MarkdownParser.parse('# 一级标题');
      expect(elements.length, 1);
      expect(elements[0].type, ElementType.heading);
      expect(elements[0].content, '一级标题');
      expect(elements[0].level, 1);
    });

    test('解析多级标题', () {
      final elements = MarkdownParser.parse('## 二级标题\n### 三级标题');
      expect(elements.length, 2);
      expect(elements[0].type, ElementType.heading);
      expect(elements[0].level, 2);
      expect(elements[1].type, ElementType.heading);
      expect(elements[1].level, 3);
    });

    test('解析无序列表示', () {
      final elements = MarkdownParser.parse('- 列表项1\n- 列表项2');
      final listItems = elements.where((e) => e.type == ElementType.list).toList();
      expect(listItems.length, 2);
      expect(listItems[0].content, '列表项1');
      expect(listItems[1].content, '列表项2');
    });

    test('解析有序列表', () {
      final elements = MarkdownParser.parse('1. 第一项\n2. 第二项');
      final listItems = elements.where((e) => e.type == ElementType.list).toList();
      expect(listItems.length, 2);
      expect(listItems[0].content, '第一项');
      expect(listItems[0].attributes?['ordered'], true);
    });

    test('解析引用块', () {
      final elements = MarkdownParser.parse('> 这是一段引用');
      expect(elements.length, 1);
      expect(elements[0].type, ElementType.blockquote);
      expect(elements[0].content, '这是一段引用');
    });

    test('解析代码块', () {
      final elements = MarkdownParser.parse('```dart\nprint("hello");\n```');
      final codeElements = elements.where((e) => e.type == ElementType.code).toList();
      expect(codeElements.isNotEmpty, true);
    });

    test('解析包含行内公式的段落', () {
      final elements = MarkdownParser.parse('这是一段包含 \$E=mc^2\$ 的文本');
      final paragraphs = elements.where((e) => e.type == ElementType.paragraph).toList();
      expect(paragraphs.isNotEmpty, true);
      final children = paragraphs[0].children;
      expect(children, isNotNull);
      final formula = children!.where((c) => c.type == ElementType.formula).toList();
      expect(formula.isNotEmpty, true);
    });

    test('解析包含块级公式的段落', () {
      final elements = MarkdownParser.parse('\$\$\\int_0^1 x^2 dx\$\$');
      final paragraphs = elements.where((e) => e.type == ElementType.paragraph).toList();
      expect(paragraphs.isNotEmpty, true);
      final children = paragraphs[0].children;
      expect(children, isNotNull);
      final formula = children!.where((c) => c.type == ElementType.formula).toList();
      expect(formula.isNotEmpty, true);
    });

    test('空行应被解析', () {
      final elements = MarkdownParser.parse('第一段\n\n第二段');
      final paragraphs = elements.where((e) => e.type == ElementType.paragraph).toList();
      expect(paragraphs.length, 2);
    });
  });
}