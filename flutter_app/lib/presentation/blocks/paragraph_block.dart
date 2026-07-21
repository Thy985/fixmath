/// ParagraphBlock：段落块（render + edit 双态）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
///
/// **双态切换**（参考 Phase 2.9 Prototype Demo 1）：
/// - [RenderMode.rendered]：渲染最终样式（[ParagraphElement.children] → [Text.rich]）
/// - [RenderMode.editing]：显示 Markdown source（[TextField] + [TextEditingController]）
///
/// **用户事件流**（Hard Rule 2：Command Layer 强制）：
/// 1. 点击块 → `coordinator.setFocus(id)` 切到 editing mode
/// 2. 编辑文本 → debounce 后 `coordinator.handle(UpdateBlockSourceCommand(...))`
/// 3. 失焦 → `coordinator.clearFocus(id)` 切回 rendered mode
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/（经 EditorCoordinator）→ core/editing/。
library;

import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';

/// 段落块（render + edit 双态）。
///
/// 接收 [state] / [element] / [coordinator] 三个参数，
/// 由 [BlockRenderer] 在 [editor_shell.dart] 中分发渲染。
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

class _ParagraphBlockState extends State<ParagraphBlock> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.coordinator.sourceOf(widget.state.id),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ParagraphBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若 coordinator 已变更（如 undo / redo），同步 controller 文本
    if (widget.state.mode != oldWidget.state.mode) {
      _textController.text = widget.coordinator.sourceOf(widget.state.id);
      if (widget.state.mode == RenderMode.editing) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.state.mode == RenderMode.editing) {
      _commitSource();
      widget.coordinator.clearFocus(widget.state.id);
    }
  }

  void _onBlockTap() {
    widget.coordinator.setFocus(widget.state.id);
  }

  void _commitSource() {
    widget.coordinator.handle(UpdateBlockSourceCommand(
      blockId: widget.state.id,
      newSource: _textController.text,
      origin: CommandOrigin.keyboard,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.mode == RenderMode.editing) {
      return _buildEditing();
    }
    return _buildRendered();
  }

  Widget _buildEditing() {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      maxLines: null,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSubmitted: (_) => _focusNode.unfocus(),
    );
  }

  Widget _buildRendered() {
    return GestureDetector(
      onTap: _onBlockTap,
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
