/// BlockEditorFacade：UI 层对编辑内核的封装（Prototype 专用）。
///
/// 落地 ADR-0009 §3.5 + Interaction-Model.md §2.3。
///
/// **职责**：
/// - 持有 [InMemoryDocumentEditor] + [EditorHistory] + [CommandHandler]
/// - 提供 [handler] 供 UI 层调用 [EditorCommand]
/// - 提供 [undo] / [redo] 方法（封装 Transaction revert/apply）
///
/// **不持有 UI 状态**：UI 状态由 [BlockViewState] 单独建模。
library;

import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/core/editing/transaction.dart';
import 'package:formula_fix/data/models/document.dart';

import '../../../core/editing/block_types.dart';
import '../../commands/command_handler.dart';
import 'in_memory_document_editor.dart';

/// BlockEditor 封装（Prototype 专用）。
///
/// UI 层通过 `facade.handler.handle(command)` 处理用户事件，
/// 通过 `facade.undo()` / `facade.redo()` 撤销 / 重做。
class BlockEditorFacade {
  /// 编辑内核（持有 Document AST + BlockId 分配）。
  final InMemoryDocumentEditor editor;

  /// Undo / Redo 历史栈。
  final EditorHistory history;

  /// Command 处理器（v1.1 新增）。
  late final CommandHandler handler;

  BlockEditorFacade({
    required this.editor,
    required this.history,
  }) {
    handler = CommandHandler(this);
  }

  /// 从初始 [Document] 构造（每个段落成为一个块）。
  ///
  /// Prototype 简化实现：按行切分 content，每行一个 [ParagraphElement]。
  /// Phase 3 正式实现应用 [MarkdownParser.parse] 解析。
  factory BlockEditorFacade.fromContent(String content) {
    final editor = InMemoryDocumentEditor();
    final lines = content.isEmpty ? <String>[''] : content.split('\n');
    for (final line in lines) {
      editor.addParagraph(line);
    }
    final history = EditorHistory(maxHistorySize: 200);
    return BlockEditorFacade(editor: editor, history: history);
  }

  /// 从空文档构造（包含一个空段落）。
  factory BlockEditorFacade.empty() {
    return BlockEditorFacade.fromContent('');
  }

  // ============ 查询接口 ============

  /// 当前块数。
  int get blockCount => editor.blockCount;

  /// 所有 [BlockId]（按顺序）。
  List<BlockId> get allIds => editor.allIds;

  /// 获取指定块的 [DocumentElement]。
  DocumentElement? getBlock(BlockId id) => editor.getBlock(id);

  /// 获取指定块的 source（通过 [fromElement] 序列化）。
  String sourceOf(BlockId id) => editor.sourceOf(id);

  /// 所有块的 source 列表。
  List<String> get allSources => editor.allSources;

  // ============ Undo / Redo ============

  /// 是否可 undo。
  bool get canUndo => history.canUndo;

  /// 是否可 redo。
  bool get canRedo => history.canRedo;

  /// Undo 一步：从 history 弹出 Transaction，逆序 revert ops 到 editor。
  ///
  /// 返回被撤销的 Transaction（用于 UI 显示，如 "撤销：拆分块"），失败返回 null。
  Transaction? undo() {
    // current state snapshot（Prototype 简化：不保存完整 snapshot，传空 Transaction）
    final currentState = Transaction(
      id: TransactionId.next(),
      ops: const [],
      metadata: TransactionMetadata(timestamp: DateTime.now()),
      origin: TransactionOrigin.undo,
    );
    final tx = history.undo(currentState);
    if (tx == null) return null;

    // 逆序 revert ops 到 editor
    for (final op in tx.ops.reversed) {
      op.revert(editor);
    }
    return tx;
  }

  /// Redo 一步：从 history 弹出 Transaction，顺序 apply ops 到 editor。
  ///
  /// 返回被重做的 Transaction，失败返回 null。
  Transaction? redo() {
    final currentState = Transaction(
      id: TransactionId.next(),
      ops: const [],
      metadata: TransactionMetadata(timestamp: DateTime.now()),
      origin: TransactionOrigin.redo,
    );
    final tx = history.redo(currentState);
    if (tx == null) return null;

    // 顺序 apply ops 到 editor
    for (final op in tx.ops) {
      op.apply(editor);
    }
    return tx;
  }

  @override
  String toString() =>
      'BlockEditorFacade(blockCount=$blockCount, canUndo=$canUndo, canRedo=$canRedo)';
}
