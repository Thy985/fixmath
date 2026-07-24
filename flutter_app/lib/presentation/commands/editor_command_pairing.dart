/// Phase 3.3 PR #3 新增 2 个 Command 子类（自动配对 + 自动续列表）。
///
/// 落地 Phase 3.3 PR #3 Task Contract v1.1 §3.1 + §3.2 + ADR-0011 §5。
///
/// **设计要点（v1.1 Human Owner 审批）**：
/// - Command = 意图（在哪里做什么），不携带 State（如 currentSource）
/// - PairInsertCommand 通过 insertOffset 明确描述插入位置，不通过 selection 推断
/// - CommandOrigin.ime：自动配对 / 续列表是 IME 输入的"副作用"
/// - 不实现 Coalescing：两个独立 undo 步骤（Phase 3.4 技术债）
///
/// 本文件是 [editor_command.dart] 的 `part`（同 library），以复用 [EditorCommand]
/// sealed 约束与 [CommandOrigin] 定义，同时满足 AGENTS.md §1.2 ≤400 行。
part of 'editor_command.dart';

/// 自动配对模式（[PairInsertCommand.mode]）。
enum PairInsertMode {
  /// 光标后追加配对符右半部分（无选区时）。
  ///
  /// 用户输入 '(' 后，Command 只追加 ')'，不修改 '('。
  appendAfterCursor,

  /// 选区包裹为 prefix + selection + suffix（有选区时）。
  ///
  /// 选区末尾追加 suffixChar（insertOffset = selection.end）。
  wrapSelection,
}

/// 自动配对 Command：追加配对符右半部分或包裹选区。
///
/// **关键约束**（Task Contract §9.2 R4）：不修改原始用户输入，只追加配对符
/// 右半部分。原始输入（如 '('）由 IME 直接提交到 controller，本 Command 只
/// 追加 ')'。
///
/// **v1.1 修订**：新增 [insertOffset] 字段，不通过 selection 推断 cursor。
/// Command 是历史记录对象，必须描述"我要在哪里做什么"，而不是"当前状态
/// 是什么"。
///
/// **CommandOrigin**：[CommandOrigin.ime]（Task Contract §2.2 决策）
@immutable
final class PairInsertCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 配对符右半部分（如 ')' / ']' / '}' / '`'）。
  ///
  /// **v1.1 修订**：移除 `prefixChar` 字段。appendAfterCursor 模式只追加
  /// suffixChar（prefixChar 已由 IME 提交，Command 不需要知道）；
  /// wrapSelection 模式同样只追加 suffixChar 到选区末尾。
  final String suffixChar;

  /// 插入位置（绝对 offset，基于 source）。
  ///
  /// **v1.1 新增**：
  /// - appendAfterCursor 模式 = 光标位置（'(' 之后）
  /// - wrapSelection 模式 = 选区末尾（selection.end）
  final int insertOffset;

  /// 配对模式。
  final PairInsertMode mode;

  /// 相对插入文本末尾的光标偏移（0 = 末尾，负数 = 从末尾前移）。
  ///
  /// - appendAfterCursor 模式：光标在 suffixChar 之前
  ///   （offset = -suffixChar.length，如 ')' → -1，光标在 '()' 中间）
  /// - wrapSelection 模式：光标在 suffixChar 之后（offset = 0）
  final int cursorOffset;

  const PairInsertCommand({
    required this.blockId,
    required this.suffixChar,
    required this.insertOffset,
    this.mode = PairInsertMode.appendAfterCursor,
    this.cursorOffset = 0,
    super.origin = CommandOrigin.ime,
  }) : super(displayName: '自动配对');
}

/// 自动续列表 Command：插入换行 + 续行前缀。
///
/// **触发条件**：用户按回车（onChanged 检测到 '\n'），且当前行有列表 / 引用
/// 前缀。
///
/// **续行规则**（Task Contract §3.8）：
/// - `- item` → `- `（无序列表）
/// - `* item` → `* `（无序列表）
/// - `1. item` → `2. `（有序列表，编号 +1）
/// - `> quote` → `> `（引用）
/// - `- [ ] task` → `- [ ] `（任务列表）
///
/// **退出规则**：当前行为空模式（如 `- ` 后无内容），回车清除前缀。
///
/// **v1.1 修订**：删除 `currentSource` 字段。Command = 意图，Handler = 执行。
/// Handler 通过 `editor.getBlock(c.blockId)` 读取当前 source。
///
/// **CommandOrigin**：[CommandOrigin.ime]（Task Contract §2.2 决策）
@immutable
final class InsertNewLineWithPrefixCommand extends EditorCommand {
  /// 目标块 ID。
  final BlockId blockId;

  /// 续行前缀（如 '- ' / '1. ' / '> '）。
  final String prefix;

  /// 是否为退出续行（清除空行前缀）。
  final bool isExit;

  const InsertNewLineWithPrefixCommand({
    required this.blockId,
    required this.prefix,
    this.isExit = false,
    super.origin = CommandOrigin.ime,
  }) : super(displayName: '自动续列表');
}
