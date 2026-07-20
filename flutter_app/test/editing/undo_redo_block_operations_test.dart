/// TC-EDIT-6.6 5 类 BlockOperation 各自的 undo/redo 循环测试（从 undo_redo_round_trip_test.dart 拆分）。
///
/// 拆分原因：原文件超 400 行限制（AGENTS.md §1.2 + TC-ARCH-7）。
///
/// 验证：每类 BlockOperation（insert / delete / merge / split / move）单独做
/// 5 轮 undo/redo 循环，每轮后 editor 状态一致（无状态污染）。
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.6。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
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

  group('TC-EDIT-6.6 5 类 BlockOperation undo/redo 循环', () {
    test('insert undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.insertAfter(targetId, const ParagraphElement(children: [TextElement('b')]));
      final tx = builder.commit();

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(['a', 'b']));
        lastTx = redone;
      }
    });

    test('delete undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      editor.addParagraph('a');
      final targetId = editor.addParagraph('b');
      editor.addParagraph('c');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.delete(targetId);
      final tx = builder.commit();

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(['a', 'c']));
        lastTx = redone;
      }
    });

    test('merge undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('hello ');
      final rightId = editor.addParagraph('world');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.merge(leftId, rightId);
      final tx = builder.commit();

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(['hello world']));
        lastTx = redone;
      }
    });

    test('split undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('helloworld');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.split(targetId, 5);
      final tx = builder.commit();

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(['hello', 'world']));
        lastTx = redone;
      }
    });

    test('move undo/redo 循环（5 轮）', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      editor.addParagraph('b');
      final cId = editor.addParagraph('c');
      final history = EditorHistory();
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops = BlockOperations(editor, builder);
      ops.move(aId, cId, before: false);
      final tx = builder.commit();

      var lastTx = tx;
      for (var i = 0; i < 5; i++) {
        final undone = history.undo(lastTx);
        revertOps(editor, undone!);
        expect(editor.allSources, equals(initialSources));
        final redone = history.redo(undone);
        applyOps(editor, redone!);
        expect(editor.allSources, equals(['b', 'c', 'a']));
        lastTx = redone;
      }
    });
  });
}
