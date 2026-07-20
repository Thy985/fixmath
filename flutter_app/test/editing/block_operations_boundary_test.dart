/// TC-EDIT-6.4 边界场景测试（v1.3 评审反馈 P4 新增）。
///
/// 补齐契约 §4.1 要求但未覆盖的边界场景：
/// - split offset=0 → 新块为空 Paragraph
/// - split offset=source.length → 原块变空 Paragraph
/// - delete 仅 1 块时 → 返回 false（守卫）
/// - move targetId == refId → 返回 false（守卫）
/// - merge List + List（异 ordered）→ 回退为 Paragraph
///
/// 详见 Phase 2.6 Task Contract §4.1。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.4 边界: split', () {
    test('split offset=0 → 原块变空，新块保留全部内容', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.split(targetId, 0), isTrue);
      expect(editor.blockCount, equals(2));
      // 原块（offset 之前）为空，新块（offset 之后）保留全部
      expect(editor.allSources, equals(['', 'hello']));
    });

    test('split offset=source.length → 原块保留全部，新块为空', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.split(targetId, 5), isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello', '']));
    });

    test('split revert 后状态恢复（含 offset=0 边界）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);
      ops.split(targetId, 0);

      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['hello']));
    });
  });

  group('TC-EDIT-6.4 边界: delete 守卫', () {
    test('仅 1 块时 delete 返回 false（保护 Document 至少 1 块）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('only');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.delete(targetId), isFalse);
      expect(builder.opCount, equals(0));
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['only']));
    });

    test('多块时 delete 仍可正常工作', () {
      final editor = MockDocumentEditor();
      editor.addParagraph('a');
      final targetId = editor.addParagraph('b');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.delete(targetId), isTrue);
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['a']));
    });
  });

  group('TC-EDIT-6.4 边界: move 守卫', () {
    test('move targetId == refId → 返回 false', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      editor.addParagraph('b');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.move(aId, aId, before: true), isFalse);
      expect(builder.opCount, equals(0));
      expect(editor.allSources, equals(['a', 'b']));
    });
  });

  group('TC-EDIT-6.4 边界: merge List ordered', () {
    test('List + List（异 ordered）→ 回退为 Paragraph', () {
      final editor = MockDocumentEditor();
      // 左块：ordered list
      final leftId = editor.addBlock('1. ordered', BlockType.listItem);
      // 右块：unordered list
      final rightId = editor.addBlock('- unordered', BlockType.listItem);

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.merge(leftId, rightId), isTrue);
      expect(editor.blockCount, equals(1));
      // 合并后类型应为 Paragraph（异 ordered 回退）
      final merged = editor.getBlock(leftId);
      expect(merged, isA<ParagraphElement>());
    });

    test('List + List（同 ordered）→ 保留 List 类型', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addBlock('1. first', BlockType.listItem);
      final rightId = editor.addBlock('2. second', BlockType.listItem);

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      expect(ops.merge(leftId, rightId), isTrue);
      expect(editor.blockCount, equals(1));
      final merged = editor.getBlock(leftId);
      expect(merged, isA<ListElement>());
      expect((merged as ListElement).ordered, isTrue);
    });
  });
}
