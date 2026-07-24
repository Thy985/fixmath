/// EditorCommand sealed class + 核心子类（用户意图，纯数据）。
///
/// 落地 ADR-0009 §3.2 + Phase 3.1-A Task Contract §3.1.A.1（R6 评审反馈）。
///
/// 设计原则：
/// - **sealed class**：让 [CommandHandler._dispatch] 改用 switch 表达式时获得编译期
///   exhaustive 保证，新增 Command 类型时编译器立即报错
/// - **纯数据**：可序列化、可记录、可重放（用于 AI / 录制回放 / 协同编辑）
/// - **来源显式**：[origin] 区分意图来源（keyboard / ime / ai / voice / menu / gesture）
/// - **不感知执行**：Command 不持有 TransactionBuilder 引用，不感知执行细节
///
/// **为什么 sealed class 必须与子类同 library**：
/// Dart sealed class 限定所有直接子类必须位于同一 library。本文件定义 [EditorCommand]
/// 与 8 个核心子类；Phase 3.3 新增的 5 个 Command 子类拆到同 library 的
/// [editor_command_insert.dart] / [editor_command_pairing.dart]（用 `part` 共享 library，
/// 既满足 sealed 约束，又满足 AGENTS.md §1.2 ≤400 行约束）。外部仅通过
/// `export` 引用（见 commands.dart）。
///
/// **不破坏运行时行为**：sealed 仅在编译期生效，不影响 dispatch 性能。
library;

import 'package:flutter/widgets.dart';

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';

part 'editor_command_insert.dart';
part 'editor_command_pairing.dart';

/// Command 来源枚举。
///
/// 影响 Coalescing 决策：仅 [keyboard] / [ime] 在 Transaction 层可能合并；
/// 其他来源统一映射为 [TransactionOrigin.programmatic]。
enum CommandOrigin {
  /// 键盘输入（参与 Coalescing）。
  keyboard,

  /// IME commit（中文 / 日文输入 commit）。
  ime,

  /// AI Agent（未来扩展）。
  ai,

  /// 语音输入（未来扩展）。
  voice,

  /// 工具栏菜单点击。
  menu,

  /// 手势（tap / drag / long press）。
  gesture,
}

/// EditorCommand sealed 抽象（用户意图，纯数据）。
///
/// 所有 UI 事件必须先构造 [EditorCommand] 子类，再交由 [CommandHandler] 处理。
/// 禁止 UI 直接调用 [BlockOperations]（ADR-0009 Hard Rule 2）。
///
/// **sealed 限定**：所有直接子类必须位于本 library（含其 `part` 文件）。外部
/// import 通过 [commands.dart] 的 `export 'editor_command.dart'` 引用。
@immutable
sealed class EditorCommand {
  /// 人类可读的 Command 名称（用于 Undo / Redo 菜单显示）。
  ///
  /// 例如："拆分块" / "删除块" / "更新文本"。
  final String displayName;

  /// Command 来源（区分 keyboard / ime / ai / voice / menu / gesture）。
  ///
  /// 影响 Coalescing 决策（仅 keyboard origin 合并）+ Undo / Redo 显示。
  final CommandOrigin origin;

  const EditorCommand({
    required this.displayName,
    required this.origin,
  });
}

// ============ 8 种核心 EditorCommand 子类（sealed library 限定） ============

/// 拆分块（在 [offset] 位置把 [blockId] 拆成两块）。
@immutable
final class SplitBlockCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 拆分偏移（基于 source 字符串）。
  final int offset;

  const SplitBlockCommand({
    required this.blockId,
    required this.offset,
    super.origin = CommandOrigin.keyboard,
  }) : super(displayName: '拆分块');
}

/// 与前一块合并（[blockId] 内容追加到上一块末尾）。
@immutable
final class MergeWithPreviousCommand extends EditorCommand {
  /// 当前块 ID（将与前一块合并）。
  final BlockId blockId;

  const MergeWithPreviousCommand({
    required this.blockId,
    super.origin = CommandOrigin.keyboard,
  }) : super(displayName: '与前一块合并');
}

/// 在指定块后插入新块（默认空 paragraph）。
@immutable
final class InsertBlockAfterCommand extends EditorCommand {
  /// 锚点块 ID（新块插入到此块之后）。
  final BlockId blockId;

  /// 新块的内容。
  final DocumentElement element;

  const InsertBlockAfterCommand({
    required this.blockId,
    required this.element,
    super.origin = CommandOrigin.keyboard,
  }) : super(displayName: '插入块');
}

/// 删除指定块。
@immutable
final class DeleteBlockCommand extends EditorCommand {
  final BlockId blockId;

  const DeleteBlockCommand({
    required this.blockId,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '删除块');
}

/// 上移块（Alt+Up）。
@immutable
final class MoveBlockUpCommand extends EditorCommand {
  final BlockId blockId;

  const MoveBlockUpCommand({
    required this.blockId,
    super.origin = CommandOrigin.gesture,
  }) : super(displayName: '上移块');
}

/// 下移块（Alt+Down）。
@immutable
final class MoveBlockDownCommand extends EditorCommand {
  final BlockId blockId;

  const MoveBlockDownCommand({
    required this.blockId,
    super.origin = CommandOrigin.gesture,
  }) : super(displayName: '下移块');
}

/// 更新块内容（编辑时，最常见 command）。
@immutable
final class UpdateBlockSourceCommand extends EditorCommand {
  final BlockId blockId;

  /// 新的 source（Markdown 格式）。
  final String newSource;

  const UpdateBlockSourceCommand({
    required this.blockId,
    required this.newSource,
    super.origin = CommandOrigin.keyboard,
  }) : super(displayName: '更新文本');
}

/// 尝试 BlockType 转换（自动检测，如 `# heading` → HeadingElement）。
@immutable
final class TransformBlockCommand extends EditorCommand {
  final BlockId blockId;

  const TransformBlockCommand({
    required this.blockId,
    super.origin = CommandOrigin.keyboard,
  }) : super(displayName: '转换块类型');
}

