/// TC-EDIT-6.2 TransactionBuilder commit/rollback/嵌套/onChange 测试。
///
/// 验证：
/// - add / commit / rollback 行为正确
/// - 嵌套 commit 把 ops 合并到 parent（不触发 onChange）
/// - 顶层 commit 触发 onChange 1 次
/// - rollback 丢弃 ops，不应用变更
/// - 已完成的 builder 不能再 add/commit/rollback
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.2。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.2 TransactionBuilder 基本行为', () {
    test('add 收集 op，commit 返回包含 ops 的 Transaction', () {
      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
      );

      builder.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'a',
      ));
      builder.add(TextOperation(
        blockId: BlockId(1),
        offset: 1,
        inserted: 'b',
      ));

      expect(builder.opCount, equals(2));

      final tx = builder.commit(label: '输入 ab');
      expect(tx.ops.length, equals(2));
      expect(tx.metadata.label, equals('输入 ab'));
      expect(tx.origin, equals(TransactionOrigin.keyboard));
    });

    test('commit 时 id 在 Builder 创建时已生成（v1.2 补强 2）', () {
      final builder1 = TransactionBuilder(origin: TransactionOrigin.keyboard);
      final builder2 = TransactionBuilder(origin: TransactionOrigin.keyboard);

      // builder1.id 在创建时已生成（不是 commit 时）
      expect(builder1.id, isNot(equals(builder2.id)));

      final tx1 = builder1.commit();
      // commit 后 tx1.id 与 builder1.id 一致
      expect(tx1.id, equals(builder1.id));
    });

    test('commit 时填充 timestamp', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final before = DateTime.now();
      final tx = builder.commit();
      final after = DateTime.now();

      expect(tx.metadata.timestamp.isAfter(before) ||
          tx.metadata.timestamp.isAtSameMomentAs(before), isTrue);
      expect(tx.metadata.timestamp.isBefore(after) ||
          tx.metadata.timestamp.isAtSameMomentAs(after), isTrue);
    });

    test('label 优先用 commit 时传入的，否则用构造时的 defaultLabel', () {
      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        label: 'default-label',
      );
      final tx = builder.commit();
      expect(tx.metadata.label, equals('default-label'));

      final builder2 = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        label: 'default-label',
      );
      final tx2 = builder2.commit(label: 'override-label');
      expect(tx2.metadata.label, equals('override-label'));
    });
  });

  group('TC-EDIT-6.2 TransactionBuilder onChange 回调', () {
    test('顶层 commit 触发 onChange 1 次', () {
      var callCount = 0;
      Transaction? receivedTx;

      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        onChange: (tx) {
          callCount++;
          receivedTx = tx;
        },
      );

      builder.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'x',
      ));

      final tx = builder.commit();

      expect(callCount, equals(1));
      expect(receivedTx, isNotNull);
      expect(receivedTx!.id, equals(tx.id));
    });

    test('onChange 不传时不触发', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);

      builder.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'x',
      ));

      // 不抛异常
      builder.commit();
    });

    test('commit 后 Transaction 可应用到 editor', () {
      final editor = MockDocumentEditor();
      final id = editor.addParagraph('');

      Transaction? receivedTx;
      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        onChange: (tx) {
          receivedTx = tx;
          // apply 所有 ops 到 editor
          for (final op in tx.ops) {
            op.apply(editor);
          }
        },
      );

      builder.add(TextOperation(
        blockId: id,
        offset: 0,
        inserted: 'hello',
      ));

      builder.commit();

      expect(receivedTx, isNotNull);
      expect(receivedTx!.ops.length, equals(1));
      expect(editor.sourceOf(id), equals('hello'));
    });
  });

  group('TC-EDIT-6.2 TransactionBuilder rollback', () {
    test('rollback 丢弃 ops，不触发 onChange', () {
      var callCount = 0;
      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        onChange: (_) => callCount++,
      );

      builder.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'x',
      ));

      builder.rollback();

      expect(callCount, equals(0));
      expect(builder.opCount, equals(0));
    });

    test('rollback 后 isCompleted = true', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      builder.rollback();
      expect(builder.isCompleted, isTrue);
    });
  });

  group('TC-EDIT-6.2 TransactionBuilder 已完成状态', () {
    test('commit 后 add 抛 StateError', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      builder.commit();

      expect(
        () => builder.add(TextOperation(
          blockId: BlockId(1),
          offset: 0,
        )),
        throwsStateError,
      );
    });

    test('commit 后再 commit 抛 StateError', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      builder.commit();

      expect(() => builder.commit(), throwsStateError);
    });

    test('commit 后 rollback 抛 StateError', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      builder.commit();

      expect(() => builder.rollback(), throwsStateError);
    });

    test('rollback 后 add 抛 StateError', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      builder.rollback();

      expect(
        () => builder.add(TextOperation(
          blockId: BlockId(1),
          offset: 0,
        )),
        throwsStateError,
      );
    });

    test('rollback 后 commit 抛 StateError', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      builder.rollback();

      expect(() => builder.commit(), throwsStateError);
    });
  });

  group('TC-EDIT-6.2 TransactionBuilder 嵌套合并', () {
    test('子 builder commit 把 ops 合并到 parent，不触发 onChange', () {
      var parentCallCount = 0;
      var childCallCount = 0;

      final parent = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (_) => parentCallCount++,
      );

      final child = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        parent: parent,
        onChange: (_) => childCallCount++,
      );

      parent.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'a',
      ));

      child.add(TextOperation(
        blockId: BlockId(1),
        offset: 1,
        inserted: 'b',
      ));

      // 子 commit：不触发 onChange，但合并到 parent
      child.commit();

      expect(childCallCount, equals(0));
      expect(parentCallCount, equals(0));
      expect(parent.opCount, equals(2));  // parent 的 op + child 合并的 op
    });

    test('isNested 检测', () {
      final parent = TransactionBuilder(origin: TransactionOrigin.keyboard);
      final child = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        parent: parent,
      );

      expect(parent.isNested, isFalse);
      expect(child.isNested, isTrue);
    });

    test('parent commit 触发 onChange 1 次，包含 parent + child 的 ops', () {
      var callCount = 0;
      Transaction? receivedTx;

      final parent = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) {
          callCount++;
          receivedTx = tx;
        },
      );

      parent.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'a',
      ));

      final child = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        parent: parent,
      );
      child.add(TextOperation(
        blockId: BlockId(1),
        offset: 1,
        inserted: 'b',
      ));
      child.commit();

      final child2 = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        parent: parent,
      );
      child2.add(TextOperation(
        blockId: BlockId(1),
        offset: 2,
        inserted: 'c',
      ));
      child2.commit();

      // parent 还没 commit，onChange 未触发
      expect(callCount, equals(0));

      parent.commit();

      expect(callCount, equals(1));
      expect(receivedTx!.ops.length, equals(3));  // parent 1 + child 1 + child2 1
    });

    test('子 rollback 不影响 parent 已收集的 ops', () {
      final parent = TransactionBuilder(origin: TransactionOrigin.keyboard);
      parent.add(TextOperation(
        blockId: BlockId(1),
        offset: 0,
        inserted: 'parent-op',
      ));

      final child = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        parent: parent,
      );
      child.add(TextOperation(
        blockId: BlockId(1),
        offset: 1,
        inserted: 'child-op',
      ));
      child.rollback();

      // parent 的 op 不受影响
      expect(parent.opCount, equals(1));
    });
  });

  group('TC-EDIT-6.2 TransactionBuilder TransactionOrigin 6 值', () {
    test('所有 6 个 origin 都可用', () {
      for (final origin in TransactionOrigin.values) {
        final builder = TransactionBuilder(origin: origin);
        final tx = builder.commit();
        expect(tx.origin, equals(origin));
      }
    });

    test('keyboard origin 标记可参与 coalescing', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.keyboard);
      expect(builder.origin, equals(TransactionOrigin.keyboard));
    });

    test('ime origin 标记独立成单元', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.ime);
      expect(builder.origin, equals(TransactionOrigin.ime));
    });

    test('paste origin 标记独立成单元', () {
      final builder = TransactionBuilder(origin: TransactionOrigin.paste);
      expect(builder.origin, equals(TransactionOrigin.paste));
    });

    test('undo / redo origin 不入栈（由 EditorHistory 处理）', () {
      final undoBuilder = TransactionBuilder(origin: TransactionOrigin.undo);
      final redoBuilder = TransactionBuilder(origin: TransactionOrigin.redo);
      expect(undoBuilder.origin, equals(TransactionOrigin.undo));
      expect(redoBuilder.origin, equals(TransactionOrigin.redo));
    });
  });
}
