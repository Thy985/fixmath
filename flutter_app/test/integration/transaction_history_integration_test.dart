/// TC-EDIT-8.2 Transaction + History 集成测试。
///
/// 落地 Phase 2.8 Task Contract §3.2：验证多 op Transaction 序列的 Undo/Redo
/// 闭环、coalescing 在跨 origin 场景下的行为、以及 TransactionBuilder 嵌套合并
/// 在 history 栈中的一致性。
///
/// 与 [undo_redo_round_trip_test.dart] TC-EDIT-6.6 的差异：
/// TC-EDIT-6.6 验证"单 Transaction 单 origin 循环"，本测试验证：
/// - 单 Transaction 含多 op（BlockOp + BlockOp + TextOp 混合）
/// - 多 Transaction 序列（含 5 轮 undo/redo 完整闭环）
/// - coalescing 跨 origin 行为（keyboard/ime/paste/programmatic）
/// - 自定义 canCoalesce predicate 注入
///
/// 详见 Phase 2.8 Task Contract §3.2。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import '../editing/helpers/mock_document_editor.dart';

/// 公共 helper：apply Transaction ops → editor。
void _applyOps(MockDocumentEditor editor, Transaction tx) {
  for (final op in tx.ops) {
    op.apply(editor);
  }
}

/// 公共 helper：revert Transaction ops → editor（逆序）。
void _revertOps(MockDocumentEditor editor, Transaction tx) {
  for (final op in tx.ops.reversed) {
    op.revert(editor);
  }
}

void main() {
  group('TC-EDIT-8.2 Transaction + History 集成测试', () {
    // ============ 多 op Transaction 闭环 ============

    group('多 op Transaction 闭环', () {
      test('单 Transaction 含 insert + insert + delete → undo/redo 一致', () {
        // 初始：[a, b, c]
        // T1: insertAfter(a, X) + insertAfter(X, Y) + delete(b)
        // 期望：[a, X, Y, c]
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        final bId = editor.addParagraph('b');
        editor.addParagraph('c');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        final xId = ops.insertAfter(
          aId,
          const ParagraphElement(children: [TextElement('X')]),
        )!;
        ops.insertAfter(
          xId,
          const ParagraphElement(children: [TextElement('Y')]),
        );
        ops.delete(bId);
        final tx = builder.commit();

        // tx 应包含 3 ops
        expect(tx.ops.length, equals(3));
        final afterApply = editor.allSources.toList();
        expect(afterApply, equals(['a', 'X', 'Y', 'c']));

        // 5 轮 undo/redo
        var lastTx = tx;
        for (var i = 0; i < 5; i++) {
          final undone = history.undo(lastTx);
          _revertOps(editor, undone!);
          expect(editor.allSources, equals(initialSources));

          final redone = history.redo(undone);
          _applyOps(editor, redone!);
          expect(editor.allSources, equals(afterApply));
          lastTx = redone;
        }
      });

      test('单 Transaction 含 BlockOp + TextOp 混合 → undo/redo 一致', () {
        // 初始：[a='hello']
        // T1: TextOperation(a, offset=5, inserted='!') + insertAfter(a, 'new')
        // 期望：[a='hello!', new='new']
        // 注意：BlockOperation eager apply，TextOperation 仅 builder.add（需手动 apply）
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('hello');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        // TextOp 先 add（不自动 apply）
        builder.add(TextOperation(
          blockId: aId,
          offset: 5,
          inserted: '!',
        ));
        // BlockOp eager apply
        BlockOperations(editor, builder)
            .insertAfter(aId, const ParagraphElement(children: [TextElement('new')]));
        final tx = builder.commit();

        // 手动 apply TextOp（BlockOp 已 eager apply）
        for (final op in tx.ops) {
          if (op is TextOperation) op.apply(editor);
        }

        final afterApply = editor.allSources.toList();
        expect(afterApply, equals(['hello!', 'new']));

        var lastTx = tx;
        for (var i = 0; i < 5; i++) {
          final undone = history.undo(lastTx);
          _revertOps(editor, undone!);
          expect(editor.allSources, equals(initialSources));

          final redone = history.redo(undone);
          _applyOps(editor, redone!);
          expect(editor.allSources, equals(afterApply));
          lastTx = redone;
        }
      });
    });

    // ============ 多 Transaction 序列闭环 ============

    group('多 Transaction 序列闭环', () {
      test('5 Transaction 序列 undo x5 → redo x5 → 状态精确恢复', () {
        // 初始：[a='']
        // T1: programmatic insert 'a' → [a='a']
        // T2: programmatic insert 'b' → [a='ab']
        // T3: programmatic insert 'c' → [a='abc']
        // T4: programmatic insertAfter(a, 'X') → [a='abc', X='X']
        // T5: programmatic insertAfter(X, 'Y') → [a='abc', X='X', Y='Y']
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        void commitInsertText(String text, int offset) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.programmatic,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: offset,
            inserted: text,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        BlockId commitInsertAfter(BlockId afterId, String text) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.programmatic,
            onChange: (tx) => history.push(tx),
          );
          final newId = BlockOperations(editor, builder).insertAfter(
            afterId,
            ParagraphElement(children: [TextElement(text)]),
          );
          builder.commit();
          return newId!;
        }

        commitInsertText('a', 0);
        commitInsertText('b', 1);
        commitInsertText('c', 2);
        final xId = commitInsertAfter(aId, 'X');
        commitInsertAfter(xId, 'Y');

        expect(history.undoCount, equals(5));
        final afterAll = editor.allSources.toList();
        expect(afterAll, equals(['abc', 'X', 'Y']));

        // undo x5：每次传 history.lastOrNull
        Transaction? lastUndone;
        for (var i = 0; i < 5; i++) {
          lastUndone = history.undo(history.lastOrNull!);
          _revertOps(editor, lastUndone!);
        }
        expect(editor.allSources, equals(initialSources));
        expect(history.canUndo, isFalse);

        // redo x5：first redo 传 lastUndone，后续传 redone
        Transaction? redone = history.redo(lastUndone!);
        _applyOps(editor, redone!);
        for (var i = 1; i < 5; i++) {
          redone = history.redo(redone!);
          _applyOps(editor, redone!);
        }
        expect(editor.allSources, equals(afterAll));
        expect(history.canRedo, isFalse);
      });

      test('多 Transaction 中途部分 undo + redo → 状态正确', () {
        // 初始：[a='']
        // T1: insert 'a' → [a='a']
        // T2: insert 'b' → [a='ab']
        // T3: insert 'c' → [a='abc']
        // undo T3 → [a='ab']
        // undo T2 → [a='a']
        // redo T2 → [a='ab']
        // undo T2（redo 后栈顶又变 T2）→ [a='a']
        // redo T2 → [a='ab']
        // redo T3 → [a='abc']
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory();

        void commitInsertText(String text, int offset) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.programmatic,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: offset,
            inserted: text,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        commitInsertText('a', 0);
        commitInsertText('b', 1);
        commitInsertText('c', 2);
        expect(history.undoCount, equals(3));

        // undo T3
        var undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.allSources, equals(['ab']));

        // undo T2
        undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.allSources, equals(['a']));

        // redo T2
        var redone = history.redo(undone);
        _applyOps(editor, redone!);
        expect(editor.allSources, equals(['ab']));

        // undo T2 again
        undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.allSources, equals(['a']));

        // redo T2
        redone = history.redo(undone);
        _applyOps(editor, redone!);
        expect(editor.allSources, equals(['ab']));

        // redo T3
        redone = history.redo(redone);
        _applyOps(editor, redone!);
        expect(editor.allSources, equals(['abc']));
      });
    });

    // ============ coalescing 跨 origin 行为 ============

    group('coalescing 跨 origin 行为', () {
      test('5 类 origin 共存场景下 coalescing 仅合并连续 keyboard TextOp', () {
        // 同 BlockId 上依次：
        // T1: keyboard 'a' @ offset=0
        // T2: keyboard 'b' @ offset=1  → 与 T1 合并（连续 keyboard TextOp）
        // T3: ime 'c' @ offset=2        → 不合并（origin != keyboard）
        // T4: keyboard 'd' @ offset=3   → 不合并（prev 是 ime）
        // T5: paste 'ef' @ offset=4     → 不合并（origin != keyboard）
        // T6: programmatic 'g' @ offset=6  → 不合并
        // 期望栈深度 = 5（T1+T2 合并为 1，T3、T4、T5、T6 各 1）
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory();

        void commitText(String text, int offset, TransactionOrigin origin) {
          final builder = TransactionBuilder(
            origin: origin,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: offset,
            inserted: text,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        commitText('a', 0, TransactionOrigin.keyboard);
        commitText('b', 1, TransactionOrigin.keyboard);
        commitText('c', 2, TransactionOrigin.ime);
        commitText('d', 3, TransactionOrigin.keyboard);
        commitText('ef', 4, TransactionOrigin.paste);
        commitText('g', 6, TransactionOrigin.programmatic);

        expect(history.undoCount, equals(5),
            reason: 'T1+T2 应合并为 1，T3-T6 各 1，总 5');
        expect(editor.sourceOf(aId), equals('abcdefg'));
      });

      test('coalescing offset 不连续 → 不合并', () {
        // T1: keyboard 'a' @ offset=0
        // T2: keyboard 'b' @ offset=1  → 连续，合并
        // T3: keyboard 'c' @ offset=5  → offset 不连续，不合并
        // 期望栈深度 = 2
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('xyz');  // 长度 3，预留跳跃空间
        final history = EditorHistory();

        void commitText(String text, int offset) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.keyboard,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: offset,
            inserted: text,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        commitText('a', 0);
        commitText('b', 1);
        commitText('c', 5);  // offset 不连续（期望 2，实际 5）

        expect(history.undoCount, equals(2),
            reason: 'T1+T2 offset 连续合并，T3 offset 不连续独立');
      });

      test('coalescing prev.ops.last 非 TextOperation → 不合并', () {
        // T1: keyboard insertAfter（BlockOp，非 TextOp）
        // T2: keyboard TextOp @ offset=0
        // 期望：T1 与 T2 不合并（prev.ops.last 不是 TextOperation）
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory();

        // T1: keyboard origin 但 op 是 BlockOp（insertAfter）
        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.keyboard,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder1)
            .insertAfter(aId, const ParagraphElement(children: [TextElement('new')]));
        builder1.commit();

        // T2: keyboard origin + TextOp，但 prev.ops.last 是 BlockOp
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.keyboard,
          onChange: (tx) => history.push(tx),
        );
        final textOp = TextOperation(blockId: aId, offset: 0, inserted: 'a');
        textOp.apply(editor);
        builder2.add(textOp);
        builder2.commit();

        expect(history.undoCount, equals(2),
            reason: 'prev.ops.last 非 TextOperation 时不合并');
      });
    });

    // ============ 自定义 canCoalesce predicate ============

    group('自定义 canCoalesce predicate', () {
      test('注入 always-false predicate → 连续 keyboard TextOp 不合并', () {
        // 用 always-false predicate 完全禁用 coalescing
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory(
          canCoalesce: (prev, next) => false,
        );

        for (var i = 0; i < 3; i++) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.keyboard,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: i,
            inserted: String.fromCharCode('a'.codeUnitAt(0) + i),
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        expect(history.undoCount, equals(3),
            reason: 'always-false predicate 禁用 coalescing');
      });

      test('注入 always-true predicate → 不同 origin 也合并', () {
        // 用 always-true predicate 强制合并（不推荐，仅验证 API 可注入）
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory(
          canCoalesce: (prev, next) => true,
        );

        void commitText(String text, int offset, TransactionOrigin origin) {
          final builder = TransactionBuilder(
            origin: origin,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: offset,
            inserted: text,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        commitText('a', 0, TransactionOrigin.keyboard);
        commitText('b', 1, TransactionOrigin.ime);
        commitText('c', 2, TransactionOrigin.paste);

        expect(history.undoCount, equals(1),
            reason: 'always-true predicate 强制合并所有');
      });
    });

    // ============ 嵌套 Transaction ============

    group('嵌套 Transaction + History 集成', () {
      test('子 builder commit 合并到 parent → parent 单次 push', () {
        // parent builder + child builder
        // child commit 把 ops 合并到 parent，不触发 onChange
        // parent commit 触发 onChange 一次，history push 1 个 Transaction
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('hello');
        final history = EditorHistory();
        var onChangeCount = 0;

        final parent = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) {
            history.push(tx);
            onChangeCount++;
          },
        );
        // parent 自己 add 一个 TextOp
        final parentOp = TextOperation(blockId: aId, offset: 5, inserted: '!');
        parentOp.apply(editor);
        parent.add(parentOp);

        // 子 builder（通过 parent 参数嵌套）
        final child = TransactionBuilder(
          parent: parent,
          origin: TransactionOrigin.programmatic,
        );
        final childOp = TextOperation(blockId: aId, offset: 6, inserted: '?');
        childOp.apply(editor);
        child.add(childOp);
        child.commit();  // 不触发 onChange

        expect(onChangeCount, equals(0));

        final tx = parent.commit();
        expect(onChangeCount, equals(1));
        expect(history.undoCount, equals(1));
        expect(tx.ops.length, equals(2));
        expect(editor.sourceOf(aId), equals('hello!?'));

        // undo 一次撤销 parent + child 的所有 ops
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.sourceOf(aId), equals('hello'));

        // redo 恢复
        final redone = history.redo(undone);
        _applyOps(editor, redone!);
        expect(editor.sourceOf(aId), equals('hello!?'));
      });
    });

    // ============ 边界场景 ============

    group('边界场景', () {
      test('空 Transaction 仍 push 入栈（undo 后无副作用）', () {
        final editor = MockDocumentEditor();
        editor.addParagraph('a');  // 初始化 editor，BlockId 不在此测试中使用
        final history = EditorHistory();

        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        builder.commit();  // 空 Transaction 也 push

        expect(history.undoCount, equals(1));
        final undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);  // 无 op，无副作用
        expect(editor.allSources, equals(['a']));
        expect(history.canUndo, isFalse);
      });

      test('history.clear 清空 undo + redo 栈', () {
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('');
        final history = EditorHistory();

        void commitText(String text, int offset) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.programmatic,
            onChange: (tx) => history.push(tx),
          );
          final textOp = TextOperation(
            blockId: aId,
            offset: offset,
            inserted: text,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
        }

        commitText('a', 0);
        commitText('b', 1);
        // undo 一次填 redo 栈
        history.undo(history.lastOrNull!);
        expect(history.undoCount, equals(1));
        expect(history.redoCount, equals(1));

        // clear 清空两栈
        history.clear();
        expect(history.canUndo, isFalse);
        expect(history.canRedo, isFalse);
        expect(history.undoCount, equals(0));
        expect(history.redoCount, equals(0));
      });
    });
  });
}
