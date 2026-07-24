/// InMemoryDocumentEditor：DocumentEditor 的内存实现（Phase 3.0 production 路径）。
///
/// 落地 ADR-0009 §4 + Phase 3.0 Task Contract §2.6（复用 Phase 2.9 产出）。
/// 落地 Phase 3.3 Task Contract §3.3.1 + §3.3.4（title / wordCount / isDirty）。
///
/// **职责**：
/// - 实现 [DocumentEditor] 接口（内核抽象）
/// - 维护 `List<_Entry>` 保存每个 [BlockId] 对应的 [DocumentElement]
/// - 提供 [addParagraph] / [sourceOf] / [allIds] / [allElements] 等辅助方法
/// - **Phase 3.3 新增**：[title] / [wordCount] / [isDirty] / [markSaved]
///
/// **不修改内核**（Hard Rule: Phase 3.0 不动 lib/core/editing/）。
///
/// **Phase 3.1+ 接入真实 .md 文件时**：替换为基于 .md 的 [DocumentEditor] 实现，
/// UI 层不变（[EditorCoordinator] 通过接口依赖，不直接耦合 [InMemoryDocumentEditor]）。
library;

import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/document_editor.dart';
import 'package:formula_fix/data/models/document.dart';

/// 内存态 [DocumentEditor] 实现（Phase 3.0 production 路径）。
///
/// 维护 `List<_Entry>` 保存每个 [BlockId] 对应的 [DocumentElement]。
/// 提供 [addParagraph] / [sourceOf] / [allIds] / [allElements] 等辅助方法。
class InMemoryDocumentEditor implements DocumentEditor {
  final List<_Entry> _blocks = [];
  int _nextIdValue = 100;

  /// 文档标题（Phase 3.3：从种子文档元数据或首个 HeadingElement 提取）。
  ///
  /// 默认值 `'未命名'` 在 EditorPage 构造时可被覆盖。
  String _title;

  /// Dirty 标记（Phase 3.3：ADR-0011 §4 归属 Document State）。
  ///
  /// - 任何 mutating 操作（insert / remove / replace / update）后置 true
  /// - [markSaved] 时置 false
  /// - undo / redo 不直接修改此标记（由 EditorCoordinator 根据 history 状态推导）
  bool _isDirty = false;

  InMemoryDocumentEditor({String title = '未命名'}) : _title = title;

  /// 文档标题。
  String get title => _title;

  /// 设置文档标题（用于 EditorPage 接入种子文档元数据）。
  set title(String value) => _title = value;

  /// 是否有未保存修改（ADR-0011 §4：Dirty 归属 Document State）。
  bool get isDirty => _isDirty;

  /// 标记文档已保存（重置 isDirty）。
  ///
  /// 由 EditorCoordinator.save()（Phase 3.4+ 接入）或外部保存逻辑调用。
  void markSaved() => _isDirty = false;

  /// 字数统计（Phase 3.3：基于 allSources 计算）。
  ///
  /// **实现**：拼接所有块 source,按 Unicode code unit 计数（含空白）。
  /// 这是最简单的实现,足够 Phase 3.3 状态栏显示。
  /// Phase 3.4+ 可升级为 CJK 字符感知的字数统计（排除空白 / 标点）。
  int get wordCount => allSources.fold<int>(
        0,
        (sum, source) => sum + source.length,
      );

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
    _isDirty = true;
    return id;
  }

  @override
  DocumentElement removeBlock(BlockId id) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].id == id) {
        _isDirty = true;
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
        _isDirty = true;
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
    // 直接委托给 replaceBlock（两者行为相同，replaceBlockKeepId 仅是语义糖）
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
        _isDirty = true;
        // 通知调用方迁移信息（若提供了回调）
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
        _isDirty = true;
        return;
      }
    }
    throw StateError('BlockId not found: $id');
  }

  // ============ 辅助方法（Prototype 时期已存在，Phase 3.0 保留） ============

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

  /// 返回所有 [BlockId]（按顺序，不可变列表）。
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

  /// 返回所有块的 source 列表（不可变）。
  List<String> get allSources =>
      _blocks.map((e) => fromElement(e.element)).toList(growable: false);
}

class _Entry {
  final BlockId id;
  final DocumentElement element;
  _Entry(this.id, this.element);
}
