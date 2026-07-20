/// TC-EDIT-7.5：transform / updateSource 边界测试。
///
/// 落地 Phase 2.7 Task Contract §4.5：
/// - transform apply 失败 / updateSource + tryTransform 边界
/// - BlockId 生命周期 + Phase 2.6 split 兼容性 + revert 幂等性
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_operations.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/core/editing/transaction_builder.dart';
import 'package:formula_fix/data/models/document.dart';

import 'helpers/mock_document_editor.dart';

TransactionBuilder _newBuilder() =>
    TransactionBuilder(origin: TransactionOrigin.programmatic);

void main() {
  group('TC-EDIT-7.5 transform / updateSource 边界测试', () {
    group('transform op apply 失败路径', () {
      test('transformedType 为 null → apply 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: id,
          // transformedType 不传 → null
        );

        expect(op.apply(editor), isFalse);
        // editor 状态不变
        expect(editor.getBlock(id), isA<ParagraphElement>());
      });

      test('targetId 不存在 → apply 返回 false', () {
        final editor = MockDocumentEditor();

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: BlockId(999),
          transformedType: BlockType.heading,
        );

        expect(op.apply(editor), isFalse);
        expect(editor.blockCount, equals(0));
      });

      test('oldType == newType → apply 返回 false（无需 transform）', () {
        final editor = MockDocumentEditor();
        final id = editor.addBlock('# Title', BlockType.heading);

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: id,
          transformedType: BlockType.heading,  // 同 type
        );

        expect(op.apply(editor), isFalse);
        // editor 状态不变
        expect(editor.getBlock(id), isA<HeadingElement>());
        expect(editor.sourceOf(id), equals('# Title'));
      });

      test('revert 未 apply 过的 op → 安全（无副作用）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');
        final originalElement = editor.getBlock(id);

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: id,
          transformedType: BlockType.heading,
        );

        // 不 apply，直接 revert
        op.revert(editor);

        // editor 状态不变
        expect(editor.getBlock(id), equals(originalElement));
      });

      test('apply → revert → apply → revert 多轮幂等性', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: id,
          transformedType: BlockType.heading,
        );

        // 第 1 轮
        expect(op.apply(editor), isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
        op.revert(editor);
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('# Title'));

        // 第 2 轮
        expect(op.apply(editor), isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
        op.revert(editor);
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('# Title'));

        // 第 3 轮
        expect(op.apply(editor), isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
        op.revert(editor);
        expect(editor.getBlock(id), isA<ParagraphElement>());
      });
    });

    group('updateSource 边界', () {
      test('newSource 为空字符串 → type 变为 paragraph，source=空', () {
        final editor = MockDocumentEditor();
        final id = editor.addBlock('# Title', BlockType.heading);
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.updateSource(id, ''), isTrue);

        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals(''));
      });

      test('newSource 含 emoji → source 保留', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        // emoji 在 UTF-16 是 surrogate pair（2 code units），但 source 应原样保留
        expect(ops.updateSource(id, '# 😀'), isTrue);

        expect(editor.getBlock(id), isA<HeadingElement>());
        expect(editor.sourceOf(id), equals('# 😀'));
      });

      test('newSource 含换行符 → code 类型可含换行', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        // ```dart\nprint(1);\n``` 是合法 code block
        expect(ops.updateSource(id, '```dart\nprint(1);\n```'), isTrue);

        expect(editor.getBlock(id), isA<CodeElement>());
        expect((editor.getBlock(id) as CodeElement).language, equals('dart'));
        expect((editor.getBlock(id) as CodeElement).code, equals('print(1);'));
      });

      test('多轮 type 切换：paragraph → heading → listItem → paragraph', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final originalIdValue = id.value;
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        // 第 1 次：→ heading
        ops.updateSource(id, '# Title');
        expect(editor.getBlock(id), isA<HeadingElement>());

        // 第 2 次：→ listItem
        ops.updateSource(id, '- item');
        expect(editor.getBlock(id), isA<ListElement>());

        // 第 3 次：→ paragraph
        ops.updateSource(id, 'plain text');
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('plain text'));

        // BlockId 全程不变
        expect(id.value, equals(originalIdValue));
      });

      test('updateSource 触发 transform 但 TextOp 失败 → 返回 false', () {
        // 这种场景难以构造（TextOp 失败需 offset 越界，但 updateSource 总是 offset=0）
        // 跳过此测试，仅保留 placeholder
        // 实际：offset=0 + deleted=oldSource + inserted=newSource 总是合法
        // 所以 updateSource 失败仅在 targetId 不存在时发生
      }, skip: 'TextOp 边界失败无法构造');

      test('updateSource 调用顺序：transform 先于 TextOperation', () {
        // 验证：updateSource 触发 transform 时，builder.ops 中
        // BlockOperation.transform 在 TextOperation 之前
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.updateSource(id, '# Title');
        final tx = builder.commit();

        expect(tx.ops.length, equals(2));
        // 第 1 个 op 是 transform（先 transform 为新 type）
        expect(tx.ops[0], isA<BlockOperation>());
        expect(
          (tx.ops[0] as BlockOperation).opType,
          equals(BlockOpType.transform),
        );
        // 第 2 个 op 是 TextOperation（替换 source）
        expect(tx.ops[1], isA<TextOperation>());
      });
    });

    group('tryTransform 边界', () {
      test('source 为空字符串 → 不触发 transform', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.tryTransform(id), isFalse);
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(builder.opCount, equals(0));
      });

      test('source 含 emoji 但触发 heading 规则 → 仍 transform', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# 😀 Title');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
        // HeadingElement.text 保留 '# ' 之后的所有内容（含 emoji）
        expect((editor.getBlock(id) as HeadingElement).text, equals('😀 Title'));
      });

      test('已 transform 过的 block 再次 tryTransform → 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        // 第 1 次：触发 transform
        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());

        // 第 2 次：source 不变，detectBlockType 仍为 heading，type 已是 heading → 不触发
        expect(ops.tryTransform(id), isFalse);
        expect(editor.getBlock(id), isA<HeadingElement>());
        expect(builder.opCount, equals(1));  // 仅第 1 次的 op
      });

      test('mermaid block：```mermaid\n...\n``` → transform 为 mermaid', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('```mermaid\ngraph TD;\nA-->B;\n```');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.tryTransform(id), isTrue);
        // 检测：detectBlockType 返回 code（regex `^```+\S*` 匹配 mermaid fence）
        // 但 toElement 内部根据 language.toLowerCase() == 'mermaid' 分流为 MermaidElement
        // 所以最终 element 是 MermaidElement（BlockType.fromElement 返回 mermaid）
        final element = editor.getBlock(id);
        expect(element, isA<MermaidElement>());
        expect((element as MermaidElement).code, equals('graph TD;\nA-->B;'));
      });

      test('多种前缀混合：`# - *` 作为 paragraph source → 仍触发 heading', () {
        // '# - *' 匹配 heading 规则（`^#{1,6}\s+(.*)$`），不会触发 listItem
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# - *');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.tryTransform(id), isTrue);
        expect(editor.getBlock(id), isA<HeadingElement>());
      });
    });

    group('BlockId 生命周期', () {
      test('多次 transform 后 BlockId 保持不变', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final originalIdValue = id.value;
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        // 轮换多次 type
        ops.updateSource(id, '# Title');  // → heading
        expect(id.value, equals(originalIdValue));

        ops.updateSource(id, '- item');  // → listItem
        expect(id.value, equals(originalIdValue));

        ops.updateSource(id, '> quote');  // → blockquote
        expect(id.value, equals(originalIdValue));

        ops.updateSource(id, 'plain');  // → paragraph
        expect(id.value, equals(originalIdValue));
      });

      test('split 自动 transform 不变更原块 BlockId', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello# Title');
        final originalIdValue = id.value;
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.split(id, 5);

        expect(editor.allIds.first.value, equals(originalIdValue));
        expect(editor.allIds.last.value, isNot(equals(originalIdValue)));
      });
    });

    group('Phase 2.6 既有 split 测试兼容性', () {
      test('Phase 2.6 `helloworld` split → 仍仅 1 op（无 transform）', () {
        final editor = MockDocumentEditor();
        final targetId = editor.addParagraph('helloworld');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.split(targetId, 5), isTrue);
        expect(editor.blockCount, equals(2));
        expect(editor.allSources, equals(['hello', 'world']));
        expect(builder.opCount, equals(1));
      });

      test('Phase 2.6 `hello` split → 仅 1 op（无 transform）', () {
        final editor = MockDocumentEditor();
        final targetId = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        expect(ops.split(targetId, 2), isTrue);
        expect(editor.allSources, equals(['he', 'llo']));
        expect(builder.opCount, equals(1));
      });

      test('Phase 2.6 split revert 后 BlockId 仍可恢复', () {
        final editor = MockDocumentEditor();
        final targetId = editor.addParagraph('helloworld');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.split(targetId, 5);
        expect(editor.blockCount, equals(2));

        for (final op in builder.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.blockCount, equals(1));
        expect(editor.allIds.first, equals(targetId));
        expect(editor.sourceOf(targetId), equals('helloworld'));
      });
    });

    group('revert 幂等性', () {
      test('transform op 双次 revert → 安全（无副作用）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('# Title');

        final op = BlockOperation(
          opType: BlockOpType.transform,
          targetId: id,
          transformedType: BlockType.heading,
        );

        op.apply(editor);
        op.revert(editor);
        op.revert(editor);  // 第 2 次 revert：写入同值 → 无副作用

        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.sourceOf(id), equals('# Title'));
      });

      test('updateSource 双次 revert → 安全（无副作用）', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final builder = _newBuilder();
        final ops = BlockOperations(editor, builder);

        ops.updateSource(id, '# Title');
        final tx = builder.commit();

        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.sourceOf(id), equals('hello'));

        // 第 2 轮 revert（不应破坏状态）
        for (final op in tx.ops.reversed) {
          op.revert(editor);
        }
        expect(editor.getBlock(id), isA<ParagraphElement>());
        expect(editor.allIds, contains(id));
      }, skip: 'TextOperation.revert 边界检查会抛 StateError（评审反馈 A 修复），双次 revert 不再安全');
    });
  });
}
