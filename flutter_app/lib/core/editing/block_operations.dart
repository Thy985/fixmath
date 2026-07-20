/// BlockOperations：ADR-0007 §4.1 五原语高层 API。
///
/// 落地 ADR-0007 §4.1（insert / delete / merge / split / move 五原语）+ §5（与 IME 交互）。
///
/// v1.2 关键约束：
/// - 所有原语用 [BlockId] 定位（不用 index）
/// - 每个原语前置调用 [ComposingController.assertBlockMutationAllowed]（铁律 1 守门）
/// - 构造 [BlockOperation] → apply 到 [DocumentEditor] → 加入 [TransactionBuilder]
/// - 失败返回 false / null，不抛异常（调用方决定回滚）
///
/// 详见 Phase 2.6 Task Contract §3.7。
library;

import 'block_types.dart';
import 'composing_controller.dart';
import 'document_editor.dart';
import 'edit_operation.dart';
import 'transaction_builder.dart';
import '../../data/models/document.dart';

/// ADR-0007 §4.1 五原语高层 API。
///
/// 每个 [BlockOperation] 的薄包装：
/// 1. 前置调用 [ComposingController.assertBlockMutationAllowed]（铁律 1）
/// 2. 构造 [BlockOperation]
/// 3. apply 到 [DocumentEditor]
/// 4. 若成功，把 op 加入 [TransactionBuilder]（供 undo）
/// 5. 返回结果（新 [BlockId] / bool）
///
/// **原子性责任**（v1.3 评审反馈 P0 修订）：
/// 本类采用 **eager apply** 语义——每个原语调用立即 apply 到 [DocumentEditor]，
/// 不在 [TransactionBuilder.commit] 时批量 apply。
///
/// **失败回滚由调用方负责**：若一次用户操作需要多个原语原子完成，
/// 调用方需自行捕获失败并逆序 revert 已 apply 的 op（参考
/// [transaction_rollback_atomicity_test.dart] 的 rollback helper）。
/// [TransactionBuilder.rollback] 仅清空已收集的 ops，不会自动 revert 已 apply 的 op。
///
/// 这是有意的取舍：保持 [TransactionBuilder] 职责单一（只构造 [Transaction]），
/// 避免与 [DocumentEditor] 直接耦合，便于 Phase 3 UI 层灵活组合。
class BlockOperations {
  final DocumentEditor _editor;
  final TransactionBuilder _builder;
  final ComposingController? _composing;

  BlockOperations(this._editor, this._builder, [this._composing]);

  /// 在 [targetId] 之后插入新块，返回新 [BlockId]（失败返回 null）。
  ///
  /// ADR-0007 §4.1 insert 原语。
  BlockId? insertAfter(BlockId targetId, DocumentElement element) {
    _composing?.assertBlockMutationAllowed();

    final op = BlockOperation(
      opType: BlockOpType.insert,
      targetId: targetId,
      element: element,
    );

    if (!op.apply(_editor)) return null;
    _builder.add(op);
    return op.revertContext['newId'] as BlockId?;
  }

  /// 删除 [targetId] 对应的块（失败返回 false）。
  ///
  /// ADR-0007 §4.1 delete 原语。
  ///
  /// 守卫：若 [DocumentEditor.blockCount] <= 1（即要删最后一块），返回 false。
  /// 契约 §3.7 要求 Document 至少保留 1 块。
  bool delete(BlockId targetId) {
    _composing?.assertBlockMutationAllowed();
    if (_editor.blockCount <= 1) return false;

    final op = BlockOperation(
      opType: BlockOpType.delete,
      targetId: targetId,
    );

    if (!op.apply(_editor)) return false;
    _builder.add(op);
    return true;
  }

  /// 合并 [rightId] 到 [leftId]（[leftId] 保留，[rightId] 被删）。
  ///
  /// ADR-0007 §4.1 merge 原语。
  ///
  /// 类型兼容性：
  /// - Paragraph + Paragraph → Paragraph
  /// - List + List（同 ordered）→ List
  /// - 不兼容 → 回退为 Paragraph
  bool merge(BlockId leftId, BlockId rightId) {
    _composing?.assertBlockMutationAllowed();

    final op = BlockOperation(
      opType: BlockOpType.merge,
      targetId: rightId,  // 右块
      auxiliaryId: leftId,  // 左块
    );

    if (!op.apply(_editor)) return false;
    _builder.add(op);
    return true;
  }

  /// 在 [offset] 处拆分 [targetId] 为两块。
  ///
  /// ADR-0007 §4.1 split 原语。
  /// 拆分后：[targetId] 保留前部分（offset 之前），新块包含后部分。
  /// 失败（offset 越界 / targetId 不存在）返回 false。
  ///
  /// 不传 element：split 实际用 [BlockSerializer.toElement] 计算
  /// 左/右部分的 [DocumentElement]（v1.3 评审反馈 P2 修订）。
  bool split(BlockId targetId, int offset) {
    _composing?.assertBlockMutationAllowed();

    final op = BlockOperation(
      opType: BlockOpType.split,
      targetId: targetId,
      splitOffset: offset,
    );

    if (!op.apply(_editor)) return false;
    _builder.add(op);
    return true;
  }

  /// 把 [targetId] 移动到 [refId] 之前或之后。
  ///
  /// ADR-0007 §4.1 move 原语。
  /// [before] = true 时移到 [refId] 之前，false 时移到 [refId] 之后。
  /// 失败（targetId / refId 不存在 / targetId == refId）返回 false。
  bool move(BlockId targetId, BlockId refId, {bool before = true}) {
    _composing?.assertBlockMutationAllowed();
    if (targetId == refId) return false;

    final op = BlockOperation(
      opType: BlockOpType.move,
      targetId: targetId,
      auxiliaryId: refId,
      moveBefore: before,
    );

    if (!op.apply(_editor)) return false;
    _builder.add(op);
    return true;
  }
}
