/// TC-EDIT-6.4 BlockOperations 多原语组合 + 兼容性测试。
///
/// 验证：
/// - 多原语组合成 1 个 Transaction + 逆序 revert 恢复
/// - 部分失败不影响已成功操作的 builder 收集
/// - 不传 composing controller 时不守门（向后兼容）
///
/// 守门测试（composing 态抛 StateError）见 [ime_mutation_forbidden_test.dart]
/// （TC-EDIT-6.9，v1.1 评审反馈 5D 新增）。
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.4。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.4 BlockOperations 多原语组合', () {
    test('多个原语组合成 1 个 Transaction', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');

      final builder = TransactionBuilder(
        origin: TransactionOrigin.programmatic,
        label: '组合操作',
      );
      final ops = BlockOperations(editor, builder);

      ops.insertAfter(aId, const ParagraphElement(children: [TextElement('x')]));
      ops.delete(bId);
      ops.split(aId, 0);

      expect(builder.opCount, equals(3));

      final tx = builder.commit();
      expect(tx.ops.length, equals(3));
      expect(tx.metadata.label, equals('组合操作'));
    });

    test('全部原语逆序 revert 恢复 editor 状态', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('abc');
      final bId = editor.addParagraph('xyz');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      // 1. 在 a 后插入新块
      ops.insertAfter(aId, const ParagraphElement(children: [TextElement('NEW')]));
      // 2. 拆分 a
      ops.split(aId, 1);
      // 3. 删除 b
      ops.delete(bId);

      expect(editor.blockCount, equals(3));

      // 逆序 revert
      for (final op in builder.ops.reversed) {
        op.revert(editor);
      }

      // 状态恢复到初始：[a='abc', b='xyz']
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['abc', 'xyz']));
    });

    test('部分失败不影响已成功操作的 builder 收集', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      final ops = BlockOperations(editor, builder);

      ops.insertAfter(aId, const ParagraphElement(children: [TextElement('b')]));
      expect(builder.opCount, equals(1));

      ops.delete(const BlockId(999));
      expect(builder.opCount, equals(1));

      ops.insertAfter(aId, const ParagraphElement(children: [TextElement('c')]));
      expect(builder.opCount, equals(2));
    });
  });

  group('TC-EDIT-6.4 BlockOperations 不传 composing controller', () {
    test('无 composing controller 时不守门（向后兼容）', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final builder = TransactionBuilder(origin: TransactionOrigin.programmatic);
      // BlockOperations 第三个参数 _composing 不传
      final ops = BlockOperations(editor, builder);

      // 不抛异常（无 composing controller 时不守门）
      final newId = ops.insertAfter(
        targetId,
        const ParagraphElement(children: [TextElement('world')]),
      );

      expect(newId, isNotNull);
      expect(builder.opCount, equals(1));
    });
  });
}
