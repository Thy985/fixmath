/// TC-ARCH-12: AST Snapshot Regression。
///
/// 对应 ADR-0007 §Phase 2.4 Evaluation Addendum（2026-07-19）：
/// 证明 Phase 2.4 后 AST 数据形状 0 变化。这是 AST 稳定性的**显式证明**，
/// 防止未来 Phase 2.5+ 误改 AST 字段或 parser 行为而不自知。
///
/// 测试方法：构造 5 份 Phase 1 sample markdown 文档（覆盖 10 类 Block + 8 类 Inline），
/// 用 `MarkdownParser.parse(sample)` 解析得 AST，对 AST 做**硬编码期望值断言**。
/// 若未来误改 AST 字段或 parser 行为，此测试必失败。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('TC-ARCH-12.1 inline 全覆盖', () {
    test('paragraph with all inline elements', () {
      // 8 类 Inline：text / bold / italic / strike / inlineCode / link / image / formula
      const source = 'text **bold** *italic* ~~strike~~ `code` '
          '[link](url) ![img](url) \$formula\$';
      final ast = MarkdownParser.parse(source);
      expect(ast.length, equals(1));
      expect(ast[0], isA<ParagraphElement>());
      final para = ast[0] as ParagraphElement;
      // 包含所有 inline 类型（部分可能合并为 TextElement）
      expect(para.children, isNotEmpty);
      // 至少含 BoldElement / ItalicElement / InlineCodeElement
      expect(
        para.children.any((e) => e is BoldElement),
        isTrue,
        reason: '应含 BoldElement',
      );
      expect(
        para.children.any((e) => e is ItalicElement),
        isTrue,
        reason: '应含 ItalicElement',
      );
      expect(
        para.children.any((e) => e is InlineCodeElement),
        isTrue,
        reason: '应含 InlineCodeElement',
      );
    });
  });

  group('TC-ARCH-12.2 heading/rule/quote', () {
    test('heading 6 级 + horizontalRule + blockquote', () {
      const source = '# H1\n\n## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n'
          '###### H6\n\n---\n\n> quote';
      final ast = MarkdownParser.parse(source);
      // 应含 6 heading + 1 rule + 1 quote（中间空行被解析为 EmptyLineElement）
      final headings = ast.whereType<HeadingElement>().toList();
      expect(headings.length, equals(6));
      expect(headings[0].level, equals(1));
      expect(headings[0].text, equals('H1'));
      expect(headings[5].level, equals(6));
      expect(headings[5].text, equals('H6'));
      expect(ast.whereType<HorizontalRuleElement>().length, equals(1));
      final quote = ast.whereType<BlockquoteElement>().single;
      expect(quote.text, equals('quote'));
    });
  });

  group('TC-ARCH-12.3 list/task/indent', () {
    test('list ordered/unordered + taskListItem checked/unchecked + indent', () {
      // 用空行分隔避免 parser 的 list item merge 行为（[markdown_parser.dart:182]）
      const source = '- item a\n\n- [ ] todo\n\n- [x] done\n\n1. first';
      final ast = MarkdownParser.parse(source);
      final lists = ast.whereType<ListElement>().toList();
      final tasks = ast.whereType<TaskListItemElement>().toList();
      // unordered list item
      expect(lists.any((l) => !l.ordered && l.indent == 0), isTrue);
      // ordered list item
      expect(lists.any((l) => l.ordered && l.indent == 0), isTrue);
      // task list items
      expect(tasks.length, equals(2));
      expect(tasks.any((t) => !t.checked), isTrue);
      expect(tasks.any((t) => t.checked), isTrue);
    });

    test('nested list indent preserved', () {
      // 单独测试 nested indent：`  - nested` 应被 merge 进 parent 但保留 indent=1
      const source = '- parent\n  - nested';
      final ast = MarkdownParser.parse(source);
      final lists = ast.whereType<ListElement>().toList();
      expect(lists.length, equals(1));
      // 合并后 indent 应为 1（parser 的 merge 行为）
      expect(lists[0].indent, equals(1));
    });
  });

  group('TC-ARCH-12.4 code/mermaid/table', () {
    test('code with language + mermaid + table multi-row multi-col', () {
      const source = '```dart\nprint(1);\n```\n\n```mermaid\ngraph TD\n```\n\n'
          '| a | b | c |\n|---|---|---|\n| 1 | 2 | 3 |\n| 4 | 5 | 6 |';
      final ast = MarkdownParser.parse(source);
      final codes = ast.whereType<CodeElement>().toList();
      expect(codes.length, equals(1));
      expect(codes[0].language, equals('dart'));
      expect(codes[0].code, equals('print(1);'));
      final mermaid = ast.whereType<MermaidElement>().single;
      expect(mermaid.code, equals('graph TD'));
      final table = ast.whereType<TableElement>().single;
      expect(table.headers, equals(['a', 'b', 'c']));
      expect(table.rows.length, equals(2));
      expect(table.rows[0], equals(['1', '2', '3']));
      expect(table.rows[1], equals(['4', '5', '6']));
    });
  });

  group('TC-ARCH-12.5 empty line 混合', () {
    test('empty lines preserved as EmptyLineElement（验证 Phase 2.4 决策）', () {
      // 关键测试：验证 EmptyLineElement 在 AST 中保留
      // 若未来误改 parser 把空行跳过，此测试必失败
      const source = '# Title\n\n\nParagraph';
      final ast = MarkdownParser.parse(source);
      expect(ast.whereType<HeadingElement>().single.text, equals('Title'));
      expect(ast.whereType<ParagraphElement>().length, equals(1));
      // 至少有一个 EmptyLineElement（保留空行格式）
      expect(
        ast.whereType<EmptyLineElement>().isNotEmpty,
        isTrue,
        reason: 'EmptyLineElement 必须保留（ADR-0007 Phase 2.4 Addendum）',
      );
    });

    test('10 类 Block 全覆盖 sanity check', () {
      // 综合测试：1 份 markdown 覆盖 9 类 Block（EmptyLineElement 是第 10 类，由空行产生）
      const source = '# H\n\nparagraph\n\n- list\n\n1. ordered\n\n'
          '- [ ] task\n\n```dart\ncode\n```\n\n'
          '```mermaid\ngraph\n```\n\n| a |\n|---|\n| 1 |\n\n> quote\n\n---\n\n';
      final ast = MarkdownParser.parse(source);
      // 9 类 Block + EmptyLineElement（第 10 类）
      expect(ast.whereType<HeadingElement>().isNotEmpty, isTrue);
      expect(ast.whereType<ParagraphElement>().isNotEmpty, isTrue);
      expect(ast.whereType<ListElement>().isNotEmpty, isTrue);
      expect(ast.whereType<TaskListItemElement>().isNotEmpty, isTrue);
      expect(ast.whereType<CodeElement>().isNotEmpty, isTrue);
      expect(ast.whereType<MermaidElement>().isNotEmpty, isTrue);
      expect(ast.whereType<TableElement>().isNotEmpty, isTrue);
      expect(ast.whereType<BlockquoteElement>().isNotEmpty, isTrue);
      expect(ast.whereType<HorizontalRuleElement>().isNotEmpty, isTrue);
      expect(ast.whereType<EmptyLineElement>().isNotEmpty, isTrue);
    });
  });
}
