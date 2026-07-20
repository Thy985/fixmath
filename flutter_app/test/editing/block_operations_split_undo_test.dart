/// TC-EDIT-7.3b：BlockOperations.split 自动 transform 的 Undo/Redo 循环 + 失败路径。
///
/// 落地 Phase 2.7 Task Contract §4.3（接续 TC-EDIT-7.3a）：
/// - split + transform 链式 op 的 undo/redo 循环（依赖 _applySplit 幂等性）
/// - split 失败路径（offset 越界 / targetId 不存在 / tryTransform 失败）
/// - 连续多次 split 都触发 transform
///
/// 触发规则 + BlockId 稳定性见
/// [block_operations_split_transform_test.dart]（TC-EDIT-7.3a）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

/// 测试用 TransactionBuilder 工厂（默认 origin=programmatic）。
TransactionBuilder _newBuilder() =>
    TransactionBuilder(origin: TransactionOrigin.programmatic);

void main() {
  group('TC-EDIT-7.3b split 自动 transform: Undo/Redo 循环', () {
    group('Undo 循环', () {
      test('split + transform → undo 完全恢复', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello# Title');
        final originalSource = editor.sourceOf(id);
        final originalType = BlockType.fromElement(editor.getBlock(id)!);

        ops.split(id, 5);
        final tx = builder.commit();

        // 模拟 undo：逆序 revert 所有 op
        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }

        expect(editor.blockCount, equals(1));
        expect(editor.allIds.first, equals(id));
        expect(editor.sourceOf(id), equals(originalSource));
        expect(
          BlockType.fromElement(editor.getBlock(id)!),
          equals(originalType),
        );
      });

      test('split + transform → undo + redo 完全恢复', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello# Title');

        ops.split(id, 5);
        final tx = builder.commit();

        // undo
        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.blockCount, equals(1));

        // redo
        for (final op in tx.ops) {
          op.apply(editor);
        }
        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HeadingElement>());
        expect(editor.sourceOf(newId), equals('# Title'));
      });

      test('split 无 transform → undo 完全恢复', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('helloworld');

        ops.split(id, 5);
        final tx = builder.commit();

        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }

        expect(editor.blockCount, equals(1));
        expect(editor.allIds.first, equals(id));
        expect(editor.sourceOf(id), equals('helloworld'));
      });
    });
  });

  group('TC-EDIT-7.3b split 自动 transform: 失败路径', () {
    test('split 失败（offset 越界）→ 不触发 transform，opCount=0', () {
      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder);
      final id = editor.addParagraph('# Title');  // 长度 7

      expect(ops.split(id, 100), isFalse);  // offset 越界

      expect(builder.opCount, equals(0));
      expect(editor.blockCount, equals(1));
    });

    test('split 失败（targetId 不存在）→ 不触发 transform，opCount=0', () {
      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder);

      expect(ops.split(const BlockId(999), 1), isFalse);

      expect(builder.opCount, equals(0));
      expect(editor.blockCount, equals(0));
    });

    test('split 成功但 tryTransform 失败 → split 仍成功，仅 1 个 op', () {
      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder);
      // 右部分 'world' 不匹配任何规则 → tryTransform 返回 false
      final id = editor.addParagraph('helloworld');

      expect(ops.split(id, 5), isTrue);

      // split 成功 + tryTransform 失败 → 仅 split op
      expect(builder.opCount, equals(1));
      expect(editor.blockCount, equals(2));
    });
  });

  group('TC-EDIT-7.3b split 自动 transform: 多次 split', () {
    test('连续 2 次 split 都触发 transform → 4 个 op', () {
      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder);
      // source = '> quote# Title'，长度 14
      // 第 1 次 split 在 offset 7：左='> quote'，右='# Title'（触发 heading）
      // 第 2 次 split 在 id (paragraph '> quote') 的 offset 0：左=''，右='> quote'（触发 blockquote）
      final id = editor.addParagraph('> quote# Title');

      // 第 1 次 split：'> quote' + '# Title'
      ops.split(id, 7);
      // 第 2 次 split：在原 id (paragraph '> quote') 的 offset 0 处拆分
      // → 左 ''，右 '> quote'（触发 blockquote）
      ops.split(id, 0);

      // 每次 split + transform = 2 ops，共 4 ops
      expect(builder.opCount, equals(4));
      expect(editor.blockCount, equals(3));
      // 第 1 块：paragraph ''（原 id 被 2 次 split 截断）
      expect(editor.getBlock(id), isA<ParagraphElement>());
      expect(editor.sourceOf(id), equals(''));
      // 块状态包含 3 种 type
      expect(editor.allSources, containsAll(['', '# Title', '> quote']));
    });
  });
}
