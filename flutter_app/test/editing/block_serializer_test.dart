/// TC-EDIT-3: BlockEditor 双向映射单元测试。
///
/// 对应 ADR-0007 §1.3（Wrapping）+ §Phase 2.3 三项交付。
///
/// Round-trip 判定采用 **AST equivalence**（非字符串等价）：
/// `parse(source) == parse(fromElement(toElement(source, type)))`
/// Markdown 不是 canonical 形式（`*hello*` 与 `_hello_` 字符串不等但 AST 等价）。
///
/// InlineSerializer 的独立测试见 [inline_serializer_test.dart]。
/// AST 等价性 helper 见 [test/helpers/ast_equality.dart]。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/data/models/document.dart';

import '../helpers/ast_equality.dart';

void main() {
  group('TC-EDIT-3.1 toElement 正样本', () {
    test('heading', () {
      final element = toElement('# Title', BlockType.heading);
      expect(element, isA<HeadingElement>());
      expect((element as HeadingElement).level, equals(1));
      expect(element.text, equals('Title'));
    });

    test('heading level 6', () {
      final element = toElement('###### Deep', BlockType.heading);
      expect((element as HeadingElement).level, equals(6));
      expect(element.text, equals('Deep'));
    });

    test('paragraph with inline', () {
      final element = toElement('hello **world**', BlockType.paragraph);
      expect(element, isA<ParagraphElement>());
      final para = element as ParagraphElement;
      expect(para.children.length, equals(2));
      expect(para.children[0], isA<TextElement>());
      expect(para.children[1], isA<BoldElement>());
    });

    test('listItem unordered', () {
      final element = toElement('- item', BlockType.listItem);
      expect(element, isA<ListElement>());
      final list = element as ListElement;
      expect(list.ordered, isFalse);
      expect(list.indent, equals(0));
    });

    test('listItem ordered', () {
      final element = toElement('1. first', BlockType.listItem);
      expect(element, isA<ListElement>());
      expect((element as ListElement).ordered, isTrue);
    });

    test('listItem with indent', () {
      final element = toElement('  - nested', BlockType.listItem);
      expect((element as ListElement).indent, equals(1));
    });

    test('taskListItem unchecked', () {
      final element = toElement('- [ ] todo', BlockType.taskListItem);
      expect(element, isA<TaskListItemElement>());
      expect((element as TaskListItemElement).checked, isFalse);
    });

    test('taskListItem checked', () {
      final element = toElement('- [x] done', BlockType.taskListItem);
      expect((element as TaskListItemElement).checked, isTrue);
    });

    test('taskListItem checked uppercase X', () {
      final element = toElement('- [X] done', BlockType.taskListItem);
      expect((element as TaskListItemElement).checked, isTrue);
    });

    test('code with language', () {
      final element = toElement('```dart\nprint(1);\n```', BlockType.code);
      expect(element, isA<CodeElement>());
      final code = element as CodeElement;
      expect(code.language, equals('dart'));
      expect(code.code, equals('print(1);'));
    });

    test('code without language', () {
      final element = toElement('```\nplain\n```', BlockType.code);
      expect(element, isA<CodeElement>());
      expect((element as CodeElement).language, isNull);
    });

    test('code with mermaid language returns MermaidElement', () {
      final element = toElement('```mermaid\ngraph TD\n```', BlockType.code);
      expect(element, isA<MermaidElement>());
      expect((element as MermaidElement).code, equals('graph TD'));
    });

    test('mermaid BlockType', () {
      final element = toElement('```mermaid\ngraph TD\n```', BlockType.mermaid);
      expect(element, isA<MermaidElement>());
    });

    test('table with header and rows', () {
      const source = '| a | b |\n|---|---|\n| 1 | 2 |';
      final element = toElement(source, BlockType.table);
      expect(element, isA<TableElement>());
      final table = element as TableElement;
      expect(table.headers, equals(['a', 'b']));
      expect(table.rows.length, equals(1));
      expect(table.rows[0], equals(['1', '2']));
    });

    test('blockquote', () {
      final element = toElement('> quote', BlockType.blockquote);
      expect(element, isA<BlockquoteElement>());
      expect((element as BlockquoteElement).text, equals('quote'));
    });

    test('horizontalRule', () {
      final element = toElement('---', BlockType.horizontalRule);
      expect(element, isA<HorizontalRuleElement>());
    });
  });

  group('TC-EDIT-3.2 toElement 边界与降级', () {
    test('empty source for paragraph', () {
      final element = toElement('', BlockType.paragraph);
      expect(element, isA<ParagraphElement>());
      expect((element as ParagraphElement).children, isEmpty);
    });

    test('invalid heading 降级 level=1', () {
      // 无 `# ` 前缀，降级为 level=1 + 原文
      final element = toElement('no heading marker', BlockType.heading);
      expect((element as HeadingElement).level, equals(1));
      expect(element.text, equals('no heading marker'));
    });

    test('invalid list 降级 unordered + 0 indent', () {
      final element = toElement('not a list', BlockType.listItem);
      final list = element as ListElement;
      expect(list.ordered, isFalse);
      expect(list.indent, equals(0));
    });

    test('invalid code 降级 no language', () {
      final element = toElement('not a code fence', BlockType.code);
      expect(element, isA<CodeElement>());
      expect((element as CodeElement).language, isNull);
    });

    test('horizontalRule ignores source content', () {
      // horizontalRule 永远返回 const，忽略 source
      final element = toElement('anything', BlockType.horizontalRule);
      expect(element, isA<HorizontalRuleElement>());
    });
  });

  group('TC-EDIT-3.3 fromElement 正样本', () {
    test('heading', () {
      const element = HeadingElement(level: 2, text: 'Hello');
      expect(fromElement(element), equals('## Hello'));
    });

    test('paragraph with text', () {
      const element = ParagraphElement(children: [TextElement('hello')]);
      expect(fromElement(element), equals('hello'));
    });

    test('listItem unordered', () {
      const element = ListElement(
        children: [TextElement('item')],
        ordered: false,
        indent: 0,
      );
      expect(fromElement(element), equals('- item'));
    });

    test('listItem ordered', () {
      const element = ListElement(
        children: [TextElement('first')],
        ordered: true,
        indent: 0,
      );
      expect(fromElement(element), equals('1. first'));
    });

    test('listItem with indent 2', () {
      const element = ListElement(
        children: [TextElement('nested')],
        ordered: false,
        indent: 2,
      );
      expect(fromElement(element), equals('    - nested'));
    });

    test('taskListItem unchecked', () {
      const element = TaskListItemElement(
        children: [TextElement('todo')],
        checked: false,
      );
      expect(fromElement(element), equals('- [ ] todo'));
    });

    test('taskListItem checked', () {
      const element = TaskListItemElement(
        children: [TextElement('done')],
        checked: true,
      );
      expect(fromElement(element), equals('- [x] done'));
    });

    test('code with language', () {
      const element = CodeElement(code: 'print(1);', language: 'dart');
      expect(fromElement(element), equals('```dart\nprint(1);\n```'));
    });

    test('code without language', () {
      const element = CodeElement(code: 'plain', language: null);
      expect(fromElement(element), equals('```\nplain\n```'));
    });

    test('mermaid', () {
      const element = MermaidElement(code: 'graph TD');
      expect(fromElement(element), equals('```mermaid\ngraph TD\n```'));
    });

    test('table', () {
      const element = TableElement(
        headers: ['a', 'b'],
        rows: [['1', '2']],
      );
      const expected = '|a|b|\n|---|---|\n|1|2|';
      expect(fromElement(element), equals(expected));
    });

    test('blockquote', () {
      const element = BlockquoteElement(text: 'quote');
      expect(fromElement(element), equals('> quote'));
    });

    test('horizontalRule', () {
      const element = HorizontalRuleElement();
      expect(fromElement(element), equals('---'));
    });

    test('EmptyLineElement throws ArgumentError', () {
      expect(
        () => fromElement(const EmptyLineElement()),
        throwsArgumentError,
      );
    });
  });

  group('TC-EDIT-3.4 Round-trip AST equivalence', () {
    // Round-trip 判定：parse(source) == parse(fromElement(toElement(source, type)))
    // 用 astDeepEquals 递归比较 AST 字段。

    test('heading round-trip', () {
      const source = '# Title';
      final e1 = toElement(source, BlockType.heading);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.heading);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('paragraph round-trip with bold', () {
      const source = 'hello **world**';
      final e1 = toElement(source, BlockType.paragraph);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.paragraph);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('paragraph round-trip with formula', () {
      const source = r'formula $\frac{a}{b}$ end';
      final e1 = toElement(source, BlockType.paragraph);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.paragraph);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('listItem unordered round-trip', () {
      const source = '- item';
      final e1 = toElement(source, BlockType.listItem);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.listItem);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('listItem ordered round-trip', () {
      const source = '1. first';
      final e1 = toElement(source, BlockType.listItem);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.listItem);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('taskListItem round-trip', () {
      const source = '- [x] done';
      final e1 = toElement(source, BlockType.taskListItem);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.taskListItem);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('code round-trip', () {
      const source = '```dart\nprint(1);\n```';
      final e1 = toElement(source, BlockType.code);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.code);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('mermaid round-trip', () {
      const source = '```mermaid\ngraph TD\n```';
      final e1 = toElement(source, BlockType.mermaid);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.mermaid);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('table round-trip', () {
      const source = '| a | b |\n|---|---|\n| 1 | 2 |';
      final e1 = toElement(source, BlockType.table);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.table);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('blockquote round-trip', () {
      const source = '> quote';
      final e1 = toElement(source, BlockType.blockquote);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.blockquote);
      expect(astDeepEquals(e1, e2), isTrue);
    });

    test('horizontalRule round-trip', () {
      const source = '---';
      final e1 = toElement(source, BlockType.horizontalRule);
      final serialized = fromElement(e1);
      final e2 = toElement(serialized, BlockType.horizontalRule);
      expect(astDeepEquals(e1, e2), isTrue);
    });
  });
}
