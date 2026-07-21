/// HeadingBlock：标题块（level 1-6，render + edit 双态）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
///
/// **双态切换**：
/// - [RenderMode.rendered]：显示标题文本，按 [HeadingElement.level] 1-6 渲染不同字号
/// - [RenderMode.editing]：显示 Markdown source（如 `## 标题`）
///
/// **字号映射**（参考 Material Design type scale，简化版）：
/// - h1: 28 / bold
/// - h2: 24 / bold
/// - h3: 22 / bold
/// - h4: 20 / w600
/// - h5: 18 / w600
/// - h6: 16 / w600 / italic
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/ → core/editing/。
library;

import 'package:flutter/material.dart';

import '../../data/models/document.dart';
import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';

/// 标题块（render + edit 双态，level 1-6）。
class HeadingBlock extends StatefulWidget {
  /// 当前块的 UI 视图状态。
  final BlockViewState state;

  /// 当前块的 AST 数据（[HeadingElement]）。
  final HeadingElement element;

  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const HeadingBlock({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  State<HeadingBlock> createState() => _HeadingBlockState();
}

class _HeadingBlockState extends State<HeadingBlock> {
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
  void didUpdateWidget(covariant HeadingBlock oldWidget) {
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
      maxLines: 1,
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.state.isFocused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.element.text,
          style: _styleForLevel(widget.element.level),
        ),
      ),
    );
  }

  /// 按 heading level 1-6 返回对应 [TextStyle]。
  TextStyle _styleForLevel(int level) {
    switch (level) {
      case 1:
        return const TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
      case 2:
        return const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
      case 3:
        return const TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
      case 4:
        return const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
      case 5:
        return const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
      case 6:
        return const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic);
      default:
        // 防御性兜底：level 越界（应为 1-6）回退到 h6 样式
        return const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    }
  }
}
