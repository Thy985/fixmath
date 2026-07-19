/// TC-EDIT-6.3 EditorHistory coalescing + canCoalesce 注入测试。
///
/// 验证：
/// - push 入栈 / coalescing 合并 / 不合并独立入栈
/// - undo / redo 行为正确
/// - canCoalesce predicate 可注入（v1.1 评审反馈 4）
/// - _defaultCanCoalesce 7 触发条件（v1.2 升级）
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.3。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';

void main() {
  group('TC-EDIT-6.3 EditorHistory 基本 push/undo/redo', () {
    test('push 入栈，undoCount 增加', () {
      final history = EditorHistory();
      final tx = _makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'x')],
      );

      history.push(tx);

      expect(history.undoCount, equals(1));
      expect(history.canUndo, isTrue);
    });

    test('undo 后 redo 栈填充', () {
      final history = EditorHistory();
      final tx = _makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'x')],
      );
      history.push(tx);

      final undone = history.undo(tx);

      expect(undone, isNotNull);
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);
    });

    test('redo 恢复 undo 的 Transaction', () {
      final history = EditorHistory();
      final tx = _makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'x')],
      );
      history.push(tx);
      final undone = history.undo(tx);
      final redone = history.redo(undone!);  // redo 而非 undo

      expect(redone, isNotNull);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('clear 清空 undo / redo 栈', () {
      final history = EditorHistory();
      history.push(_makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'x')],
      ));
      history.push(_makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'y')],
      ));

      history.clear();

      expect(history.undoCount, equals(0));
      expect(history.redoCount, equals(0));
    });
  });

  group('TC-EDIT-6.3 _defaultCanCoalesce 7 触发条件', () {
    test('同 BlockId + offset 连续 + keyboard + < 500ms → 合并', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'b')],
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(1));  // 合并
    });

    test('不同 BlockId → 不合并', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(2), offset: 0, inserted: 'b')],  // 不同 BlockId
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('offset 不连续 → 不合并', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      // tx1 后预期 offset=1，但 tx2 offset=5（不连续）
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 5, inserted: 'b')],
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('prev.origin != keyboard → 不合并', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.programmatic,  // 非 keyboard
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'b')],
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('next.origin != keyboard → 不合并（v1.2 补强）', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.paste,  // 非 keyboard
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'b')],
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('ime origin 不合并（独立成单元）', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.ime,  // IME commit 独立
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: '你')],
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('超过 500ms → 不合并', () {
      final history = EditorHistory();
      final now = DateTime.now();

      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'b')],
        timestamp: now.add(const Duration(milliseconds: 600)),  // 超过 500ms
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('prev.ops.last 不是 TextOperation → 不合并', () {
      final history = EditorHistory();
      final now = DateTime.now();
      final blockId = BlockId(1);

      // prev.ops.last 是 BlockOperation（非 TextOperation）
      final tx1 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [BlockOperation(opType: BlockOpType.insert, targetId: blockId)],
        timestamp: now,
      );
      final tx2 = _makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now.add(const Duration(milliseconds: 100)),
      );

      history.push(tx1);
      history.push(tx2);

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('连续多 op coalescing：5 个 TextOperation 合并为 1', () {
      final history = EditorHistory();
      final blockId = BlockId(1);
      var time = DateTime.now();

      // 输入 "hello" = 5 个 TextOperation
      final ops = ['h', 'e', 'l', 'l', 'o'];
      for (var i = 0; i < ops.length; i++) {
        final tx = _makeTransaction(
          origin: TransactionOrigin.keyboard,
          ops: [TextOperation(blockId: blockId, offset: i, inserted: ops[i])],
          timestamp: time,
        );
        history.push(tx);
        time = time.add(const Duration(milliseconds: 50));
      }

      expect(history.undoCount, equals(1));  // 5 个合并为 1
      final last = history.lastOrNull!;
      expect(last.ops.length, equals(5));  // 合并后包含 5 个 ops
    });
  });

  group('TC-EDIT-6.3 canCoalesce predicate 注入（v1.1 评审反馈 4）', () {
    test('注入 always-true predicate → 所有 push 都合并', () {
      final history = EditorHistory(
        canCoalesce: (_, __) => true,  // 总是合并
      );

      history.push(_makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
      ));
      history.push(_makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(2), offset: 0, inserted: 'b')],
      ));
      history.push(_makeTransaction(
        origin: TransactionOrigin.programmatic,
        ops: [TextOperation(blockId: BlockId(3), offset: 0, inserted: 'c')],
      ));

      expect(history.undoCount, equals(1));  // 全部合并
      expect(history.lastOrNull!.ops.length, equals(3));
    });

    test('注入 always-false predicate → 不合并', () {
      final history = EditorHistory(
        canCoalesce: (_, __) => false,  // 不合并
      );

      final now = DateTime.now();
      history.push(_makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      ));
      history.push(_makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'b')],
        timestamp: now,
      ));

      expect(history.undoCount, equals(2));  // 不合并
    });

    test('注入自定义 predicate：仅同 origin 合并', () {
      final history = EditorHistory(
        canCoalesce: (prev, next) => prev.origin == next.origin,
      );

      final now = DateTime.now();
      history.push(_makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      ));
      history.push(_makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(99), offset: 0, inserted: 'b')],  // 不同 BlockId
        timestamp: now.add(const Duration(seconds: 10)),  // 超时
      ));
      // 同 origin → 合并
      expect(history.undoCount, equals(1));

      history.push(_makeTransaction(
        origin: TransactionOrigin.programmatic,  // 不同 origin
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'c')],
      ));
      // 不同 origin → 不合并
      expect(history.undoCount, equals(2));
    });
  });

  group('TC-EDIT-6.3 coalescingWindow 自定义', () {
    test('1000ms 窗口：600ms 间隔仍合并', () {
      final history = EditorHistory(
        coalescingWindow: const Duration(milliseconds: 1000),
      );
      final now = DateTime.now();

      history.push(_makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 0, inserted: 'a')],
        timestamp: now,
      ));
      history.push(_makeTransaction(
        origin: TransactionOrigin.keyboard,
        ops: [TextOperation(blockId: BlockId(1), offset: 1, inserted: 'b')],
        timestamp: now.add(const Duration(milliseconds: 600)),  // 600ms
      ));

      expect(history.undoCount, equals(1));  // 合并
    });
  });
}

// ============ Test helpers ============

Transaction _makeTransaction({
  required TransactionOrigin origin,
  required List<EditOperation> ops,
  DateTime? timestamp,
  String? label,
}) {
  return Transaction(
    id: TransactionId.next(),
    ops: ops,
    metadata: TransactionMetadata(
      timestamp: timestamp ?? DateTime.now(),
      label: label,
    ),
    origin: origin,
  );
}
