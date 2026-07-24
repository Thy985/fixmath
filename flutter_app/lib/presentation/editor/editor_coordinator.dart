/// EditorCoordinator：UI 层对编辑内核的协调器（Phase 3.0 production 路径）。
///
/// 落地 ADR-0009 §3.5 + Phase 3.0 Task Contract §3.4 + §2.4（避免 God Object）。
/// 落地 Phase 3.1-A Task Contract §3.1.A.3（弱化版 R1 评审反馈）：
/// viewStates + focusedId 合并为不可变 [CoordinatorState] `_state` 单字段,
/// 每次修改产生新副本,消除多步修改的中间不一致状态。
///
/// **职责**（只协调，不持有业务状态）：持有 editor / history / handler,
/// 管理 [CoordinatorState],提供 [handle] / [undo] / [redo]。
///
/// **变更通知**：继承 [ChangeNotifier],状态变化时调用 [notifyListeners]。
/// **Hard Rule 1（AST 零污染）**：UI 状态通过 [CoordinatorState] 单独建模。
/// **Hard Rule 4（避免 God Object）**：不持有 Theme / File / Route 等领域状态。
/// **Hard Rule 8（依赖方向）**：editor/ → core/editing/（单向依赖）。
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

/// UI 层对编辑内核的协调器（Phase 3.0 production 路径）。
///
/// Widget 通过 [EditorScope] 获取 Coordinator 实例,调用：
/// - `coordinator.handle(command)` — 处理用户事件
/// - `coordinator.viewStateOf(id)` — 查询 UI 状态
/// - `coordinator.setFocus(id)` / `clearFocus(id)` — 管理焦点
/// - `coordinator.undo()` / `redo()` — 撤销 / 重做
class EditorCoordinator extends ChangeNotifier {
  final InMemoryDocumentEditor editor;
  final EditorHistory history;
  late final CommandHandler handler;

  /// UI 状态聚合（不可变,Phase 3.1-A R1 弱化版）。
  CoordinatorState _state;

  EditorCoordinator({
    required this.editor,
    required this.history,
  }) : _state = const CoordinatorState.empty() {
    handler = CommandHandler(editor: editor, history: history);
    final initial = <BlockId, BlockViewState>{};
    for (final id in editor.allIds) {
      initial[id] = BlockViewState(id: id);
    }
    _state = CoordinatorState.initial(initial);
  }

  // ============ Command 入口 ============

  /// 处理 [EditorCommand],成功时触发 [notifyListeners] 重建 UI。
  ///
  /// **Dirty tracking（ADR-0011 §4）**：handle 成功后 dirty 由 editor 的
  /// mutating 方法自动标记。undo/redo 不直接修改 dirty 标记。
  bool handle(EditorCommand command) {
    final ok = handler.handle(command);
    if (ok) notifyListeners();
    return ok;
  }

  // ============ 查询接口（转发到 editor） ============

  int get blockCount => editor.blockCount;
  List<BlockId> get allIds => editor.allIds;
  DocumentElement? getBlock(BlockId id) => editor.getBlock(id);
  String sourceOf(BlockId id) => editor.sourceOf(id);

  // ============ Phase 3.3 chrome 接线（§3.3.1 + §3.3.4） ============

  /// 文档标题（Phase 3.3：透传 editor.title,用于 EditorAppBar）。
  String get title => editor.title;

  /// 实时字数统计（Phase 3.3：透传 editor.wordCount,用于 EditorStatusBar）。
  int get wordCount => editor.wordCount;

  /// 是否有未保存修改（ADR-0011 §4：Dirty 归属 Document State）。
  /// handle() 成功后自动 true,markSaved() 后 false。
  bool get isDirty => editor.isDirty;

  /// 标记文档已保存（重置 isDirty）。Phase 3.4+ 接入持久化时调用。
  void markSaved() => editor.markSaved();

  // ============ Phase 3.3 PR #2B: Toolbar 便捷查询 ============

  /// 当前聚焦块的 [BlockType]（null = 无聚焦块）。
  /// 用于 MarkdownToolbar 判断 CodeBlock（§2.8 禁用工具栏）。
  BlockType? get focusedBlockType {
    final id = _state.focusedId;
    if (id == null) return null;
    final element = editor.getBlock(id);
    if (element == null) return null;
    return BlockType.fromElement(element);
  }

  /// 当前聚焦块的 [TextSelection]（§2.7.1 强一致读取,Toolbar 用此值）。
  TextSelection? get focusedSelection => _state.focusedSelection;

  /// 当前聚焦块是否有非空选区。
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

  // ============ Undo / Redo ============

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  /// Undo 一步。返回被撤销的 Transaction,失败返回 null。
  ///
  /// **Prototype 限制**（R2）：currentState 使用空 Transaction,
  /// redo → undo 链在第 2 步会丢失状态记录。Phase 3.0+ 需 state snapshot。
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

  /// Redo 一步。返回被重做的 Transaction,失败返回 null。
  /// **Prototype 限制**：与 [undo] 相同。
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

  /// 构造空 Transaction 作为 undo/redo 的 currentState（Prototype 限制）。
  Transaction _emptyCurrentState(TransactionOrigin origin) => Transaction(
        id: TransactionId.next(),
        ops: const [],
        metadata: TransactionMetadata(timestamp: DateTime.now()),
        origin: origin,
      );

  /// 同步 viewStates：移除已不在 editor 的 BlockId,补全新增的 BlockId。
  void _syncViewStates() {
    _state = _state.syncViewStates(editor.allIds);
  }

  @override
  String toString() => 'EditorCoordinator(blockCount=$blockCount, '
      'focused=${_state.focusedId}, canUndo=$canUndo, canRedo=$canRedo)';
}
