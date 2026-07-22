/// QuoteBlock：引用块（render + edit 双态）。
///
/// 落地 Phase 3.2 Task Contract §3.4（任务 3.2.3）+ ADR-0009 §3.3。
///
/// **双态切换**：
/// - [RenderMode.rendered]：左侧 3dp `#C0C0C0` 竖线 + serif 正文
/// - [RenderMode.editing]：由基类 `buildEditField` 提供 [TextField]
///
/// **视觉规范**（[ui-spec.md §2.3](../../design/ui-spec.md)）：
/// - 左侧 3dp `#C0C0C0` 竖线（Typora 化原则）
/// - serif 正文（与 ParagraphBlock 的 sans-serif 区分）
/// - 无卡片背景（与 CodeBlock 的 grey.shade100 区分）
///
/// **AST 类型**：[BlockquoteElement]（已存在于 document.dart）
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/ → core/editing/。
library;

import 'package:flutter/material.dart';

import '../../../core/editing/block_types.dart';
import '../../../data/models/document.dart';
import '../../editor/editor_coordinator.dart';
import '../../states/block_view_state.dart';
import '../../themes/editor_tokens.dart';
import '../base_block_state.dart';

/// 引用块 Widget（Stateless，仅持有 props）。
class QuoteBlock extends StatefulWidget {
  /// 当前块的 UI 视图状态。
  final BlockViewState state;

  /// 当前块的 AST 数据（[BlockquoteElement]）。
  final BlockquoteElement element;

  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const QuoteBlock({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  State<QuoteBlock> createState() => _QuoteBlockState();
}

/// 引用块 State：extends [BaseBlockState] 共享 controller / focus / commit 样板。
///
/// **Phase 3.2 §3.0 方案 A**：仅保留 buildRenderContent + edit 态配置,
/// 不重写 build()（基类统一调度）。
class _QuoteBlockState extends BaseBlockState<QuoteBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(QuoteBlock oldWidget) => oldWidget.state.mode;

  /// edit 态多行（引用块可能含多行文本）。
  @override
  int? get editFieldMaxLines => null;

  /// edit 态 serif 字体（与 render 态视觉一致）。
  @override
  TextStyle? get editFieldStyle => const TextStyle(
        fontFamily: 'serif',
        fontSize: EditorTokens.paragraphFontSize,
      );

  @override
  Widget buildRenderContent(BuildContext context) {
    return GestureDetector(
      onTap: onBlockTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: EditorTokens.quoteBorderColor,
              width: 3,
            ),
          ),
        ),
        child: Text(
          widget.element.text,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: EditorTokens.paragraphFontSize,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
