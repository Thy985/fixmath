/// DocumentEditor 的 mock 实现（测试专用）。
///
/// 用于 Phase 2.6 各类测试（TC-EDIT-6.1 ~ 6.9）验证 EditOperation / Transaction /
/// EditorHistory / BlockOperations 的 apply / revert 行为，无需依赖真实 UI 层。
///
/// 维护 `List<_Entry>` 保存每个 [BlockId] 对应的 [DocumentElement]，
/// 模拟真实 DocumentEditor 的 BlockId 分配 / 查找 / 修改行为。
///
/// **不暴露 listener**（v1.1 评审反馈 2：DocumentEditor 是 model mutation boundary，
/// notification 责任在 [TransactionBuilder.commit] 一层）。
///
/// 本文件仅用于 test/，不放入 lib/。
library;

import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/document_editor.dart';
import 'package:formula_fix/data/models/document.dart';

/// 用于单测的 [DocumentEditor] mock 实现。
///
/// 维护 `List<_Entry>` 保存每个 [BlockId] 对应的 [DocumentElement]，
/// 模拟真实 DocumentEditor 的 BlockId 分配 / 查找 / 修改行为。
///
/// 提供 [addParagraph] / [sourceOf] 等测试辅助方法，简化测试代码。
class MockDocumentEditor implements DocumentEditor {
  final List<_Entry> _blocks = [];
  int _nextIdValue = 100;

  MockDocumentEditor();

  @override
  int get blockCount => _blocks.length;

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

  // ============ 测试辅助方法 ============

  /// 用 source 构造 [ParagraphElement] 并插入到末尾，返回 [BlockId]。
  ///
  /// 用于快速设置测试初始状态。
  BlockId addParagraph(String source) {
    return insertBlock(_blocks.length, ParagraphElement(children: [
      TextElement(source),
    ]));
  }

  /// 用 source 构造 [ParagraphElement] 并插入到指定位置，返回 [BlockId]。
  BlockId addParagraphAt(int index, String source) {
    return insertBlock(index, ParagraphElement(children: [
      TextElement(source),
    ]));
  }

  /// 用任意 source + type 构造 [DocumentElement] 并插入到末尾，返回 [BlockId]。
  BlockId addBlock(String source, BlockType type) {
    return insertBlock(_blocks.length, toElement(source, type));
  }

  /// 获取指定 [BlockId] 对应块的 Markdown source（通过 [fromElement] 序列化）。
  ///
  /// 找不到时抛 [StateError]。
  String sourceOf(BlockId id) {
    final element = getBlock(id);
    if (element == null) {
      throw StateError('BlockId not found: $id');
    }
    return fromElement(element);
  }

  /// 返回所有块的 source 列表（用于断言整体状态）。
  List<String> get allSources {
    return _blocks.map((e) => fromElement(e.element)).toList();
  }

  /// 返回当前所有 BlockId 列表（按顺序）。
  @override
  List<BlockId> get allIds {
    return _blocks.map((e) => e.id).toList();
  }
}

class _Entry {
  final BlockId id;
  final DocumentElement element;
  _Entry(this.id, this.element);
}
