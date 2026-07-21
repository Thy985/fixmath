/// Document 编辑器接口（model mutation boundary）。
///
/// 所有 [EditOperation.apply] / [revert] 通过此接口修改 Document 状态，
/// 不直接操作 AST，不触发任何通知（纯数据修改）。
///
/// Notification 责任在 [TransactionBuilder.commit] 一层，
/// 避免 N 个 op 触发 N 次 UI rebuild。
///
/// Phase 3 UI 层实现具体类，包装 Document + AST。
/// Phase 2.6 单测用 mock 实现（见 test/editing/document_editor_test.dart）。
///
/// 详见 Phase 2.6 Task Contract §3.1（v1.1 评审反馈 2 修订）+ ADR-0008 §2。
library;

import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/core/editing/block_types.dart';

/// Document 编辑器抽象接口。
///
/// v1.2 关键约束：
/// - 所有方法仅修改数据，不触发任何 listener / onChange / notify
/// - notification 责任在 [TransactionBuilder.commit] 一层（1 commit = 1 notification）
/// - 所有 op 用 [BlockId] 定位（不用 index，因 index 在 insert/delete 后失效）
///
/// v1.3 修订（Phase 2.9 PR 评审 R1）：新增 [allIds] getter，支持 CommandHandler
/// 通过 [DocumentEditor] 接口查询相邻 BlockId（之前依赖 InMemoryDocumentEditor 的
/// 辅助方法，导致循环依赖）。
///
/// 注：不加 `@immutable`，因实现类（如 mock / Phase 3 UI 实现类）必然持有可变状态。
/// DocumentElement 本身保持 immutable（[document.dart:30](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart)）。
abstract class DocumentEditor {
  /// 当前块数。
  int get blockCount;

  /// 所有 [BlockId]（按文档顺序）。
  ///
  /// v1.3 新增。用于 CommandHandler 查询相邻 BlockId（如 merge prev / move up/down）。
  /// 实现类应返回不可变列表（避免外部修改内部状态）。
  List<BlockId> get allIds;

  /// 按 [BlockId] 查找块。
  ///
  /// [BlockId] 是稳定 identity（[block_types.dart:23](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart)），
  /// 不随 insert/delete 变化。
  ///
  /// 找不到时返回 null（调用方决定是否抛异常）。
  DocumentElement? getBlock(BlockId id);

  /// 按 [BlockId] 查找 index（用于 revert 时恢复位置）。
  ///
  /// 找不到时返回 -1（revert 失败时调用方决定如何处理）。
  int indexOf(BlockId id);

  /// 在 [index] 处插入 [element]，分配新 [BlockId]。
  ///
  /// index 越界时抛 [RangeError]。
  ///
  /// 返回新分配的 [BlockId]（用于 [BlockOperation] revert context）。
  ///
  /// 可选 [preserveId]：若指定，则用此 [BlockId] 插入（不重新分配）。
  /// 用于 [BlockOperation] 的 revert：恢复被 delete/move 的块时保持原 [BlockId] 不变
  /// （符合"BlockId 是稳定 identity"原则，[block_types.dart:23](file:///d:/Projects/Active/math/flutter_app/lib/core/editing/block_types.dart)）。
  /// 调用方需保证 [preserveId] 当前不存在于 editor 中（否则由实现决定行为）。
  BlockId insertBlock(int index, DocumentElement element, {BlockId? preserveId});

  /// 移除 [id] 对应的块，返回被移除的元素（用于 revert）。
  ///
  /// 找不到时抛 [StateError]。
  DocumentElement removeBlock(BlockId id);

  /// 替换 [id] 对应的块为 [element]，返回旧元素（用于 revert）。
  ///
  /// **Phase 3.1-A PR #2（R5）行为变更**：
  /// 此方法默认**保持 [BlockId] 不变**（不再默默分配新 BlockId）。
  /// 调用方持有旧 [BlockId] 的引用（如 BlockViewState、focus 状态、
  /// UI 控制器）依然有效。
  ///
  /// 若需分配新 [BlockId]（如 BlockType 转换场景），使用
  /// [replaceBlockWithMigration] 显式选择并接受迁移回调。
  ///
  /// 找不到时抛 [StateError]。
  DocumentElement replaceBlock(BlockId id, DocumentElement element);

  /// 显式保持 [BlockId] 不变的替换（[replaceBlock] 的显式版本）。
  ///
  /// 行为等同于 [replaceBlock]（Phase 3.1-A PR #2 起）+ [updateBlockContent]，
  /// 但语义更清晰：调用方主动声明"保持 BlockId"。
  ///
  /// 用于代码可读性高的场景（如 Block source 同步更新）。
  ///
  /// 找不到时抛 [StateError]。
  DocumentElement replaceBlockKeepId(BlockId id, DocumentElement element);

  /// 替换 [id] 对应的块为 [element]，分配新 [BlockId]，并通过 [onMigrated]
  /// 回调通知调用方迁移信息。
  ///
  /// **使用场景**：BlockType 转换（如 Paragraph → Heading）需要重建 element
  /// 但保留 source；调用方在 [onMigrated] 中更新 BlockViewState / focus / UI
  /// 控制器的 BlockId 引用。
  ///
  /// [onMigrated] 回调签名：`(BlockId oldId, BlockId newId) -> void`。
  /// 若 [onMigrated] 为 null，行为等同旧版 `replaceBlock`（分配新 BlockId 但不通知），
  /// 仅用于向后兼容（不推荐）。
  ///
  /// 返回旧 [DocumentElement]（用于 revert）。
  ///
  /// 找不到时抛 [StateError]。
  DocumentElement replaceBlockWithMigration(
    BlockId id,
    DocumentElement element, {
    void Function(BlockId oldId, BlockId newId)? onMigrated,
  });

  /// 仅替换 [id] 对应块的内容（保持 [BlockId] 不变）。
  ///
  /// 用于 [TextOperation.apply]：BlockId 不变，仅 source 变化。
  ///
  /// 找不到时抛 [StateError]。
  void updateBlockContent(BlockId id, DocumentElement newContent);
}
