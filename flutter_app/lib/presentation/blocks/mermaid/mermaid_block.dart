/// MermaidBlock：Mermaid 图表块（render + edit 双态）。
///
/// 落地 Phase 3.2 Task Contract §3.3（任务 3.2.2）+ ADR-0009 §3.3。
///
/// **双态切换**：
/// - [RenderMode.rendered]：通过 [MermaidElementWidget] 调用
///   [MermaidService.renderToSvg] 异步获取 SVG,用 [flutter_svg] 绘制。
///   WebView 未就绪时显示占位（不崩溃）。
/// - [RenderMode.editing]：由基类 [buildEditField] 提供 [TextField]
///   （source 为 Mermaid 源码）
///
/// **视觉规范**（[ui-spec.md §2.6](../../design/ui-spec.md)）：
/// - 浅灰背景（与 CodeBlock 一致,Mermaid 属于"技术图表"）
/// - 圆角 4dp
/// - 居中显示（图表通常不需要左对齐）
///
/// **WebView 复用**（Hard Rule 8 + Task Contract §3.2.8）：
/// - 不自建 WebView 实例,完全依赖 [MermaidService] 的 static facade
/// - MermaidService 已管理单 WebView 实例 + LRU 缓存（256 entries）+ 并发控制
/// - 若 [MermaidService.isReady] 为 false（WebView 未 attach 或 reset）,
///   显示占位 + 源码预览（不抛错,允许用户在 edit 态修正源码）
///
/// **AST 类型**：[MermaidElement]（已存在于 document.dart,字段 `code`）
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/ → core/editing/ → core/services/。
library;

import 'package:flutter/material.dart';

import '../../../core/editing/block_types.dart';
import '../../../core/services/mermaid_renderer.dart';
import '../../../core/services/mermaid_service.dart';
import '../../../data/models/document.dart';
import '../../editor/editor_coordinator.dart';
import '../../states/block_view_state.dart';
import '../../themes/editor_tokens.dart';
import '../base_block_state.dart';

/// Mermaid 图表块 Widget（StatefulWidget,依赖 BaseBlockState 共享样板）。
class MermaidBlock extends StatefulWidget {
  /// 当前块的 UI 视图状态。
  final BlockViewState state;

  /// 当前块的 AST 数据（[MermaidElement]）。
  final MermaidElement element;

  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const MermaidBlock({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  State<MermaidBlock> createState() => _MermaidBlockState();
}

/// Mermaid 块 State：extends [BaseBlockState] 共享 controller / focus / commit 样板。
///
/// **Phase 3.2 §3.0 方案 A**：仅保留 buildRenderContent + edit 态配置,
/// 不重写 build()（基类统一调度）。
class _MermaidBlockState extends BaseBlockState<MermaidBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(MermaidBlock oldWidget) => oldWidget.state.mode;

  /// edit 态多行（Mermaid 源码多行）。
  @override
  int? get editFieldMaxLines => null;

  /// edit 态 monospace 字体（与 CodeBlock 一致,源码可读）。
  @override
  TextStyle? get editFieldStyle => const TextStyle(
        fontFamily: 'monospace',
        fontSize: EditorTokens.codeFontSize,
      );

  /// edit 态 newline action（Mermaid 源码多行,允许换行）。
  @override
  TextInputAction get editFieldInputAction => TextInputAction.newline;

  @override
  Widget buildRenderContent(BuildContext context) {
    return GestureDetector(
      onTap: onBlockTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: EditorTokens.codeBackground,
          borderRadius: BorderRadius.circular(EditorTokens.blockRadius),
          border: Border.all(
            color: widget.state.isFocused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                : EditorTokens.borderDefault,
          ),
        ),
        child: _buildMermaidContent(),
      ),
    );
  }

  /// 构建 Mermaid 内容：WebView 就绪用 [MermaidElementWidget],否则占位。
  Widget _buildMermaidContent() {
    // WebView 未就绪：显示占位 + 源码预览（不崩溃）
    if (!MermaidService.isReady) {
      return _buildWebViewNotReadyPlaceholder();
    }
    // WebView 就绪：用 MermaidElementWidget 异步渲染 SVG
    return MermaidElementWidget(
      code: widget.element.code,
      theme: MermaidTheme.light, // Phase 3.2 固定 light,主题切换留 Phase 3.9+
    );
  }

  /// WebView 未就绪时的占位：显示提示 + 源码预览。
  Widget _buildWebViewNotReadyPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sync, size: 14, color: EditorTokens.textSecondary),
            SizedBox(width: 6),
            Text(
              'WebView 预热中（Mermaid 图表将在就绪后渲染）',
              style: TextStyle(
                fontSize: EditorTokens.statusBarFontSize,
                color: EditorTokens.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: EditorTokens.tableHeaderBackground,
            borderRadius: BorderRadius.circular(EditorTokens.chipRadius),
          ),
          child: Text(
            widget.element.code,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: EditorTokens.codeFontSize,
              color: EditorTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
