/// TC-EDIT-8.1 编辑闭环集成测试。
///
/// 落地 Phase 2.8 Task Contract §3.1：验证完整编辑链路
///   source → BlockOperations → DocumentEditor → TransactionBuilder
///   → Transaction → EditorHistory.push → undo → redo → source 一致性
///
/// 与 [undo_redo_block_operations_test.dart] TC-EDIT-6.6 的差异：
/// TC-EDIT-6.6 验证"单类 op 单独循环"，本测试验证"多类 op 组合链路"，
/// 覆盖 Phase 2.7 transform / updateSource 与 Phase 2.6 五原语的协同。
///
/// 详见 Phase 2.8 Task Contract §3.1。
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
  group('TC-EDIT-8.1 编辑闭环集成测试', () {
    // ============ 单 Transaction 闭环 ============

    group('单 Transaction 闭环', () {
      test('insert + split + transform 链路 → 5 轮 undo/redo 一致', () {
        // 初始：1 块 Paragraph 'hello# Title'
        // 操作链：insertAfter + split(at 5) + 自动 transform 新块 '# Title' → heading
        // 期望：2 块 [Paragraph 'hello'] + [Heading '# Title']
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('hello# Title');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        ops.split(aId, 5);
        final tx = builder.commit();

        // tx 应包含 2 ops: split + transform（split 自动触发 transform）
        expect(tx.ops.length, equals(2));
        expect(tx.ops[0], isA<BlockOperation>());
        expect(
          (tx.ops[0] as BlockOperation).opType,
          equals(BlockOpType.split),
        );
        expect(tx.ops[1], isA<BlockOperation>());
        expect(
          (tx.ops[1] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );

        // 应用后状态
        final afterApply = editor.allSources.toList();
        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(aId), isA<ParagraphElement>());
        expect(editor.sourceOf(aId), equals('hello'));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HeadingElement>());
        expect(editor.sourceOf(newId), equals('# Title'));

        // 5 轮 undo/redo 循环
        var lastTx = tx;
        for (var i = 0; i < 5; i++) {
          final undone = history.undo(lastTx);
          _revertOps(editor, undone!);
          expect(editor.allSources, equals(initialSources));
          expect(editor.blockCount, equals(1));
          expect(editor.allIds.first, equals(aId));
          expect(editor.getBlock(aId), isA<ParagraphElement>());
          expect(editor.sourceOf(aId), equals('hello# Title'));

          final redone = history.redo(undone);
          _applyOps(editor, redone!);
          expect(editor.allSources, equals(afterApply));
          expect(editor.blockCount, equals(2));
          expect(editor.getBlock(newId), isA<HeadingElement>());
          lastTx = redone;
        }
      });

      test('updateSource 触发 transform 链路 → 5 轮 undo/redo 一致', () {
        // 初始：1 块 Paragraph 'hello'
        // 操作链：updateSource(blockId, '# Title')
        //   → 内部触发 transform (paragraph → heading) + TextOperation
        // 期望：1 块 Heading '# Title'
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        ops.updateSource(id, '# Title');
        final tx = builder.commit();

        // tx 应包含 2 ops: transform + TextOperation
        expect(tx.ops.length, equals(2));
        expect(tx.ops[0], isA<BlockOperation>());
        expect(
          (tx.ops[0] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
        expect(tx.ops[1], isA<TextOperation>());

        final afterApply = editor.allSources.toList();

        var lastTx = tx;
        for (var i = 0; i < 5; i++) {
          final undone = history.undo(lastTx);
          _revertOps(editor, undone!);
          expect(editor.allSources, equals(initialSources));
          expect(editor.getBlock(id), isA<ParagraphElement>());

          final redone = history.redo(undone);
          _applyOps(editor, redone!);
          expect(editor.allSources, equals(afterApply));
          expect(editor.getBlock(id), isA<HeadingElement>());
          lastTx = redone;
        }
      });

      test('delete + move + merge 链路 → 5 轮 undo/redo 一致', () {
        // 初始：4 块 ['a', 'b', 'c', 'd']
        // 操作链：delete(b) + move(d, a, before=true) + merge(a, d)
        // 期望：2 块 ['d', 'a']
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        final bId = editor.addParagraph('b');
        editor.addParagraph('c');
        final dId = editor.addParagraph('d');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops = BlockOperations(editor, builder);
        ops.delete(bId);
        ops.move(dId, aId, before: true);
        ops.merge(aId, dId);  // merge left=a, right=d
        final tx = builder.commit();

        // tx 应包含 3 ops: delete + move + merge
        expect(tx.ops.length, equals(3));

        final afterApply = editor.allSources.toList();
        expect(editor.blockCount, equals(2));

        var lastTx = tx;
        for (var i = 0; i < 5; i++) {
          final undone = history.undo(lastTx);
          _revertOps(editor, undone!);
          expect(editor.allSources, equals(initialSources));
          expect(editor.blockCount, equals(4));

          final redone = history.redo(undone);
          _applyOps(editor, redone!);
          expect(editor.allSources, equals(afterApply));
          expect(editor.blockCount, equals(2));
          lastTx = redone;
        }
      });
    });

    // ============ 多 Transaction 闭环 ============

    group('多 Transaction 序列闭环', () {
      test('4 个独立 Transaction → undo x4 → redo x4 一致', () {
        // 初始：1 块 Paragraph 'a'
        // T1: insertAfter(a, 'b') → ['a', 'b']
        // T2: split(a, 1) → a 保留前 1 字符 = 'a'，新块 '' 插入到 a 之后
        //     顺序：[a(idx0), newEmpty(idx1), b(idx2)]
        // T3: updateSource(newEmpty, '# Title') → transform paragraph → heading + TextOperation
        // T4: delete(a) → 只剩 ['# Title'(heading), 'b']
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        final history = EditorHistory();

        // T1
        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder1)
            .insertAfter(aId, const ParagraphElement(children: [TextElement('b')]));
        builder1.commit();

        // T2: split a at offset 1 → 新块 id 在 aId 的下一位
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder2).split(aId, 1);
        builder2.commit();
        // split 后新块在 aId + 1 的位置
        final newEmptyId = editor.allIds[editor.indexOf(aId) + 1];
        expect(newEmptyId, isNot(equals(aId)));
        expect(editor.sourceOf(newEmptyId), equals(''));

        // T3: updateSource(空块, '# Title') → transform + TextOperation
        final builder3 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder3).updateSource(newEmptyId, '# Title');
        builder3.commit();
        expect(editor.getBlock(newEmptyId), isA<HeadingElement>());

        // T4: delete(aId)
        final builder4 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder4).delete(aId);
        builder4.commit();

        expect(history.undoCount, equals(4));

        final afterAll = editor.allSources.toList();
        expect(afterAll.length, equals(2));
        expect(editor.sourceOf(editor.allIds.first), equals('# Title'));
        expect(editor.sourceOf(editor.allIds.last), equals('b'));

        // undo x4：每次传 history.lastOrNull（即将被 undo 的 Transaction）
        // 参照 undo_redo_round_trip_test.dart:246-260 的正确模式。
        Transaction? lastUndone;
        for (var i = 0; i < 4; i++) {
          lastUndone = history.undo(history.lastOrNull!);
          _revertOps(editor, lastUndone!);
        }
        // 应回到初始状态：1 块 ['a']
        expect(editor.blockCount, equals(1));
        expect(editor.allSources, equals(['a']));

        // redo x4：currentState 传"上一次操作的 Transaction"
        // redo 1 传 lastUndone（最后一次 undo 返回的），
        // 后续传上一次 redo 返回的。
        Transaction? redone = history.redo(lastUndone!);
        _applyOps(editor, redone!);
        for (var i = 1; i < 4; i++) {
          redone = history.redo(redone!);
          _applyOps(editor, redone!);
        }
        expect(editor.allSources, equals(afterAll));
        // 注：不在此处再 undo x4 验证 redo 不破坏 undo 链——
        // HistoryManager.redo(currentState) 在 currentState 与 redoStack 栈顶
        // 不一致时会向 undoStack 推入重复项（已知 API 限制，Phase 2.8 不修复，
        // 留作 Phase 3+ TransactionExecutor 抽象的改进项，见 ADR-0008 §10）。
      });

      test('多 Transaction 中途部分 undo + 部分 redo → 状态正确', () {
        // 初始：1 块 'a'
        // T1: insertAfter(a, 'b') → ['a', 'b']
        // T2: insertAfter(b, 'c') → ['a', 'b', 'c']  （用上次插入的 id 作为锚点）
        // T3: insertAfter(c, 'd') → ['a', 'b', 'c', 'd']
        // undo T3 → ['a', 'b', 'c']
        // undo T2 → ['a', 'b']
        // redo T2 → ['a', 'b', 'c']
        // redo T3 → ['a', 'b', 'c', 'd']
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        final history = EditorHistory();

        // 追加式插入：每次用上次插入返回的 BlockId 作为新锚点，
        // 确保 [a, b, c, d] 而非 [a, d, c, b]（连续 insertAfter(a) 会反向插入）。
        BlockId buildAndCommit(BlockId afterId, String text) {
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

        final bId = buildAndCommit(aId, 'b');
        final cId = buildAndCommit(bId, 'c');
        buildAndCommit(cId, 'd');

        expect(editor.allSources, equals(['a', 'b', 'c', 'd']));
        expect(history.undoCount, equals(3));

        // undo T3（栈顶）：传 history.lastOrNull（即将被 undo 的）
        var undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.allSources, equals(['a', 'b', 'c']));

        // undo T2
        undone = history.undo(history.lastOrNull!);
        _revertOps(editor, undone!);
        expect(editor.allSources, equals(['a', 'b']));

        // redo T2（redo 1 传最后一次 undo 返回的 undone）
        var redone = history.redo(undone);
        _applyOps(editor, redone!);
        expect(editor.allSources, equals(['a', 'b', 'c']));

        // redo T3（后续传上一次 redo 返回的 redone）
        redone = history.redo(redone);
        _applyOps(editor, redone!);
        expect(editor.allSources, equals(['a', 'b', 'c', 'd']));
      });
    });

    // ============ coalescing 在闭环中的行为 ============

    group('coalescing 在闭环中的行为', () {
      test('连续 keyboard TextOperation 合并 → undo 1 次撤销全部', () {
        // 初始：1 块 ''
        // 5 次 keyboard TextOperation（同 BlockId、offset 连续递增、< 500ms）→ 合并为 1 个 Transaction
        // undo 1 次应回到初始
        //
        // 关键：必须用 offset 连续递增的 TextOperation（不是 updateSource 全量替换，
        // 因为 updateSource 用 offset=0+全量替换，offset 不连续，不触发 coalescing）
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();

        // 模拟逐字符追加输入 'hello'
        const chars = ['h', 'e', 'l', 'l', 'o'];
        var currentOffset = 0;
        for (final ch in chars) {
          final builder = TransactionBuilder(
            origin: TransactionOrigin.keyboard,
            onChange: (tx) => history.push(tx),
          );
          // 直接构造 TextOperation：在末尾追加 1 字符（offset 连续递增）
          final textOp = TextOperation(
            blockId: id,
            offset: currentOffset,
            deleted: '',
            inserted: ch,
          );
          textOp.apply(editor);
          builder.add(textOp);
          builder.commit();
          currentOffset++;
        }

        // coalescing 应合并 5 次为 1 个 Transaction
        expect(history.undoCount, equals(1),
            reason: '5 次 offset 连续的 keyboard TextOperation 应 coalesce 为 1 个');

        // undo 1 次应回到初始
        // 关键：必须传 history.lastOrNull（栈顶 Transaction，即 coalescing 合并后的），
        // 而非 commit() 的返回值（commit 返回本次提交的 Transaction，但合并后栈顶被替换）。
        // 参照 undo_redo_round_trip_test.dart:197-198 的正确模式。
        final undone = history.undo(history.lastOrNull!)!;
        _revertOps(editor, undone);
        expect(editor.allSources, equals(initialSources));

        // redo
        final redone = history.redo(undone)!;
        _applyOps(editor, redone);
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('keyboard + ime 混合 → 不合并', () {
        // 初始：1 块 ''
        // T1: keyboard 'a'（合并候选）
        // T2: ime 'b'（不与 keyboard 合并）
        // T3: keyboard 'c'（不与 ime 合并）
        // 期望：3 个独立 Transaction
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('');
        final history = EditorHistory();

        void commitWith(String text, TransactionOrigin origin) {
          final builder = TransactionBuilder(
            origin: origin,
            onChange: (tx) => history.push(tx),
          );
          BlockOperations(editor, builder)
              .updateSource(id, editor.sourceOf(id) + text);
          builder.commit();
        }

        commitWith('a', TransactionOrigin.keyboard);
        commitWith('b', TransactionOrigin.ime);
        commitWith('c', TransactionOrigin.keyboard);

        expect(history.undoCount, equals(3),
            reason: '不同 origin 不应合并');
        expect(editor.sourceOf(id), equals('abc'));
      });

      test('paste 后接 keyboard → paste 独立，keyboard 独立', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('');
        final history = EditorHistory();

        void commitWith(String text, TransactionOrigin origin) {
          final builder = TransactionBuilder(
            origin: origin,
            onChange: (tx) => history.push(tx),
          );
          BlockOperations(editor, builder)
              .updateSource(id, editor.sourceOf(id) + text);
          builder.commit();
        }

        // paste 'hello'（5 字符一次性）
        commitWith('hello', TransactionOrigin.paste);
        // 接 keyboard '!'
        commitWith('!', TransactionOrigin.keyboard);

        expect(history.undoCount, equals(2),
            reason: 'paste 与 keyboard 不应合并');
        expect(editor.sourceOf(id), equals('hello!'));
      });
    });

    // ============ 复合链路：split + transform + updateSource + undo ============

    group('复合链路', () {
      test('split + transform + updateSource + delete 链路 → undo 完全恢复', () {
        // 初始：1 块 'ab# Title'
        // 1. split at 2 → 'ab' + '# Title'
        // 2. 自动 transform 新块 → '# Title' 变 Heading
        // 3. updateSource(newId, '## Sub') → heading level 变 2
        // 4. delete(原块 aId) → 只剩 1 块
        // 期望 undo x4 完全恢复
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('ab# Title');
        final history = EditorHistory();
        final initialSources = editor.allSources.toList();
        final initialIds = editor.allIds.toList();

        // T1: split + auto transform（一个 Transaction）
        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder1).split(aId, 2);
        builder1.commit();

        // 找到新块的 id（最后一个 id）
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HeadingElement>());

        // T2: updateSource(newId, '## Sub')
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder2).updateSource(newId, '## Sub');
        builder2.commit();

        // T3: delete(aId)
        final builder3 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder3).delete(aId);
        final tx3 = builder3.commit();

        expect(history.undoCount, equals(3));
        expect(editor.blockCount, equals(1));
        expect(editor.sourceOf(newId), equals('## Sub'));

        // undo x3 → 完全恢复
        var lastTx = tx3;
        for (final expected in [
          [aId, newId],  // undo T3 后：恢复 aId，2 块
          [aId, newId],  // undo T2 后：2 块，但 newId 恢复为 '# Title'
          [aId],         // undo T1 后：1 块
        ]) {
          final undone = history.undo(lastTx)!;
          _revertOps(editor, undone);
          expect(editor.allIds.length, equals(expected.length));
          lastTx = undone;
        }
        expect(editor.allSources, equals(initialSources));
        expect(editor.allIds, equals(initialIds));
        expect(editor.sourceOf(aId), equals('ab# Title'));
      });
    });

    // ============ 边界：空 Transaction 不入栈 ============

    group('边界场景', () {
      test('rollback 后 history 状态不变', () {
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        final history = EditorHistory();

        // 先 commit 一个 T1
        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder1)
            .insertAfter(aId, const ParagraphElement(children: [TextElement('b')]));
        builder1.commit();
        expect(history.undoCount, equals(1));

        // 开 T2，rollback（不入栈）
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final ops2 = BlockOperations(editor, builder2);
        ops2.insertAfter(aId, const ParagraphElement(children: [TextElement('c')]));
        // rollback：先 revert ops，再 builder.rollback
        for (final op in builder2.ops.reversed) {
          op.revert(editor);
        }
        builder2.rollback();

        // history 不变
        expect(history.undoCount, equals(1));
        expect(history.canUndo, isTrue);
        expect(editor.allSources, equals(['a', 'b']));
      });

      test('空 Transaction commit 不破坏 history', () {
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        final history = EditorHistory();

        // T1: 有 op
        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, builder1)
            .insertAfter(aId, const ParagraphElement(children: [TextElement('b')]));
        builder1.commit();

        // T2: 空 op（commit 但无 add）
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        builder2.commit();  // 空 Transaction 也 push

        expect(history.undoCount, equals(2));
        // undo T2（空 op revert 无效果）
        final lastTx = history.lastOrNull!;
        final undone = history.undo(lastTx)!;
        _revertOps(editor, undone);  // 无 op，无副作用
        expect(editor.allSources, equals(['a', 'b']));
      });
    });
  });
}
