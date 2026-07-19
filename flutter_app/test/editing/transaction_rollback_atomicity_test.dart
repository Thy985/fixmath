/// TC-EDIT-6.7 Transaction 回滚原子性测试（v1.1 评审反馈 5B 新增）。
///
/// 验证：
/// - 3 op Transaction 第 3 步失败 → 全部 rollback（editor 状态恢复）
/// - 5 op Transaction 第 1 步失败 → 直接返回 false（无 op 已 apply）
/// - 5 op Transaction 第 5 步失败 → 4 个 op 全部 rollback
/// - rollback 后 editor 状态精确恢复（含 BlockId 不残留）
/// - rollback 后可立即开新 Transaction（不阻塞）
/// - rollback 后 history.canUndo / canRedo 状态不变
/// - 嵌套 Transaction 内层 rollback → 不影响外层
/// - 嵌套 Transaction 外层 rollback → 内层 ops 全部 revert
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.7。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  /// 公共 rollback helper：revert builder 中所有 op + discard。
  void rollbackTransaction(
    MockDocumentEditor editor,
    TransactionBuilder builder,
  ) {
    for (final op in builder.ops.reversed) {
      op.revert(editor);
    }
    builder.rollback();
  }

  group('TC-EDIT-6.7 Transaction 回滚原子性', () {
    test('3 op Transaction 第 3 步失败 → 全部 rollback', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      // op 1: insert (成功)
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('x')]));
      // op 2: split (成功)
      ops.split(aId, 0);
      // op 3: delete 非法 BlockId (失败)
      final op3Success = ops.delete(BlockId(999));

      expect(op3Success, isFalse);
      expect(builder.opCount, equals(2));  // 失败 op 不入 builder

      // 检测到失败 → rollback 全部
      rollbackTransaction(editor, builder);

      // editor 状态完全恢复
      expect(editor.allSources, equals(initialSources));
      expect(builder.isCompleted, isTrue);
    });

    test('5 op Transaction 第 1 步失败 → 直接返回 false（无 op 已 apply）', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final initialBlockCount = editor.blockCount;

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      // op 1: delete 非法 BlockId (失败)
      final op1Success = ops.delete(BlockId(999));

      expect(op1Success, isFalse);
      expect(builder.opCount, equals(0));
      expect(editor.blockCount, equals(initialBlockCount));
      // 无需 rollback（无 op 已 apply）
    });

    test('5 op Transaction 第 5 步失败 → 4 个 op 全部 rollback', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('abc');
      final bId = editor.addParagraph('xyz');
      final initialSources = editor.allSources.toList();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      // op 1-4: 成功
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('NEW')]));
      ops.split(aId, 1);
      ops.delete(bId);
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('NEW2')]));
      expect(builder.opCount, equals(4));

      // op 5: 失败（split 非法 BlockId）
      final op5Success = ops.split(BlockId(999), 1);
      expect(op5Success, isFalse);
      expect(builder.opCount, equals(4));  // 失败不入 builder

      rollbackTransaction(editor, builder);

      expect(editor.allSources, equals(initialSources));
      expect(builder.isCompleted, isTrue);
    });

    test('rollback 后 editor 状态精确恢复（BlockId 不残留）', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final initialSources = editor.allSources.toList();
      final initialIds = editor.allIds.toList();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      // 3 个 insert 操作（每个都会分配新 BlockId）
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('b')]));
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('c')]));
      ops.insertAfter(aId, ParagraphElement(children: [TextElement('d')]));
      expect(editor.blockCount, equals(4));  // a + b + c + d

      rollbackTransaction(editor, builder);

      // 状态精确恢复
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(initialSources));
      expect(editor.allIds, equals(initialIds));
      // rollback 不应残留新分配的 BlockId
      expect(editor.allIds.first, equals(aId));
    });

    test('rollback 后可立即开新 Transaction（不阻塞）', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');

      final builder1 = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops1 = BlockOperations(editor, builder1);
      ops1.insertAfter(aId, ParagraphElement(children: [TextElement('b')]));
      rollbackTransaction(editor, builder1);

      expect(builder1.isCompleted, isTrue);

      // 立即开新 Transaction
      final builder2 = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops2 = BlockOperations(editor, builder2);
      ops2.insertAfter(aId, ParagraphElement(children: [TextElement('c')]));

      expect(editor.allSources, equals(['a', 'c']));
      expect(builder2.opCount, equals(1));

      final tx2 = builder2.commit();
      expect(tx2.ops.length, equals(1));
    });

    test('rollback 后 history.canUndo / canRedo 状态不变', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final history = EditorHistory();

      // 先 push 一个 Transaction 到 history
      final builder1 = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        onChange: (tx) => history.push(tx),
      );
      final ops1 = BlockOperations(editor, builder1);
      ops1.insertAfter(aId, ParagraphElement(children: [TextElement('committed')]));
      builder1.commit();

      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      // 开新 Transaction，然后 rollback
      final builder2 = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops2 = BlockOperations(editor, builder2);
      ops2.insertAfter(aId, ParagraphElement(children: [TextElement('rolled-back')]));
      rollbackTransaction(editor, builder2);

      // history 状态不变
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
      expect(history.undoCount, equals(1));
    });

    test('嵌套 Transaction 内层 rollback → 不影响外层', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');

      final parent = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final parentOps = BlockOperations(editor, parent);
      parentOps.insertAfter(aId, ParagraphElement(children: [TextElement('parent-op')]));
      expect(parent.opCount, equals(1));

      final child = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        parent: parent,
      );
      final childOps = BlockOperations(editor, child);
      childOps.insertAfter(aId, ParagraphElement(children: [TextElement('child-op')]));
      expect(child.opCount, equals(1));

      // 子 rollback：丢弃 child 的 ops，不影响 parent
      child.rollback();
      expect(child.isCompleted, isTrue);
      expect(parent.opCount, equals(1));  // parent op 仍在

      // parent 仍可 commit
      final tx = parent.commit();
      expect(tx.ops.length, equals(1));
    });

    test('嵌套 Transaction 外层 rollback → 内层 ops 全部 revert', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final initialSources = editor.allSources.toList();

      final parent = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final parentOps = BlockOperations(editor, parent);
      parentOps.insertAfter(aId, ParagraphElement(children: [TextElement('parent-op')]));

      final child = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        parent: parent,
      );
      final childOps = BlockOperations(editor, child);
      childOps.insertAfter(aId, ParagraphElement(children: [TextElement('child-op')]));
      // 子 commit：把 ops 合并到 parent
      child.commit();
      expect(parent.opCount, equals(2));  // parent 1 + child 1

      // 外层 rollback：revert parent 中所有 ops（含 child 合并的）
      rollbackTransaction(editor, parent);

      expect(parent.isCompleted, isTrue);
      expect(editor.allSources, equals(initialSources));
    });
  });
}
