/// BlockOperation：6 类块级操作的 apply/revert 实现。
///
/// 落地 ADR-0007 §4.1（五原语）+ §4.3（transform）+ ADR-0008 §2（apply/revert 幂等纯函数）。
part of 'edit_operation.dart';

/// 6 类块级操作的类型标识。
///
/// Phase 2.7 新增 [transform]：基于 source 的 BlockType 重映射
/// （如 `# Hello` 在 paragraph 块中输入后自动变 heading）。
enum BlockOpType {
  insert,
  delete,
  merge,
  split,
  move,
  transform,
}

/// 块级操作：结构变化。
///
/// 每次 §4.1 五原语调用 = 1 个 [BlockOperation]。
/// apply 前必须先调用 [ComposingController.assertBlockMutationAllowed]
/// （由 [TransactionBuilder.add] 自动执行，ADR-0008 §5 铁律 1）。
///
/// v1.2 关键约束：所有 op 用 [BlockId] 定位；revertContext 保存 immutable snapshot
/// （含 index + 完整 element，因 [DocumentElement] 已 @immutable）。
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

  /// transform 的目标 [BlockType]（Phase 2.7 新增）。
  ///
  /// 仅 [BlockOpType.transform] 使用。apply 时通过 [BlockSerializer.toElement]
  /// 重建 element。**不变更 BlockId**（Task Contract §1.5）：通过
  /// [DocumentEditor.updateBlockContent]，revert 通过同一接口恢复 originalElement。
  final BlockType? transformedType;

  /// apply 时填充的 revert context（每类 op 不同）。
  ///
  /// Map 本身可变（apply 时写入），但保存的值都是 immutable snapshot
  /// （[DocumentElement] 已 @immutable）。保存的字段详见 Phase 2.6 Task
  /// Contract §3.3 表。键名常量（评审反馈 B）：所有 key 通过常量引用。
  final Map<String, Object?> revertContext;

  // revertContext 键名常量（评审反馈 B）：所有 key 通过常量引用，禁止裸字符串。
  // 命名约定：_k + 字段名（lowerCamelCase）。共用：kNewId（insert/split/move）、
  // _kOldIndex（delete/move）。
  static const String kNewId = 'newId';
  static const String _kInsertIndex = 'insertIndex';
  static const String _kDeletedElement = 'deletedElement';
  static const String _kOldIndex = 'oldIndex';
  static const String _kLeftElement = 'leftElement';
  static const String _kRightElement = 'rightElement';
  static const String _kRightOldIndex = 'rightOldIndex';
  static const String _kMergedType = 'mergedType';
  static const String _kOriginalElement = 'originalElement';
  static const String _kSplitOffset = 'splitOffset';
  static const String _kTargetIndex = 'targetIndex';
  static const String _kElement = 'element';
  static const String _kNewIndex = 'newIndex';

  BlockOperation({
    required this.opType,
    required this.targetId,
    this.auxiliaryId,
    this.element,
    this.splitOffset,
    this.moveBefore = true,
    this.transformedType,
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
      BlockOpType.transform => _applyTransform(editor),
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
      case BlockOpType.transform:
        _revertTransform(editor);
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
    // 幂等性（Phase 2.8 集成测试揭示的 P0 bug 修复）：
    // re-apply（redo）时复用首次分配的 newId，与 split/delete/merge/move 一致
    // （"BlockId 是稳定 identity"原则，ADR-0008 §9）。否则依赖此 insert 后续
    // BlockId 的 op（如另一个 insertAfter(newId, ...)）在 redo 时会因 newId
    // 不一致而 apply 失败。
    //
    // **Lifecycle 维护约定**：新增 [BlockOpType] 时若调用 insertBlock/replaceBlock
    // （分配新 BlockId），必须遵循此模式：apply 时从 revertContext 读 preserveId、
    // apply 后写回新 id、revert 不清除（下次 redo 复用）。违反将导致依赖该 BlockId
    // 的后续 op redo 失败（参考 TC-EDIT-8.1 "多 Transaction 中途部分 undo + 部分 redo"）。
    final preserveId = revertContext[kNewId] as BlockId?;
    final newId = editor.insertBlock(insertIndex, element!, preserveId: preserveId);
    revertContext[kNewId] = newId;
    revertContext[_kInsertIndex] = insertIndex;
    return true;
  }

  void _revertInsert(DocumentEditor editor) {
    final newId = revertContext[kNewId] as BlockId?;
    if (newId == null) return;
    editor.removeBlock(newId);
  }

  // ============ delete ============

  bool _applyDelete(DocumentEditor editor) {
    final index = editor.indexOf(targetId);
    if (index == -1) return false;

    final deletedElement = editor.removeBlock(targetId);
    revertContext[_kDeletedElement] = deletedElement;
    revertContext[_kOldIndex] = index;
    return true;
  }

  void _revertDelete(DocumentEditor editor) {
    final deletedElement =
        revertContext[_kDeletedElement] as DocumentElement?;
    final oldIndex = revertContext[_kOldIndex] as int?;
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

    revertContext[_kLeftElement] = leftElement;
    revertContext[_kRightElement] = deletedRight;
    revertContext[_kRightOldIndex] = rightIndex;
    revertContext[_kMergedType] = mergedType;
    return true;
  }

  void _revertMerge(DocumentEditor editor) {
    final leftId = auxiliaryId;
    final leftElement =
        revertContext[_kLeftElement] as DocumentElement?;
    final rightElement =
        revertContext[_kRightElement] as DocumentElement?;
    final rightOldIndex = revertContext[_kRightOldIndex] as int?;

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
    // 幂等性（v1.3 Phase 2.7）：re-apply（redo）时复用首次分配的 newId，
    // 确保 split + transform 链式 op 在 redo 时仍能定位到新块。
    final preserveId = revertContext[kNewId] as BlockId?;
    final newId = editor.insertBlock(
      targetIndex + 1,
      rightElement,
      preserveId: preserveId,
    );

    revertContext[_kOriginalElement] = originalElement;
    revertContext[_kSplitOffset] = offset;
    revertContext[kNewId] = newId;
    revertContext[_kTargetIndex] = targetIndex;
    return true;
  }

  void _revertSplit(DocumentEditor editor) {
    final newId = revertContext[kNewId] as BlockId?;
    final originalElement =
        revertContext[_kOriginalElement] as DocumentElement?;
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

    revertContext[_kElement] = element2;
    revertContext[_kOldIndex] = oldIndex;
    revertContext[kNewId] = newId;
    revertContext[_kNewIndex] = insertIndex;
    return true;
  }

  void _revertMove(DocumentEditor editor) {
    final newId = revertContext[kNewId] as BlockId?;
    final element2 = revertContext[_kElement] as DocumentElement?;
    final oldIndex = revertContext[_kOldIndex] as int?;
    if (newId == null || element2 == null || oldIndex == null) return;

    // 逆序：先删新位置，再插回原位置（保留原 BlockId = targetId）
    editor.removeBlock(newId);
    editor.insertBlock(oldIndex, element2, preserveId: targetId);
  }

  // ============ transform（Phase 2.7 新增） ============

  /// apply：source 不变，重新解析为 [transformedType] 类型。
  ///
  /// 落地 ADR-0007 §4.3（Markdown 快捷映射规则表）。
  /// 不变更 BlockId（Task Contract §1.5）：通过 [DocumentEditor.updateBlockContent]
  /// 保留原 BlockId；revert 通过同一接口恢复 [originalElement] snapshot。
  ///
  /// 失败条件（返回 false）：[transformedType] null / [targetId] 不存在 / 新旧 type 相同。
  bool _applyTransform(DocumentEditor editor) {
    final newType = transformedType;
    if (newType == null) return false;

    final originalElement = editor.getBlock(targetId);
    if (originalElement == null) return false;

    final oldType = BlockType.fromElement(originalElement);
    if (oldType == newType) return false;  // 无需 transform

    // source 不变，仅用新 type 重新解析
    final source = fromElement(originalElement);
    final newElement = toElement(source, newType);

    // 保留 BlockId，仅替换 element 内容
    editor.updateBlockContent(targetId, newElement);

    // 保存完整 originalElement snapshot，revert 时直接恢复（含所有字段）
    revertContext[_kOriginalElement] = originalElement;
    return true;
  }

  void _revertTransform(DocumentEditor editor) {
    final originalElement =
        revertContext[_kOriginalElement] as DocumentElement?;
    if (originalElement == null) return;

    // 恢复 originalElement（保留 BlockId）
    editor.updateBlockContent(targetId, originalElement);
  }

  @override
  String toString() => 'BlockOperation(opType=$opType, targetId=$targetId, auxiliaryId=$auxiliaryId)';
}
