/// TC-EDIT-7.2：BlockOperations.tryTransform + updateSource 单测。
///
/// 落地 Phase 2.7 Task Contract §4.2：
/// - tryTransform 7 类规则触发 / 失败路径（无规则 / targetId 不存在 / type 已匹配）
/// - updateSource 行为（TextOperation + tryTransform 链式）
/// - IME 铁律 1 守门 + TransactionBuilder 集成
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

/// 测试用 TransactionBuilder 工厂（默认 origin=programmatic）。
TransactionBuilder _newBuilder() =>
    TransactionBuilder(origin: TransactionOrigin.programmatic);

void main() {
  group('TC-EDIT-7.2 BlockOperations.tryTransform', () {
    group('7 类规则触发', () {
      test('# Title → 自动 transform 为 heading', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');

        final transformed = ops.tryTransform(id);

        expect(transformed, isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
      });

      test('- item → 自动 transform 为 listItem (unordered)', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('- item');

        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<ListElement>());
        expect((editor.getBlock(id) as ListElement).ordered, isFalse);
      });

      test('1. item → 自动 transform 为 listItem (ordered)', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('1. item');

        expect(ops.tryTransform(id), isTrue);
        expect((editor.getBlock(id) as ListElement).ordered, isTrue);
      });

      test('- [ ] task → 自动 transform 为 taskListItem', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('- [ ] task');

        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<TaskListItemElement>());
        expect((editor.getBlock(id) as TaskListItemElement).checked, isFalse);
      });

      test('```dart\\n...\\n``` → 自动 transform 为 code', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('```dart\nprint(1);\n```');

        expect(ops.tryTransform(id), isTrue);
        final code = editor.getBlock(id) as CodeElement;
        expect(code.language, equals('dart'));
        expect(code.code, equals('print(1);'));
      });

      test('> quote → 自动 transform 为 blockquote', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('> quote');

        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<BlockquoteElement>());
      });

      test('--- → 自动 transform 为 horizontalRule', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('---');

        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<HorizontalRuleElement>());
      });
    });

    group('失败路径', () {
      test('source 不匹配任何规则 → 返回 false', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello world');

        expect(ops.tryTransform(id), isFalse);
        expect(editor.getBlock(id), isA<ParagraphElement>());
      });

      test('targetId 不存在 → 返回 false', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');
        editor.removeBlock(id);

        expect(ops.tryTransform(id), isFalse);
      });

      test('当前 type 已匹配规则（heading + # Title）→ 返回 false', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');

        // 第一次 transform 成功
        expect(ops.tryTransform(id), isTrue);
        // 第二次：当前已是 heading，detectBlockType 也是 heading → 无需 transform
        expect(ops.tryTransform(id), isFalse);
      });

      test('已 transform 为 code 后再次 tryTransform → 返回 false', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('```dart\nfoo\n```');

        expect(ops.tryTransform(id), isTrue);
        // 已是 code，detectBlockType 返回 code，相同 type → false
        expect(ops.tryTransform(id), isFalse);
      });
    });

    group('BlockId 不变', () {
      test('tryTransform 后 BlockId 不变', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');
        final originalIdValue = id.value;

        ops.tryTransform(id);

        expect(editor.allIds.length, equals(1));
        expect(editor.allIds.first.value, equals(originalIdValue));
      });
    });

    group('TransactionBuilder 集成', () {
      test('tryTransform 成功 → op 自动加入 TransactionBuilder', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');

        ops.tryTransform(id);

        final tx = builder.commit();
        expect(tx.ops.length, equals(1));
        expect(tx.ops.first, isA<BlockOperation>());
        final op = tx.ops.first as BlockOperation;
        expect(op.opType, equals(BlockOpType.transform));
        expect(op.transformedType, equals(BlockType.heading));
      });

      test('tryTransform 失败 → TransactionBuilder 为空', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello world');  // 不匹配规则

        ops.tryTransform(id);

        final tx = builder.commit();
        expect(tx.ops, isEmpty);
      });
    });
  });

  group('TC-EDIT-7.2 BlockOperations.updateSource', () {
    group('基础行为', () {
      test('updateSource 把 source 改为 # Title → 自动触发 transform', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');

        final ok = ops.updateSource(id, '# Title');

        expect(ok, isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
        expect(editor.sourceOf(id), equals('# Title'));
      });

      test('updateSource 改为无规则匹配的 source → 仅 TextOperation', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');

        ops.updateSource(id, 'world');

        // 仍是 paragraph
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('world'));
      });

      test('updateSource 从 # Title 改为 hello → 触发 heading → paragraph', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('# Title');

        // 先 transform 为 heading
        ops.tryTransform(id);
        expect(editor.getBlock(id), isA<HeadingElement>());

        // 再 updateSource 改回普通文本
        ops.updateSource(id, 'hello');

        // detectBlockType('hello') = paragraph，与当前 heading 不同 → 触发 transform
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('updateSource 改为 - item → 触发 paragraph → listItem', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('text');

        ops.updateSource(id, '- new item');

        expect(editor.getBlock(id), isA<ListElement>());
        expect(editor.sourceOf(id), equals('- new item'));
      });

      test('updateSource 改为 ```code``` → 触发 paragraph → code', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('text');

        ops.updateSource(id, '```python\nprint(1)\n```');

        expect(editor.getBlock(id), isA<CodeElement>());
        expect((editor.getBlock(id) as CodeElement).language, equals('python'));
      });

      test('updateSource 失败：targetId 不存在', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');
        editor.removeBlock(id);

        expect(ops.updateSource(id, 'world'), isFalse);
      });

      test('updateSource 后 BlockId 不变', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');
        final originalIdValue = id.value;

        ops.updateSource(id, '# Title');

        expect(editor.allIds.length, equals(1));
        expect(editor.allIds.first.value, equals(originalIdValue));
      });
    });

    group('TransactionBuilder 集成', () {
      test('updateSource 触发 transform → 2 个 op（BlockOperation.transform + TextOperation）', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');

        ops.updateSource(id, '# Title');

        // 顺序：先 transform（source 不变，仅 type 变），再 TextOperation（替换 source）
        // 见 block_operations.dart updateSource 方法注释「顺序原理」
        final tx = builder.commit();
        expect(tx.ops.length, equals(2));
        expect(tx.ops[0], isA<BlockOperation>());
        expect(
          (tx.ops[0] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
        expect(tx.ops[1], isA<TextOperation>());
      });

      test('updateSource 无 transform 触发 → 仅 1 个 TextOperation', () {
        final editor = MockDocumentEditor();
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');

        ops.updateSource(id, 'world');  // 无规则匹配

        final tx = builder.commit();
        expect(tx.ops.length, equals(1));
        expect(tx.ops.first, isA<TextOperation>());
      });

      test('updateSource + undo → 完全恢复', () {
        final editor = MockDocumentEditor();
        final builder = TransactionBuilder(
          origin: TransactionOrigin.programmatic,
          onChange: (tx) {},  // 不入 history，仅测试 commit
        );
        final ops = BlockOperations(editor, builder);
        final id = editor.addParagraph('hello');
        final originalSource = editor.sourceOf(id);

        ops.updateSource(id, '# Title');
        final tx = builder.commit();

        // 模拟 undo：逆序 revert 所有 op
        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }

        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals(originalSource));
      });
    });
  });

  // ============ IME 铁律 1 守门 ============
  group('TC-EDIT-7.2 IME 铁律 1 守门', () {
    test('composing 中调用 tryTransform → 抛 StateError', () {
      final host = MockComposingHost(
        source: '# Title',
        composing: ComposingRegion.empty,
      );
      final composing = ComposingController(host);
      composing.onComposingStart();

      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder, composing);
      final id = editor.addParagraph('# Title');

      expect(() => ops.tryTransform(id), throwsStateError);
    });

    test('composing 中调用 updateSource → 抛 StateError', () {
      final host = MockComposingHost(
        source: 'hello',
        composing: ComposingRegion.empty,
      );
      final composing = ComposingController(host);
      composing.onComposingStart();

      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder, composing);
      final id = editor.addParagraph('hello');

      expect(() => ops.updateSource(id, 'world'), throwsStateError);
    });

    test('idle 态可正常调用 tryTransform / updateSource', () {
      final host = MockComposingHost(
        source: '',
        composing: ComposingRegion.empty,
      );
      final composing = ComposingController(host);

      final editor = MockDocumentEditor();
      final builder = _newBuilder();
      final ops = BlockOperations(editor, builder, composing);
      final id = editor.addParagraph('# Title');

      expect(composing.isActive, isFalse);
      expect(ops.tryTransform(id), isTrue);
    });
  });
}
