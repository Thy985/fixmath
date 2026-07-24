/// EditorCoordinator：UI 层对编辑内核的协调器（Phase 3.0 production 路径）。
///
/// 落地 ADR-0009 §3.5 + Phase 3.0 §3.4 + §2.4（避免 God Object）+
/// Phase 3.1-A §3.1.A.3（弱化版 R1：CoordinatorState 单字段）。
/// **职责**：持有 editor / history / handler,管理 [CoordinatorState]。
/// 只协调,不持有业务状态。Hard Rule 1/4/8（AST 零污染 / 不持领域 / 单向依赖）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextSelection;
import '../../core/editing/block_types.dart';
import '../../core/editing/editor_history.dart';
import '../../core/editing/transaction.dart';
import '../../data/models/document.dart';
import '../commands/command_handler.dart';
import '../commands/editor_command.dart';
import '../states/block_view_state.dart';
import '../states/coordinator_state.dart';
import 'in_memory_document_editor.dart';

/// UI 层对编辑内核的协调器。Widget 通过 [EditorScope] 获取实例。
class EditorCoordinator extends ChangeNotifier {
  final InMemoryDocumentEditor editor;
  final EditorHistory history;
  late final CommandHandler handler;
  CoordinatorState _state;

  EditorCoordinator({
    required this.editor,
    required this.history,
  }) : _state = const CoordinatorState.empty() {
    handler = CommandHandler(editor: editor, history: history);
    _state = CoordinatorState.initial({
      for (final id in editor.allIds) id: BlockViewState(id: id),
    });
  }

  // ============ Command 入口 ============

  /// 处理 [EditorCommand]（成功后同步 selection 到 [BlockViewState]）。
  /// oldSource 捕获：cursorOffset 计算需要插入前的 source 长度（tryTransform 可能改变序列化结果）。
  bool handle(EditorCommand command) {
    final (oldSource, oldIds) = switch (command) {
      InsertTextCommand c => (editor.sourceOf(c.blockId), null),
      InsertTemplateCommand c when c.mode == TemplateInsertMode.insert =>
        (editor.sourceOf(c.blockId), null),
      InsertTemplateCommand c when c.mode == TemplateInsertMode.newBlock =>
        (null, editor.allIds.toSet()),
      InsertNewLineWithPrefixCommand c => (editor.sourceOf(c.blockId), null),
      _ => (null, null),
    };
    final ok = handler.handle(command);
    if (ok) {
      _syncSelectionAfterCommand(command, oldSource, oldIds);
      notifyListeners();
    }
    return ok;
  }

  /// 命令后同步 selection（R1+R2 + PR #2C 模板）。
  void _syncSelectionAfterCommand(
      EditorCommand command, String? oldSource, Set<BlockId>? oldIds) {
    switch (command) {
      case InsertTextCommand c:
        _setCollapsedCursor(c.blockId, c.selection, oldSource,
            c.text.length, c.cursorOffset);
      case WrapSelectionCommand c:
        final start = c.selection.start;
        final len = c.selection.end - start;
        _updateSelectionInternal(c.blockId, TextSelection(
          baseOffset: start + c.prefix.length,
          extentOffset: start + c.prefix.length + len,
        ));
      case InsertTemplateCommand c when c.mode == TemplateInsertMode.insert:
        _setCollapsedCursor(c.blockId, c.selection, oldSource,
            c.template.length, c.cursorOffset);
      case InsertTemplateCommand c when c.mode == TemplateInsertMode.newBlock:
        // newBlock 模式：焦点转移到新块,光标在 offset 0
        final newId = editor.allIds.firstWhere(
          (id) => !(oldIds?.contains(id) ?? false),
          orElse: () => editor.allIds.last);
        _state = _state.focusOn(newId);
        _updateSelectionInternal(newId, const TextSelection.collapsed(offset: 0));
      case PairInsertCommand c:
        _setCollapsedCursor(c.blockId, TextSelection.collapsed(offset: c.insertOffset),
            null, c.suffixChar.length, c.cursorOffset);
      case InsertNewLineWithPrefixCommand c:
        _updateSelectionInternal(c.blockId,
            TextSelection.collapsed(offset: editor.sourceOf(c.blockId).length));
      default:
        break;
    }
  }

  /// 计算单光标位置并更新 viewState（InsertText / InsertTemplate(insert) 共用）。
  void _setCollapsedCursor(BlockId id, TextSelection? sel, String? oldSource,
      int textLen, int cursorOffset) {
    final insertOffset = sel?.baseOffset ?? (oldSource?.length ?? 0);
    _updateSelectionInternal(
        id, TextSelection.collapsed(offset: insertOffset + textLen + cursorOffset));
  }

  void _updateSelectionInternal(BlockId id, TextSelection selection) {
    final cur = _state.viewStateOf(id) ?? BlockViewState(id: id);
    _state = _state.updateViewState(id, cur.copyWith(selection: selection));
  }

  // ============ 查询接口（转发到 editor） ============

  int get blockCount => editor.blockCount;
  List<BlockId> get allIds => editor.allIds;
  DocumentElement? getBlock(BlockId id) => editor.getBlock(id);
  String sourceOf(BlockId id) => editor.sourceOf(id);

  // ============ Phase 3.3 chrome 接线 ============

  String get title => editor.title;
  int get wordCount => editor.wordCount;
  bool get isDirty => editor.isDirty;
  void markSaved() => editor.markSaved();

  // ============ Phase 3.3 PR #2B: Toolbar 便捷查询 ============

  /// 聚焦块的 [BlockType]（null = 无聚焦,§2.8 CodeBlock 禁用工具栏）。
  BlockType? get focusedBlockType {
    final id = _state.focusedId;
    if (id == null) return null;
    final element = editor.getBlock(id);
    return element == null ? null : BlockType.fromElement(element);
  }

  /// 聚焦块是否为 CodeBlock（消除 Toolbar 对 core/editing/ 的依赖）。
  bool get isFocusedOnCodeBlock => focusedBlockType == BlockType.code;
  /// 聚焦块的 selection（§2.7.1 强一致读取,Toolbar 用此值）。
  TextSelection? get focusedSelection => _state.focusedSelection;
  bool get hasSelection => _state.hasSelection;

  // ============ UI 视图状态（Hard Rule 1：AST 零污染）============

  BlockViewState? viewStateOf(BlockId id) => _state.viewStateOf(id);

  /// 更新指定块的 [BlockViewState],触发 [notifyListeners]。
  void updateViewState(BlockId id, BlockViewState state) {
    _state = _state.updateViewState(id, state);
    notifyListeners();
  }

  BlockId? get focusedId => _state.focusedId;

  /// 聚焦指定块。旧块切回渲染态,新块切到编辑态。
  void setFocus(BlockId id) {
    if (_state.focusedId == id) return;
    _state = _state.focusOn(id);
    notifyListeners();
  }

  /// 清除指定块的焦点（切回渲染态）。
  void clearFocus(BlockId id) {
    final next = _state.clearFocusOf(id);
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  // ============ Undo / Redo（Prototype 限制：currentState 空 Transaction） ============

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  Transaction? undo() {
    final tx = history.undo(_emptyCurrentState(TransactionOrigin.undo));
    if (tx == null) return null;
    for (final op in tx.ops.reversed) {
      op.revert(editor);
    }
    _syncViewStates();
    notifyListeners();
    return tx;
  }

  Transaction? redo() {
    final tx = history.redo(_emptyCurrentState(TransactionOrigin.redo));
    if (tx == null) return null;
    for (final op in tx.ops) {
      op.apply(editor);
    }
    _syncViewStates();
    notifyListeners();
    return tx;
  }

  Transaction _emptyCurrentState(TransactionOrigin o) => Transaction(
      id: TransactionId.next(), ops: const [],
      metadata: TransactionMetadata(timestamp: DateTime.now()), origin: o);

  void _syncViewStates() => _state = _state.syncViewStates(editor.allIds);

  @override
  String toString() => 'EditorCoordinator(blocks=$blockCount, focused=${_state.focusedId})';
}
