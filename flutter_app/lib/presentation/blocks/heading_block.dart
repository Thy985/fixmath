/// HeadingBlock：标题块（level 1-6，render + edit 双态）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
/// 落地 Phase 3.1-A Task Contract §3.1.A.2（R4 评审反馈）：
/// - `_HeadingBlockState` 改为 `extends BaseBlockState<HeadingBlock>` 共享样板
/// - 消除约 40 行 controller / focus / commit 重复代码
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

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import '../editor/editor_coordinator.dart';
import '../states/block_view_state.dart';
import 'block_editing_mixin.dart';

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

/// 标题块 State：extends [BaseBlockState] 共享 controller / focus / commit 样板。
///
/// **Phase 3.1-A R4 修订**：从独立 State 改为 `extends BaseBlockState<HeadingBlock>`，
/// 消除约 40 行 controller / focus / commit 样板。
class _HeadingBlockState extends BaseBlockState<HeadingBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(HeadingBlock oldWidget) => oldWidget.state.mode;

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
      maxLines: 1,
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
