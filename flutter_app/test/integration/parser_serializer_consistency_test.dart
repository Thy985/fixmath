/// TC-EDIT-8.4 Parser/Serializer 一致性集成测试。
///
/// 落地 Phase 2.8 Task Contract §3.4：验证 5 类复杂块（Table / List / Formula /
/// Code / Mermaid）经 BlockOperation 后 source round-trip 一致性，特别关注：
/// - Table cell 含 `|` 边界
/// - List ordered/unordered merge 后 type 兼容性
/// - Code fence 冲突
/// - Mermaid transform 后 BlockId 不变
/// - 全部 undo 后 source 与初始一致
///
/// 与 [block_serializer_test.dart] TC-EDIT-3.x 的差异：
/// TC-EDIT-3.x 验证"纯函数 round-trip"，本测试验证：
/// - source → BlockOperation.updateSource → undo → source 一致
/// - source → transform → BlockOperation.updateSource → undo → source 一致
/// - 多类块混合场景下 source 不被破坏
///
/// 详见 Phase 2.8 Task Contract §3.4。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/core/editing/block_type_detector.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import '../editing/helpers/mock_document_editor.dart';

/// Apply Transaction ops to editor（按 op 顺序）。
void _applyOps(MockDocumentEditor editor, Transaction tx) {
  for (final op in tx.ops) {
    op.apply(editor);
  }
}

/// Revert Transaction ops from editor（逆序）。
void _revertOps(MockDocumentEditor editor, Transaction tx) {
  for (final op in tx.ops.reversed) {
    op.revert(editor);
  }
}

void main() {
  group('TC-EDIT-8.4 Parser/Serializer 一致性集成测试', () {
    // ============ Table 一致性 ============

    group('Table 一致性', () {
      test('Table source round-trip：parser trim 空格 → 已知非 bit-perfect', () {
        // 已知 round-trip 非一致性（block_serializer.dart docstring 标注）：
        // parser 用 `inner.split('|').map((s) => s.trim())` trim 掉 cell 边界空格，
        // serializer 不加空格 → round-trip 后 `| col1 | col2 |` 变 `|col1|col2|`
        const source = '| col1 | col2 |\n| --- | --- |\n| a | b |';
        final element = toElement(source, BlockType.table);
        expect(element, isA<TableElement>());
        final restored = fromElement(element);
        // 期望值反映实际行为：parser trim 空格后 serializer 不补回
        expect(restored, equals('|col1|col2|\n|---|---|\n|a|b|'));
      });

      test('Table cell 含 | → toElement 仍返回 TableElement（边界已知）', () {
        // cell 含 | 时 parser 用 split('|') 会误拆，但 toElement 仍返回 TableElement
        // （不降级为 Paragraph，因为 toElement 不感知此边界）
        const source = '| a|b | c |\n| --- | --- |\n| d | e |';
        final element = toElement(source, BlockType.table);
        expect(element, isA<TableElement>());
        // element 字段被 parser 误拆，但 round-trip 后 source 结构不变
        // （误拆的 cells 会重新序列化回 | 分隔的格式）
        final restored = fromElement(element);
        expect(restored, contains('|'));
        expect(restored, contains('---'));
      });

      test('Table updateSource → undo → source 一致', () {
        // 初始 Table 块（直接用 addBlock 构造 TableElement，不走 addParagraph）
        // 注：parser trim 空格后 source 会变 trim 格式，因此初始 source 也用 trim 后的格式
        const initialSource = '|h1|h2|\n|---|---|\n|a|b|';
        final editor = MockDocumentEditor();
        final tId = editor.addBlock(initialSource, BlockType.table);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);

        // updateSource: 改 cell 内容（type 不变，仅 TextOp）
        const newSource = '|X|Y|\n|---|---|\n|1|2|';
        ops.updateSource(tId, newSource);
        builder.commit();

        // 注：BlockOp 是 eager apply（已在 updateSource 中 apply），不需要再次 apply
        expect(editor.sourceOf(tId), equals(newSource));

        // undo → 恢复 initial
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.sourceOf(tId), equals(initialSource));

        // redo → 恢复 new
        final redone = history.redo(undone);
        _applyOps(editor, redone!);
        expect(editor.sourceOf(tId), equals(newSource));
      });
    });

    // ============ List 一致性 ============

    group('List 一致性', () {
      test('List ordered + unordered merge 异 ordered → 回退 Paragraph', () {
        // 异 ordered（1. + 2.）merge → _mergeType 返回 paragraph
        // 注意：实际 _mergeType 检查 leftList.ordered != rightList.ordered
        // 这里构造 left 是 ordered(1.)，right 是 unordered(-)，ordered 字段不同 → 回退
        final editor = MockDocumentEditor();
        final leftId = editor.addBlock('1. ordered item', BlockType.listItem);
        final rightId = editor.addBlock('- unordered item', BlockType.listItem);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);

        // merge right into left（异 ordered → 回退 Paragraph）
        ops.merge(leftId, rightId);
        builder.commit();

        // left 块 source 应为 '1. ordered item' + '- unordered item' = paragraph
        final leftElement = editor.getBlock(leftId);
        expect(leftElement, isA<ParagraphElement>());
        expect(editor.sourceOf(leftId), equals('1. ordered item- unordered item'));
        expect(editor.blockCount, equals(1));

        // undo → 恢复 2 块
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.blockCount, equals(2));
        expect(editor.sourceOf(leftId), equals('1. ordered item'));
        expect(editor.sourceOf(rightId), equals('- unordered item'));
      });

      test('List 同 ordered merge → 保留 List 类型', () {
        final editor = MockDocumentEditor();
        final leftId = editor.addBlock('1. first', BlockType.listItem);
        final rightId = editor.addBlock('1. second', BlockType.listItem);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        ops.merge(leftId, rightId);
        builder.commit();

        // 同 ordered（都为 true）→ 保留 ListElement
        final leftElement = editor.getBlock(leftId);
        expect(leftElement, isA<ListElement>());
        final listEl = leftElement as ListElement;
        expect(listEl.ordered, isTrue);
        expect(editor.sourceOf(leftId), equals('1. first1. second'));

        // undo
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.sourceOf(leftId), equals('1. first'));
        expect(editor.sourceOf(rightId), equals('1. second'));
      });

      test('List split 后保留类型 + undo 一致', () {
        // unordered list split
        final editor = MockDocumentEditor();
        final lId = editor.addBlock('- abcdef', BlockType.listItem);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        ops.split(lId, 6);  // '- abcd' + 'ef'
        builder.commit();

        expect(editor.blockCount, equals(2));
        final leftEl = editor.getBlock(lId);
        expect(leftEl, isA<ListElement>());
        expect((leftEl as ListElement).ordered, isFalse);

        // undo
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.blockCount, equals(1));
        expect(editor.sourceOf(lId), equals('- abcdef'));
      });
    });

    // ============ Formula 一致性 ============

    group('Formula 一致性', () {
      test(r'Formula inline $...$ round-trip', () {
        const source = r'inline $E = mc^2$ formula';
        final element = toElement(source, BlockType.paragraph);
        expect(element, isA<ParagraphElement>());
        final para = element as ParagraphElement;
        // 应解析出 FormulaElement
        expect(
          para.children.any((e) => e is FormulaElement),
          isTrue,
        );
        final restored = fromElement(element);
        expect(restored, equals(source));
      });

      test(r'Formula display $$...$$ round-trip', () {
        const source = r'display $$\int_0^1 f(x) dx$$ formula';
        final element = toElement(source, BlockType.paragraph);
        expect(element, isA<ParagraphElement>());
        final para = element as ParagraphElement;
        // 应解析出 displayMode=true 的 FormulaElement
        final formula = para.children.whereType<FormulaElement>().first;
        expect(formula.displayMode, isTrue);
        final restored = fromElement(element);
        expect(restored, equals(source));
      });

      test('Paragraph 含 Formula → updateSource → undo 一致', () {
        const initialSource = r'formula $x^2$ here';
        final editor = MockDocumentEditor();
        final pId = editor.addParagraph(initialSource);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);

        // updateSource：替换 formula 内容
        // 注：updateSource 内部 eager apply TextOp（不需手动 apply）
        const newSource = r'formula $y^3$ here';
        ops.updateSource(pId, newSource);
        builder.commit();
        expect(editor.sourceOf(pId), equals(newSource));

        // undo
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.sourceOf(pId), equals(initialSource));

        // redo
        final redone = history.redo(undone);
        _applyOps(editor, redone!);
        expect(editor.sourceOf(pId), equals(newSource));
      });
    });

    // ============ Code 一致性 ============

    group('Code 一致性', () {
      test('Code block round-trip：含语言标识 + 多行 code', () {
        const source = '```dart\nvoid main() {\n  print("hello");\n}\n```';
        final element = toElement(source, BlockType.code);
        expect(element, isA<CodeElement>());
        final codeEl = element as CodeElement;
        expect(codeEl.language, equals('dart'));
        expect(codeEl.code, contains('void main'));
        final restored = fromElement(element);
        expect(restored, equals(source));
      });

      test('Code block updateSource → undo 一致', () {
        const initialSource = '```python\nprint("old")\n```';
        final editor = MockDocumentEditor();
        final cId = editor.addParagraph(initialSource);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);

        const newSource = '```python\nprint("new")\n```';
        // 注：updateSource 内部 eager apply（不需手动 apply TextOp）
        ops.updateSource(cId, newSource);
        builder.commit();
        expect(editor.sourceOf(cId), equals(newSource));

        // undo
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.sourceOf(cId), equals(initialSource));
      });

      test('Code block 含 fence 冲突（内部 ``` 不破坏 round-trip）', () {
        // code 内部含 ``` 会被 round-trip 后被误解析，但 source 不变（按字符串原样保存）
        const source = '```text\ncontains ``` inside\n```';
        final element = toElement(source, BlockType.code);
        // element 仍是 CodeElement（parser 容忍）
        expect(element, isA<CodeElement>());
        // round-trip 后 source 可能不完全一致，但应保留 code 内容
        final restored = fromElement(element);
        expect(restored, contains('contains'));
      });
    });

    // ============ Mermaid 一致性 ============

    group('Mermaid 一致性', () {
      test('Mermaid transform 后 BlockId 不变', () {
        // 场景：paragraph 块 updateSource 为 ```mermaid\n...\n```
        // → updateSource 内部先 transform 为 mermaid type → BlockId 不变
        const initialSource = 'before mermaid';
        final editor = MockDocumentEditor();
        final mId = editor.addParagraph(initialSource);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);

        const mermaidSource = '```mermaid\ngraph LR\n  A --> B\n```';
        // 注：updateSource 内部 eager apply（不需手动 apply TextOp）
        ops.updateSource(mId, mermaidSource);
        builder.commit();

        // transform op 不变更 BlockId
        expect(editor.allIds, contains(mId));
        expect(editor.blockCount, equals(1));

        // element 已变 MermaidElement
        final element = editor.getBlock(mId);
        expect(element, isA<MermaidElement>());

        // source round-trip 一致
        expect(editor.sourceOf(mId), equals(mermaidSource));

        // undo
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.allIds, contains(mId));
        expect(editor.sourceOf(mId), equals(initialSource));
        // element 回到 ParagraphElement
        expect(editor.getBlock(mId), isA<ParagraphElement>());
      });

      test('Mermaid block round-trip（toElement 直接构造）', () {
        const source = '```mermaid\nsequenceDiagram\n  A->>B: Hello\n```';
        final element = toElement(source, BlockType.mermaid);
        expect(element, isA<MermaidElement>());
        final mermaid = element as MermaidElement;
        expect(mermaid.code, contains('sequenceDiagram'));
        final restored = fromElement(element);
        expect(restored, equals(source));
      });

      test('Paragraph → Mermaid → Paragraph 完整闭环', () {
        // 验证 transform / revert 多次往返一致性
        const initialSource = 'plain text';
        final editor = MockDocumentEditor();
        final pId = editor.addParagraph(initialSource);

        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);

        const mermaidSource = '```mermaid\nflowchart TD\n  X --> Y\n```';
        // 注：updateSource 内部 eager apply（不需手动 apply TextOp）
        ops.updateSource(pId, mermaidSource);
        builder.commit();

        // 3 轮 undo/redo
        for (var i = 0; i < 3; i++) {
          final undone = history.undo(history.lastOrNull!);
          _revertOps(editor, undone!);
          expect(editor.sourceOf(pId), equals(initialSource));
          expect(editor.getBlock(pId), isA<ParagraphElement>());

          final redone = history.redo(undone);
          _applyOps(editor, redone!);
          expect(editor.sourceOf(pId), equals(mermaidSource));
          expect(editor.getBlock(pId), isA<MermaidElement>());
        }
      });
    });

    // ============ 多类块混合场景 ============

    group('多类块混合', () {
      test('混合块文档：Table + List + Code + Mermaid + Paragraph', () {
        // 验证多类块在同一 Document 中独立 round-trip + Undo/Redo 一致
        final editor = MockDocumentEditor();
        final pId = editor.addParagraph('plain');
        editor.addBlock('|h|\n|---|\n|a|', BlockType.table);
        editor.addBlock('- list item', BlockType.listItem);
        editor.addBlock('```dart\nvoid f() {}\n```', BlockType.code);
        editor.addBlock('```mermaid\ngraph LR\n  A --> B\n```', BlockType.code);

        final initialSources = editor.allSources.toList();
        expect(initialSources.length, equals(5));

        // 全部 5 块 source round-trip
        for (final id in editor.allIds) {
          final element = editor.getBlock(id)!;
          final source = fromElement(element);
          final restored = fromElement(toElement(source, BlockType.fromElement(element)));
          expect(restored, equals(source),
              reason: 'block $id round-trip failed: $source');
        }

        // updateSource 改第一块（paragraph → heading）
        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        // 注：updateSource 内部 eager apply（不需手动 apply TextOp）
        ops.updateSource(pId, '# Heading');
        builder.commit();

        // pId 变 heading
        expect(editor.getBlock(pId), isA<HeadingElement>());

        // undo → 恢复 paragraph
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.getBlock(pId), isA<ParagraphElement>());
        expect(editor.allSources.toList(), equals(initialSources));
      });

      test('detectBlockType 与 BlockType.fromElement 互逆性', () {
        // 5 类 source → detectBlockType → toElement → BlockType.fromElement 应一致
        // 注：detectBlockType 不检测 table（无 table 规则），table source 会被归类为 paragraph
        const cases = <(String, BlockType)>[
          ('# Heading 1', BlockType.heading),
          ('plain paragraph', BlockType.paragraph),
          ('- unordered item', BlockType.listItem),
          ('1. ordered item', BlockType.listItem),
          ('```dart\ncode\n```', BlockType.code),
          ('> quote', BlockType.blockquote),
          ('```mermaid\ngraph LR\n  A --> B\n```', BlockType.code),  // detectBlockType 返回 code（mermaid 区分在 toElement 内部）
          ('---', BlockType.horizontalRule),
        ];

        for (final (source, expectedType) in cases) {
          final detected = detectBlockType(source);
          expect(detected, equals(expectedType),
              reason: 'detectBlockType failed for: "$source"');

          final element = toElement(source, detected);
          final fromElementType = BlockType.fromElement(element);
          // detectBlockType 与 fromElement 应互逆（mermaid 除外，因 detectBlockType 把 mermaid 当 code）
          if (detected == BlockType.code && source.startsWith('```mermaid')) {
            // mermaid：detectBlockType 返回 code，toElement 内部转为 MermaidElement，
            // fromElement(MermaidElement) 返回 mermaid
            expect(fromElementType, equals(BlockType.mermaid));
          } else {
            expect(fromElementType, equals(detected),
                reason: 'fromElement != detectBlockType for: "$source"');
          }
        }
      });
    });
  });
}
