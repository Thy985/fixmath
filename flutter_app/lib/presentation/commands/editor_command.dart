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

// ============ Phase 3.3 PR #2A 新增 3 个 Command 子类 ============
//
// 落地 Phase 3.3 PR #2A Task Contract v2.1 §4.3 + ADR-0011 §5。
//
// 设计要点（§2.4 selection 传递方案 A）：
// - Command 字段携带 [TextSelection]，由 Toolbar 构造时从
//   `coordinator.focusedSelection` 传入（强一致读取，见 §2.7.1）
// - CommandHandler 保持纯逻辑层，不反向依赖 CoordinatorState
// - selection == null 表示单光标点（无选区），用于计算插入位置

/// 在光标位置插入文本（Markdown 工具栏按钮）。
///
/// 例如点击 B 按钮无选区时插入 `****`，光标移到中间（[cursorOffset] = -2）。
///
/// **[cursorOffset] 语义**：相对插入文本末尾的偏移。
/// - 0 = 光标在插入文本末尾
/// - 负数 = 从末尾前移（如 -2 表示在 `**|**` 中间）
@immutable
final class InsertTextCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 待插入文本（含光标占位考虑，如 `**|**` 仅文档示意，实际插入 `****`）。
  final String text;

  /// 相对插入文本末尾的光标偏移（0 = 末尾，负数 = 从末尾前移）。
  final int cursorOffset;

  /// 当前选区（null = 单光标点）。
  ///
  /// 由 Toolbar 构造时从 `coordinator.focusedSelection` 传入。
  /// CommandHandler 用此计算插入位置（selection.baseOffset）。
  final TextSelection? selection;

  const InsertTextCommand({
    required this.blockId,
    required this.text,
    this.cursorOffset = 0,
    this.selection,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '插入文本');
}

/// 选区包裹（选中文字 → `**selection**`）。
///
/// 例如选中 `hello`，点击 B 按钮包裹为 `**hello**`，光标移到末尾。
@immutable
final class WrapSelectionCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 前缀（如 `**` / `` ` `` / `[`）。
  final String prefix;

  /// 后缀（如 `**` / `` ` `` / `](url)`）。
  final String suffix;

  /// 当前选区（必须非 null，包裹必须有选区）。
  final TextSelection selection;

  const WrapSelectionCommand({
    required this.blockId,
    required this.prefix,
    required this.suffix,
    required this.selection,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '包裹选区');
}

/// 模板插入模式（[InsertTemplateCommand.mode]）。
enum TemplateInsertMode {
  /// 在当前块光标位置插入模板文本。
  insert,

  /// 在当前块后插入新 Block（模板作为独立 Block）。
  newBlock,
}

/// 插入模板（表格 / Mermaid / 代码块等）。
///
/// **过渡方案（Phase 3.3 PR #2C）**：字符串 [template] + [mode]。
/// **长期方向（Phase 3.4+）**：演进为 `enum MarkdownTemplate` + domain 层
/// `TemplateRegistry` 生成结构化内容（见 [ADR-0011](../../../docs/ADR/0011-phase3.3-architecture-decisions.md)
/// §5 演进路径）。
///
/// **Hard Rule（Task Contract v2.1 §2.5.1）**：禁止业务逻辑用字符串判断模板类型
/// （如 `if (template.contains('mermaid'))`）。模板内容必须作为常量管理
/// （如 `Templates.mermaidDefault`）。
///
/// **[cursorOffset] 语义**（仅 [TemplateInsertMode.insert] 模式生效）：
/// 相对插入文本末尾的光标偏移（与 [InsertTextCommand.cursorOffset] 语义一致）。
/// - 0 = 光标在插入文本末尾（默认）
/// - 负数 = 从末尾前移（如代码块模板 `cursorOffset = -3` 将光标定位到代码区首行）
@immutable
final class InsertTemplateCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 模板文本（Markdown 格式）。
  ///
  /// 由调用方从常量（如 `Templates.tableDefault`）传入，禁止运行时字符串拼接判断。
  final String template;

  /// 插入模式（insert = 当前块光标插入；newBlock = 新建块）。
  final TemplateInsertMode mode;

  /// 当前选区（仅 [TemplateInsertMode.insert] 模式使用，null = 单光标点）。
  final TextSelection? selection;

  /// 相对插入文本末尾的光标偏移（仅 [TemplateInsertMode.insert] 模式生效）。
  ///
  /// 0 = 末尾（默认），负数 = 从末尾前移。
  /// [TemplateInsertMode.newBlock] 模式忽略此字段（光标固定在新块首）。
  final int cursorOffset;

  const InsertTemplateCommand({
    required this.blockId,
    required this.template,
    this.mode = TemplateInsertMode.insert,
    this.selection,
    this.cursorOffset = 0,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '插入模板');
}
