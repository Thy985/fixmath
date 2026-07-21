/// CodeBlock：代码块（render + edit 双态，显示 language 标签 + monospace）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
///
/// **双态切换**：
/// - [RenderMode.rendered]：显示代码 + 顶部 language 标签（灰色 chip）
/// - [RenderMode.editing]：显示 Markdown source（含 ```lang ... ``` 围栏）
///
/// **Phase 3.0 限制**：
/// - 不实现语法高亮（Phase 3.2+ 引入 flutter_highlight 或类似库）
/// - 不实现代码折叠 / 行号（Phase 3.5+）
/// - 仅显示纯文本（monospace + 浅灰背景）
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/ → core/editing/。
library;

import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';

/// 代码块（render + edit 双态，显示 language 标签 + monospace）。
class CodeBlock extends StatefulWidget {
  /// 当前块的 UI 视图状态。
  final BlockViewState state;

  /// 当前块的 AST 数据（[CodeElement]）。
  final CodeElement element;

  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const CodeBlock({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
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
  void didUpdateWidget(covariant CodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      textInputAction: TextInputAction.newline,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSubmitted: (_) => _focusNode.unfocus(),
    );
  }

  Widget _buildRendered() {
    final language = widget.element.language;
    return GestureDetector(
      onTap: _onBlockTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.state.isFocused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (language != null && language.isNotEmpty)
              _buildLanguageChip(language),
            if (language != null && language.isNotEmpty)
              const SizedBox(height: 6),
            Text(
              widget.element.code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageChip(String language) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        language,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: Colors.black54,
        ),
      ),
    );
  }
}
