/// ParagraphBlock：段落块（render + edit 双态）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
/// 落地 Phase 3.1-A Task Contract §3.1.A.2（R4 评审反馈）：
/// - `_ParagraphBlockState` 改为 `extends BaseBlockState<ParagraphBlock>` 共享样板
/// - 消除约 40 行 controller / focus / commit 重复代码
///
/// **双态切换**（参考 Phase 2.9 Prototype Demo 1）：
/// - [RenderMode.rendered]：渲染最终样式（[ParagraphElement.children] → [Text.rich]）
/// - [RenderMode.editing]：显示 Markdown source（[TextField] + [TextEditingController]）
///
/// **用户事件流**（Hard Rule 2：Command Layer 强制）：
/// 1. 点击块 → `coordinator.setFocus(id)` 切到 editing mode
/// 2. 用户输入 → `TextEditingController` 记录
/// 3. 失焦 → `coordinator.handle(UpdateBlockSourceCommand(...))` 提交
/// 4. `coordinator.notifyListeners()` → `AnimatedBuilder` 重建
library;

import 'package:flutter/material.dart';

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';
import 'base_block_state.dart';

/// 段落块 Widget（Stateless，仅持有 props）。
class ParagraphBlock extends StatefulWidget {
  /// 当前块的 UI 视图状态。
  final BlockViewState state;

  /// 当前块的 AST 数据（[ParagraphElement]）。
  final ParagraphElement element;

  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const ParagraphBlock({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  State<ParagraphBlock> createState() => _ParagraphBlockState();
}

/// 段落块 State：extends [BaseBlockState] 共享 controller / focus / commit 样板。
///
/// **Phase 3.1-A R4 修订**：从独立 State 改为 `extends BaseBlockState<ParagraphBlock>`，
/// 消除约 40 行 controller / focus / commit 样板。
class _ParagraphBlockState extends BaseBlockState<ParagraphBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(ParagraphBlock oldWidget) => oldWidget.state.mode;

  @override
  Widget build(BuildContext context) {
    if (currentMode == RenderMode.editing) {
      return _buildEditing();
    }
    return _buildRendered();
  }

  @override
  Widget buildRenderContent(BuildContext context) {
    // 当前实现直接在 build() 中按 mode 分发，保留 buildRenderContent 为兼容空实现
    return const SizedBox.shrink();
  }

  Widget _buildEditing() {
    return TextField(
      controller: textController,
      focusNode: focusNode,
      maxLines: null,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSubmitted: (_) => focusNode.unfocus(),
    );
  }

  Widget _buildRendered() {
    return GestureDetector(
      onTap: onBlockTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.state.isFocused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _buildInlineSpans(widget.element.children),
      ),
    );
  }

  /// 把 [InlineElement] 列表渲染为 [Text.rich]，支持 bold / italic / code / formula。
  ///
  /// **Phase 3.0 简化实现**：仅渲染基本 inline 类型，复杂嵌套留到 Phase 3.2+。
  Widget _buildInlineSpans(List<InlineElement> children) {
    final span = _buildInlineList(children, const TextStyle(fontSize: 16));
    return Text.rich(span);
  }

  InlineSpan _buildInlineList(
      List<InlineElement> children, TextStyle baseStyle) {
    return TextSpan(
      style: baseStyle,
      children: children.map((e) => _buildInlineSpan(e, baseStyle)).toList(),
    );
  }

  InlineSpan _buildInlineSpan(InlineElement element, TextStyle baseStyle) {
    return switch (element) {
      TextElement(:final text) => TextSpan(text: text, style: baseStyle),
      BoldElement(:final children) => TextSpan(
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          children: children.map((e) => _buildInlineSpan(e, baseStyle)).toList(),
        ),
      ItalicElement(:final children) => TextSpan(
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          children: children.map((e) => _buildInlineSpan(e, baseStyle)).toList(),
        ),
      StrikethroughElement(:final children) => TextSpan(
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          children: children.map((e) => _buildInlineSpan(e, baseStyle)).toList(),
        ),
      InlineCodeElement(:final code) => TextSpan(
          text: code,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      FormulaElement(:final latex) => TextSpan(
          text: '\$$latex\$',
          style: baseStyle.copyWith(color: Colors.deepPurple),
        ),
      LinkElement(:final text, :final url) => TextSpan(
          text: text,
          style: baseStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          children: [
            TextSpan(
              text: ' ($url)',
              style: baseStyle,
            ),
          ],
        ),
      ImageElement(:final alt) => TextSpan(
          text: '[图片: $alt]',
          style: baseStyle.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
    };
  }
}
