/// TC-EDIT-6.8 Notification 次数验证测试（v1.1 评审反馈 5C 新增）。
///
/// 验证 [TransactionBuilder] 的 onChange 回调次数：
/// - 1 op Transaction commit → onChange 触发 1 次
/// - 5 op Transaction commit → onChange 触发 1 次（不是 5 次）
/// - 10 op Transaction commit → onChange 触发 1 次（不是 10 次）
/// - Transaction rollback → onChange 触发 0 次
/// - 嵌套 Transaction 外层 commit → onChange 触发 1 次（内层不触发）
/// - Transaction undo → 调用方负责触发 onChange（1 次）
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.8。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.8 Notification 次数验证', () {
    test('1 op Transaction commit → onChange 触发 1 次', () {
      var callCount = 0;
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');

      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        onChange: (_) => callCount++,
      );
      final ops = BlockOperations(editor, builder);

      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('a')]));

      builder.commit();
      expect(callCount, equals(1));
    });

    test('5 op Transaction commit → onChange 触发 1 次（不是 5 次）', () {
      var callCount = 0;
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (_) => callCount++,
      );
      final ops = BlockOperations(editor, builder);

      // 5 个 op
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('x1')]));
      ops.insertAfter(bId, ParagraphElement(children: [TextElement('x2')]));
      ops.insertAfter(cId, ParagraphElement(children: [TextElement('x3')]));
      ops.delete(bId);
      ops.split(aId, 0);

      expect(builder.opCount, equals(5));

      builder.commit();
      expect(callCount, equals(1));  // 不是 5 次
    });

    test('10 op Transaction commit → onChange 触发 1 次（不是 10 次）', () {
      var callCount = 0;
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (_) => callCount++,
      );
      final ops = BlockOperations(editor, builder);

      // 10 个 op：连续插入 10 个块
      for (var i = 0; i < 10; i++) {
        ops.insertAfter(
          targetId,
          ParagraphElement(children: [TextElement('block-$i')]),
        );
      }

      expect(builder.opCount, equals(10));

      builder.commit();
      expect(callCount, equals(1));  // 不是 10 次
    });

    test('Transaction rollback → onChange 触发 0 次', () {
      var callCount = 0;
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (_) => callCount++,
      );
      final ops = BlockOperations(editor, builder);

      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('x')]));

      // 检测到失败时手动 revert + rollback
      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      builder.rollback();

      expect(callCount, equals(0));
      expect(builder.isCompleted, isTrue);
    });

    test('嵌套 Transaction 外层 commit → onChange 触发 1 次（内层不触发）', () {
      var parentCallCount = 0;
      var childCallCount = 0;
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');

      final parent = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (_) => parentCallCount++,
      );
      final parentOps = BlockOperations(editor, parent);

      parentOps.insertAfter(
        targetId,
        ParagraphElement(children: [TextElement('parent-op')]),
      );

      final child = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        parent: parent,
        onChange: (_) => childCallCount++,
      );
      final childOps = BlockOperations(editor, child);
      childOps.insertAfter(
        targetId,
        ParagraphElement(children: [TextElement('child-op')]),
      );

      child.commit();
      // 子 commit 不触发 onChange（合并到 parent）
      expect(childCallCount, equals(0));
      expect(parentCallCount, equals(0));

      parent.commit();
      // 父 commit 触发 onChange 1 次
      expect(parentCallCount, equals(1));
      expect(childCallCount, equals(0));  // 子 onChange 仍为 0
    });

    test('Transaction undo → 调用方负责触发 onChange（1 次）', () {
      // EditorHistory.undo 不自动触发 onChange，由调用方触发
      var callCount = 0;
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');
      final history = EditorHistory();

      // 1. Commit 一个 Transaction，触发 onChange 1 次
      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) {
          callCount++;
          history.push(tx);
        },
      );
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('x')]));
      final tx = builder.commit();

      expect(callCount, equals(1));
      expect(history.canUndo, isTrue);

      // 2. Undo：EditorHistory.undo 不触发 onChange
      //    调用方手动 revert + 手动触发 onChange 1 次
      final undone = history.undo(tx);
      expect(undone, isNotNull);
      // 调用方负责 revert
      for (final op in undone!.ops.reversed) {
        op.revert(editor);
      }
      // 调用方负责触发 onChange（模拟 UI 通知）
      callCount++;
      expect(callCount, equals(2));

      // 3. Redo：同样由调用方触发 onChange
      final redone = history.redo(undone);
      expect(redone, isNotNull);
      for (final op in redone!.ops) {
        op.apply(editor);
      }
      callCount++;
      expect(callCount, equals(3));
    });
  });
}
