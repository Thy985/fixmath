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

    group('表格解析', () {
      test('解析简单表格', () {
        final elements = MarkdownParser.parse(
          '| 列1 | 列2 |\n| --- | --- |\n| A | B |',
        );
        final tables = elements.whereType<TableElement>().toList();
        expect(tables.length, 1);
        expect(tables[0].headers, ['列1', '列2']);
        expect(tables[0].rows.length, 1);
        expect(tables[0].rows[0], ['A', 'B']);
      });

      test('解析多行表格', () {
        final elements = MarkdownParser.parse(
          '| A | B |\n| - | - |\n| 1 | 2 |\n| 3 | 4 |',
        );
        final tables = elements.whereType<TableElement>().toList();
        expect(tables.length, 1);
        expect(tables[0].headers, ['A', 'B']);
        expect(tables[0].rows.length, 2);
      });

      test('忽略表格分隔行', () {
        final elements = MarkdownParser.parse(
          '| A | B |\n| - | - |\n| C | D |',
        );
        final tables = elements.whereType<TableElement>().toList();
        expect(tables.length, 1);
        expect(tables[0].rows.length, 1);
      });
    });

    group('列表嵌套', () {
      test('解析嵌套列表', () {
        final elements = MarkdownParser.parse(
          '- 水果\n  - 苹果\n  - 香蕉',
        );
        final items = elements.whereType<ListElement>().toList();
        expect(items.length, 1);
        expect(items[0].text, contains('苹果'));
        expect(items[0].indent, 1);
      });

      test('解析有序嵌套列表', () {
        final elements = MarkdownParser.parse(
          '1. 项目\n  1. 子项目',
        );
        final items = elements.whereType<ListElement>().toList();
        expect(items.length, 1);
        expect(items[0].ordered, true);
      });
    });

    group('代码块边界情况', () {
      test('处理未闭合的代码块', () {
        final elements = MarkdownParser.parse(
          '```python\nprint("未闭合"\n继续文本',
        );
        expect(elements.isNotEmpty, true);
      });

      test('处理多个代码块', () {
        final elements = MarkdownParser.parse(
          '```js\nconsole.log("first")\n```\n\n中间文本\n\n```dart\nvoid main() {}\n```',
        );
        final codeElements = elements.whereType<CodeElement>().toList();
        expect(codeElements.length, 2);
        expect(codeElements[0].language, 'js');
        expect(codeElements[1].language, 'dart');
      });
    });

    group('空行处理', () {
      test('空行生成EmptyLineElement', () {
        final elements = MarkdownParser.parse('文本\n\n更多文本');
        final emptyLines = elements.whereType<EmptyLineElement>().toList();
        expect(emptyLines.length, 1);
      });
    });
  });
}
