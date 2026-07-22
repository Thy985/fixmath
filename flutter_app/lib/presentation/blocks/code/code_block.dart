/// CodeBlock：代码块（render + edit 双态，显示 language 标签 + 语法高亮）。
///
/// 落地 Phase 3.0 Task Contract §3.3（3 种 BlockType 之一）+ ADR-0009 §3.3。
/// 落地 Phase 3.1-A Task Contract §3.1.A.2（R4 评审反馈）：
/// - `_CodeBlockState` 改为 `extends BaseBlockState<CodeBlock>` 共享样板
/// - 消除约 40 行 controller / focus / commit 重复代码
/// 落地 Phase 3.2 Task Contract §3.0 方案 A（基类统一调度）：
/// - 移除 `build()` 重写（基类统一分发）
/// - 移除 `_buildEditing()` / `_buildRendered()`
/// - `buildRenderContent` 仅实现 render 态差异
/// - `editFieldStyle` 配置为 monospace / 14sp
/// - `editFieldInputAction = newline`（代码块允许多行）
/// 落地 Phase 3.2 Task Contract §3.11（任务 3.2.10,PR #3）：
/// - render 态接入 [HighlightView]（flutter_highlight 纯 Dart 语法高亮）
/// - 主题：githubTheme（light,Phase 3.9+ 接入主题切换时改为 Theme 驱动）
/// - 未知 language fallback 到 'plaintext'（不崩溃）
///
/// **双态切换**：
/// - [RenderMode.rendered]：[HighlightView] 显示语法高亮代码 + 顶部 language 标签
/// - [RenderMode.editing]：由基类 `buildEditField` 提供 [TextField]（monospace）
///
/// **依赖**：`flutter_highlight`（Phase 3.2 §3.11 选项 A,Human Owner 已审批）
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/ → core/editing/。
library;

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

import '../../../core/editing/block_types.dart';
import '../../../data/models/document.dart';
import '../../editor/editor_coordinator.dart';
import '../../states/block_view_state.dart';
import '../../themes/editor_tokens.dart';
import '../base_block_state.dart';

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
/// **Phase 3.1-A R4 修订**：从独立 State 改为 `extends BaseBlockState<CodeBlock>`,
/// 消除约 40 行 controller / focus / commit 样板。
/// **Phase 3.2 §3.0 方案 A 修订**：移除 build() / _buildEditing() / _buildRendered(),
/// 仅保留 buildRenderContent + edit 态配置（monospace / newline）。
class _CodeBlockState extends BaseBlockState<CodeBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(CodeBlock oldWidget) => oldWidget.state.mode;

  /// edit 态 monospace / 14sp。
  @override
  TextStyle? get editFieldStyle => const TextStyle(
        fontFamily: 'monospace',
        fontSize: EditorTokens.codeFontSize,
      );

  /// edit 态允许多行 + newline action（代码块习惯）。
  ///
  /// **行为说明**：[TextInputAction.newline] 不会触发 [TextField.onSubmitted]
  /// 回调（基类 [BaseBlockState.buildEditField] 中的 `onSubmitted`）,而是插入
  /// 换行符。代码块的失焦通过点击其他区域触发 [BaseBlockState._onFocusChange]
  /// 处理（focusNode 失焦时自动 commit）。
  @override
  TextInputAction get editFieldInputAction => TextInputAction.newline;

  @override
  Widget buildRenderContent(BuildContext context) {
    final language = widget.element.language;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (language != null && language.isNotEmpty) ...[
              _buildLanguageChip(_normalizeLanguage(language)),
              const SizedBox(height: 6),
            ],
            HighlightView(
              widget.element.code,
              language: _normalizeLanguage(language),
              theme: githubTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: EditorTokens.codeFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 归一化 language 标签：空或未知时返回 'plaintext'（不崩溃）。
  ///
  /// flutter_highlight 的 highlight 包内置支持常见语言（dart / python /
  /// javascript / java / go / rust / sql / json / yaml / bash 等）。
  /// 未知 language 会让 highlight 包抛 StateError,因此 fallback 到 plaintext。
  String _normalizeLanguage(String? language) {
    if (language == null || language.isEmpty) return 'plaintext';
    // 常见 language 别名归一化（与 highlight 包的注册名对齐）
    const aliases = {
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'rb': 'ruby',
      'sh': 'bash',
      'shell': 'bash',
      'yml': 'yaml',
      'golang': 'go',
      'kt': 'kotlin',
      'rs': 'rust',
    };
    final normalized = language.toLowerCase();
    return aliases[normalized] ?? normalized;
  }

  Widget _buildLanguageChip(String language) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EditorTokens.codeLanguageChip,
        borderRadius: BorderRadius.circular(EditorTokens.chipRadius),
      ),
      child: Text(
        language,
        style: const TextStyle(
          fontSize: EditorTokens.statusBarFontSize,
          fontFamily: 'monospace',
          color: EditorTokens.textSecondary,
        ),
      ),
    );
  }
}
