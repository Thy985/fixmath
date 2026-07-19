/// TC-EDIT-1: Block 编辑内核数据类测试
///
/// 对应 ADR-0007 §1.2（BlockType 1:1 映射）+ §2.1（BlockPosition）+ §3.1（ComposingRegion）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('TC-EDIT-1.1 BlockId', () {
    test('同值相等', () {
      expect(const BlockId(1), equals(const BlockId(1)));
    });

    test('不同值不等', () {
      expect(const BlockId(1), isNot(equals(const BlockId(2))));
    });

    test('hashCode 一致性', () {
      expect(const BlockId(1).hashCode, equals(const BlockId(1).hashCode));
    });

    test('toString 含 value', () {
      expect(const BlockId(42).toString(), contains('42'));
    });
  });

  group('TC-EDIT-1.2 BlockType.fromElement 1:1 映射', () {
    test('HeadingElement → heading', () {
      expect(
        BlockType.fromElement(const HeadingElement(level: 1, text: 't')),
        equals(BlockType.heading),
      );
    });

    test('ParagraphElement → paragraph', () {
      expect(
        BlockType.fromElement(const ParagraphElement(children: [])),
        equals(BlockType.paragraph),
      );
    });

    test('ListElement → listItem', () {
      expect(
        BlockType.fromElement(const ListElement(children: [], ordered: false)),
        equals(BlockType.listItem),
      );
    });

    test('TaskListItemElement → taskListItem', () {
      expect(
        BlockType.fromElement(
          const TaskListItemElement(children: [], checked: false),
        ),
        equals(BlockType.taskListItem),
      );
    });

    test('CodeElement → code', () {
      expect(
        BlockType.fromElement(const CodeElement(code: 'print(1)')),
        equals(BlockType.code),
      );
    });

    test('TableElement → table', () {
      expect(
        BlockType.fromElement(
          const TableElement(headers: ['a'], rows: []),
        ),
        equals(BlockType.table),
      );
    });

    test('BlockquoteElement → blockquote', () {
      expect(
        BlockType.fromElement(const BlockquoteElement(text: 'q')),
        equals(BlockType.blockquote),
      );
    });

    test('MermaidElement → mermaid', () {
      expect(
        BlockType.fromElement(const MermaidElement(code: 'graph TD')),
        equals(BlockType.mermaid),
      );
    });

    test('HorizontalRuleElement → horizontalRule', () {
      expect(
        BlockType.fromElement(const HorizontalRuleElement()),
        equals(BlockType.horizontalRule),
      );
    });

    test('EmptyLineElement 抛 ArgumentError（空行不可编辑）', () {
      expect(
        () => BlockType.fromElement(const EmptyLineElement()),
        throwsArgumentError,
      );
    });
  });

  group('TC-EDIT-1.3 BlockSelection', () {
    test('默认 affinity 是 downstream', () {
      const sel = BlockSelection(start: 0, end: 5);
      expect(sel.affinity, equals(TextAffinity.downstream));
    });

    test('length = end - start', () {
      const sel = BlockSelection(start: 2, end: 8);
      expect(sel.length, equals(6));
    });

    test('isCollapsed = true 当 start == end', () {
      const sel = BlockSelection(start: 5, end: 5);
      expect(sel.isCollapsed, isTrue);
    });

    test('isCollapsed = false 当 start < end', () {
      const sel = BlockSelection(start: 0, end: 1);
      expect(sel.isCollapsed, isFalse);
    });

    test('start < 0 抛 assertion error', () {
      expect(
        () => BlockSelection(start: -1, end: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('end < start 抛 assertion error', () {
      expect(
        () => BlockSelection(start: 5, end: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equality 包含 affinity', () {
      const a = BlockSelection(
          start: 0, end: 1, affinity: TextAffinity.downstream);
      const b = BlockSelection(
          start: 0, end: 1, affinity: TextAffinity.upstream);
      expect(a, isNot(equals(b)));
    });

    test('copyWith 不变原对象', () {
      const original = BlockSelection(start: 0, end: 5);
      final modified = original.copyWith(end: 10);
      expect(original.end, equals(5));
      expect(modified.end, equals(10));
    });
  });

  group('TC-EDIT-1.4 BlockPosition', () {
    const blockId = BlockId(1);

    test('offset >= 0', () {
      expect(
        () => BlockPosition(blockId: blockId, offset: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('isCursor = true 当 selection null', () {
      const pos = BlockPosition(blockId: blockId, offset: 5);
      expect(pos.isCursor, isTrue);
    });

    test('isCursor = true 当 selection.isCollapsed', () {
      const pos = BlockPosition(
        blockId: blockId,
        offset: 5,
        selection: BlockSelection(start: 5, end: 5),
      );
      expect(pos.isCursor, isTrue);
    });

    test('isCursor = false 当有范围选区', () {
      const pos = BlockPosition(
        blockId: blockId,
        offset: 5,
        selection: BlockSelection(start: 0, end: 5),
      );
      expect(pos.isCursor, isFalse);
    });

    test('equality 含 blockId + offset + selection', () {
      const a = BlockPosition(
        blockId: blockId,
        offset: 3,
        selection: BlockSelection(start: 0, end: 3),
      );
      const b = BlockPosition(
        blockId: blockId,
        offset: 3,
        selection: BlockSelection(start: 0, end: 3),
      );
      expect(a, equals(b));
    });

    test('copyWith 不变原对象', () {
      const original = BlockPosition(blockId: blockId, offset: 5);
      final modified = original.copyWith(offset: 10);
      expect(original.offset, equals(5));
      expect(modified.offset, equals(10));
    });

    test('copyWith 可清空 selection（_sentinel 机制）', () {
      const original = BlockPosition(
        blockId: blockId,
        offset: 5,
        selection: BlockSelection(start: 0, end: 5),
      );
      final modified = original.copyWith(selection: null);
      expect(modified.selection, isNull);
    });
  });

  group('TC-EDIT-1.5 ComposingRegion', () {
    test('empty 常量 isActive = false', () {
      expect(ComposingRegion.empty.isActive, isFalse);
    });

    test('start >= 0 且 end > start 时 isActive = true', () {
      const region = ComposingRegion(start: 0, end: 5);
      expect(region.isActive, isTrue);
    });

    test('start < 0 时 isActive = false', () {
      const region = ComposingRegion(start: -1, end: 5);
      expect(region.isActive, isFalse);
    });

    test('end <= start 时 isActive = false', () {
      const region = ComposingRegion(start: 5, end: 5);
      expect(region.isActive, isFalse);
    });

    test('length = end - start 当 active', () {
      const region = ComposingRegion(start: 0, end: 5);
      expect(region.length, equals(5));
    });

    test('length = 0 当 inactive', () {
      expect(ComposingRegion.empty.length, equals(0));
    });

    test('equality', () {
      const a = ComposingRegion(start: 0, end: 3);
      const b = ComposingRegion(start: 0, end: 3);
      const c = ComposingRegion(start: 0, end: 4);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
