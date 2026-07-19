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
  bool delete(BlockId targetId) {
    _composing?.assertBlockMutationAllowed();

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
  bool split(BlockId targetId, int offset) {
    _composing?.assertBlockMutationAllowed();

    final op = BlockOperation(
      opType: BlockOpType.split,
      targetId: targetId,
      splitOffset: offset,
      // element 占位：split.apply 实际用 toElement(leftSource/rightSource, type) 计算
      element: const ParagraphElement(children: [TextElement('')]),
    );

    if (!op.apply(_editor)) return false;
    _builder.add(op);
    return true;
  }

  /// 把 [targetId] 移动到 [refId] 之前或之后。
  ///
  /// ADR-0007 §4.1 move 原语。
  /// [before] = true 时移到 [refId] 之前，false 时移到 [refId] 之后。
  /// 失败（targetId / refId 不存在）返回 false。
  bool move(BlockId targetId, BlockId refId, {bool before = true}) {
    _composing?.assertBlockMutationAllowed();

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
