/// InMemoryDocumentEditor：DocumentEditor 的内存实现（Prototype 专用）。
///
/// 落地 ADR-0009 §4：Phase 2.9 Prototype 需要一个具体的 [DocumentEditor] 实现，
/// 因内核（lib/core/editing/document_editor.dart）只定义抽象接口，
/// Phase 3 才会实现正式 UI 层的具体类。
///
/// 本类基于 test/editing/helpers/mock_document_editor.dart 的实现，
/// 提取到 lib/ 供 Prototype Demo 使用。**不修改内核**。
library;

import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/document_editor.dart';
import 'package:formula_fix/data/models/document.dart';

/// 内存态 [DocumentEditor] 实现（Prototype 专用）。
///
/// 维护 `List<_Entry>` 保存每个 [BlockId] 对应的 [DocumentElement]。
/// 提供 [addParagraph] / [sourceOf] / [allIds] / [allElements] 等辅助方法。
class InMemoryDocumentEditor implements DocumentEditor {
  final List<_Entry> _blocks = [];
  int _nextIdValue = 100;

  InMemoryDocumentEditor();

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

  /// **Phase 3.1-A PR #2（R5）行为变更**：此方法默认**保持 [BlockId] 不变**
  /// （不再默默分配新 BlockId 给新 element）。
  ///
  /// 调用方持有旧 [BlockId] 的引用（如 BlockViewState、focus 状态、UI 控制器）
  /// 依然有效。
  ///
  /// 若需分配新 [BlockId]（如 BlockType 转换场景），使用
  /// [replaceBlockWithMigration] 显式选择并接受迁移回调。
  ///
  /// [replaceBlockKeepId] 是本方法的显式版本（行为相同，语义更清晰）。
  @override
  DocumentElement replaceBlock(BlockId id, DocumentElement element) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        final old = _blocks[i].element;
        // Phase 3.1-A PR #2（R5）：保持 BlockId 不变（之前是分配新 BlockId）
        _blocks[i] = _Entry(id, element);
        return old;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  /// 显式保持 [BlockId] 不变的替换（[replaceBlock] 的显式版本）。
  ///
  /// 行为等同 [replaceBlock]，但语义更清晰：调用方主动声明"保持 BlockId"。
  @override
  DocumentElement replaceBlockKeepId(BlockId id, DocumentElement element) {
    return replaceBlock(id, element);
  }

  /// 替换 [id] 对应的块为 [element]，分配新 [BlockId]，并通过 [onMigrated]
  /// 回调通知调用方迁移信息。
  ///
  /// **使用场景**：BlockType 转换（如 Paragraph → Heading）需要重建 element
  /// 但保留 source；调用方在 [onMigrated] 中更新 BlockViewState / focus / UI
  /// 控制器的 BlockId 引用。
  ///
  /// 若 [onMigrated] 为 null，行为等同旧版 `replaceBlock`（分配新 BlockId 但不通知），
  /// 仅用于向后兼容（不推荐）。
  @override
  DocumentElement replaceBlockWithMigration(
    BlockId id,
    DocumentElement element, {
    void Function(BlockId oldId, BlockId newId)? onMigrated,
  }) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        final old = _blocks[i].element;
        final newId = BlockId(_nextIdValue++);
        _blocks[i] = _Entry(newId, element);
        onMigrated?.call(id, newId);
        return old;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  @override
  void updateBlockContent(BlockId id, DocumentElement newContent) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        _blocks[i] = _Entry(id, newContent);
        return;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  // ============ Prototype 辅助方法 ============

  /// 用 source 构造 [ParagraphElement] 并追加到末尾，返回 [BlockId]。
  BlockId addParagraph(String source) {
    return insertBlock(_blocks.length, ParagraphElement(children: [
      TextElement(source),
    ]));
  }

  /// 用任意 source + type 构造 [DocumentElement] 并追加到末尾，返回 [BlockId]。
  BlockId addBlock(String source, BlockType type) {
    return insertBlock(_blocks.length, toElement(source, type));
  }

  /// 返回所有 [BlockId]（按顺序）。
  @override
  List<BlockId> get allIds => _blocks.map((e) => e.id).toList(growable: false);

  /// 返回所有 [DocumentElement]（按顺序）。
  List<DocumentElement> get allElements =>
      _blocks.map((e) => e.element).toList(growable: false);

  /// 获取指定 [BlockId] 对应块的 Markdown source。
  String sourceOf(BlockId id) {
    final element = getBlock(id);
    if (element == null) {
      throw StateError('BlockId not found: $id');
    }
    return fromElement(element);
  }

  /// 返回所有块的 source 列表。
  List<String> get allSources =>
      _blocks.map((e) => fromElement(e.element)).toList(growable: false);
}

class _Entry {
  final BlockId id;
  final DocumentElement element;
  _Entry(this.id, this.element);
}
