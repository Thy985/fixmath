/// TC-EDIT-6.9 IME 组合态操作禁止测试（v1.1 评审反馈 5D 新增）。
///
/// 验证 ADR-0007 §3.2 铁律 1（不切块）：
/// - composing.isActive 时调 insert/delete/merge/split/move → 抛 StateError
/// - composing.isActive 时调 TextOperation.apply → 不抛
///   （TextOperation 不受铁律 1 约束，仅在 commit 阶段触发 origin=ime）
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.9。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/composing_controller.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_composing_host.dart';
import 'helpers/mock_document_editor.dart';

/// 构造一个处于 composing 态的 BlockOperations。
typedef Ctx = ({MockDocumentEditor editor, BlockId targetId, BlockOperations ops});

Ctx _makeComposingBlockOperations({
  String source = 'hello',
  int composingStart = 0,
  int? composingEnd,
}) {
  final editor = MockDocumentEditor();
  final targetId = editor.addParagraph(source);

  final host = MockComposingHost(
    source: source,
    composing: ComposingRegion(
      start: composingStart,
      end: composingEnd ?? source.length,
    ),
  );
  final composing = ComposingController(host);
  composing.onComposingStart();

  final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
  final ops = BlockOperations(editor, builder, composing);
  return (editor: editor, targetId: targetId, ops: ops);
}

void main() {
  group('TC-EDIT-6.9 IME 组合态操作禁止', () {
    test('composing.isActive 时调 insert → 抛 StateError', () {
      final ctx = _makeComposingBlockOperations();

      expect(
        () => ctx.ops.insertAfter(
          ctx.targetId,
          const ParagraphElement(children: [TextElement('x')]),
        ),
        throwsStateError,
      );
      expect(ctx.editor.blockCount, equals(1));
    });

    test('composing.isActive 时调 delete → 抛 StateError', () {
      final ctx = _makeComposingBlockOperations();

      expect(() => ctx.ops.delete(ctx.targetId), throwsStateError);
      expect(ctx.editor.blockCount, equals(1));
    });

    test('composing.isActive 时调 merge → 抛 StateError', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('a');
      final rightId = editor.addParagraph('b');

      final host = MockComposingHost(
        source: 'a',
        composing: const ComposingRegion(start: 0, end: 1),
      );
      final composing = ComposingController(host);
      composing.onComposingStart();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder, composing);

      expect(() => ops.merge(leftId, rightId), throwsStateError);
      expect(builder.opCount, equals(0));
    });

    test('composing.isActive 时调 split → 抛 StateError', () {
      final ctx = _makeComposingBlockOperations(source: 'abc');

      expect(() => ctx.ops.split(ctx.targetId, 1), throwsStateError);
      expect(ctx.editor.blockCount, equals(1));
    });

    test('composing.isActive 时调 move → 抛 StateError', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');

      final host = MockComposingHost(
        source: 'a',
        composing: const ComposingRegion(start: 0, end: 1),
      );
      final composing = ComposingController(host);
      composing.onComposingStart();

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder, composing);

      expect(() => ops.move(aId, bId), throwsStateError);
      expect(builder.opCount, equals(0));
    });

    test('composing.isActive 时调 TextOperation.apply → 不抛', () {
      // TextOperation 不受铁律 1 约束（不在 BlockOperation 范畴）
      // 仅在 commit 阶段触发 origin=ime
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final host = MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 0, end: 5),
      );
      final composing = ComposingController(host);
      composing.onComposingStart();
      expect(composing.isActive, isTrue);

      final op = TextOperation(
        blockId: targetId,
        offset: 5,
        inserted: ' world',
      );

      // 不抛异常：TextOperation 直接 apply 到 editor
      expect(op.apply(editor), isTrue);
      expect(editor.sourceOf(targetId), equals('hello world'));
    });
  });
}
