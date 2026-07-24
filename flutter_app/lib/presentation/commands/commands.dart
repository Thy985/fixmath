/// EditorCommand 子类的 re-export 桥。
///
/// 落地 Phase 3.1-A Task Contract §3.1.A.1（R6 评审反馈）。
///
/// **为什么需要本文件**：
/// Dart `sealed class` 限定所有直接子类必须位于同一 library，因此 [EditorCommand]
/// 与 8 个具体 Command 子类合并到 [editor_command.dart]。但其他文件（包括 Block
/// 组件、Prototype、tests）已经 `import '../commands/commands.dart';`，
/// 重命名为 `editor_command.dart` 会造成大规模 import 改动。
///
/// **方案**：本文件用 `export` 桥接，外部 import 不变。
///
/// **保留别名**（[UpdateBlockSourceCommand] / [SplitBlockCommand] 等），
/// 让 `import 'commands.dart'` 仍能访问所有 Command 类型。
library;

export 'editor_command.dart' show EditorCommand, CommandOrigin;

// 8 个具体 Command 子类
export 'editor_command.dart' show SplitBlockCommand;
export 'editor_command.dart' show MergeWithPreviousCommand;
export 'editor_command.dart' show InsertBlockAfterCommand;
export 'editor_command.dart' show DeleteBlockCommand;
export 'editor_command.dart' show MoveBlockUpCommand;
export 'editor_command.dart' show MoveBlockDownCommand;
export 'editor_command.dart' show UpdateBlockSourceCommand;
export 'editor_command.dart' show TransformBlockCommand;

// Phase 3.3 PR #2A 新增 3 个 Command 子类（Markdown 工具栏 + 模板菜单）
export 'editor_command.dart' show InsertTextCommand;
export 'editor_command.dart' show WrapSelectionCommand;
export 'editor_command.dart' show InsertTemplateCommand;
export 'editor_command.dart' show TemplateInsertMode;

// Phase 3.3 PR #3 新增 2 个 Command 子类（自动配对 + 自动续列表）
export 'editor_command.dart' show PairInsertCommand;
export 'editor_command.dart' show PairInsertMode;
export 'editor_command.dart' show InsertNewLineWithPrefixCommand;
