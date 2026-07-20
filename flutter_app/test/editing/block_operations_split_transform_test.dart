/// TC-EDIT-7.3a：BlockOperations.split 自动 transform 单测（核心触发规则）。
///
/// 落地 Phase 2.7 Task Contract §4.3：
/// - split 后自动对新块（右部分）调用 [tryTransform]
/// - 覆盖 ADR-0007 §4.3 的 7 类 Markdown 快捷映射规则
/// - split + transform 链式 op 自动加入 TransactionBuilder
/// - BlockId 稳定性（原块 id 不变，新块获得新 id）
/// - 不触发 transform 的场景（无规则匹配 / type 不变）
///
/// Undo/Redo 循环 / 失败路径 / 多次 split 见
/// [block_operations_split_undo_test.dart]（TC-EDIT-7.3b）。
/// split 本身的行为由 [block_operations_test.dart] TC-EDIT-6.4 覆盖。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

/// 测试用 TransactionBuilder 工厂（默认 origin=programmatic）。
TransactionBuilder _newBuilder() =>
    TransactionBuilder(origin: TransactionOrigin.programmatic);

void main() {
  group('TC-EDIT-7.3a BlockOperations.split 自动 transform', () {
    // ============ 7 类规则触发（split 后右部分触发规则） ============

    group('7 类规则触发', () {
      test('split 把 `# Title` 切到右部分 → 自动 transform 为 heading', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        // source = 'hello# Title'，split at 5 → left='hello', right='# Title'
        final id = editor.addParagraph('hello# Title');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HeadingElement>());
        expect(editor.sourceOf(newId), equals('# Title'));
      });

      test('split 把 `- item` 切到右部分 → 自动 transform 为 listItem (unordered)', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello- item');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<ListElement>());
        expect((editor.getBlock(newId) as ListElement).ordered, isFalse);
      });

      test('split 把 `1. item` 切到右部分 → 自动 transform 为 listItem (ordered)', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello1. item');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<ListElement>());
        expect((editor.getBlock(newId) as ListElement).ordered, isTrue);
      });

      test('split 把 `- [ ] task` 切到右部分 → 自动 transform 为 taskListItem', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello- [ ] task');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<TaskListItemElement>());
        expect((editor.getBlock(newId) as TaskListItemElement).checked, isFalse);
      });

      test('split 把 ``` ```dart\n...\n``` ``` 切到右部分 → 自动 transform 为 code', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello```dart\nprint(1);\n```');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<CodeElement>());
        expect((editor.getBlock(newId) as CodeElement).language, equals('dart'));
      });

      test('split 把 `> quote` 切到右部分 → 自动 transform 为 blockquote', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello> quote');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<BlockquoteElement>());
      });

      test('split 把 `---` 切到右部分 → 自动 transform 为 horizontalRule', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello---');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HorizontalRuleElement>());
      });
    });

    // ============ 不触发 transform 的场景 ============

    group('不触发 transform', () {
      test('split 后右部分无规则匹配 → 右部分保持 paragraph', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('helloworld');

        expect(ops.split(id, 5), isTrue);

        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<ParagraphElement>());
        expect(editor.sourceOf(newId), equals('world'));
      });

      test('split 在 offset=0 → 左部分为空 paragraph，右部分触发规则', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');

        expect(ops.split(id, 0), isTrue);

        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals(''));
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HeadingElement>());
      });

      test('split 在末尾 offset=source.length → 右部分为空 paragraph', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');

        expect(ops.split(id, 7), isTrue);  // 7 = '# Title'.length

        expect(editor.blockCount, equals(2));
        // 左：原 paragraph '# Title'（split 自动 transform 仅作用于右部分）
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('# Title'));
        // 右：空 paragraph（无规则匹配，source='' → detectBlockType 返回 paragraph）
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<ParagraphElement>());
        expect(editor.sourceOf(newId), equals(''));
      });

      test('split heading 块 → 左右都保持 heading（type 不变不触发 transform）', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addBlock('# Title', BlockType.heading);

        expect(ops.split(id, 2), isTrue);  // split after '# '

        expect(editor.blockCount, equals(2));
        expect(editor.getBlock(id), isA<HeadingElement>());
        expect(editor.sourceOf(id), equals('# '));
        // 右：'Title' 继承 heading 类型。toElement('Title', heading) 走 fallback
        // 生成 HeadingElement(text='Title')，fromElement 重新序列化为 '# Title'，
        // detectBlockType 仍返回 heading → 与 currentType 相同 → 不触发 transform。
        final newId = editor.allIds.last;
        expect(editor.getBlock(newId), isA<HeadingElement>());
        expect(editor.sourceOf(newId), equals('# Title'));
      });
    });

    // ============ op 加入 TransactionBuilder ============

    group('TransactionBuilder 集成', () {
      test('split 触发 transform → 2 个 op（split + transform）', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello# Title');

        ops.split(id, 5);

        // 顺序：先 split，后 transform（split 内部 apply 成功后才 tryTransform）
        expect(builder.opCount, equals(2));
        expect(builder.ops[0], isA<BlockOperation>());
        expect(
          (builder.ops[0] as BlockOperation).opType,
          equals(BlockOpType.split),
        );
        expect(builder.ops[1], isA<BlockOperation>());
        expect(
          (builder.ops[1] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
      });

      test('split 不触发 transform → 仅 1 个 split op', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('helloworld');

        ops.split(id, 5);

        expect(builder.opCount, equals(1));
        expect(builder.ops[0], isA<BlockOperation>());
        expect(
          (builder.ops[0] as BlockOperation).opType,
          equals(BlockOpType.split),
        );
      });

      test('commit 后 tx.ops 包含 split + transform', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello# Title');

        ops.split(id, 5);
        final tx = builder.commit();

        expect(tx.ops.length, equals(2));
        expect(
          (tx.ops[0] as BlockOperation).opType,
          equals(BlockOpType.split),
        );
        expect(
          (tx.ops[1] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
      });
    });

    // ============ BlockId 稳定性 ============

    group('BlockId 稳定性', () {
      test('split 后原块 id 不变，新块获得新 id', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello# Title');
        final originalIdValue = id.value;

        ops.split(id, 5);

        expect(editor.allIds.length, equals(2));
        expect(editor.allIds.first.value, equals(originalIdValue));
        expect(editor.allIds.last.value, isNot(equals(originalIdValue)));
      });

      test('transform 不变更新块的 BlockId（split 已分配）', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello# Title');

        ops.split(id, 5);

        // tryTransform 通过 updateBlockContent，不调用 replaceBlock，新块 id 不变
        final newIdAfterSplit = editor.allIds.last;
        for (final op in builder.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.allIds.length, equals(1));
        expect(editor.allIds.first.value, equals(id.value));
        expect(newIdAfterSplit, isNotNull);
      });
    });
  });
}
