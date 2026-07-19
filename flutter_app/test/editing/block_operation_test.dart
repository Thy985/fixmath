/// TC-EDIT-6.1 BlockOperation apply/revert 幂等性测试 - 5 类块级操作部分。
///
/// 验证 5 类 BlockOperation（insert/delete/merge/split/move）：
/// - apply + revert → editor 状态恢复（含 index / 元素 snapshot）
/// - 幂等性：apply-revert-apply-revert 循环
/// - 边界：非法 BlockId / 缺 element / 缺 splitOffset / 缺 auxiliaryId
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.1。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.1 BlockOperation insert', () {
    test('apply 在 target 之后插入新块，revert 后恢复', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('hello');

      final op = BlockOperation(
        opType: BlockOpType.insert,
        targetId: targetId,
        element: ParagraphElement(children: [TextElement('world')]),
      );

      expect(op.apply(editor), isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello', 'world']));

      op.revert(editor);
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['hello']));
    });

    test('幂等性：apply-revert-apply-revert 循环状态一致', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');

      final op = BlockOperation(
        opType: BlockOpType.insert,
        targetId: targetId,
        element: ParagraphElement(children: [TextElement('b')]),
      );

      for (var i = 0; i < 3; i++) {
        expect(op.apply(editor), isTrue);
        expect(editor.blockCount, equals(2));
        op.revert(editor);
        expect(editor.blockCount, equals(1));
      }
    });

    test('缺 element → apply 返回 false', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');

      final op = BlockOperation(
        opType: BlockOpType.insert,
        targetId: targetId,
        // element 缺失
      );

      expect(op.apply(editor), isFalse);
    });

    test('非法 targetId → apply 返回 false', () {
      final editor = MockDocumentEditor();

      final op = BlockOperation(
        opType: BlockOpType.insert,
        targetId: BlockId(999),
        element: ParagraphElement(children: [TextElement('x')]),
      );

      expect(op.apply(editor), isFalse);
    });
  });

  group('TC-EDIT-6.1 BlockOperation delete', () {
    test('apply 删除块，revert 后恢复（含 oldIndex）', () {
      final editor = MockDocumentEditor();
      editor.addParagraph('a');
      final targetId = editor.addParagraph('b');
      editor.addParagraph('c');

      final op = BlockOperation(
        opType: BlockOpType.delete,
        targetId: targetId,
      );

      expect(op.apply(editor), isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['a', 'c']));

      op.revert(editor);
      expect(editor.blockCount, equals(3));
      expect(editor.allSources, equals(['a', 'b', 'c']));
    });

    test('幂等性：apply-revert-apply-revert 循环', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('x');

      final op = BlockOperation(
        opType: BlockOpType.delete,
        targetId: targetId,
      );

      for (var i = 0; i < 3; i++) {
        expect(op.apply(editor), isTrue);
        expect(editor.blockCount, equals(0));
        op.revert(editor);
        expect(editor.blockCount, equals(1));
      }
    });

    test('非法 targetId → apply 返回 false', () {
      final editor = MockDocumentEditor();

      final op = BlockOperation(
        opType: BlockOpType.delete,
        targetId: BlockId(999),
      );

      expect(op.apply(editor), isFalse);
    });
  });

  group('TC-EDIT-6.1 BlockOperation merge', () {
    test('apply 合并右块到左块，revert 后恢复（含 rightOldIndex）', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('hello ');
      final rightId = editor.addParagraph('world');

      final op = BlockOperation(
        opType: BlockOpType.merge,
        targetId: rightId,
        auxiliaryId: leftId,
      );

      expect(op.apply(editor), isTrue);
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['hello world']));

      op.revert(editor);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello ', 'world']));
    });

    test('幂等性：apply-revert-apply-revert 循环', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('foo');
      final rightId = editor.addParagraph('bar');

      final op = BlockOperation(
        opType: BlockOpType.merge,
        targetId: rightId,
        auxiliaryId: leftId,
      );

      for (var i = 0; i < 3; i++) {
        expect(op.apply(editor), isTrue);
        expect(editor.blockCount, equals(1));
        op.revert(editor);
        expect(editor.blockCount, equals(2));
      }
    });

    test('缺 auxiliaryId（左块）→ apply 返回 false', () {
      final editor = MockDocumentEditor();
      final rightId = editor.addParagraph('b');

      final op = BlockOperation(
        opType: BlockOpType.merge,
        targetId: rightId,
        // auxiliaryId 缺失
      );

      expect(op.apply(editor), isFalse);
    });

    test('非法 auxiliaryId → apply 返回 false', () {
      final editor = MockDocumentEditor();
      final rightId = editor.addParagraph('b');

      final op = BlockOperation(
        opType: BlockOpType.merge,
        targetId: rightId,
        auxiliaryId: BlockId(999),
      );

      expect(op.apply(editor), isFalse);
    });

    test('不兼容类型 → 回退为 Paragraph', () {
      final editor = MockDocumentEditor();
      final leftId = editor.addParagraph('text');
      final codeId = editor.addBlock('```dart\nprint(1)\n```', BlockType.code);

      final op = BlockOperation(
        opType: BlockOpType.merge,
        targetId: codeId,
        auxiliaryId: leftId,
      );

      expect(op.apply(editor), isTrue);
      expect(editor.blockCount, equals(1));
      final element = editor.getBlock(leftId);
      expect(element, isA<ParagraphElement>());
    });
  });

  group('TC-EDIT-6.1 BlockOperation split', () {
    test('apply 拆分原块为两部分，revert 后恢复', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('helloworld');

      final op = BlockOperation(
        opType: BlockOpType.split,
        targetId: targetId,
        splitOffset: 5,
        element: ParagraphElement(children: [TextElement('placeholder')]),
      );

      expect(op.apply(editor), isTrue);
      expect(editor.blockCount, equals(2));
      expect(editor.allSources, equals(['hello', 'world']));

      op.revert(editor);
      expect(editor.blockCount, equals(1));
      expect(editor.allSources, equals(['helloworld']));
    });

    test('幂等性：apply-revert-apply-revert 循环', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('abcdef');

      final op = BlockOperation(
        opType: BlockOpType.split,
        targetId: targetId,
        splitOffset: 3,
        element: ParagraphElement(children: [TextElement('p')]),
      );

      for (var i = 0; i < 3; i++) {
        expect(op.apply(editor), isTrue);
        expect(editor.blockCount, equals(2));
        op.revert(editor);
        expect(editor.blockCount, equals(1));
      }
    });

    test('缺 splitOffset → apply 返回 false', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('abc');

      final op = BlockOperation(
        opType: BlockOpType.split,
        targetId: targetId,
        element: ParagraphElement(children: [TextElement('p')]),
      );

      expect(op.apply(editor), isFalse);
    });

    test('splitOffset 越界 → apply 返回 false', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('abc');

      final op = BlockOperation(
        opType: BlockOpType.split,
        targetId: targetId,
        splitOffset: 100,
        element: ParagraphElement(children: [TextElement('p')]),
      );

      expect(op.apply(editor), isFalse);
    });

    test('非法 targetId → apply 返回 false', () {
      final editor = MockDocumentEditor();

      final op = BlockOperation(
        opType: BlockOpType.split,
        targetId: BlockId(999),
        splitOffset: 1,
        element: ParagraphElement(children: [TextElement('p')]),
      );

      expect(op.apply(editor), isFalse);
    });
  });

  group('TC-EDIT-6.1 BlockOperation move', () {
    test('apply 移动块到 ref 之前，revert 后恢复', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      // 把 b 移到 c 之前
      final op = BlockOperation(
        opType: BlockOpType.move,
        targetId: bId,
        auxiliaryId: cId,
        moveBefore: true,
      );

      expect(op.apply(editor), isTrue);
      expect(editor.allSources, equals(['a', 'b', 'c'])); // 顺序不变（b 已在 c 前）
      // 但 BlockId 顺序变了
      final idsAfter = editor.allIds;
      expect(idsAfter[1], equals(bId));

      op.revert(editor);
      expect(editor.allSources, equals(['a', 'b', 'c']));
      expect(editor.allIds[0], equals(aId));
      expect(editor.allIds[1], equals(bId));
      expect(editor.allIds[2], equals(cId));
    });

    test('apply 移动块到 ref 之后，revert 后恢复', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      // 把 a 移到 c 之后
      final op = BlockOperation(
        opType: BlockOpType.move,
        targetId: aId,
        auxiliaryId: cId,
        moveBefore: false,
      );

      expect(op.apply(editor), isTrue);
      expect(editor.allSources, equals(['b', 'c', 'a']));
      // bId 不变（move 不改变其他块的 identity）
      expect(editor.allIds[0], equals(bId));

      op.revert(editor);
      expect(editor.allSources, equals(['a', 'b', 'c']));
    });

    test('幂等性：apply-revert-apply-revert 循环', () {
      final editor = MockDocumentEditor();
      final aId = editor.addParagraph('a');
      final bId = editor.addParagraph('b');
      final cId = editor.addParagraph('c');

      final op = BlockOperation(
        opType: BlockOpType.move,
        targetId: aId,
        auxiliaryId: cId,
        moveBefore: false,
      );

      for (var i = 0; i < 3; i++) {
        expect(op.apply(editor), isTrue);
        expect(editor.allSources, equals(['b', 'c', 'a']));
        // bId 在循环中保持不变（验证 stable identity）
        expect(editor.allIds[0], equals(bId));
        op.revert(editor);
        expect(editor.allSources, equals(['a', 'b', 'c']));
      }
    });

    test('缺 auxiliaryId → apply 返回 false', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');

      final op = BlockOperation(
        opType: BlockOpType.move,
        targetId: targetId,
        // auxiliaryId 缺失
      );

      expect(op.apply(editor), isFalse);
    });

    test('非法 auxiliaryId → apply 返回 false', () {
      final editor = MockDocumentEditor();
      final targetId = editor.addParagraph('a');

      final op = BlockOperation(
        opType: BlockOpType.move,
        targetId: targetId,
        auxiliaryId: BlockId(999),
      );

      expect(op.apply(editor), isFalse);
    });
  });
}
