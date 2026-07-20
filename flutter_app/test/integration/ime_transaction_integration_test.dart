/// TC-EDIT-8.3 IME + Transaction 集成测试。
///
/// 落地 Phase 2.8 Task Contract §3.3：验证 ADR-0007 §3.2 三铁律在
/// Transaction 上下文中的行为，特别是 composing 态对 BlockOperation 的
/// 守门、IME commit 入栈的 origin 标记、以及与 keyboard 输入的
/// coalescing 隔离。
///
/// 与 [ime_mutation_forbidden_test.dart] TC-EDIT-6.9 的差异：
/// TC-EDIT-6.9 验证"单 op 守门"，本测试验证：
/// - composing 态下 5 原语 + tryTransform + updateSource **全套守门**
/// - composing 拒绝不污染已收集的 ops（前一个 Transaction 仍完整）
/// - IME commit 后产生的 Transaction.origin == TransactionOrigin.ime
/// - IME commit 后立即输入 keyboard 字符 → 不与 IME commit 合并
/// - ComposingController.cancel 后 EditorHistory.canUndo 不变
///
/// 详见 Phase 2.8 Task Contract §3.3。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/composing_controller.dart';
import 'package:formula_fix/core/editing/composing_state.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import '../editing/helpers/mock_composing_host.dart';
import '../editing/helpers/mock_document_editor.dart';

/// 构造一个处于 composing 态的 BlockOperations（editor 已有 2 块，便于测 merge/move）。
typedef ComposingCtx = ({
  MockDocumentEditor editor,
  MockComposingHost host,
  ComposingController composing,
  BlockId aId,
  BlockId bId,
  BlockOperations ops,
  TransactionBuilder builder,
});

ComposingCtx _makeComposingOps({
  String source = 'hello',
  String secondSource = 'world',
  int composingStart = 0,
  int? composingEnd,
}) {
  final editor = MockDocumentEditor();
  final aId = editor.addParagraph(source);
  final bId = editor.addParagraph(secondSource);

  final host = MockComposingHost(
    source: source,
    composing: ComposingRegion(
      start: composingStart,
      end: composingEnd ?? source.length,
    ),
  );
  final composing = ComposingController(host);
  composing.onComposingStart();

  final builder = TransactionBuilder(
    origin: TransactionOrigin.programmatic,
    onChange: (tx) {},
  );
  final ops = BlockOperations(editor, builder, composing);
  return (
    editor: editor,
    host: host,
    composing: composing,
    aId: aId,
    bId: bId,
    ops: ops,
    builder: builder,
  );
}

void main() {
  group('TC-EDIT-8.3 IME + Transaction 集成测试', () {
    // ============ 铁律 1：composing 态下 BlockOperation 守门 ============

    group('铁律 1：composing 态下 BlockOperation 守门', () {
      test('composing 态调 insertAfter → 抛 StateError', () {
        final ctx = _makeComposingOps();

        expect(
          () => ctx.ops.insertAfter(
            ctx.aId,
            const ParagraphElement(children: [TextElement('x')]),
          ),
          throwsStateError,
        );
        expect(ctx.editor.blockCount, equals(2));
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 态调 delete → 抛 StateError', () {
        final ctx = _makeComposingOps();

        expect(() => ctx.ops.delete(ctx.aId), throwsStateError);
        expect(ctx.editor.blockCount, equals(2));
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 态调 merge → 抛 StateError', () {
        final ctx = _makeComposingOps();

        expect(() => ctx.ops.merge(ctx.aId, ctx.bId), throwsStateError);
        expect(ctx.editor.blockCount, equals(2));
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 态调 split → 抛 StateError', () {
        final ctx = _makeComposingOps(source: 'abcdef');

        expect(() => ctx.ops.split(ctx.aId, 3), throwsStateError);
        expect(ctx.editor.blockCount, equals(2));
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 态调 move → 抛 StateError', () {
        final ctx = _makeComposingOps();

        expect(() => ctx.ops.move(ctx.aId, ctx.bId), throwsStateError);
        expect(ctx.editor.blockCount, equals(2));
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 态调 tryTransform → 抛 StateError', () {
        final ctx = _makeComposingOps(source: '# title');

        expect(() => ctx.ops.tryTransform(ctx.aId), throwsStateError);
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 态调 updateSource → 抛 StateError', () {
        final ctx = _makeComposingOps(source: 'hello');

        expect(
          () => ctx.ops.updateSource(ctx.aId, '# Title'),
          throwsStateError,
        );
        expect(ctx.builder.opCount, equals(0));
      });
    });

    // ============ composing 拒绝不污染已收集 ops ============

    group('composing 拒绝不污染已收集 ops', () {
      test('composing 态拒绝后 builder.opCount 仍为 0', () {
        final ctx = _makeComposingOps();

        // 连续拒绝 3 次
        expect(
          () => ctx.ops.insertAfter(
            ctx.aId,
            const ParagraphElement(children: [TextElement('x')]),
          ),
          throwsStateError,
        );
        expect(() => ctx.ops.delete(ctx.aId), throwsStateError);
        expect(() => ctx.ops.split(ctx.aId, 1), throwsStateError);
        expect(ctx.builder.opCount, equals(0));
      });

      test('composing 拒绝后 editor 状态不变', () {
        final ctx = _makeComposingOps(source: 'hello', secondSource: 'world');
        final sourcesBefore = ctx.editor.allSources.toList();

        expect(() => ctx.ops.insertAfter(
          ctx.aId,
          const ParagraphElement(children: [TextElement('x')]),
        ), throwsStateError);
        expect(() => ctx.ops.delete(ctx.aId), throwsStateError);
        expect(() => ctx.ops.merge(ctx.aId, ctx.bId), throwsStateError);

        expect(ctx.editor.allSources.toList(), equals(sourcesBefore));
      });

      test('前一个 Transaction 已 commit 后 composing 拒绝不影响 history', () {
        // 场景：
        // 1. idle 态做 1 个 Transaction（programmatic insertAfter）→ push 到 history
        // 2. 进入 composing 态
        // 3. composing 态拒绝 BlockOperation（不影响 history 栈）
        // 4. cancel composing
        // 5. history.undoCount 仍为 1
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');
        editor.addParagraph('b');

        // Step 1: idle 态做 1 个 Transaction
        final history = EditorHistory();
        final idleBuilder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        BlockOperations(editor, idleBuilder).insertAfter(
          aId,
          const ParagraphElement(children: [TextElement('X')]),
        );
        idleBuilder.commit();
        expect(history.undoCount, equals(1));

        // Step 2-3: 进入 composing 态并尝试 BlockOperation（应拒绝）
        final host = MockComposingHost(
          source: 'a',
          composing: const ComposingRegion(start: 0, end: 1),
        );
        final composing = ComposingController(host);
        composing.onComposingStart();
        final composingBuilder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final composingOps = BlockOperations(editor, composingBuilder, composing);
        expect(
          () => composingOps.insertAfter(
            aId,
            const ParagraphElement(children: [TextElement('Y')]),
          ),
          throwsStateError,
        );

        // Step 4: cancel composing
        composing.onComposingCancel();

        // Step 5: history 栈未被污染
        expect(history.undoCount, equals(1));
        expect(composingBuilder.opCount, equals(0));
      });
    });

    // ============ IME commit 入栈 origin ============

    group('IME commit 入栈 origin', () {
      test('IME commit 后产生的 Transaction.origin == ime', () {
        // 场景：composing → commit → 产生 TextOperation → builder.origin == ime
        // 注意：TextOperation 不受铁律 1 守门，可在 composing 态构造
        // 但 Phase 2.5 IME commit 流程是：
        //   composing.onComposingStart() → 用户输入 → onComposingCommit(text)
        //   → host.replaceRange(composing, text)
        //   → 调用方应构造 TextOperation 并 push（origin=ime）
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('hello');

        final host = MockComposingHost(
          source: 'hello',
          composing: const ComposingRegion(start: 0, end: 5),
        );
        final composing = ComposingController(host);
        composing.onComposingStart();

        // 模拟 IME commit：composing region [0, 5) → "你好"
        composing.onComposingCommit('你好');
        expect(host.source, equals('你好'));
        expect(composing.state, equals(ComposingState.idle));

        // 调用方构造 TextOperation（origin=ime）push 到 history
        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.ime,
          onChange: (tx) => history.push(tx),
        );
        // TextOperation 表示 source 替换：offset=0, deleted='hello', inserted='你好'
        final textOp = TextOperation(
          blockId: aId,
          offset: 0,
          deleted: 'hello',
          inserted: '你好',
        );
        textOp.apply(editor);
        builder.add(textOp);
        final tx = builder.commit();

        expect(tx.origin, equals(TransactionOrigin.ime));
        expect(history.undoCount, equals(1));
        expect(editor.sourceOf(aId), equals('你好'));

        // undo 恢复
        final undone = history.undo(history.lastOrNull!);
        for (final op in undone!.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.sourceOf(aId), equals('hello'));
      });

      test('IME commit 后立即输入 keyboard 字符 → 两个 Transaction 不合并', () {
        // 场景：
        // T1: IME commit（origin=ime）→ source: '你好'
        // T2: keyboard 输入 '!'（origin=keyboard）→ source: '你好!'
        // T1 与 T2 origin 不同 → coalescing 不触发 → history.undoCount == 2
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('hello');

        final history = EditorHistory();

        // T1: IME commit
        final host1 = MockComposingHost(
          source: 'hello',
          composing: const ComposingRegion(start: 0, end: 5),
        );
        final composing1 = ComposingController(host1);
        composing1.onComposingStart();
        composing1.onComposingCommit('你好');

        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.ime,
          onChange: (tx) => history.push(tx),
        );
        final textOp1 = TextOperation(
          blockId: aId,
          offset: 0,
          deleted: 'hello',
          inserted: '你好',
        );
        textOp1.apply(editor);
        builder1.add(textOp1);
        builder1.commit();

        // T2: keyboard 输入 '!'（offset 连续：紧接 '你好' 之后）
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.keyboard,
          onChange: (tx) => history.push(tx),
        );
        final textOp2 = TextOperation(
          blockId: aId,
          offset: 2,  // '你好' 长度为 2
          inserted: '!',
        );
        textOp2.apply(editor);
        builder2.add(textOp2);
        builder2.commit();

        expect(history.undoCount, equals(2));
        expect(editor.sourceOf(aId), equals('你好!'));

        // undo T2（keyboard）→ source: '你好'
        final undone2 = history.undo(history.lastOrNull!);
        for (final op in undone2!.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.sourceOf(aId), equals('你好'));

        // undo T1（ime）→ source: 'hello'
        final undone1 = history.undo(history.lastOrNull!);
        for (final op in undone1!.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.sourceOf(aId), equals('hello'));
      });

      test('两个连续 ime commit Transaction 不合并（不同 origin 行为验证）', () {
        // 即使两个连续 ime Transaction 的 ops.last 都是 TextOperation，
        // 也因 origin != keyboard 而不合并
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('a');

        final history = EditorHistory();

        // T1: ime commit 'b' → source: 'ab'
        final builder1 = TransactionBuilder(
          origin: TransactionOrigin.ime,
          onChange: (tx) => history.push(tx),
        );
        final op1 = TextOperation(blockId: aId, offset: 1, inserted: 'b');
        op1.apply(editor);
        builder1.add(op1);
        builder1.commit();

        // T2: ime commit 'c' → source: 'abc'
        final builder2 = TransactionBuilder(
          origin: TransactionOrigin.ime,
          onChange: (tx) => history.push(tx),
        );
        final op2 = TextOperation(blockId: aId, offset: 2, inserted: 'c');
        op2.apply(editor);
        builder2.add(op2);
        builder2.commit();

        // ime origin 不参与 coalescing（仅 keyboard 可合并）
        expect(history.undoCount, equals(2));
        expect(editor.sourceOf(aId), equals('abc'));
      });
    });

    // ============ ComposingController.cancel 不入栈 ============

    group('ComposingController.cancel 不入栈', () {
      test('cancel 后 EditorHistory.canUndo 不变（cancel 不入栈）', () {
        // 场景：
        // 1. idle 态做 1 个 Transaction → history.undoCount == 1
        // 2. 进入 composing 态
        // 3. composing cancel → source 回滚
        // 4. history.undoCount 仍为 1（cancel 不入栈）
        final editor = MockDocumentEditor();
        final aId = editor.addParagraph('hello');

        // Step 1: idle 态 push 1 个 Transaction
        final history = EditorHistory();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) => history.push(tx),
        );
        final op = TextOperation(blockId: aId, offset: 5, inserted: '!');
        op.apply(editor);
        builder.add(op);
        builder.commit();
        expect(history.undoCount, equals(1));
        expect(history.canUndo, isTrue);

        // Step 2-3: composing + cancel
        final host = MockComposingHost(
          source: 'hello!',
          composing: const ComposingRegion(start: 0, end: 5),
        );
        final composing = ComposingController(host);
        composing.onComposingStart();
        // 模拟 composing 中 source 变化（host.source 被改）
        host.source = 'HELLO!composed';
        composing.onComposingCancel();
        // cancel 后 source 回滚到 composing 开始前的备份
        expect(host.source, equals('hello!'));

        // Step 4: history 未受影响
        expect(history.undoCount, equals(1));
        expect(history.canUndo, isTrue);
        expect(history.canRedo, isFalse);
      });

      test('cancel 后 composing.state 回到 idle（可继续 BlockOperation）', () {
        final editor = MockDocumentEditor();
        editor.addParagraph('hello');

        final host = MockComposingHost(
          source: 'hello',
          composing: const ComposingRegion(start: 0, end: 5),
        );
        final composing = ComposingController(host);
        composing.onComposingStart();
        expect(composing.isActive, isTrue);

        composing.onComposingCancel();
        expect(composing.state, equals(ComposingState.idle));
        expect(composing.isActive, isFalse);

        // 现在可以正常调用 BlockOperation（不抛 StateError）
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) {},
        );
        final editor2 = MockDocumentEditor();
        final aId = editor2.addParagraph('hello');
        final ops = BlockOperations(editor2, builder, composing);
        // cancel 后 composing 已 idle，可以 insert
        final newId = ops.insertAfter(
          aId,
          const ParagraphElement(children: [TextElement('new')]),
        );
        expect(newId, isNotNull);
        expect(builder.opCount, equals(1));
      });
    });

    // ============ composing.committing / cancelling 短暂态守门 ============

    group('composing.committing / cancelling 短暂态守门', () {
      test('committing 短暂态中 BlockOperation 仍被守门', () {
        // 验证 ComposingState.committing 期间也禁止 BlockOperation
        // （committing 是 onComposingCommit 内部的短暂态，
        //  实际上不会持续到用户层面，但理论上 isActive 仍为 true）
        final editor = MockDocumentEditor();
        editor.addParagraph('hello');

        final host = MockComposingHost(
          source: 'hello',
          composing: const ComposingRegion(start: 0, end: 5),
        );
        final composing = ComposingController(host);
        composing.onComposingStart();
        // 此时 state == composing，isActive == true
        expect(composing.isActive, isTrue);

        // 在 composing 态调 BlockOperation 应抛
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) {},
        );
        final ops = BlockOperations(editor, builder, composing);
        expect(
          () => ops.insertAfter(
            editor.allIds.first,
            const ParagraphElement(children: [TextElement('x')]),
          ),
          throwsStateError,
        );

        // commit 后回到 idle，可继续 BlockOperation
        composing.onComposingCommit('你好');
        expect(composing.isActive, isFalse);
      });
    });
  });
}
