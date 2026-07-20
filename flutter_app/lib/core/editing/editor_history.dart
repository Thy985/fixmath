/// EditorHistory：包装 [HistoryManager] 提供 Transaction 级 Undo/Redo + Coalescing。
///
/// 落地 ADR-0008 §4（Coalescing 6+1 触发条件）+ §6（包装而非重写 [HistoryManager]）。
///
/// v1.2 关键约束：
/// - canCoalesce **predicate 函数化**（v1.1 评审反馈 4）：可注入，不写死
/// - 默认 _defaultCanCoalesce 7 触发条件（v1.2 从 6 升级）：
///   1. next.ops 非空
///   2. prev.origin == keyboard
///   3. prev.ops.last 是 [TextOperation]
///   4. next.origin == keyboard
///   5. next.ops.last 是 [TextOperation]
///   6. 同 [BlockId]
///   7. offset 连续（nextLastOp.offset == prevLastOp.offset + prevLastOp.inserted.length）
///   8. < [coalescingWindow]（默认 500ms）
///
/// **apply/revert 责任**：本类只负责栈管理 + coalescing。
/// 实际 apply/revert 到 [DocumentEditor] 的责任在调用方（UI 或 BlockOperations 层）。
///
/// 详见 Phase 2.6 Task Contract §3.6。
library;

import '../utils/history_manager.dart';
import 'edit_operation.dart';
import 'transaction.dart';

/// Coalescing predicate 函数类型。
///
/// 返回 true 时，[EditorHistory.push] 会把 [next] 合并到 [prev]（替换栈顶）。
typedef CoalescePredicate = bool Function(Transaction prev, Transaction next);

/// Transaction 级 Undo/Redo 历史管理器。
///
/// 包装 [HistoryManager]<Transaction>，新增 coalescing 支持。
/// 旧 [HistoryManager] API（push/undo/redo/clear/canUndo/canRedo）保留向后兼容。
///
/// v1.3（Phase 2.8）：新增 [maxHistorySize] 参数，允许调用方按需配置栈深度
/// （默认 50，与 [HistoryManager] 默认值一致）。
///
/// **Phase 3 UI 接入建议**：生产环境推荐 `maxHistorySize: 100` 至 `200`，
/// 覆盖用户单次编辑会话的典型 undo 深度。默认 50 主要为测试友好，
/// 大型文档编辑场景下 50 步可能不够（见 TC-EDIT-8.5.3 性能测试）。
class EditorHistory {
  final HistoryManager<Transaction> _history;

  /// Coalescing 时间窗口（默认 500ms）。
  ///
  /// 超过此间隔的连续 keyboard TextOperation 不合并。
  final Duration coalescingWindow;

  /// 用户注入的 coalescing predicate（可选）。
  ///
  /// 若为 null，使用 [_defaultCanCoalesce]。
  final CoalescePredicate? _userCanCoalesce;

  EditorHistory({
    this.coalescingWindow = const Duration(milliseconds: 500),
    int maxHistorySize = 50,
    CoalescePredicate? canCoalesce,
  })  : _history = HistoryManager<Transaction>(
          maxHistorySize: maxHistorySize,
        ),
        _userCanCoalesce = canCoalesce;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  int get undoCount => _history.undoCount;
  int get redoCount => _history.redoCount;

  /// 栈顶 Transaction（用于检查 coalescing，不弹出）。
  Transaction? get lastOrNull => _history.lastOrNull;

  /// Coalescing 判定（可注入，默认 [_defaultCanCoalesce]）。
  ///
  /// 调用方式：`history.canCoalesce(prev, next)` 或作为 tear-off 传递。
  bool canCoalesce(Transaction prev, Transaction next) {
    final userPredicate = _userCanCoalesce;
    if (userPredicate != null) {
      return userPredicate(prev, next);
    }
    return _defaultCanCoalesce(prev, next);
  }

  /// 推入新 [Transaction]（自动 coalescing）。
  ///
  /// 若 [canCoalesce] 返回 true，则把 [transaction] 合并到栈顶
  /// （保留栈顶 id/metadata，追加 [transaction].ops）。
  /// 否则把 [transaction] 作为新条目推入栈顶。
  void push(Transaction transaction) {
    final last = _history.lastOrNull;
    if (last != null && canCoalesce(last, transaction)) {
      final merged = _mergeTransactions(last, transaction);
      _history.replaceLast(merged);
    } else {
      _history.push(transaction);
    }
  }

  /// Undo：返回被撤销的 [Transaction]（调用方负责 revert）。
  ///
  /// [currentState]：当前 editor 状态快照（推入 redo 栈用于 redo）。
  /// 不能 undo 时返回 null。
  Transaction? undo(Transaction currentState) {
    return _history.undo(currentState);
  }

  /// Redo：返回被重做的 [Transaction]（调用方负责 apply）。
  ///
  /// [currentState]：当前 editor 状态快照（推入 undo 栈用于再次 undo）。
  /// 不能 redo 时返回 null。
  Transaction? redo(Transaction currentState) {
    return _history.redo(currentState);
  }

  /// 清空 undo / redo 栈。
  void clear() => _history.clear();

  /// 合并两个 [Transaction]（保留 [prev] 的 id/origin/label，追加 [next].ops）。
  ///
  /// 时间戳用 [next] 的（反映合并后的最新时间）。
  Transaction _mergeTransactions(Transaction prev, Transaction next) {
    final mergedOps = [...prev.ops, ...next.ops];
    return Transaction(
      id: prev.id,
      ops: mergedOps,
      metadata: TransactionMetadata(
        timestamp: next.metadata.timestamp,
        label: prev.metadata.label,
      ),
      origin: prev.origin,
    );
  }

  /// 默认 coalescing 规则（7 触发条件）。
  ///
  /// v1.2 从 6 条件升级为 7 条件：增加 next.origin == keyboard 检查，
  /// 确保 paste / ime / programmatic / undo / redo 都不参与合并。
  bool _defaultCanCoalesce(Transaction prev, Transaction next) {
    // 1. next.ops 非空
    if (next.ops.isEmpty) return false;

    // 2. prev.origin == keyboard
    if (prev.origin != TransactionOrigin.keyboard) return false;

    // 3. prev.ops 非空且 last 是 TextOperation
    if (prev.ops.isEmpty) return false;
    final prevLastOp = prev.ops.last;
    if (prevLastOp is! TextOperation) return false;

    // 4. next.origin == keyboard（v1.2 补强：仅 keyboard 可参与合并）
    if (next.origin != TransactionOrigin.keyboard) return false;

    // 5. next.ops.last 是 TextOperation
    final nextLastOp = next.ops.last;
    if (nextLastOp is! TextOperation) return false;

    // 6. 同 BlockId
    if (prevLastOp.blockId != nextLastOp.blockId) return false;

    // 7. offset 连续：nextLastOp.offset == prevLastOp.offset + prevLastOp.inserted.length
    final expectedOffset =
        prevLastOp.offset + prevLastOp.inserted.length;
    if (nextLastOp.offset != expectedOffset) return false;

    // 8. < coalescingWindow（ADR-0008 §4 封口规则 1）
    final timeDiff = next.metadata.timestamp
        .difference(prev.metadata.timestamp)
        .abs();
    if (timeDiff > coalescingWindow) return false;

    return true;
  }
}
