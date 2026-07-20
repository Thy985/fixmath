/// TC-EDIT-7.4：transform + updateSource undo/redo 循环测试。
///
/// 落地 Phase 2.7 Task Contract §4.4：
/// - transform 单独的 5 轮 undo/redo 循环（无状态污染）
/// - updateSource（transform + TextOperation 链式）5 轮循环
/// - split + transform 链式 5 轮循环
/// - 复合操作链（transform → updateSource）undo/redo
///
/// 与 [undo_redo_block_operations_test.dart] TC-EDIT-6.6 风格对齐，
/// 但聚焦 Phase 2.7 新增的 transform / updateSource op。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

/// 测试用 TransactionBuilder 工厂（默认 origin=programmatic）。
TransactionBuilder _newBuilder() =>
    TransactionBuilder(origin: TransactionOrigin.programmatic);

/// 根据 [Type] 返回对应 [Matcher]（运行时类型匹配）。
Matcher _matcherForType(Type type) {
  switch (type) {
    case HeadingElement:
      return isA<HeadingElement>();
    case ListElement:
      return isA<ListElement>();
    case TaskListItemElement:
      return isA<TaskListItemElement>();
    case CodeElement:
      return isA<CodeElement>();
    case BlockquoteElement:
      return isA<BlockquoteElement>();
    case HorizontalRuleElement:
      return isA<HorizontalRuleElement>();
    case ParagraphElement:
      return isA<ParagraphElement>();
    default:
      throw ArgumentError('Unsupported type: $type');
  }
}

void main() {
  group('TC-EDIT-7.4 transform + updateSource undo/redo 循环', () {
    // ============ transform 单独循环 ============

    group('transform 单独循环', () {
      test('transform undo/redo 循环（5 轮）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.tryTransform(id);
        final tx = builder.commit();

        final initialAfterApply = editor.allSources.toList();

        // 5 轮 undo/redo 循环
        for (var i = 0; i < 5; i++) {
          // undo: 逆序 revert
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals('# Title'));

          // redo: 正序 apply
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.allSources, equals(initialAfterApply));
          expect(editor.getBlock(id), isA<HeadingElement>());
        }
      });

      test('transform paragraph → listItem → undo 完全恢复', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('- item');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.tryTransform(id);
        final tx = builder.commit();

        expect(editor.getBlock(id), isA<ListElement>());

        // undo
        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('- item'));
      });

      test('transform 7 类规则 undo/redo 各 1 轮', () {
        // 7 类规则各做 1 轮 undo/redo，验证每类规则都可逆
        final cases = <(String, Type)>[
          ('# Title', HeadingElement),
          ('- item', ListElement),
          ('1. item', ListElement),
          ('- [ ] task', TaskListItemElement),
          ('```dart\nprint(1);\n```', CodeElement),
          ('> quote', BlockquoteElement),
          ('---', HorizontalRuleElement),
        ];

        for (final (source, expectedType) in cases) {
          final editor = MockDocumentEditor();
          final id = editor.addParagraph(source);
          final builder = _newBuilder();
          final ops = BlockOperations(editor, builder);

          ops.tryTransform(id);
          final tx = builder.commit();

          expect(editor.getBlock(id), _matcherForType(expectedType),
              reason: 'transform 失败：$source');

          // undo
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.getBlock(id), isA<ParagraphElement>(),
              reason: 'undo 失败：$source');
          expect(editor.sourceOf(id), equals(source),
              reason: 'undo source 不匹配：$source');

          // redo
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.getBlock(id), _matcherForType(expectedType),
              reason: 'redo 失败：$source');
        }
      });
    });

    // ============ updateSource 循环 ============

    group('updateSource 循环', () {
      test('updateSource 触发 transform → undo/redo 循环（5 轮）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.updateSource(id, '# Title');
        final tx = builder.commit();

        final afterApply = editor.allSources.toList();

        // 5 轮 undo/redo
        for (var i = 0; i < 5; i++) {
          // undo
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals('hello'));

          // redo
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.allSources, equals(afterApply));
          expect(editor.getBlock(id), isA<HeadingElement>());
        }
      });

      test('updateSource 从 heading 改回 paragraph → undo/redo 循环（5 轮）', () {
        final editor = MockDocumentEditor();
        final id = editor.addBlock('# Title', BlockType.heading);
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        // updateSource: '# Title' → 'hello'（heading → paragraph）
        ops.updateSource(id, 'hello');
        final tx = builder.commit();

        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));

        // 5 轮 undo/redo
        for (var i = 0; i < 5; i++) {
          // undo
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.getBlock(id), isA<HeadingElement>());
          expect(editor.sourceOf(id), equals('# Title'));

          // redo
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals('hello'));
        }
      });

      test('updateSource 无 transform → 仅 TextOperation undo/redo 循环', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.updateSource(id, 'world');
        final tx = builder.commit();

        expect(tx.ops.length, equals(1));
        expect(tx.ops.first, isA<TextOperation>());

        for (var i = 0; i < 5; i++) {
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.sourceOf(id), equals('hello'));

          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.sourceOf(id), equals('world'));
        }
      });
    });

    // ============ split + transform 链式循环 ============

    group('split + transform 链式循环', () {
      test('split + transform undo/redo 循环（5 轮）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello# Title');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.split(id, 5);
        final tx = builder.commit();

        // tx 应包含 2 ops: split + transform
        expect(tx.ops.length, equals(2));

        final afterApply = editor.allSources.toList();
        expect(editor.blockCount, equals(2));

        for (var i = 0; i < 5; i++) {
          // undo
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.blockCount, equals(1));
          expect(editor.allIds.first, equals(id));
          expect(editor.sourceOf(id), equals('hello# Title'));
          expect(editor.getBlock(id), isA<ParagraphElement>());

          // redo
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.allSources, equals(afterApply));
          expect(editor.blockCount, equals(2));
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals('hello'));
          final newId = editor.allIds.last;
          expect(editor.getBlock(newId), isA<HeadingElement>());
        }
      });
    });

    // ============ 复合操作链 undo/redo ============

    group('复合操作链 undo/redo', () {
      test('transform → updateSource 反向 → undo/redo 循环（3 轮）', () {
        // 步骤：
        // 1. paragraph '# Title' → tryTransform → heading
        // 2. heading '# Title' → updateSource('hello') → heading transform 回 paragraph + TextOperation
        // 期望 tx 包含 2 ops: BlockOperation.transform + BlockOperation.transform + TextOperation = 3 ops
        // 但实际：第 2 步 updateSource 内部触发 transform + TextOperation = 2 ops
        // 加上第 1 步的 transform = 1 op
        // 总共 3 ops
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.tryTransform(id);
        ops.updateSource(id, 'hello');
        final tx = builder.commit();

        expect(tx.ops.length, equals(3));
        // 顺序：
        // ops[0] = BlockOperation.transform (paragraph → heading)
        // ops[1] = BlockOperation.transform (heading → paragraph，updateSource 触发)
        // ops[2] = TextOperation (替换 source)
        expect(tx.ops[0], isA<BlockOperation>());
        expect(
          (tx.ops[0] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
        expect(tx.ops[1], isA<BlockOperation>());
        expect(
          (tx.ops[1] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
        expect(tx.ops[2], isA<TextOperation>());

        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));

        final afterApply = editor.allSources.toList();

        for (var i = 0; i < 3; i++) {
          // undo
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals('# Title'));

          // redo
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.allSources, equals(afterApply));
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals('hello'));
        }
      });

      test('split + transform + updateSource 链式 undo/redo 循环（3 轮）', () {
        // 步骤：
        // 1. paragraph 'ab# Title' → split at 2 → 2 ops (split + transform → heading '# Title')
        // 2. updateSource(newId1, 'hello') → 2 ops (transform heading → paragraph + TextOperation)
        // 总共 4 ops
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('ab# Title');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.split(id, 2);
        final newId = editor.allIds.last;

        ops.updateSource(newId, 'hello');
        final tx = builder.commit();

        expect(tx.ops.length, equals(4));
        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('ab'));
        expect(editor.getBlock(newId), isA<ParagraphElement>());
        expect(editor.sourceOf(newId), equals('hello'));

        final afterApply = editor.allSources.toList();

        for (var i = 0; i < 3; i++) {
          // undo
          for (final op in tx.ops.reversed) {
            op.revert(editor);
          }
          expect(editor.blockCount, equals(1));
          expect(editor.allIds.first, equals(id));
          expect(editor.sourceOf(id), equals('ab# Title'));

          // redo
          for (final op in tx.ops) {
            op.apply(editor);
          }
          expect(editor.allSources, equals(afterApply));
          expect(editor.blockCount, equals(2));
        }
      });
    });
  });
}
