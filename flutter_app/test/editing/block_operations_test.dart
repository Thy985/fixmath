/// TC-EDIT-6.4 BlockOperations 五原语 apply + revert + 失败 + builder 收集测试。
///
/// 验证：
/// - insert / delete / merge / split / move 各 apply + 通过 op.revert 恢复
/// - op 自动加入 TransactionBuilder（commit 后入 Transaction.ops）
/// - 失败返回 false / null（非法 BlockId / offset 越界等）
///
/// 守门 + 组合 + 兼容性测试见 [block_operations_guard_test.dart]。
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.4。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.4 BlockOperations.insertAfter', () {
    test('apply 在 target 之后插入新块，返回新 BlockId', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      final newId = ops.insertAfter(
        targetId,
        const ParagraphElement(children: [TextElement('world')]),
      );

      expect(newId, isNotNull);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello', 'world']));
      expect(editor.indexOf(newId!), equals(1));
      expect(editor.indexOf(targetId), equals(0));
    });

    test('op 自动加入 TransactionBuilder', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(builder.opCount, equals(0));
      ops.insertAfter(
        targetId,
        const ParagraphElement(children: [TextElement('b')]),
      );
      expect(builder.opCount, equals(1));
    });

    test('commit 后 Transaction.ops 包含此 BlockOperation', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(
        targetId,
        const ParagraphElement(children: [TextElement('b')]),
      );

      final tx = builder.commit();
      expect(tx.ops.length, equals(1));
      expect(tx.ops.first, isA<BlockOperation>());
    });

    test('通过 op.revert 恢复 editor 状态', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(
        targetId,
        const ParagraphElement(children: [TextElement('world')]),
      );

      expect(editor.blockCount, equals(2));

      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['hello']));
    });

    test('失败：非法 targetId 返回 null，op 不入 builder', () {
      final editor = MockDocumentEditor();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      final newId = ops.insertAfter(
        const BlockId(999),
        const ParagraphElement(children: [TextElement('x')]),
      );

      expect(newId, isNull);
      expect(builder.opCount, equals(0));
      expect(editor.blockCount, equals(0));
    });
  });

  group('TC-EDIT-6.4 BlockOperations.delete', () {
    test('apply 删除块', () {
      final editor = MockDocumentEditor();
      editor.addParagraph('a');
      final targetId = editor.addParagraph('b');
      editor.addParagraph('c');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.delete(targetId), isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['a', 'c']));
    });

    test('op 自动加入 TransactionBuilder', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');
      editor.addParagraph('b'); // P1 守卫：保证至少 1 块，故需 ≥2 块才能 delete

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.delete(targetId);

      expect(builder.opCount, equals(1));
    });

    test('通过 op.revert 恢复（BlockId 保持稳定）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');
      final targetIdValue = targetId.value;
      editor.addParagraph('b'); // P1 守卫：保证至少 1 块，故需 ≥2 块才能 delete

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.delete(targetId);

      expect(editor.blockCount, equals(1));

      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['a', 'b']));
      // revert 后 BlockId 保持稳定（preserveId）
      expect(editor.allIds.first.value, equals(targetIdValue));
    });

    test('失败：非法 targetId 返回 false，op 不入 builder', () {
      final editor = MockDocumentEditor();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.delete(const BlockId(999)), isFalse);
      expect(builder.opCount, equals(0));
    });
  });

  group('TC-EDIT-6.4 BlockOperations.merge', () {
    test('apply 合并右块到左块', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('hello ');
      final rightId = editor.addParagraph('world');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.merge(leftId, rightId), isTrue);
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['hello world']));
    });

    test('op 自动加入 TransactionBuilder', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('a');
      final rightId = editor.addParagraph('b');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.merge(leftId, rightId);

      expect(builder.opCount, equals(1));
    });

    test('通过 op.revert 恢复', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('hello ');
      final rightId = editor.addParagraph('world');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.merge(leftId, rightId);

      expect(editor.blockCount, equals(1));

      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello ', 'world']));
    });

    test('失败：非法 auxiliaryId 返回 false', () {
      final editor = MockDocumentEditor();
      final rightId = editor.addParagraph('b');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.merge(const BlockId(999), rightId), isFalse);
      expect(builder.opCount, equals(0));
    });
  });

  group('TC-EDIT-6.4 BlockOperations.split', () {
    test('apply 在 offset 处拆分块', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('helloworld');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.split(targetId, 5), isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello', 'world']));
    });

    test('op 自动加入 TransactionBuilder', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('abc');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.split(targetId, 1);

      expect(builder.opCount, equals(1));
    });

    test('通过 op.revert 恢复', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('helloworld');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.split(targetId, 5);

      expect(editor.blockCount, equals(2));

      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['helloworld']));
    });

    test('失败：offset 越界返回 false', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('abc');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.split(targetId, 100), isFalse);
      expect(builder.opCount, equals(0));
    });

    test('失败：非法 targetId 返回 false', () {
      final editor = MockDocumentEditor();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.split(const BlockId(999), 1), isFalse);
      expect(builder.opCount, equals(0));
    });
  });

  group('TC-EDIT-6.4 BlockOperations.move', () {
    test('apply 把 target 移到 refId 之前', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.move(cId, aId, before: true), isTrue);
      expect(editor.allSources, equals(['c', 'a', 'b']));
    });

    test('apply 把 target 移到 refId 之后', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.move(aId, cId, before: false), isTrue);
      expect(editor.allSources, equals(['b', 'c', 'a']));
    });

    test('op 自动加入 TransactionBuilder', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.move(aId, bId, before: false);

      expect(builder.opCount, equals(1));
    });

    test('通过 op.revert 恢复', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.move(aId, cId, before: false);

      expect(editor.allSources, equals(['b', 'c', 'a']));

      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.allSources, equals(['a', 'b', 'c']));
    });

    test('失败：非法 refId 返回 false', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.move(aId, const BlockId(999), before: true), isFalse);
      expect(builder.opCount, equals(0));
    });
  });
}
