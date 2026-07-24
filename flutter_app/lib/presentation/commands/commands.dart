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
///
/// **为何单一整体再导出**：[editor_command.dart] 用 `part` 把 5 个
/// Phase 3.3 Command 子类并入同一 library（满足 sealed 约束）。本文件
/// 只做 `export 'editor_command.dart';` 整体桥接——**禁止用 `show` 逐个
/// 再导出 part 中声明的类型**（会让同一类型在 Dart 分析器下拥有
/// 「editor_command.dart 库」与「editor_command_insert.dart 库」两个身份，
/// 触发 duplicate / list_element_type_not_assignable / non_exhaustive_switch）。
library;

export 'editor_command.dart';
