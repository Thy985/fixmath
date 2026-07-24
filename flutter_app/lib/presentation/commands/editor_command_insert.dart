/// Phase 3.3 PR #2A 新增 3 个 Command 子类（Markdown 工具栏 + 模板菜单）。
///
/// 落地 Phase 3.3 PR #2A Task Contract v2.1 §4.3 + ADR-0011 §5。
///
/// **设计要点（§2.4 selection 传递方案 A）**：
/// - Command 字段携带 [TextSelection]，由 Toolbar 构造时从
///   `coordinator.focusedSelection` 传入（强一致读取，见 §2.7.1）
/// - CommandHandler 保持纯逻辑层，不反向依赖 CoordinatorState
/// - selection == null 表示单光标点（无选区），用于计算插入位置
///
/// 本文件是 [editor_command.dart] 的 `part`（同 library），以复用 [EditorCommand]
/// sealed 约束与 [CommandOrigin] 定义，同时满足 AGENTS.md §1.2 ≤400 行。
part of 'editor_command.dart';

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
