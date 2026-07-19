/// TC-EDIT-6.6 Undo/Redo 循环一致性测试（v1.1 评审反馈 5A 新增）。
///
/// 验证：
/// - apply → undo → redo → undo → redo（5 轮循环）
///   - 每轮后 editor 状态一致（无状态污染）
///   - history.canUndo / canRedo 状态正确切换
/// - TextOperation undo/redo 循环（5 轮）
/// - 混合 Transaction（含 BlockOp + TextOp）undo/redo 循环（5 轮）
/// - coalescing 合并后的 Transaction undo/redo 循环（5 轮）
/// - 多 Transaction 序列的 undo/redo 循环
/// - 边界：连续多次 undo（超过栈深度）→ 返回 null（不抛异常）
/// - 边界：连续多次 redo（超过 redo 栈深度）→ 返回 null
///
/// 5 类 BlockOperation 各自的 undo/redo 循环测试已拆分到
/// `undo_redo_block_operations_test.dart`（TC-ARCH-7 文件大小限制）。
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.6。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  /// 公共 helper：apply Transaction ops → editor。
  void applyOps(MockDocumentEditor editor, Transaction tx) {
    for (final op in tx.ops) {
      op.apply(editor);
    }
  }

  /// 公共 helper：revert Transaction ops → editor。
  void revertOps(MockDocumentEditor editor, Transaction tx) {
    for (final op in tx.ops.reversed) {
      op.revert(editor);
    }
  }

  group('TC-EDIT-6.6 Undo/Redo 循环一致性', () {
    test('apply → undo → redo → undo → redo（5 轮循环）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      // 1. Commit + push
      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('world')]));
      final tx = builder.commit();

      final appliedSources = editor.allSources.toList();

      // 2. 5 轮循环
      Transaction? lastTx = tx;
      for (var i = 0; i < 5; i++) {
        // undo
        final undone = history.undo(lastTx!);
        expect(undone, isNotNull);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        expect(history.canUndo, isFalse);
        expect(history.canRedo, isTrue);

        // redo
        final redone = history.redo(undone);
        expect(redone, isNotNull);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(appliedSources));
        expect(history.canUndo, isTrue);
        expect(history.canRedo, isFalse);

        lastTx = redone;
      }
    });

    test('TextOperation undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.keyboard,
        onChange: (tx) => history.push(tx),
      );
      builder.add(TextOperation(
        blockId: targetId,
        offset: 5,
        inserted: ' world',
      ));
      final tx = builder.commit();

      final appliedSources = ['hello world'];

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(appliedSources));
        lastTx = redone;
      }
    });

    test('混合 Transaction（含 BlockOp + TextOp）undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      // 混合：BlockOp + TextOp
      builder.add(TextOperation(
        blockId: targetId,
        offset: 5,
        inserted: '!',
      ));
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('new')]));
      final tx = builder.commit();

      final appliedSources = ['hello!', 'new'];

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(appliedSources));
        lastTx = redone;
      }
    });

    test('coalescing 合并后的 Transaction undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      // 连续 push 3 个 keyboard TextOp（同 BlockId，offset 连续）
      // EditorHistory 会自动 coalesce 为 1 个 Transaction
      for (var i = 0; i < 3; i++) {
        final builder = TransactionBuilder(
          origin: TransactionOrigin.keyboard,
          onChange: (tx) => history.push(tx),
        );
        builder.add(TextOperation(
          blockId: targetId,
          offset: i,  // 连续 offset
          inserted: String.fromCharCode('a'.codeUnitAt(0) + i),
        ));
        final tx = builder.commit();
        // apply 到 editor
        for (final op in tx.ops) {
          op.apply(editor);
        }
      }

      // 合并后只有 1 个 Transaction 入栈
      expect(history.undoCount, equals(1));
      final appliedSources = ['abc'];

      // undo 合并后的 Transaction：一次撤销所有 3 个字符
      final lastTx = history.lastOrNull!;
      final undone = history.undo(lastTx);
      expect(undone, isNotNull);
      revertOps(editor, undone!);
      expect(editor.allSources, equals(initialSources));

      // redo
      final redone = history.redo(undone);
      expect(redone, isNotNull);
      applyOps(editor, redone!);
      expect(editor.allSources, equals(appliedSources));
    });

    test('多 Transaction 序列 undo/redo 循环', () {
      // apply T1 → apply T2 → apply T3 → undo × 3 → redo × 3
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('');
      final history = EditorHistory();

      final sources = <String>[''];  // 初始

      void applyAndPush(TransactionBuilder builder) {
        final tx = builder.commit();
        for (final op in tx.ops) {
          op.apply(editor);
        }
        history.push(tx);
        sources.add(editor.allSources.first);
      }

      // T1: insert 'a'
      var b = TransactionBuilder(origin: TransactionOrigin.programmatic);
      b.add(TextOperation(blockId: targetId, offset: 0, inserted: 'a'));
      applyAndPush(b);

      // T2: insert 'b'
      b = TransactionBuilder(origin: TransactionOrigin.programmatic);
      b.add(TextOperation(blockId: targetId, offset: 1, inserted: 'b'));
      applyAndPush(b);

      // T3: insert 'c'
      b = TransactionBuilder(origin: TransactionOrigin.programmatic);
      b.add(TextOperation(blockId: targetId, offset: 2, inserted: 'c'));
      applyAndPush(b);

      // 当前状态：'abc'
      expect(editor.allSources, equals(['abc']));
      expect(history.undoCount, equals(3));

      // undo × 3：每次传 history.lastOrNull（即将被 undo 的 Transaction）
      // 这样 redoStack 推入顺序与 undoStack 弹出顺序一致，
      // redo 时才能按 T1 → T2 → T3 顺序弹出。
      // 第一次 undo → 'ab'
      var undone = history.undo(history.lastOrNull!);
      revertOps(editor, undone!);
      expect(editor.allSources, equals(['ab']));

      undone = history.undo(history.lastOrNull!);
      revertOps(editor, undone!);
      expect(editor.allSources, equals(['a']));

      undone = history.undo(history.lastOrNull!);
      revertOps(editor, undone!);
      expect(editor.allSources, equals(['']));
      expect(history.canUndo, isFalse);

      // redo × 3：currentState 传"上一次操作的 Transaction"
      // redo 1 传 undone（最后一次 undo 返回的），后续传 redone（上一次 redo 返回的）
      var redone = history.redo(undone);
      applyOps(editor, redone!);
      expect(editor.allSources, equals(['a']));

      redone = history.redo(redone);
      applyOps(editor, redone!);
      expect(editor.allSources, equals(['ab']));

      redone = history.redo(redone);
      applyOps(editor, redone!);
      expect(editor.allSources, equals(['abc']));
      expect(history.canRedo, isFalse);
    });

    test('边界：连续多次 undo（超过栈深度）→ 返回 null（不抛异常）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');
      final history = EditorHistory();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('b')]));
      final tx = builder.commit();

      // 第一次 undo：返回 Transaction
      final undone1 = history.undo(tx);
      expect(undone1, isNotNull);

      // 第二次 undo：栈空，返回 null
      final undone2 = history.undo(undone1!);
      expect(undone2, isNull);

      // 第三次 undo：仍为 null
      final undone3 = history.undo(tx);
      expect(undone3, isNull);
    });

    test('边界：连续多次 redo（超过 redo 栈深度）→ 返回 null', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');
      final history = EditorHistory();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(targetId, ParagraphElement(children: [TextElement('b')]));
      final tx = builder.commit();

      // undo 后 redo
      final undone = history.undo(tx);
      expect(undone, isNotNull);
      final redone1 = history.redo(undone!);
      expect(redone1, isNotNull);

      // 第二次 redo：栈空，返回 null
      final redone2 = history.redo(redone1!);
      expect(redone2, isNull);

      // 第三次 redo：仍为 null
      final redone3 = history.redo(tx);
      expect(redone3, isNull);
    });
  });
}
