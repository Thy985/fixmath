/// R3 _shared 层单元测试：InMemoryDocumentEditor 的 CRUD 操作。
///
/// 落地 PR 评审 R3（Phase 2.9 PR review）+ Phase 2.9 Task Contract §5.1。
///
/// **覆盖范围**：
/// - insertBlock：返回新 BlockId（>=100，唯一），index 越界抛 RangeError
/// - removeBlock：返回被移除元素，找不到抛 StateError
/// - replaceBlock：返回旧元素，**保持 BlockId 不变**（Phase 3.1-A PR #2 R5 行为变更）
/// - updateBlockContent：保持 BlockId 不变
/// - getBlock / indexOf：查询行为
/// - allIds / allElements / allSources：返回不可变列表
/// - addParagraph / addBlock / sourceOf 辅助方法
///
/// **不在范围**：DocumentEditor 接口的副作用边界（无 listener）→
/// 见 test/editing/document_editor_test.dart TC-EDIT-6.5
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/presentation/prototype/_shared/in_memory_document_editor.dart';

void main() {
  group('R3 InMemoryDocumentEditor CRUD', () {
    group('insertBlock', () {
      test('空 editor 插入第 1 块，blockCount == 1', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.insertBlock(
            0, const ParagraphElement(children: [TextElement('hello')]));
        expect(editor.blockCount, equals(1));
        expect(id.value, greaterThanOrEqualTo(100));
      });

      test('返回新 BlockId（>=100，唯一，自增）', () {
        final editor = InMemoryDocumentEditor();
        final id1 = editor.insertBlock(
            0, const ParagraphElement(children: [TextElement('a')]));
        final id2 = editor.insertBlock(
            1, const ParagraphElement(children: [TextElement('b')]));
        expect(id1, isNot(equals(id2)));
        expect(id1.value, greaterThanOrEqualTo(100));
        expect(id2.value, greaterThan(id1.value),
            reason: 'BlockId 应自增');
      });

      test('preserveId 参数：用指定 BlockId 插入（不重新分配）', () {
        final editor = InMemoryDocumentEditor();
        const customId = BlockId(999);
        final id = editor.insertBlock(
          0,
          const ParagraphElement(children: [TextElement('custom')]),
          preserveId: customId,
        );
        expect(id, equals(customId));
      });

      test('index 越界（< 0 或 > blockCount）抛 RangeError', () {
        final editor = InMemoryDocumentEditor();
        expect(
          () => editor.insertBlock(
              -1, const ParagraphElement(children: [TextElement('x')])),
          throwsRangeError,
        );
        expect(
          () => editor.insertBlock(
              5, const ParagraphElement(children: [TextElement('x')])),
          throwsRangeError,
        );
      });
    });

    group('removeBlock', () {
      test('返回被移除元素', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('hello');
        final removed = editor.removeBlock(id);
        expect(removed, isA<ParagraphElement>());
      });

      test('remove 后 blockCount 递减', () {
        final editor = InMemoryDocumentEditor();
        editor.addParagraph('a');
        editor.addParagraph('b');
        expect(editor.blockCount, equals(2));
        final id = editor.allIds.first;
        editor.removeBlock(id);
        expect(editor.blockCount, equals(1));
      });

      test('找不到 id 抛 StateError', () {
        final editor = InMemoryDocumentEditor();
        expect(
          () => editor.removeBlock(const BlockId(999)),
          throwsStateError,
        );
      });
    });

    group('replaceBlock（R5：保持 BlockId 行为）', () {
      test('返回旧元素', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('old');
        final old = editor.replaceBlock(
            id, const ParagraphElement(children: [TextElement('new')]));
        expect(old, isA<ParagraphElement>());
      });

      test('replace 后 BlockId 保持不变（Phase 3.1-A PR #2 R5 行为变更）', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('old');
        editor.replaceBlock(
            id, const ParagraphElement(children: [TextElement('new')]));
        // R5：replaceBlock 默认保持 BlockId（之前是分配新 BlockId）
        expect(editor.getBlock(id), isNotNull,
            reason: 'R5：replaceBlock 后 BlockId 应保持有效');
        expect(editor.blockCount, equals(1),
            reason: '块数不变（替换而非插入）');
      });

      test('replace 后 BlockId 在 allIds 中（位置不变）', () {
        final editor = InMemoryDocumentEditor();
        final id1 = editor.addParagraph('first');
        final id2 = editor.addParagraph('second');
        // 替换第一块
        editor.replaceBlock(
            id1, const ParagraphElement(children: [TextElement('new first')]));
        // allIds 长度不变，且首块 BlockId 保持不变
        expect(editor.allIds.length, equals(2));
        expect(editor.allIds[0], equals(id1),
            reason: 'R5：首块 BlockId 应保持不变');
        expect(editor.allIds[1], equals(id2),
            reason: '第二块 BlockId 应保持不变');
      });

      test('replaceBlockKeepId 行为等同 replaceBlock', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('old');
        final old = editor.replaceBlockKeepId(
            id, const ParagraphElement(children: [TextElement('new')]));
        expect(old, isA<ParagraphElement>());
        expect(editor.getBlock(id), isNotNull,
            reason: 'replaceBlockKeepId 保持 BlockId 不变');
      });

      test('replaceBlockWithMigration 分配新 BlockId 并触发回调', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('old');
        BlockId? capturedOld;
        BlockId? capturedNew;
        final old = editor.replaceBlockWithMigration(
          id,
          const ParagraphElement(children: [TextElement('new')]),
          onMigrated: (oldId, newId) {
            capturedOld = oldId;
            capturedNew = newId;
          },
        );
        expect(old, isA<ParagraphElement>());
        expect(capturedOld, equals(id),
            reason: '回调应收到原 BlockId');
        expect(capturedNew, isNot(equals(id)),
            reason: '回调应收到新 BlockId（与原 BlockId 不同）');
        expect(editor.getBlock(id), isNull,
            reason: 'replaceBlockWithMigration 后旧 BlockId 应失效');
        expect(editor.allIds.contains(capturedNew), isTrue,
            reason: '新 BlockId 应在 allIds 中');
      });

      test('找不到 id 抛 StateError', () {
        final editor = InMemoryDocumentEditor();
        expect(
          () => editor.replaceBlock(
              const BlockId(999),
              const ParagraphElement(children: [TextElement('x')])),
          throwsStateError,
        );
      });
    });

    group('updateBlockContent（保持 BlockId 不变）', () {
      test('内容已更新', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('old');
        editor.updateBlockContent(
            id, const ParagraphElement(children: [TextElement('new')]));
        final element = editor.getBlock(id);
        expect(element, isA<ParagraphElement>());
      });

      test('保持 BlockId 不变', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('old');
        editor.updateBlockContent(
            id, const ParagraphElement(children: [TextElement('new')]));
        expect(editor.getBlock(id), isNotNull,
            reason: 'updateBlockContent 不变更 BlockId');
        expect(editor.allIds, contains(id));
      });

      test('找不到 id 抛 StateError', () {
        final editor = InMemoryDocumentEditor();
        expect(
          () => editor.updateBlockContent(
              const BlockId(999),
              const ParagraphElement(children: [TextElement('x')])),
          throwsStateError,
        );
      });
    });

    group('getBlock / indexOf', () {
      test('getBlock 返回对应元素', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('hello');
        expect(editor.getBlock(id), isNotNull);
      });

      test('getBlock 找不到返回 null', () {
        final editor = InMemoryDocumentEditor();
        expect(editor.getBlock(const BlockId(999)), isNull);
      });

      test('indexOf 返回正确 index', () {
        final editor = InMemoryDocumentEditor();
        final id1 = editor.addParagraph('a');
        final id2 = editor.addParagraph('b');
        final id3 = editor.addParagraph('c');
        expect(editor.indexOf(id1), equals(0));
        expect(editor.indexOf(id2), equals(1));
        expect(editor.indexOf(id3), equals(2));
      });

      test('indexOf 找不到返回 -1', () {
        final editor = InMemoryDocumentEditor();
        expect(editor.indexOf(const BlockId(999)), equals(-1));
      });
    });

    group('allIds / allElements / allSources', () {
      test('allIds 返回按顺序的 BlockId 列表', () {
        final editor = InMemoryDocumentEditor();
        editor.addParagraph('a');
        editor.addParagraph('b');
        editor.addParagraph('c');
        expect(editor.allIds.length, equals(3));
        // 顺序应与插入顺序一致
        final sources = editor.allSources;
        expect(sources, equals(['a', 'b', 'c']));
      });

      test('allIds 返回不可变列表（外部修改不影响内部状态）', () {
        final editor = InMemoryDocumentEditor();
        editor.addParagraph('a');
        editor.addParagraph('b');
        final ids = editor.allIds;
        // 尝试修改返回的列表（应抛异常或无效）
        expect(() => ids.add(const BlockId(999)), throwsUnsupportedError,
            reason: 'allIds 应返回不可变列表');
        // 内部状态未受影响
        expect(editor.allIds.length, equals(2));
      });

      test('allElements 返回按顺序的 DocumentElement 列表', () {
        final editor = InMemoryDocumentEditor();
        editor.addParagraph('a');
        editor.addBlock('# Heading', BlockType.heading);
        final elements = editor.allElements;
        expect(elements.length, equals(2));
        expect(elements[0], isA<ParagraphElement>());
        expect(elements[1], isA<HeadingElement>());
      });

      test('allSources 通过 fromElement 序列化', () {
        final editor = InMemoryDocumentEditor();
        editor.addBlock('# Title', BlockType.heading);
        editor.addParagraph('hello');
        expect(editor.allSources, equals(['# Title', 'hello']));
      });
    });

    group('addParagraph / addBlock / sourceOf 辅助方法', () {
      test('addParagraph 追加段落并返回 BlockId', () {
        final editor = InMemoryDocumentEditor();
        final id = editor.addParagraph('hello');
        expect(editor.blockCount, equals(1));
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('addBlock 按 type 构造对应 DocumentElement', () {
        final editor = InMemoryDocumentEditor();
        final id1 = editor.addBlock('# Heading', BlockType.heading);
        final id2 = editor.addBlock('```\ncode\n```', BlockType.code);

        expect(editor.getBlock(id1), isA<HeadingElement>());
        expect(editor.getBlock(id2), isA<CodeElement>());
      });

      test('sourceOf 找不到 id 抛 StateError', () {
        final editor = InMemoryDocumentEditor();
        expect(
          () => editor.sourceOf(const BlockId(999)),
          throwsStateError,
        );
      });
    });
  });
}
