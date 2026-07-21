/// CodeBlock：代码块（render + edit 双态，显示 language 标签 + monospace）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
/// 落地 Phase 3.1-A Task Contract §3.1.A.2（R4 评审反馈）：
/// - `_CodeBlockState` 改为 `extends BaseBlockState<CodeBlock>` 共享样板
/// - 消除约 40 行 controller / focus / commit 重复代码
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

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';
import 'block_editing_mixin.dart';

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

/// 代码块 State：extends [BaseBlockState] 共享 controller / focus / commit 样板。
///
/// **Phase 3.1-A R4 修订**：从独立 State 改为 `extends BaseBlockState<CodeBlock>`，
/// 消除约 40 行 controller / focus / commit 样板。
class _CodeBlockState extends BaseBlockState<CodeBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(CodeBlock oldWidget) => oldWidget.state.mode;

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
      textInputAction: TextInputAction.newline,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSubmitted: (_) => focusNode.unfocus(),
    );
  }

  Widget _buildRendered() {
    final language = widget.element.language;
    return GestureDetector(
      onTap: onBlockTap,
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
