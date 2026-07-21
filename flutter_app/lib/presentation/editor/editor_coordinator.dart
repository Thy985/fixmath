/// EditorCoordinator：UI 层对编辑内核的协调器（Phase 3.0 production 路径）。
///
/// 落地 ADR-0009 §3.5 + Phase 3.0 Task Contract §3.4 + §2.4（避免 God Object）。
///
/// **职责**（只协调，不持有业务状态）：
/// - 持有 [InMemoryDocumentEditor] + [EditorHistory] + [CommandHandler]
/// - 管理 `Map<BlockId, BlockViewState>`（UI 视图状态，与 AST 解耦）
/// - 管理块间焦点切换（`_focusedId`）
/// - 提供 [handle] 封装 [CommandHandler.handle] + [notifyListeners]
/// - 提供 [undo] / [redo] 方法（封装 Transaction revert/apply）
///
/// **变更通知**：继承 [ChangeNotifier]，状态变化时调用 [notifyListeners]，
/// 让 [EditorShell] 等订阅者重建。
///
/// **Hard Rule 1（AST 零污染）**：UI 状态通过 [BlockViewState] 单独建模，
/// 不在 [DocumentElement] 新增字段。
/// **Hard Rule 4（避免 God Object）**：不持有 Theme / File / Route 等领域状态。
/// **Hard Rule 8（依赖方向）**：editor/ → core/editing/（单向依赖）。
///
/// **Phase 2.9 → Phase 3.0 迁移**：从
/// `lib/presentation/prototype/_shared/block_editor_facade.dart` 迁移并重命名。
library;

import 'package:flutter/foundation.dart';

import '../../core/editing/block_types.dart';
import '../../core/editing/editor_history.dart';
import '../../core/editing/transaction.dart';
import '../../data/models/document.dart';
import '../commands/command_handler.dart';
import '../commands/editor_command.dart';
import '../states/block_view_state.dart';
import 'in_memory_document_editor.dart';

/// UI 层对编辑内核的协调器（Phase 3.0 production 路径）。
///
/// Widget 通过 [EditorScope] 获取 Coordinator 实例，调用：
/// - `coordinator.handle(command)` — 处理用户事件
/// - `coordinator.viewStateOf(id)` — 查询 UI 状态
/// - `coordinator.setFocus(id)` / `clearFocus(id)` — 管理焦点
/// - `coordinator.undo()` / `redo()` — 撤销 / 重做
class EditorCoordinator extends ChangeNotifier {
  final InMemoryDocumentEditor editor;
  final EditorHistory history;
  late final CommandHandler handler;

  /// UI 视图状态（按 [BlockId] 索引，Hard Rule 1：AST 零污染）。
  final Map<BlockId, BlockViewState> _viewStates = {};

  /// 当前聚焦的块（null = 无聚焦）。
  BlockId? _focusedId;

  EditorCoordinator({
    required this.editor,
    required this.history,
  }) {
    handler = CommandHandler(editor: editor, history: history);
    for (final id in editor.allIds) {
      _viewStates[id] = BlockViewState(id: id);
    }
  }

  // ============ Command 入口 ============

  /// 处理 [EditorCommand]，成功时触发 [notifyListeners] 重建 UI。
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

  // ============ UI 视图状态（Hard Rule 1：AST 零污染） ============

  BlockViewState? viewStateOf(BlockId id) => _viewStates[id];

  /// 更新指定块的 [BlockViewState]（调用方用 `state.copyWith(...)` 构造新状态）。
  void updateViewState(BlockId id, BlockViewState state) {
    _viewStates[id] = state;
  }

  BlockId? get focusedId => _focusedId;

  /// 聚焦指定块。旧块切回渲染态，新块切到编辑态，触发 [notifyListeners]。
  void setFocus(BlockId id) {
    if (_focusedId == id) return;
    if (_focusedId != null) {
      final oldState = _viewStates[_focusedId!];
      if (oldState != null) {
        _viewStates[_focusedId!] =
            oldState.copyWith(isFocused: false, mode: RenderMode.rendered);
      }
    }
    final curState = _viewStates[id];
    if (curState != null) {
      _viewStates[id] =
          curState.copyWith(isFocused: true, mode: RenderMode.editing);
    }
    _focusedId = id;
    notifyListeners();
  }

  /// 清除指定块的焦点（切回渲染态），触发 [notifyListeners]。
  void clearFocus(BlockId id) {
    final state = _viewStates[id];
    if (state == null) return;
    _viewStates[id] =
        state.copyWith(isFocused: false, mode: RenderMode.rendered);
    if (_focusedId == id) _focusedId = null;
    notifyListeners();
  }

  // ============ Undo / Redo ============

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  /// Undo 一步。返回被撤销的 Transaction，失败返回 null。
  ///
  /// **Prototype 限制**（PR 评审 R2）：`currentState` 使用空 Transaction，
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

  /// Redo 一步。返回被重做的 Transaction，失败返回 null。
  ///
  /// **Prototype 限制**：与 [undo] 相同，`currentState` 使用空 Transaction。
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

  /// 同步 _viewStates：移除已不在 editor 的 BlockId，补全新增的 BlockId。
  void _syncViewStates() {
    final currentIds = {...editor.allIds};
    _viewStates.removeWhere((id, _) => !currentIds.contains(id));
    for (final id in editor.allIds) {
      _viewStates.putIfAbsent(id, () => BlockViewState(id: id));
    }
    if (_focusedId != null && !currentIds.contains(_focusedId)) {
      _focusedId = null;
    }
  }

  @override
  String toString() => 'EditorCoordinator(blockCount=$blockCount, '
      'focused=$_focusedId, canUndo=$canUndo, canRedo=$canRedo)';
}
