/// TC-EDIT-7.1：BlockOperation.transform apply/revert 单测。
///
/// 落地 Phase 2.7 Task Contract §4.1：
/// - 7 类规则正样本（paragraph → heading/list/task/code/blockquote/hr/list-ordered）
/// - apply 失败路径（transformedType null / targetId 不存在 / 新旧 type 相同）
/// - revert 幂等性（含 HeadingElement.level / ListElement.ordered / CodeElement.language 字段保留）
/// - BlockId 不变（Task Contract §1.5）
/// - source 保持不变（transform 仅改 type，不改 source）
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

/// TC-EDIT-7.1 测试 helper：构造 transform op 并 apply 到 [editor]。
///
/// 返回 (apply 是否成功, op) 对，便于后续 revert 测试。
(BlockOperation, bool) _applyTransform(
  MockDocumentEditor editor,
  BlockId targetId,
  BlockType transformedType,
) {
  final op = BlockOperation(
    opType: BlockOpType.transform,
    targetId: targetId,
    transformedType: transformedType,
  );
  return (op, op.apply(editor));
}

void main() {
  group('TC-EDIT-7.1 BlockOperation.transform', () {
    // ============ apply 基础：7 类规则正样本 ============

    group('apply 7 类规则', () {
      test('paragraph → heading（# Title）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');

        final (_, ok) = _applyTransform(editor, id, BlockType.heading);
        expect(ok, isTrue);

        final transformed = editor.getBlock(id);
        expect(transformed, isA<HeadingElement>());
        final heading = transformed as HeadingElement;
        expect(heading.level, equals(1));
        expect(heading.text, equals('Title'));

        // source 不变
        expect(editor.sourceOf(id), equals('# Title'));
        // BlockId 不变
        expect(editor.allIds, contains(id));
      });

      test('paragraph → heading level 3（### Section）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('### Section');

        final (_, ok) = _applyTransform(editor, id, BlockType.heading);
        expect(ok, isTrue);

        final heading = editor.getBlock(id) as HeadingElement;
        expect(heading.level, equals(3));
        expect(heading.text, equals('Section'));
      });

      test('paragraph → listItem（- item）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('- item');

        final (_, ok) = _applyTransform(editor, id, BlockType.listItem);
        expect(ok, isTrue);

        final list = editor.getBlock(id) as ListElement;
        expect(list.ordered, isFalse);
        expect(list.indent, equals(0));
      });

      test('paragraph → listItem（1. item，ordered）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('1. item');

        final (_, ok) = _applyTransform(editor, id, BlockType.listItem);
        expect(ok, isTrue);

        final list = editor.getBlock(id) as ListElement;
        expect(list.ordered, isTrue);
        expect(list.indent, equals(0));
      });

      test('paragraph → taskListItem（- [ ] task）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('- [ ] task');

        final (_, ok) = _applyTransform(editor, id, BlockType.taskListItem);
        expect(ok, isTrue);

        final task = editor.getBlock(id) as TaskListItemElement;
        expect(task.checked, isFalse);
        expect(task.indent, equals(0));
      });

      test('paragraph → taskListItem（- [x] done）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('- [x] done');

        final (_, ok) = _applyTransform(editor, id, BlockType.taskListItem);
        expect(ok, isTrue);

        final task = editor.getBlock(id) as TaskListItemElement;
        expect(task.checked, isTrue);
      });

      test('paragraph → code（```dart\\n...\\n```）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('```dart\nprint(1);\n```');

        final (_, ok) = _applyTransform(editor, id, BlockType.code);
        expect(ok, isTrue);

        final code = editor.getBlock(id) as CodeElement;
        expect(code.code, equals('print(1);'));
        expect(code.language, equals('dart'));
      });

      test('paragraph → code（无 language）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('```\ncode\n```');

        final (_, ok) = _applyTransform(editor, id, BlockType.code);
        expect(ok, isTrue);

        final code = editor.getBlock(id) as CodeElement;
        expect(code.code, equals('code'));
        expect(code.language, isNull);
      });

      test('paragraph → blockquote（> quote）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('> quote text');

        final (_, ok) = _applyTransform(editor, id, BlockType.blockquote);
        expect(ok, isTrue);

        final quote = editor.getBlock(id) as BlockquoteElement;
        expect(quote.text, equals('quote text'));
      });

      test('paragraph → horizontalRule（---）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('---');

        final (_, ok) = _applyTransform(editor, id, BlockType.horizontalRule);
        expect(ok, isTrue);

        expect(editor.getBlock(id), isA<HorizontalRuleElement>());
      });
    });

    // ============ apply 失败路径 ============

    group('apply 失败', () {
      test('transformedType 为 null → 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: id,
          // transformedType 故意不传
        );

        expect(op.apply(editor), isFalse);
        // element 未变
        expect(editor.getBlock(id), isA<ParagraphElement>());
      });

      test('targetId 不存在 → 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        // 删除该 block 模拟 targetId 不存在
        editor.removeBlock(id);

        final (_, ok) = _applyTransform(
          editor,
          id,
          BlockType.heading,
        );
        expect(ok, isFalse);
      });

      test('新旧 type 相同（paragraph → paragraph）→ 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final (_, ok) = _applyTransform(
          editor,
          id,
          BlockType.paragraph,  // 当前已是 paragraph
        );
        expect(ok, isFalse);
        // element 未变
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('heading → heading 相同 type → 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');

        // 先 transform 为 heading
        _applyTransform(editor, id, BlockType.heading);
        // 再次 transform 为 heading 应失败
        final (_, ok2) = _applyTransform(editor, id, BlockType.heading);
        expect(ok2, isFalse);
      });
    });

    // ============ revert 幂等性 + 字段保留 ============

    group('revert 幂等性', () {
      test('paragraph → heading → revert 完全恢复', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');

        final (op, ok) = _applyTransform(editor, id, BlockType.heading);
        expect(ok, isTrue);

        // revert
        op.revert(editor);

        final reverted = editor.getBlock(id);
        expect(reverted, isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('# Title'));
      });

      test('paragraph → code → revert 保留 language 字段', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('```python\nprint("hi")\n```');

        final (op, ok) = _applyTransform(editor, id, BlockType.code);
        expect(ok, isTrue);
        final code = editor.getBlock(id) as CodeElement;
        expect(code.language, equals('python'));

        // revert
        op.revert(editor);

        // 恢复为 paragraph（原 element）
        expect(editor.getBlock(id), isA<ParagraphElement>());
        // source 完全恢复
        expect(
          editor.sourceOf(id),
          equals('```python\nprint("hi")\n```'),
        );
      });

      test('paragraph → listItem → revert 保留 ordered 字段', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('1. ordered item');

        final (op, ok) = _applyTransform(editor, id, BlockType.listItem);
        expect(ok, isTrue);
        final list = editor.getBlock(id) as ListElement;
        expect(list.ordered, isTrue);

        // revert
        op.revert(editor);

        // 恢复为 paragraph
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('1. ordered item'));
      });

      test('revert 后 BlockId 不变（Task Contract §1.5）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');
        final originalIdValue = id.value;

        final (op, ok) = _applyTransform(editor, id, BlockType.heading);
        expect(ok, isTrue);

        // apply 后 BlockId 不变
        expect(editor.allIds.length, equals(1));
        expect(editor.allIds.first.value, equals(originalIdValue));

        op.revert(editor);

        // revert 后 BlockId 仍不变
        expect(editor.allIds.length, equals(1));
        expect(editor.allIds.first.value, equals(originalIdValue));
      });

      test('多次 apply-revert 循环（幂等）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');
        final originalSource = editor.sourceOf(id);

        for (var i = 0; i < 5; i++) {
          final (op, ok) = _applyTransform(editor, id, BlockType.heading);
          expect(ok, isTrue, reason: '第 $i 轮 apply 失败');
          expect(editor.getBlock(id), isA<HeadingElement>());

          op.revert(editor);
          expect(editor.getBlock(id), isA<ParagraphElement>());
          expect(editor.sourceOf(id), equals(originalSource),
              reason: '第 $i 轮 revert 后 source 不一致');
        }
      });

      test('revert 后 ListElement.ordered 字段恢复正确', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('1. ordered');

        final (op, _) = _applyTransform(editor, id, BlockType.listItem);
        expect((editor.getBlock(id) as ListElement).ordered, isTrue);

        op.revert(editor);

        // revert 后再 transform 验证 ordered 仍为 true
        _applyTransform(editor, id, BlockType.listItem);
        expect((editor.getBlock(id) as ListElement).ordered, isTrue);
      });

      test('revert 后 CodeElement.language 字段恢复正确', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('```rust\nfn main() {}\n```');

        final (op, _) = _applyTransform(editor, id, BlockType.code);
        expect((editor.getBlock(id) as CodeElement).language, equals('rust'));

        op.revert(editor);

        // revert 后再 transform 验证 language 仍为 rust
        _applyTransform(editor, id, BlockType.code);
        expect((editor.getBlock(id) as CodeElement).language, equals('rust'));
      });
    });

    // ============ source 保持（transform 不改 source） ============

    group('source 保持', () {
      test('heading transform 后 source 不变', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('### Section');
        final originalSource = editor.sourceOf(id);

        _applyTransform(editor, id, BlockType.heading);

        expect(editor.sourceOf(id), equals(originalSource));
      });

      test('code transform 后 source 不变', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('```js\nconst x = 1;\n```');
        final originalSource = editor.sourceOf(id);

        _applyTransform(editor, id, BlockType.code);

        expect(editor.sourceOf(id), equals(originalSource));
      });
    });
  });
}
