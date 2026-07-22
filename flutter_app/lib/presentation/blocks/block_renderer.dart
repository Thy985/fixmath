/// BlockRenderer：Block 渲染分发器（Phase 3.0 production 路径）。
///
/// 落地 Phase 3.0 Task Contract §3.3 + ADR-0009 §3.3（BlockRenderer 抽象）。
///
/// **核心原则（Hard Rule 3 + Hard Rule 8）**：
/// - **exhaustive switch**：3 种 BlockType（paragraph / heading / code）显式 case 分支
/// - **不允许 `_ =>` fallback**：其他 6 种类型显式抛 [UnimplementedError]
/// - **新增 Block 类型必须显式增加 case 分支**（避免默默退化显示）
/// - **依赖方向**：blocks/ → editor/ → core/editing/（单向依赖）
///
/// **为什么不允许 GenericBlock fallback**（Phase 3.0 Task Contract §3.3）：
/// 若有 fallback，新增 Block 类型时不会立刻暴露未实现，可能默默退化显示。
/// 显式抛错让 Phase 3.2+ 实现新类型时立即被测试发现。
///
/// **Phase 3.2 支持类型**（PR #3 后）：
/// - [ParagraphElement] → [ParagraphBlock]
/// - [HeadingElement] → [HeadingBlock]
/// - [CodeElement] → [CodeBlock]
/// - [BlockquoteElement] → [QuoteBlock]（Phase 3.2 §3.4 任务 3.2.3,PR #2）
/// - [TableElement] → [TableBlock]（Phase 3.2 §3.5 任务 3.2.4,PR #2）
/// - [MermaidElement] → [MermaidBlock]（Phase 3.2 §3.3 任务 3.2.2,PR #3）
///
/// **Phase 3.2+ 待实现类型**（PR #3 后）：listItem / taskListItem /
/// horizontalRule / math（块级公式 WebView 渲染留 Phase 3.5+）。
///
/// **行内元素不在 BlockRenderer 范围**（[ImageElement] / [LinkElement]）：
/// 由 [ParagraphBlock] 的 inline renderer 渲染,不进入此 switch。
/// 详见 Phase 3.2 Task Contract §3.6 / §3.7（v1.2 修订）。
library;

import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';
import 'code/code_block.dart';
import 'heading/heading_block.dart';
import 'mermaid/mermaid_block.dart';
import 'paragraph/paragraph_block.dart';
import 'quote/quote_block.dart';
import 'table/table_block.dart';

/// Block 渲染分发器（StatelessWidget）。
///
/// 根据 [element] 的具体子类型，分发到对应的 Block 组件。
/// 每个组件接收 [state]（UI 视图状态）+ [element]（AST 数据）+ [coordinator]（协调器）。
class BlockRenderer extends StatelessWidget {
  /// 当前块的 UI 视图状态（focus / mode / selection / composing）。
  final BlockViewState state;

  /// 当前块的 AST 数据。
  final DocumentElement element;

  /// 当前页面绑定的 [EditorCoordinator]（用于提交 Command）。
  final EditorCoordinator coordinator;

  const BlockRenderer({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    // Phase 3.2 PR #3：exhaustive switch 支持 6 种类型（+ Mermaid）
    // 新增 Block 类型必须显式增加 case 分支（不允许 _ fallback）
    // 使用变量绑定（pe / he / ce / be / te / me）确保类型 narrowing 后传给 Block 组件
    return switch (element) {
      ParagraphElement pe => ParagraphBlock(
          state: state,
          element: pe,
          coordinator: coordinator,
        ),
      HeadingElement he => HeadingBlock(
          state: state,
          element: he,
          coordinator: coordinator,
        ),
      CodeElement ce => CodeBlock(
          state: state,
          element: ce,
          coordinator: coordinator,
        ),
      BlockquoteElement be => QuoteBlock(
          state: state,
          element: be,
          coordinator: coordinator,
        ),
      TableElement te => TableBlock(
          state: state,
          element: te,
          coordinator: coordinator,
        ),
      MermaidElement me => MermaidBlock(
          state: state,
          element: me,
          coordinator: coordinator,
        ),
      // Phase 3.2 PR #3 后：其他 4 种类型显式抛 UnimplementedError
      // 让 Phase 3.5+ 实现新类型时立即发现（而不是默默 fallback）
      // MathBlock（块级公式 WebView 渲染）留 Phase 3.5+（依赖 FormulaSvgService）
      ListElement() ||
      TaskListItemElement() ||
      HorizontalRuleElement() =>
        throw UnimplementedError(
          'BlockType ${element.runtimeType} not supported in Phase 3.2 PR #3',
        ),
      // EmptyLineElement 不在 BlockEditor 范围（不应到达此处）
      EmptyLineElement() => throw ArgumentError(
          'EmptyLineElement is not an editable BlockType',
        ),
    };
  }
}
