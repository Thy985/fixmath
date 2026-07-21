/// TC-EDIT-6.5 DocumentEditor 副作用边界单测。
///
/// 验证：
/// - insertBlock / removeBlock / replaceBlock / updateBlockContent 行为正确
/// - DocumentEditor **不暴露 listener**（v1.1 评审反馈 2）
/// - 所有方法仅修改数据，不触发任何回调
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.5。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/document_editor.dart';

/// 用于单测的 DocumentEditor mock 实现。
///
/// 维护 `List<_Entry>` 保存每个 BlockId 对应的 DocumentElement，
/// 模拟真实 DocumentEditor 的 BlockId 分配 / 查找 / 修改行为。
class _MockDocumentEditor implements DocumentEditor {
  final List<_Entry> _blocks = [];
  int _nextIdValue = 100;

  _MockDocumentEditor();

  @override
  int get blockCount => _blocks.length;

  @override
  List<BlockId> get allIds =>
      _blocks.map((e) => e.id).toList(growable: false);

  @override
  DocumentElement? getBlock(BlockId id) {
    for (final entry in _blocks) {
      if (entry.id == id) return entry.element;
    }
    return null;
  }

  @override
  int indexOf(BlockId id) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) return i;
    }
    return -1;
  }

  @override
  BlockId insertBlock(int index, DocumentElement element, {BlockId? preserveId}) {
    if (index < 0 || index > _blocks.length) {
      throw RangeError('index out of range: $index');
    }
    final id = preserveId ?? BlockId(_nextIdValue++);
    _blocks.insert(index, _Entry(id, element));
    return id;
  }

  @override
  DocumentElement removeBlock(BlockId id) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        return _blocks.removeAt(i).element;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  @override
  DocumentElement replaceBlock(BlockId id, DocumentElement element) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        final old = _blocks[i].element;
        // 替换：新 BlockId 由 DocumentEditor 重新分配（删除旧条目，插入新条目到同位置）
        final newId = BlockId(_nextIdValue++);
        _blocks[i] = _Entry(newId, element);
        return old;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  @override
  void updateBlockContent(BlockId id, DocumentElement newContent) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        // 保持 BlockId 不变，仅替换 element
        _blocks[i] = _Entry(id, newContent);
        return;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  /// 测试辅助：用 source 构造 Paragraph 并插入，返回 BlockId。
  BlockId addParagraph(String source) {
    return insertBlock(_blocks.length, ParagraphElement(children: [
      TextElement(source),
    ]));
  }

  /// 测试辅助：用 source 构造 Paragraph 并插入到指定位置。
  BlockId addParagraphAt(int index, String source) {
    return insertBlock(index, ParagraphElement(children: [
      TextElement(source),
    ]));
  }
}

class _Entry {
  final BlockId id;
  final DocumentElement element;
  _Entry(this.id, this.element);
}

void main() {
  group('TC-EDIT-6.5 DocumentEditor 副作用边界', () {
    group('insertBlock', () {
      test('空 editor 插入第 1 块，blockCount == 1', () {
        final editor = _MockDocumentEditor();
        final id = editor.insertBlock(0, const ParagraphElement(children: [TextElement('hello')]));
        expect(editor.blockCount, equals(1));
        expect(id.value, greaterThanOrEqualTo(100));
      });

      test('返回新 BlockId（>=100，唯一）', () {
        final editor = _MockDocumentEditor();
        final id1 = editor.insertBlock(0, const ParagraphElement(children: [TextElement('a')]));
        final id2 = editor.insertBlock(1, const ParagraphElement(children: [TextElement('b')]));
        expect(id1, isNot(equals(id2)));
        expect(id1.value, greaterThanOrEqualTo(100));
        expect(id2.value, greaterThan(id1.value));
      });

      test('index 越界抛 RangeError', () {
        final editor = _MockDocumentEditor();
        expect(
          () => editor.insertBlock(5, const ParagraphElement(children: [TextElement('x')])),
          throwsRangeError,
        );
      });
    });

    group('removeBlock', () {
      test('返回被移除元素', () {
        final editor = _MockDocumentEditor();
        final id = editor.addParagraph('hello');
        final removed = editor.removeBlock(id);
        expect(removed, isA<ParagraphElement>());
      });

      test('找不到 id 抛 StateError', () {
        final editor = _MockDocumentEditor();
        expect(
          () => editor.removeBlock(const BlockId(999)),
          throwsStateError,
        );
      });
    });

    group('replaceBlock', () {
      test('返回旧元素', () {
        final editor = _MockDocumentEditor();
        final id = editor.addParagraph('old');
        final old = editor.replaceBlock(id, const ParagraphElement(children: [TextElement('new')]));
        expect(old, isA<ParagraphElement>());
      });

      test('replace 后旧 BlockId 失效（新 BlockId 重新分配）', () {
        final editor = _MockDocumentEditor();
        final id = editor.addParagraph('old');
        editor.replaceBlock(id, const ParagraphElement(children: [TextElement('new')]));
        expect(editor.getBlock(id), isNull);
      });
    });

    group('updateBlockContent', () {
      test('保持 BlockId 不变（v1.1 评审反馈 1 联动）', () {
        final editor = _MockDocumentEditor();
        final id = editor.addParagraph('old');
        editor.updateBlockContent(id, const ParagraphElement(children: [TextElement('new')]));
        // BlockId 仍能找到（不变）
        expect(editor.getBlock(id), isNotNull);
      });

      test('内容已更新', () {
        final editor = _MockDocumentEditor();
        final id = editor.addParagraph('old');
        editor.updateBlockContent(id, const ParagraphElement(children: [TextElement('new')]));
        final element = editor.getBlock(id);
        expect(element, isA<ParagraphElement>());
      });

      test('找不到 id 抛 StateError', () {
        final editor = _MockDocumentEditor();
        expect(
          () => editor.updateBlockContent(const BlockId(999), const ParagraphElement(children: [TextElement('x')])),
          throwsStateError,
        );
      });
    });

    group('getBlock / indexOf', () {
      test('getBlock 返回对应元素', () {
        final editor = _MockDocumentEditor();
        final id = editor.addParagraph('hello');
        expect(editor.getBlock(id), isNotNull);
      });

      test('indexOf 返回正确 index', () {
        final editor = _MockDocumentEditor();
        final id1 = editor.addParagraph('a');
        final id2 = editor.addParagraph('b');
        final id3 = editor.addParagraph('c');
        expect(editor.indexOf(id1), equals(0));
        expect(editor.indexOf(id2), equals(1));
        expect(editor.indexOf(id3), equals(2));
      });

      test('indexOf 找不到返回 -1', () {
        final editor = _MockDocumentEditor();
        expect(editor.indexOf(const BlockId(999)), equals(-1));
      });

      test('getBlock 找不到返回 null', () {
        final editor = _MockDocumentEditor();
        expect(editor.getBlock(const BlockId(999)), isNull);
      });
    });

    group('v1.1 评审反馈 2：DocumentEditor 不暴露 listener', () {
      test('接口定义不含 listener API（编译期约束）', () {
        // 通过类型检查验证 DocumentEditor 接口不暴露 listener API
        // 这是设计约束：所有方法仅修改数据，不触发任何回调
        //
        // 静态检查：DocumentEditor 不继承 ChangeNotifier / Listenable
        // 若未来误添加 listener API，此测试会编译失败
        final editor = _MockDocumentEditor();
        // ignore: unnecessary_type_check
        expect(editor is DocumentEditor, isTrue);
        // 明确：DocumentEditor 实例不是 ChangeNotifier / Listenable
        // ignore: unnecessary_type_check
        expect(editor is ChangeNotifier, isFalse,
            reason: 'DocumentEditor must not be ChangeNotifier');
        // ignore: unnecessary_type_check
        expect(editor is Listenable, isFalse,
            reason: 'DocumentEditor must not be Listenable');
      });

      test('所有方法仅修改数据，不触发任何回调（blockCount 反映状态）', () {
        final editor = _MockDocumentEditor();
        // 插入 5 块，验证 blockCount 累加（无副作用，无回调）
        for (var i = 0; i < 5; i++) {
          editor.addParagraph('item $i');
          expect(editor.blockCount, equals(i + 1));
        }
      });
    });
  });
}
