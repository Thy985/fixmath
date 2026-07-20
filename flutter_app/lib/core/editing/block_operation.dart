/// BlockOperation：5 类块级操作的 apply/revert 实现。
///
/// 落地 ADR-0007 §4.1（五原语）+ ADR-0008 §2（apply/revert 幂等纯函数）。
///
/// v1.2 关键约束：
/// - 所有 op 用 [BlockId] 定位
/// - apply 时填充 revertContext（含 index + 完整 element snapshot）
/// - revertContext 是 immutable snapshot，因 [DocumentElement] 已 @immutable
///
/// 5 类 BlockOperation 语义详见 Phase 2.6 Task Contract §3.3 revertContext 表。
part of 'edit_operation.dart';

/// 5 类块级操作的类型标识。
enum BlockOpType {
  insert,
  delete,
  merge,
  split,
  move,
}

/// 块级操作：结构变化。
///
/// 每次 §4.1 五原语调用 = 1 个 [BlockOperation]。
/// apply 前必须先调用 [ComposingController.assertBlockMutationAllowed]
/// （由 [TransactionBuilder.add] 自动执行，ADR-0008 §5 铁律 1）。
///
/// **v1.1 评审反馈 3 修订**：所有 op 用 [BlockId] 定位（不用 index），
/// revertContext 保存完整 snapshot（含 index / 元素）确保精确恢复。
///
/// **v1.2 评审反馈补强 1**：revertContext 是 immutable snapshot，
/// 因 [DocumentElement] 已是 @immutable，天然满足。
class BlockOperation extends EditOperation {
  /// 操作类型。
  final BlockOpType opType;

  /// 操作的目标 [BlockId]（apply 前存在）。
  ///
  /// 对 insert：插入位置的参考块 id（before/after 此块插入）。
  /// 对 delete/split/move：被操作的块 id。
  /// 对 merge：被合并的右块 id（合并到左块）。
  final BlockId targetId;

  /// 辅助 [BlockId]：
  /// - insert：null（插入到开头时）
  /// - merge：左块 id（targetId 是右块）
  /// - move：移动目标参考块 id
  /// - delete/split：null
  final BlockId? auxiliaryId;

  /// 新元素（insert/split 时使用）。
  final DocumentElement? element;

  /// split 的 offset（split 时使用）。
  final int? splitOffset;

  /// move 的 before 标记（true=移到目标前，false=移到目标后）。
  final bool moveBefore;

  /// apply 时填充的 revert context（每类 op 不同）。
  ///
  /// Map 本身可变（apply 时写入），但保存的 **值**（[DocumentElement] 等）
  /// 都是 immutable snapshot：[DocumentElement] 已是 @immutable（[document.dart]），
  /// 满足 v1.2 评审反馈补强 1 的"禁止保存 live mutable reference"约束。
  ///
  /// 保存的字段详见 Phase 2.6 Task Contract §3.3 表。
  final Map<String, Object?> revertContext;

  BlockOperation({
    required this.opType,
    required this.targetId,
    this.auxiliaryId,
    this.element,
    this.splitOffset,
    this.moveBefore = true,
    Map<String, Object?>? revertContext,
  }) : revertContext = revertContext ?? <String, Object?>{};

  @override
  bool apply(DocumentEditor editor) {
    return switch (opType) {
      BlockOpType.insert => _applyInsert(editor),
      BlockOpType.delete => _applyDelete(editor),
      BlockOpType.merge => _applyMerge(editor),
      BlockOpType.split => _applySplit(editor),
      BlockOpType.move => _applyMove(editor),
    };
  }

  @override
  void revert(DocumentEditor editor) {
    switch (opType) {
      case BlockOpType.insert:
        _revertInsert(editor);
        break;
      case BlockOpType.delete:
        _revertDelete(editor);
        break;
      case BlockOpType.merge:
        _revertMerge(editor);
        break;
      case BlockOpType.split:
        _revertSplit(editor);
        break;
      case BlockOpType.move:
        _revertMove(editor);
        break;
    }
  }

  // ============ insert ============

  bool _applyInsert(DocumentEditor editor) {
    if (element == null) return false;
    final afterId = targetId;
    final afterIndex = editor.indexOf(afterId);
    if (afterIndex == -1) return false;

    final insertIndex = afterIndex + 1;
    final newId = editor.insertBlock(insertIndex, element!);
    revertContext['newId'] = newId;
    revertContext['insertIndex'] = insertIndex;
    return true;
  }

  void _revertInsert(DocumentEditor editor) {
    final newId = revertContext['newId'] as BlockId?;
    if (newId == null) return;
    editor.removeBlock(newId);
  }

  // ============ delete ============

  bool _applyDelete(DocumentEditor editor) {
    final index = editor.indexOf(targetId);
    if (index == -1) return false;

    final deletedElement = editor.removeBlock(targetId);
    revertContext['deletedElement'] = deletedElement;
    revertContext['oldIndex'] = index;
    return true;
  }

  void _revertDelete(DocumentEditor editor) {
    final deletedElement =
        revertContext['deletedElement'] as DocumentElement?;
    final oldIndex = revertContext['oldIndex'] as int?;
    if (deletedElement == null || oldIndex == null) return;
    // 保留原 BlockId（符合"BlockId 是稳定 identity"原则）
    editor.insertBlock(oldIndex, deletedElement, preserveId: targetId);
  }

  // ============ merge ============

  bool _applyMerge(DocumentEditor editor) {
    // targetId 是右块，auxiliaryId 是左块
    final leftId = auxiliaryId;
    if (leftId == null) return false;

    final rightIndex = editor.indexOf(targetId);
    if (rightIndex == -1) return false;

    final leftElement = editor.getBlock(leftId);
    final rightElement = editor.getBlock(targetId);
    if (leftElement == null || rightElement == null) return false;

    final leftSource = fromElement(leftElement);
    final rightSource = fromElement(rightElement);

    // 类型兼容性判断（ADR-0007 §4.1）
    final mergedType = _mergeType(leftElement, rightElement);

    final mergedSource = leftSource + rightSource;
    final mergedElement = toElement(mergedSource, mergedType);

    // 删除右块
    final deletedRight = editor.removeBlock(targetId);

    // 替换左块内容（保持左块 BlockId 不变）
    editor.updateBlockContent(leftId, mergedElement);

    revertContext['leftElement'] = leftElement;
    revertContext['rightElement'] = deletedRight;
    revertContext['rightOldIndex'] = rightIndex;
    revertContext['mergedType'] = mergedType;
    return true;
  }

  void _revertMerge(DocumentEditor editor) {
    final leftId = auxiliaryId;
    final leftElement =
        revertContext['leftElement'] as DocumentElement?;
    final rightElement =
        revertContext['rightElement'] as DocumentElement?;
    final rightOldIndex = revertContext['rightOldIndex'] as int?;

    if (leftId == null ||
        leftElement == null ||
        rightElement == null ||
        rightOldIndex == null) {
      return;
    }

    // 逆序：先恢复左块内容
    editor.updateBlockContent(leftId, leftElement);
    // 再插入右块（保留原 BlockId：targetId 是右块）
    editor.insertBlock(rightOldIndex, rightElement, preserveId: targetId);
  }

  BlockType _mergeType(DocumentElement left, DocumentElement right) {
    // ADR-0007 §4.1 类型兼容性：
    // - Paragraph + Paragraph → Paragraph
    // - List + List（同 ordered）→ List
    // - List + List（异 ordered）→ 回退为 Paragraph
    // - 不兼容 → 回退为 Paragraph
    final leftType = BlockType.fromElement(left);
    final rightType = BlockType.fromElement(right);

    if (leftType == BlockType.paragraph && rightType == BlockType.paragraph) {
      return BlockType.paragraph;
    }
    if (leftType == BlockType.listItem && rightType == BlockType.listItem) {
      // 检查 ordered 字段是否一致（v1.3 评审反馈 P3 修订）
      final leftList = left as ListElement;
      final rightList = right as ListElement;
      if (leftList.ordered != rightList.ordered) {
        return BlockType.paragraph;  // 异 ordered 回退
      }
      return BlockType.listItem;
    }
    return BlockType.paragraph;  // 不兼容回退
  }

  // ============ split ============

  bool _applySplit(DocumentEditor editor) {
    final offset = splitOffset;
    if (offset == null) return false;

    final targetIndex = editor.indexOf(targetId);
    if (targetIndex == -1) return false;

    final originalElement = editor.getBlock(targetId);
    if (originalElement == null) return false;

    final originalSource = fromElement(originalElement);
    if (offset < 0 || offset > originalSource.length) return false;

    final type = BlockType.fromElement(originalElement);
    final leftSource = originalSource.substring(0, offset);
    final rightSource = originalSource.substring(offset);

    final leftElement = toElement(leftSource, type);
    final rightElement = toElement(rightSource, type);

    // 替换原块为截断的左部分（保持 BlockId 不变）
    editor.updateBlockContent(targetId, leftElement);
    // 在原块后插入右部分（新 BlockId）
    final newId = editor.insertBlock(targetIndex + 1, rightElement);

    revertContext['originalElement'] = originalElement;
    revertContext['splitOffset'] = offset;
    revertContext['newId'] = newId;
    revertContext['targetIndex'] = targetIndex;
    return true;
  }

  void _revertSplit(DocumentEditor editor) {
    final newId = revertContext['newId'] as BlockId?;
    final originalElement =
        revertContext['originalElement'] as DocumentElement?;
    if (newId == null || originalElement == null) return;

    // 逆序：先删新块，再恢复原块内容
    editor.removeBlock(newId);
    editor.updateBlockContent(targetId, originalElement);
  }

  // ============ move ============

  bool _applyMove(DocumentEditor editor) {
    final targetId2 = targetId;
    final refId = auxiliaryId;
    if (refId == null) return false;

    final oldIndex = editor.indexOf(targetId2);
    if (oldIndex == -1) return false;

    final refIndex = editor.indexOf(refId);
    if (refIndex == -1) return false;

    final element2 = editor.removeBlock(targetId2);
    // removeBlock 后 refIndex 可能变化，重新查询
    final refIndexAfterRemove = editor.indexOf(refId);
    if (refIndexAfterRemove == -1) return false;

    final insertIndex =
        moveBefore ? refIndexAfterRemove : refIndexAfterRemove + 1;
    // 保留原 BlockId（move 不应改变 identity）
    final newId = editor.insertBlock(insertIndex, element2, preserveId: targetId2);

    revertContext['element'] = element2;
    revertContext['oldIndex'] = oldIndex;
    revertContext['newId'] = newId;
    revertContext['newIndex'] = insertIndex;
    return true;
  }

  void _revertMove(DocumentEditor editor) {
    final newId = revertContext['newId'] as BlockId?;
    final element2 = revertContext['element'] as DocumentElement?;
    final oldIndex = revertContext['oldIndex'] as int?;
    if (newId == null || element2 == null || oldIndex == null) return;

    // 逆序：先删新位置，再插回原位置（保留原 BlockId = targetId）
    editor.removeBlock(newId);
    editor.insertBlock(oldIndex, element2, preserveId: targetId);
  }

  @override
  String toString() =>
      'BlockOperation(opType=$opType, targetId=$targetId, auxiliaryId=$auxiliaryId)';
}
