/// 8 个核心 EditorCommand 实现（用户意图的纯数据载体）。
///
/// 落地 ADR-0009 §3.2 + Interaction-Model.md §3.1。
/// 每个 Command 仅携带意图参数（blockId / offset / newSource 等），
/// 执行逻辑由 [CommandHandler._handle*] 方法承担。
library;

import 'package:flutter/foundation.dart';

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import 'editor_command.dart';

/// 拆分块 Command（Enter 键触发）。
///
/// 在 [blockId] 的 [offset] 处拆分为两块，左块保留原 [BlockId]，
/// 右块分配新 [BlockId]。split 后自动对新块调用 [BlockOperations.tryTransform]
/// （覆盖 Markdown 快捷映射规则，如 `# ` → heading）。
@immutable
class SplitBlockCommand implements EditorCommand {
  final BlockId blockId;
  final int offset;
  @override
  final CommandOrigin origin;

  const SplitBlockCommand({
    required this.blockId,
    required this.offset,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '拆分块';
}

/// 合并到上一块 Command（Backspace at offset 0 触发）。
///
/// 把 [blockId] 合并到前一块（前一块保留 [BlockId]，[blockId] 被删除）。
/// 若 [blockId] 是第一块，[CommandHandler._handleMerge] 返回 false。
@immutable
class MergeWithPreviousCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const MergeWithPreviousCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '合并到上一块';
}

/// 在当前块后插入新块 Command（Shift+Enter / 空行 Enter 触发）。
///
/// 在 [blockId] 之后插入 [element]（默认空段落），返回新 [BlockId]。
@immutable
class InsertBlockAfterCommand implements EditorCommand {
  final BlockId blockId;
  final DocumentElement element;
  @override
  final CommandOrigin origin;

  const InsertBlockAfterCommand({
    required this.blockId,
    DocumentElement? element,
    this.origin = CommandOrigin.keyboard,
  }) : element = element ??
            const ParagraphElement(children: [TextElement('')]);

  @override
  String get displayName => '插入新块';
}

/// 删除块 Command（空块 Backspace 触发）。
///
/// 守卫：若 [DocumentEditor.blockCount] <= 1，[CommandHandler._handleDelete] 返回 false。
@immutable
class DeleteBlockCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const DeleteBlockCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '删除块';
}

/// 上移块 Command（Alt+Up 触发）。
///
/// 把 [blockId] 移到前一块之前。若 [blockId] 是第一块，返回 false。
@immutable
class MoveBlockUpCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const MoveBlockUpCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '上移块';
}

/// 下移块 Command（Alt+Down 触发）。
///
/// 把 [blockId] 移到后一块之后。若 [blockId] 是最后一块，返回 false。
@immutable
class MoveBlockDownCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const MoveBlockDownCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '下移块';
}

/// 更新块 source Command（文本变化触发）。
///
/// **重要**：UI 文本变化必须 debounce（如 300ms），避免每次按键都产生 Transaction。
///
/// [BlockOperations.updateSource] 已封装 transform + TextOperation 逻辑。
@immutable
class UpdateBlockSourceCommand implements EditorCommand {
  final BlockId blockId;
  final String newSource;
  @override
  final CommandOrigin origin;

  const UpdateBlockSourceCommand({
    required this.blockId,
    required this.newSource,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '更新文本';
}

/// 类型转换 Command（Markdown 快捷触发）。
///
/// 检测 [blockId] 的 source 是否触发 Markdown 快捷规则（如 `# ` → heading），
/// 若触发则自动 transform 为对应 [BlockType]。
@immutable
class TransformBlockCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const TransformBlockCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '类型转换';
}
