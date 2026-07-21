/// CommandHandler：解释 EditorCommand 为 BlockOperation 序列。
///
/// 落地 ADR-0009 §3.3（v1.1 新增）：CommandHandler 是 EditorCommand 与
/// TransactionBuilder 之间的中间层，负责意图分发 + 守卫 + Transaction 生命周期。
///
/// **职责**：
/// 1. 接收 [EditorCommand]（用户意图，纯数据）
/// 2. 守卫检查（composing 态拒绝）
/// 3. 构造 [TransactionBuilder]（含正确的 origin 映射）
/// 4. 创建 [BlockOperations] 执行 BlockOperation（eager apply 到 [DocumentEditor]）
/// 5. 成功 → commit Transaction + push 到 [EditorHistory]
/// 6. 失败 → rollback（清空已收集的 ops）
///
/// **不持有 UI 状态**：CommandHandler 是纯逻辑层，依赖 [DocumentEditor] +
/// [EditorHistory] 两个内核抽象，不依赖任何 Facade/Coordinator（避免循环依赖）。
///
/// **依赖方向**（v1.1 修订，PR 评审 R1）：
/// commands/ → core/editing/（单向依赖，不反向引用 prototype/_shared/）
library;

import '../../core/editing/block_operations.dart';
import '../../core/editing/document_editor.dart';
import '../../core/editing/editor_history.dart';
import '../../core/editing/transaction.dart';
import '../../core/editing/transaction_builder.dart';
import 'commands.dart';
import 'editor_command.dart';

/// CommandHandler：解释 [EditorCommand] 为 [BlockOperation] 序列。
///
/// 依赖 [DocumentEditor] + [EditorHistory] 两个内核抽象。
/// 由 Facade/Coordinator 持有并注入这两个依赖（避免循环引用）。
class CommandHandler {
  /// 编辑器内核（持有 Document AST + BlockId 分配）。
  final DocumentEditor editor;

  /// Undo / Redo 历史栈。
  final EditorHistory history;

  CommandHandler({required this.editor, required this.history});

  /// 处理 [command]，返回是否成功。
  ///
  /// 内部流程：
  /// 1. 守卫检查（composing 态拒绝 —— Prototype 阶段不接入 IME，跳过）
  /// 2. 构造 [TransactionBuilder]（origin = command.origin 映射）
  /// 3. 创建 [BlockOperations]（每次 handle 创建新实例，绑定新 builder）
  /// 4. 分发到对应的 _handle* 方法
  /// 5. 成功 → builder.commit()（触发 onChange → history.push）
  /// 6. 失败 → builder.rollback()
  bool handle(EditorCommand command) {
    // Prototype 阶段不接入 ComposingController，守卫跳过
    // Phase 3 正式实现时：if (composing?.isActive == true) return false;

    final builder = TransactionBuilder(
      origin: _toTransactionOrigin(command.origin),
      onChange: (tx) => history.push(tx),
    );
    final operations = BlockOperations(editor, builder);

    final success = _dispatch(command, operations, builder);
    if (success) {
      builder.commit(label: command.displayName);
    } else {
      builder.rollback();
    }
    return success;
  }

  /// 分发 [command] 到对应处理方法。
  ///
  /// **Phase 3.1-A 修订（R6）**：从 if-else 链改为 switch 表达式。
  /// 配合 [EditorCommand] 的 `sealed class` 声明，编译器强制穷举所有 8 种 Command 子类。
  /// 新增 Command 类型时，编译器立即报错提示添加 case 分支。
  ///
  /// **变量绑定**（`XCommand c`）：让 narrowed 后的具体类型直接传给 `_handleX`，
  /// 避免再写一次 `command is XCommand` 类型检查。
  bool _dispatch(
    EditorCommand command,
    BlockOperations operations,
    TransactionBuilder builder,
  ) {
    return switch (command) {
      SplitBlockCommand c => _handleSplitBlock(c, operations),
      MergeWithPreviousCommand c => _handleMerge(c, operations),
      InsertBlockAfterCommand c => _handleInsert(c, operations),
      DeleteBlockCommand c => _handleDelete(c, operations),
      MoveBlockUpCommand c => _handleMoveUp(c, operations),
      MoveBlockDownCommand c => _handleMoveDown(c, operations),
      UpdateBlockSourceCommand c => _handleUpdateSource(c, operations),
      TransformBlockCommand c => _handleTransform(c, operations),
    };
  }

  /// [CommandOrigin] → [TransactionOrigin] 映射。
  ///
  /// 仅 [keyboard] / [ime] 有特殊语义（参与 Coalescing），
  /// 其他来源统一映射为 [TransactionOrigin.programmatic]。
  TransactionOrigin _toTransactionOrigin(CommandOrigin origin) {
    return switch (origin) {
      CommandOrigin.keyboard => TransactionOrigin.keyboard,
      CommandOrigin.ime => TransactionOrigin.ime,
      CommandOrigin.ai => TransactionOrigin.programmatic,
      CommandOrigin.voice => TransactionOrigin.programmatic,
      CommandOrigin.menu => TransactionOrigin.programmatic,
      CommandOrigin.gesture => TransactionOrigin.programmatic,
    };
  }

  // ============ 各 _handle* 方法 ============

  bool _handleSplitBlock(SplitBlockCommand c, BlockOperations ops) {
    // BlockOperations.split 内部已自动 tryTransform（Phase 2.7）
    return ops.split(c.blockId, c.offset);
  }

  bool _handleMerge(MergeWithPreviousCommand c, BlockOperations ops) {
    final currentIndex = editor.indexOf(c.blockId);
    if (currentIndex <= 0) return false; // 第一块无法合并
    final prevId = editor.allIds[currentIndex - 1];
    return ops.merge(prevId, c.blockId);
  }

  bool _handleInsert(InsertBlockAfterCommand c, BlockOperations ops) {
    final newId = ops.insertAfter(c.blockId, c.element);
    return newId != null;
  }

  bool _handleDelete(DeleteBlockCommand c, BlockOperations ops) {
    return ops.delete(c.blockId);
  }

  bool _handleMoveUp(MoveBlockUpCommand c, BlockOperations ops) {
    final currentIndex = editor.indexOf(c.blockId);
    if (currentIndex <= 0) return false;
    final prevId = editor.allIds[currentIndex - 1];
    return ops.move(c.blockId, prevId, before: true);
  }

  bool _handleMoveDown(MoveBlockDownCommand c, BlockOperations ops) {
    final currentIndex = editor.indexOf(c.blockId);
    if (currentIndex + 1 >= editor.blockCount) return false;
    final nextId = editor.allIds[currentIndex + 1];
    return ops.move(c.blockId, nextId, before: false);
  }

  bool _handleUpdateSource(UpdateBlockSourceCommand c, BlockOperations ops) {
    return ops.updateSource(c.blockId, c.newSource);
  }

  bool _handleTransform(TransformBlockCommand c, BlockOperations ops) {
    return ops.tryTransform(c.blockId);
  }
}
